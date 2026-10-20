local config = require("system.libraries.config")
local version = require("system.libraries.version")
local source = require("system.libraries.update_source")
local safeWrite = require("system.libraries.safe_write")
local httpClient = require("system.network.http_client")
local operation
local rootContext,controller

local M = {
  maxInstallerBytes = 4194304,
  cfgPath = "/system/config/update.cfg",
  rollbackRoot = "/var/backups/update",
  status = {
    localVersion = "unknown",
    remoteVersion = "unknown",
    updateAvailable = false,
    message = "never checked",
  },
}

local function phase(options,name,message,done,total)
  if options and type(options.progress)=="function" then pcall(options.progress,name,message,done,total) end
end
local function authorize(options)
  if options and options.authorize then local ok,err=options.authorize() if not ok then error("UPD-AUTH: "..tostring(err),0) end end
end
local function commit(options)
  authorize(options)
  if options and options.commit then options.commit() end
end

local function trim(value)
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function validFileRollback(path)
  if type(path) ~= "string" or path:sub(-1) == "/" or path:find("//", 1, true)
    or path:find("[%c:\\]") or path == "/system/config" or path:match("^/system/config/") then return false end
  for part in path:gmatch("[^/]+") do
    if part == "." or part == ".." or part:find(".mintcraft-save", 1, true) then return false end
  end
  return path == "/VERSION" or path == "/boot.lua" or path == "/startup.lua"
    or path:match("^/system/") or path:match("^/apps/")
end

local function readFile(path)
  if not fs.exists(path) then return nil end
  local handle = fs.open(path, "r")
  if not handle then return nil end
  local data = handle.readAll()
  handle.close()
  return data
end

local function copyTree(from, to)
  if not fs.exists(from) then return true end
  if fs.exists(to) then fs.delete(to) end
  local dir = fs.getDir(to)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  fs.copy(from, to)
  return true
end

local function restoreTree(from, to)
  if not fs.exists(from) then return false, "missing backup " .. tostring(from) end
  local stage = "/var/tmp/mintcraft-restore"
  if fs.exists(stage) then return false, "Interrupted restore at " .. stage .. "; inspection required" end
  fs.makeDir(stage)
  assert(config.save(stage .. "/target.cfg", to))
  local nextPath, oldPath = stage .. "/next", stage .. "/previous"
  local copied, err = pcall(fs.copy, from, nextPath)
  if not copied then
    pcall(fs.delete, stage)
    return false, "Restore staging failed: " .. tostring(err) .. "; backup retained"
  end
  if to == "/system" and fs.exists("/system/config") then
    if fs.exists(nextPath .. "/config") then fs.delete(nextPath .. "/config") end
    fs.copy("/system/config", nextPath .. "/config")
  end
  if to == "/apps" and fs.exists("/apps") then
    local core = {browser=true,combat=true,crafttube=true,devices=true,editor=true,files=true,logs=true,
      messenger=true,navigation=true,services=true,settings=true,store=true,taskmanager=true,terminal=true,update=true}
    for _, name in ipairs(fs.list("/apps")) do
      if not core[name] then
        if fs.exists(nextPath .. "/" .. name) then fs.delete(nextPath .. "/" .. name) end
        fs.copy("/apps/" .. name, nextPath .. "/" .. name)
      end
    end
  end
  local hadPrevious = fs.exists(to)
  local moved, moveErr = pcall(function()
    if hadPrevious then fs.move(to, oldPath) end
    fs.move(nextPath, to)
  end)
  if not moved then
    if fs.exists(oldPath) and not fs.exists(to) then
      local recovered = pcall(fs.move, oldPath, to)
      if not recovered then return false, "Restore interrupted; previous data at " .. oldPath end
    end
    if fs.exists(oldPath) then return false, "Restore interrupted; previous data retained at " .. oldPath end
    pcall(fs.delete, stage)
    return false, "Restore replacement failed: " .. tostring(moveErr)
  end
  fs.delete(stage)
  return true
end

local function responseBody(handle, url, limit)
  local response, err = httpClient.readResponse(handle, limit, url)
  if not response then return nil, err end
  if type(response.code) ~= "number" or response.code < 200 or response.code >= 300 then
    return nil, "GitHub HTTP " .. tostring(response.code)
  end
  return response.body
end

