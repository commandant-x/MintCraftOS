local config = require("system.libraries.config")
local version = require("system.libraries.version")
local source = require("system.libraries.update_source")

local M = {
  cfgPath = "/system/config/update.cfg",
  rollbackRoot = "/var/backups/update",
  status = {
    localVersion = "unknown",
    remoteVersion = "unknown",
    updateAvailable = false,
    message = "never checked",
  },
}

local function trim(value)
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
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
  local nextPath, oldPath = stage .. "/next", stage .. "/previous"
  local copied, err = pcall(fs.copy, from, nextPath)
  if not copied then
    pcall(fs.delete, stage)
    return false, "Restore staging failed: " .. tostring(err) .. "; backup retained"
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
    pcall(fs.delete, stage)
    return false, "Restore replacement failed: " .. tostring(moveErr)
  end
  fs.delete(stage)
  return true
end

local function httpGet(url)
  if not http or not http.get then return nil, "HTTP API disabled" end
  local ok, handle, problem, failureHandle = pcall(http.get, url, { ["User-Agent"] = "MintCraftOS" })
  if not ok then return nil, tostring(handle) end
  if not handle then
    if failureHandle and failureHandle.close then pcall(failureHandle.close) end
    return nil, tostring(problem or "request failed")
  end
  local codeOK,code=pcall(function() return handle.getResponseCode and handle.getResponseCode() or 200 end)
  if not codeOK or code<200 or code>=300 then
    pcall(handle.close) return nil,"GitHub HTTP "..tostring(code)
  end
  local readOk, data = pcall(handle.readAll)
  pcall(handle.close)
  if not readOk then return nil, tostring(data) end
  return data
end

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

function M.check()
  local cfg = M.loadConfig()
  local localVersion = M.localVersion()
  local remoteVersion, err = M.remoteVersion()

  if not remoteVersion then
    M.status = {
      localVersion = localVersion,
      remoteVersion = "unknown",
      updateAvailable = false,
      message = err or "check failed",
    }
  else
    local comparison, problem = version.compare(remoteVersion, localVersion)
    M.status = {
      localVersion = localVersion,
      remoteVersion = remoteVersion,
      updateAvailable = comparison == 1,
      message = problem or (comparison == 1 and "update available" or (comparison == -1 and "local version is newer" or "up to date")),
    }
  end

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
    pinned, err = source.resolve(M.loadConfig(), httpGet)
    if not pinned then return nil, err end
  end
  local url = source.url(pinned, "install.lua")
  local data, err = httpGet(url)
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

local function rollback()
  local info = M.rollbackInfo()
  if not info then return false, "no rollback backup" end
  local backupDir = M.rollbackRoot .. "/" .. info.id
  local manifest = config.load(backupDir .. "/manifest.cfg", nil)
  if type(manifest) ~= "table" or type(manifest.paths) ~= "table" or manifest.id ~= info.id then
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
        path:find("..",1,true) or path:find("\\",1,true) or type(manifest.existed)~="table" or type(manifest.existed[path])~="boolean" then return false,"invalid file rollback entry" end
      if path:match("^/system/config/") or path:match("^/home/") or path:match("^/packages/") or path:sub(-1)=="/" then return false,"User data is not part of a file rollback" end
      if manifest.existed[path] and fs.isDir(backupDir..path) then return false,"Expected rollback file" end
    elseif not allowed[path] then return false,"invalid rollback path list" end
    seen[path], count = true, count + 1
    if (not fileMode or manifest.existed[path]) and not fs.exists(backupDir .. path) then return false, "missing backup " .. path end
  end
  if count == 0 or count ~= #manifest.paths then return false, "empty or incomplete rollback manifest" end

  for _, path in ipairs(manifest.paths) do
    local ok,err
    if manifest.kind=="files" and not manifest.existed[path] then
      ok,err=pcall(function() if fs.exists(path) then assert(not fs.isDir(path),"Unexpected directory at "..path) fs.delete(path) end end)
    else ok,err=restoreTree(backupDir..path,path) end
    if not ok then return false, err end
  end
  return true, "rollback restored " .. tostring(manifest.fromVersion or "previous") .. ", reboot required"
end

function M.rollback()
  local ok, result, detail = pcall(rollback)
  if not ok then return false, "Rollback failed: " .. tostring(result) .. "; backup retained" end
  return result, detail
end

function M.apply()
  local pinned, err = source.resolve(M.loadConfig(), httpGet)
  if not pinned then return false, err end
  local remote, problem = httpGet(source.url(pinned, "VERSION"))
  if not remote then return false, problem end
  local comparison, invalid = version.compare(trim(remote), M.localVersion())
  if comparison ~= 1 then return false, invalid or "Pinned release is not newer than installed version" end
  local data,downloadErr=httpGet(source.url(pinned,"install.lua"))
  if not data then return false,downloadErr end
  if not data:find("-- MintCraft installer protocol: 2",1,true) then return false,"Unsupported installer; use a pinned manual installation" end
  local environment=setmetatable({print=function() end},{__index=_ENV})
  local backedUp=false
  environment.mintcraftInstallOptions={beforeInstall=function(plan)
    assert(version.compare(trim(plan.version),trim(remote))==0,"Pinned installer/version mismatch")
    local free=fs.getFreeSpace and fs.getFreeSpace("/")
    local required=plan.stageBytes+plan.backupBytes*2+math.max(32768,#plan.changed*256)
    if type(free)=="number" and free<required then error("UPD-DISK: need "..required.." free bytes; available "..free..". Backups retained.") end
    local ok,backup=M.createRollback("before update",plan.changed)
    assert(ok,tostring(backup)) backedUp=true
  end}
  local fn,loadErr=load(data,"@github-update-"..pinned.sha,"t",environment)
  if not fn then return false,loadErr end
  local ok, runErr = pcall(fn)
  if not ok then return false, tostring(runErr) end
  if not backedUp then return false,"Installer did not create a rollback checkpoint" end
  M.status.localVersion=M.localVersion() M.status.updateAvailable=false M.status.message="Installed; reboot required"
  return true, "installer finished, reboot required"
end

function M.start(ctx)
  M.stop()
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
    M.stop()
  end
  table.insert(M.listeners, ctx.eventBus:on("http_success", function(address, handle)
    if address ~= url then return end
    local ok, data = pcall(handle.readAll)
    pcall(handle.close)
    finish(ok and trim(data) or nil, not ok and tostring(data) or nil)
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
  if M.ctx and M.ctx.eventBus then
    for _, id in ipairs(M.listeners or {}) do M.ctx.eventBus:off(id) end
  end
  if M.timer and os.cancelTimer then os.cancelTimer(M.timer) end
  M.ctx, M.listeners, M.timer = nil, {}, nil
end

return M