local function httpGet(url, limit)
  if not http or not http.get then return nil, "HTTP API disabled" end
  local ok, handle, problem, failureHandle = pcall(http.get, url, { ["User-Agent"] = "MintCraftOS" })
  if not ok then return nil, tostring(handle) end
  if not handle then
    if failureHandle and failureHandle.close then pcall(failureHandle.close) end
    return nil, tostring(problem or "request failed")
  end
  return responseBody(handle, url, limit or 256)
end

local function getCommit(url) return httpGet(url, 262144) end

function M.loadConfig()
  local cfg=config.load(M.cfgPath,{})
  if type(cfg)~="table" then cfg={} end
  if type(cfg.repo)~="string" then cfg.repo="commandant-x/MintCraftOS" end
  if type(cfg.branch)~="string" then cfg.branch="main" end
  cfg.autoCheck=cfg.autoCheck~=false cfg.autoApply=false
  return cfg
end

local ROLLBACK_PATHS = {
  "/VERSION",
  "/boot.lua",
  "/startup.lua",
  "/system",
  "/apps",
  "/packages",
}

function M.localVersion()
  return trim(readFile("/VERSION") or "0.0.0")
end

function M.remoteVersion()
  local cfg = M.loadConfig()
  local url = "https://raw.githubusercontent.com/" .. cfg.repo .. "/" .. cfg.branch .. "/VERSION"
  local data, err = httpGet(url)
  if not data then return nil, err end
  return trim(data)
end

function M.check(options)
  authorize(options)
  local cfg = M.loadConfig()
  local localVersion = M.localVersion()
  phase(options,"resolve","Resolving GitHub commit")
  local pinned,err=source.resolve(cfg,getCommit)
  local remoteVersion
  if pinned then
    phase(options,"version","Reading pinned VERSION")
    remoteVersion,err=httpGet(source.url(pinned,"VERSION"))
    if remoteVersion then remoteVersion=trim(remoteVersion) end
  end

  if not remoteVersion then
    M.status = {
      localVersion = localVersion,
      remoteVersion = "unknown",
      updateAvailable = false,
      message = err or "check failed",
      ok = false,
    }
  else
    local comparison, problem = version.compare(remoteVersion, localVersion)
    M.status = {
      localVersion = localVersion,
      remoteVersion = remoteVersion,
      updateAvailable = comparison == 1,
      message = problem or (comparison == 1 and "update available" or (comparison == -1 and "local version is newer" or "up to date")),
      ok = comparison~=nil,
      source = {repo=pinned.repo,sha=pinned.sha,ref=cfg.branch},
    }
  end

  authorize(options)
  cfg=M.loadConfig()
  cfg.lastStatus = M.status.message
  cfg.lastLocalVersion = M.status.localVersion
  cfg.lastRemoteVersion = M.status.remoteVersion
  cfg.lastCheckedUptime = os.clock()
  config.save(M.cfgPath, cfg)
  return M.status
end

function M.downloadInstaller(pinned)
  if not pinned then
    local err
    pinned, err = source.resolve(M.loadConfig(), getCommit)
    if not pinned then return nil, err end
  end
  local url = source.url(pinned, "install.lua")
  local data, err = httpGet(url, M.maxInstallerBytes)
  if not data then return nil, err end

  local path = "/var/tmp/mintcraft_update.lua"
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local handle = fs.open(path, "w")
  if not handle then return nil, "cannot write update installer" end
  handle.write(data)
  handle.close()
  return path
end

function M.rollbackInfo()
  local latestPath = M.rollbackRoot .. "/latest.cfg"
  if not fs.exists(latestPath) then latestPath = M.rollbackRoot .. "/previous.cfg" end
  if not fs.exists(latestPath) then return nil end
  local data = config.load(latestPath, nil)
  if type(data) ~= "table" or type(data.id) ~= "string" or not data.id:match("^%d+%-?%d*$") then return nil end
  data.path = M.rollbackRoot .. "/" .. data.id
  return data
end

local function createRollback(reason,changes)
  local storage = M.storageInfo()
  local estimate = 0
  for _, entry in ipairs(changes or ROLLBACK_PATHS) do
    estimate = estimate + M.storageBytes(changes and ("/" .. entry) or entry)
  end
  if storage.policy.quotaBytes > 0 and storage.bytes + estimate + 32768 > storage.policy.quotaBytes then
    error("Backup quota exceeded; explicitly manage retained checkpoints before retrying")
  end
  fs.makeDir(M.rollbackRoot)

  local base = tostring(math.floor(os.epoch and os.epoch("utc") or (os.clock() * 1000)))
  local id, suffix = base, 0
  while fs.exists(M.rollbackRoot .. "/" .. id) do
    suffix = suffix + 1
    id = base .. "-" .. suffix
  end
  local backupDir = M.rollbackRoot .. "/" .. id
  fs.makeDir(backupDir)
  local manifest = {
    id = id,
    reason = reason or "update",
    fromVersion = M.localVersion(),
    createdUptime = os.clock(),
    paths = {},
  }
  if changes then manifest.kind="files" manifest.existed={} end

  for _,entry in ipairs(changes or ROLLBACK_PATHS) do
    local path=changes and ("/"..entry) or entry
    local userData=changes and (path:match("^/system/config/") or path:match("^/home/") or path:match("^/packages/"))
    if not userData then
    if changes then
      assert(path=="/VERSION" or path=="/boot.lua" or path=="/startup.lua" or path:match("^/system/") or path:match("^/apps/") or path:match("^/packages/") or path:match("^/home/"),"Invalid update path")
      assert(not path:find("..",1,true) and not path:find("\\",1,true),"Invalid update path")
      manifest.existed[path]=fs.exists(path)
    end
    if fs.exists(path) then
      local target = backupDir .. path
      copyTree(path, target)
      table.insert(manifest.paths, path)
    elseif changes then table.insert(manifest.paths,path)
    end
    end
  end

  assert(config.save(backupDir .. "/manifest.cfg", manifest))
  local latest = M.rollbackRoot .. "/latest.cfg"
  local previous = M.rollbackRoot .. "/previous.cfg"
  local pending = backupDir .. "/latest.cfg"
  assert(config.save(pending, manifest))
  if fs.exists(latest) then
    if fs.exists(previous) then fs.delete(previous) end
    fs.move(latest, previous)
  end
  fs.move(pending, latest)
  return true, manifest
end

function M.createRollback(reason,changes)
  local ok, result, detail = pcall(createRollback, reason,changes)
  if not ok then return false, tostring(result) end
  return result, detail
end

local function rollback(options)
  authorize(options)
  if options and options.localVersion and M.localVersion()~=options.localVersion then return false,"UPD-STALE: installed version changed" end
  local selected=M.rollbackInfo()
  if options and options.backupId and (not selected or selected.id~=options.backupId) then return false,"UPD-STALE: rollback checkpoint changed" end
  if fs.exists("/var/tmp/mintcraft-package") or fs.exists("/var/tmp/mintcraft-install") then
    return false, "Recover pending installation before rollback"
  end
  commit(options)
  phase(options,"recovery","Checking pending restore")
  local recovered, recoveryErr = safeWrite.recoverRestore()
  if not recovered then return false, recoveryErr end
  local info = M.rollbackInfo()
  if not info then return false, "no rollback backup" end
  local backupDir = M.rollbackRoot .. "/" .. info.id
  local manifest = config.load(backupDir .. "/manifest.cfg", nil)
  if type(manifest) ~= "table" or type(manifest.paths) ~= "table" or manifest.id ~= info.id
    or (manifest.kind ~= nil and manifest.kind ~= "files") then
    return false, "invalid rollback manifest"
  end
  local allowed, seen, count = {}, {}, 0
  for _, path in ipairs(ROLLBACK_PATHS) do allowed[path] = true end
  for index, path in pairs(manifest.paths) do
    if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #manifest.paths
      or type(path) ~= "string" or seen[path] then
      return false, "invalid rollback path list"
    end
    local fileMode=manifest.kind=="files"
    if fileMode then
      if not (path=="/VERSION" or path=="/boot.lua" or path=="/startup.lua" or path:match("^/system/") or path:match("^/apps/") or path:match("^/packages/") or path:match("^/home/")) or
        path:find("..",1,true) or path:find("//",1,true) or path:find("[%c:\\]") or type(manifest.existed)~="table" or type(manifest.existed[path])~="boolean" then return false,"invalid file rollback entry" end
      if path:match("^/system/config/") or path:match("^/home/") or path:match("^/packages/") or path:sub(-1)=="/" then return false,"User data is not part of a file rollback" end
      if manifest.existed[path] and fs.isDir(backupDir..path) then return false,"Expected rollback file" end
      if fs.exists(path) and fs.isDir(path) then return false,"Expected live file" end
      if not validFileRollback(path) then return false, "Non-canonical rollback path" end
    elseif not allowed[path] then return false,"invalid rollback path list" end
    seen[path], count = true, count + 1
    if (not fileMode or manifest.existed[path]) and not fs.exists(backupDir .. path) then return false, "missing backup " .. path end
  end
  if count == 0 or count ~= #manifest.paths then return false, "empty or incomplete rollback manifest" end

  assert(config.save("/var/tmp/mintcraft-rollback.cfg", {id=info.id}))

  for index, path in ipairs(manifest.paths) do
    phase(options,"rollback",path,index-1,#manifest.paths)
    local ok,err
    if path == "/packages" then
      ok = true -- Package databases and user-installed packages are not system rollback data.
    elseif manifest.kind=="files" and not manifest.existed[path] then
      ok,err=pcall(function() if fs.exists(path) then assert(not fs.isDir(path),"Unexpected directory at "..path) fs.delete(path) end end)
    else ok,err=restoreTree(backupDir..path,path) end
    if not ok then return false, err end
  end
  fs.delete("/var/tmp/mintcraft-rollback.cfg")
  phase(options,"rollback","Checkpoint restored",#manifest.paths,#manifest.paths)
  M.status.localVersion=M.localVersion() M.status.source=nil M.status.updateAvailable=false
  return true, "rollback restored " .. tostring(manifest.fromVersion or "previous") .. ", reboot required"
end

local function exclusive(name, fn)
  if operation or _G.mintcraftStorageOperation then return false, "Update operation in progress: " .. tostring(operation or _G.mintcraftStorageOperation) end
  operation = name
  _G.mintcraftStorageOperation = name
  local ok, result, detail = pcall(fn)
  operation = nil
  _G.mintcraftStorageOperation = nil
  if not ok then return false, name .. " failed: " .. tostring(result) end
  return result, detail
end

function M.rollback(options) return exclusive("Rollback",function() return rollback(options) end) end

local function apply(options)
  authorize(options)
  if options and options.localVersion and M.localVersion()~=options.localVersion then return false,"UPD-STALE: installed version changed" end
  if fs.exists("/var/tmp/mintcraft-package") or fs.exists("/var/tmp/mintcraft-install") or fs.exists("/var/tmp/mintcraft-rollback.cfg")
    or fs.exists("/var/tmp/mintcraft-restore") then return false, "Recover pending update before applying" end
  phase(options,"resolve","Resolving release source")
  local pinned, err
  if options and options.source then pinned={repo=options.source.repo,sha=options.source.sha}
  else pinned,err=source.resolve(M.loadConfig(),getCommit) end
  if not pinned then return false, err end
  phase(options,"version","Reading pinned VERSION")
  local remote, problem = httpGet(source.url(pinned, "VERSION"))
  if not remote then return false, problem end
  if options and options.version and trim(remote)~=options.version then return false,"UPD-STALE: confirmed release version changed" end
  local comparison, invalid = version.compare(trim(remote), M.localVersion())
  if comparison ~= 1 then return false, invalid or "Pinned release is not newer than installed version" end
  phase(options,"download","Downloading pinned installer")
  local data,downloadErr=httpGet(source.url(pinned,"install.lua"),M.maxInstallerBytes)
  if not data then return false,downloadErr end
  if not data:find("-- MintCraft installer protocol: 2",1,true) then return false,"Unsupported installer; use a pinned manual installation" end
  local environment=setmetatable({print=function() end},{__index=_ENV})
  local backedUp,committed=false,false
  environment.mintcraftInstallOptions={beforeInstall=function(plan)
    authorize(options)
    assert(version.compare(trim(plan.version),trim(remote))==0,"Pinned installer/version mismatch")
    assert(version.compare(trim(plan.version), M.localVersion()) == 1, "Installed version changed; check again")
    local free=fs.getFreeSpace and fs.getFreeSpace("/")
    local required=plan.stageBytes+plan.backupBytes*2+math.max(32768,#plan.changed*256)
    if type(free)=="number" and free<required then error("UPD-DISK: need "..required.." free bytes; available "..free..". Backups retained.") end
    commit(options)
    phase(options,"checkpoint","Creating rollback checkpoint")
    local ok,backup=M.createRollback("before update",plan.changed)
    assert(ok,tostring(backup)) backedUp=true
    assert(version.compare(trim(plan.version), M.localVersion()) == 1, "Installed version changed during checkpoint")
    phase(options,"install","Running transactional installer")
  end,onProgress=function(name,path,done,total) phase(options,name,path,done,total) end,
    onCommitted=function(installed) committed=trim(installed)==trim(remote) end}
  local fn,loadErr=load(data,"@github-update-"..pinned.sha,"t",environment)
  if not fn then return false,loadErr end
  local ok, runErr = pcall(fn)
  if not ok then return false, tostring(runErr) end
  if not backedUp then return false,"Installer did not create a rollback checkpoint" end
  if not committed or M.localVersion()~=trim(remote) then return false,"UPD-STATE: installer commit/version not verified; inspect rollback checkpoint" end
  M.status.localVersion=M.localVersion() M.status.updateAvailable=false M.status.message="Installed; reboot required"
  return true, "installer finished, reboot required"
end

function M.apply(options) return exclusive("Apply",function() return apply(options) end) end

function M.storageBytes(path)
  if not fs.exists(path) then return 0 end
  if fs.isDir(path) then
    local total = 0
    for _, name in ipairs(fs.list(path)) do total = total + M.storageBytes(path .. "/" .. name) end
    return total
  end
  return fs.getSize and fs.getSize(path) or #(readFile(path) or "")
end

function M.storageInfo()
  local policy = config.load("/system/config/update-storage.cfg", {})
  if type(policy) ~= "table" then policy = {} end
  policy = {
    quotaBytes = type(policy.quotaBytes) == "number" and math.max(0, policy.quotaBytes) or 0,
    retainCount = type(policy.retainCount) == "number" and math.max(1, math.floor(policy.retainCount)) or 3,
  }
  local protected, rows, total, validCount = {}, {}, 0, 0
  for _, pointer in ipairs({"latest.cfg", "previous.cfg"}) do
    local data = config.load(M.rollbackRoot .. "/" .. pointer, nil)
    if type(data) == "table" and type(data.id) == "string" then protected[data.id] = true end
  end
  local pending = config.load("/var/tmp/mintcraft-rollback.cfg", nil)
  if type(pending) == "table" and type(pending.id) == "string" then protected[pending.id] = true end
  if fs.exists(M.rollbackRoot) and fs.list then
    for _, id in ipairs(fs.list(M.rollbackRoot)) do
      local path = M.rollbackRoot .. "/" .. id
      if id:match("^%d+%-?%d*$") and fs.isDir(path) then
        local bytes = M.storageBytes(path)
        local manifest = config.load(path .. "/manifest.cfg", nil)
        local valid, count, seen = type(manifest) == "table" and manifest.id == id
          and type(manifest.paths) == "table" and (manifest.kind == nil or manifest.kind == "files"), 0, {}
        if valid then
          local full = {} for _, key in ipairs(ROLLBACK_PATHS) do full[key] = true end
          for index, key in pairs(manifest.paths) do
            if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #manifest.paths
              or type(key) ~= "string" or seen[key] then valid = false break end
            seen[key], count = true, count + 1
            if manifest.kind == "files" then
              if not validFileRollback(key) or type(manifest.existed) ~= "table" or type(manifest.existed[key]) ~= "boolean" then valid = false break end
            elseif not full[key] then valid = false break end
            if manifest.kind ~= "files" or manifest.existed[key] then
              if not fs.exists(path .. key) then valid = false break end
              local directory = manifest.kind ~= "files" and (key == "/system" or key == "/apps" or key == "/packages")
              if fs.isDir(path .. key) ~= (directory or false) then valid = false break end
            end
          end
          valid = valid and count > 0 and count == #manifest.paths
        end
        if valid then validCount = validCount + 1 end
        rows[#rows+1] = {id=id, bytes=bytes, valid=valid, protected=protected[id] == true or not valid}
        total = total + bytes
      end
    end
  end
  table.sort(rows, function(a,b)
    local an, bn = tonumber(a.id:match("^%d+")), tonumber(b.id:match("^%d+"))
    return an == bn and a.id > b.id or an > bn
  end)
  for _, row in ipairs(rows) do if #rows == 1 or (validCount == 1 and row.valid) then row.protected = true end end
  return {bytes=total, backups=rows, policy=policy, busy=operation}
end

function M.setStoragePolicy(policy)
  if type(policy) ~= "table" or type(policy.quotaBytes) ~= "number" or policy.quotaBytes < 0
    or policy.quotaBytes ~= policy.quotaBytes or policy.quotaBytes == math.huge
    or type(policy.retainCount) ~= "number" or policy.retainCount < 1 or policy.retainCount % 1 ~= 0 then
    return false, "Invalid storage policy"
  end
  return config.save("/system/config/update-storage.cfg", {quotaBytes=policy.quotaBytes, retainCount=policy.retainCount})
end

function M.purgeBackup(id, confirmed)
  if confirmed ~= true then return false, "Explicit confirmation required" end
  if operation or _G.mintcraftStorageOperation then return false, "Update operation in progress" end
  if fs.exists("/var/tmp/mintcraft-rollback.cfg") or fs.exists("/var/tmp/mintcraft-restore")
    or fs.exists("/var/tmp/mintcraft-install") then return false, "Recovery pending; backups retained" end
  for _, row in ipairs(M.storageInfo().backups) do
    if row.id == id then
      if row.protected then return false, "Checkpoint is protected" end
      local ok, err = pcall(fs.delete, M.rollbackRoot .. "/" .. id)
      return ok, ok and "Backup purged" or tostring(err)
    end
  end
  return false, "Unknown backup"
end

function M.pruneBackups(confirmed)
  if confirmed ~= true then return false, "Explicit confirmation required" end
  local info, removed = M.storageInfo(), 0
  for i = #info.backups, info.policy.retainCount + 1, -1 do
    local row = info.backups[i]
    if not row.protected then
      local ok, err = M.purgeBackup(row.id, true)
      if not ok then return false, err end
      removed = removed + 1
    end
  end
  return true, "Purged " .. removed .. " backups"
end

M.report = M.storageInfo
function M.cleanup(kind, options)
  options = options or {}
  if kind ~= "updates" then return false, "Unknown storage kind" end
  if options.id then return M.purgeBackup(options.id, options.confirm == true) end
  return M.pruneBackups(options.confirm == true)
end

local function stopAutomatic()
  if M.ctx and M.ctx.eventBus then
    for _, id in ipairs(M.listeners or {}) do M.ctx.eventBus:off(id) end
  end
  if M.timer and os.cancelTimer then os.cancelTimer(M.timer) end
  M.ctx, M.listeners, M.timer = nil, {}, nil
end

local function control()
  if not rootContext or not rootContext.scheduler then return nil,"UPD-SERVICE: scheduler unavailable" end
  if not controller then controller=require("system.services.update_control").new(rootContext,M) end
  return controller
end
function M.prepareAction(actor,action)
  local worker,err=control() if not worker then return false,err end
  return worker:prepare(actor,action)
end
function M.requestAction(actor,action,token)
  local worker,err=control() if not worker then return false,err end
  local ok,result=worker:request(actor,action,token)
  if ok then stopAutomatic() end
  return ok,result
end
function M.controlStatus() return controller and controller:status() or {busy=false,phase="idle",message="Ready"} end

function M.start(ctx)
  if controller and controller:status().busy then return false,"Update transaction running" end
  if controller then controller:stop() controller=nil end
  stopAutomatic()
  rootContext=ctx
  M.status.localVersion=M.localVersion()
  local cfg = M.loadConfig()
  if not cfg.autoCheck then return end
  if not ctx or not ctx.eventBus or not http or not http.request then
    M.status.message = "Automatic check unavailable"
    return
  end
  M.ctx, M.listeners = ctx, {}
  local url = "https://raw.githubusercontent.com/" .. cfg.repo .. "/" .. cfg.branch .. "/VERSION?mintcraft_auto=1"
  local function finish(remote, problem)
    local localVersion = M.localVersion()
    local comparison, invalid = version.compare(remote, localVersion)
    M.status = {
      localVersion = localVersion, remoteVersion = remote or "unknown",
      updateAvailable = comparison == 1,
      message = problem or invalid or (comparison == 1 and "update available" or "no newer release"),
    }
    if M.status.updateAvailable and ctx.notifications then
      ctx.notifications:push("info", "Update", "Version " .. remote .. " available; open Update to install", 6)
    end
    stopAutomatic()
  end
  table.insert(M.listeners, ctx.eventBus:on("http_success", function(address, handle)
    if address ~= url then return end
    local data, err = responseBody(handle, url, 256)
    finish(data and trim(data) or nil, err)
  end))
  table.insert(M.listeners, ctx.eventBus:on("http_failure", function(address, problem, handle)
    if address ~= url then return end
    if handle then pcall(handle.close) end
    finish(nil, tostring(problem))
  end))
  table.insert(M.listeners, ctx.eventBus:on("timer", function(id)
    if id == M.timer then finish(nil, "Update check timed out") end
  end))
  M.timer = os.startTimer(15)
  local ok, accepted, err = pcall(http.request, url)
  if not ok or not accepted then finish(nil, tostring(err or accepted)) end
end

function M.stop()
  if operation or controller and controller:status().busy then return false,"Update transaction running; cannot stop" end
  stopAutomatic()
  if controller then controller:stop() controller=nil end
  rootContext=nil
  return true
end

return M
