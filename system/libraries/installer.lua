local M = {}
local root = "/var/tmp/mintcraft-install"

local function write(path, content)
  local dir = fs.getDir(path)
  if not fs.exists(dir) then fs.makeDir(dir) end
  local h = assert(fs.open(path, "w"), "Cannot write " .. path)
  local ok, err = pcall(h.write, content)
  h.close()
  if not ok then error(err) end
end

local function validPath(path)
  if type(path) ~= "string" or path == "" or path:sub(1, 1) == "/" or path:sub(-1) == "/"
    or path:find("//", 1, true) or path:find("[%c:]") or path:find("\\", 1, true) then return false end
  for part in path:gmatch("[^/]+") do if part == "." or part == ".." then return false end end
  return path == "VERSION" or path == "boot.lua" or path == "startup.lua"
    or path:match("^system/") or path:match("^apps/")
    or path:match("^home/") or path:match("^packages/")
end

local function preserved(path)
  return path:match("^system/config/") or path:match("^home/") or path:match("^packages/")
end
local function identical(path,content)
  if not fs.exists(path) or fs.isDir(path) then return false end
  local h=assert(fs.open(path,"r"),"Cannot read "..path)
  local ok,data=pcall(h.readAll) pcall(h.close)
  assert(ok,tostring(data)) return data==content
end

function M.install(files,options)
  local function progress(phase,path,done,total)
    if options and type(options.onProgress)=="function" then pcall(options.onProgress,phase,path,done,total) end
  end
  local packedCodec=files["system/libraries/packed_source.lua"]
    and assert(load(files["system/libraries/packed_source.lua"],"packed codec","t",_ENV))()
  if packedCodec and fs.exists(root) then
    local recovered,problem=M.recover() assert(recovered,problem)
  end
  -- A retained transaction may contain the only backup after an interrupted write.
  if fs.exists(root) then error("Unfinished installation: recover " .. root .. " before retrying") end
  local paths = {}
  for path, content in pairs(files) do
    assert(validPath(path), "Invalid install path: " .. tostring(path))
    assert(type(content) == "string", "Invalid file content")
    table.insert(paths, path)
  end
  table.sort(paths)
  local plan={changed={},stageBytes=0,backupBytes=0,version=files.VERSION}
  for _,path in ipairs(paths) do
    local target="/"..path
    if not (preserved(path) and fs.exists(target)) and not identical(target,files[path]) then
      assert(not fs.exists(target) or not fs.isDir(target),"Destination is a directory: "..path)
      if path:match("%.lua$") then
        local fn,problem=load(files[path],"@"..path,"t",_ENV) assert(fn,tostring(problem))
        if packedCodec then
          local source=packedCodec.unpack(files[path])
          fn,problem=load(source,"@"..path,"t",_ENV) assert(fn,tostring(problem))
        end
      end
      plan.changed[#plan.changed+1]=path plan.stageBytes=plan.stageBytes+#files[path]
      if fs.exists(target) and fs.getSize then plan.backupBytes=plan.backupBytes+fs.getSize(target) end
    end
  end
  local policyPath="/system/config/update-storage.cfg"
  local policy={}
  if fs.exists(policyPath) then
    local h=assert(fs.open(policyPath,"r"))
    local raw=h.readAll() h.close()
    policy=textutils.unserialize(raw)
    assert(type(policy)=="table","Invalid update storage policy")
  end
  local bundledPolicy=files["system/config/update-storage.cfg"] and textutils.unserialize(files["system/config/update-storage.cfg"]) or {}
  plan.retainRollback=policy.retainRollback
  if plan.retainRollback==nil then plan.retainRollback=not (type(bundledPolicy)=="table" and bundledPolicy.retainRollback==false) end
  if plan.retainRollback==false then
    if options and options.beforeHistoryCleanup then options.beforeHistoryCleanup() end
    assert(not fs.exists("/var/tmp/mintcraft-rollback.cfg") and not fs.exists("/var/tmp/mintcraft-restore") and not fs.exists("/var/tmp/mintcraft-package"),"Recover pending operation before removing version history")
    if options and options.purgeHistory==true and fs.exists("/var/backups/update") then fs.delete("/var/backups/update") end
    policy.retainRollback=false
    write(policyPath,textutils.serialize(policy))
  end
  -- A manual wget upgrade must retain the same durable checkpoint as Update.
  -- Refuse before touching live files when space or the checkpoint is unavailable.
  local free=fs.getFreeSpace and fs.getFreeSpace("/")
  local upgrading=fs.exists("/VERSION") and #plan.changed>0
  -- The bundled payload is already retained and syntax/integrity checked in
  -- memory. During an upgrade, two durable copies of the old files drive undo;
  -- a third, staged copy of the new payload adds no recovery capability.
  plan.payloadBytes=plan.stageBytes
  if upgrading then plan.stageBytes=0 end
  assert(not upgrading or type(free)=="number" or free=="unlimited","INSTALL-DISK: cannot verify free space for a reversible upgrade")
  local required=plan.stageBytes+plan.backupBytes*(upgrading and plan.retainRollback and 2 or 1)+math.max(32768,#plan.changed*256)
  if type(free)=="number" then assert(free>=required,"INSTALL-DISK: insufficient space for staging and retained rollback; backups retained") end
  if options and options.beforeInstall then options.beforeInstall(plan)
  elseif upgrading and plan.retainRollback then
    -- Use the verified bundled checkpoint implementation even when upgrading
    -- an older installed service. Keep its dependency cache private.
    local loaded={}
    local function bundled(name)
      if loaded[name]~=nil then return loaded[name] end
      local path=name:gsub("%.","/")..".lua"
      if not files[path] then return require(name) end
      local environment=setmetatable({require=bundled},{__index=_ENV})
      loaded[name]=true
      local value=assert(load(files[path],"@"..path,"t",environment))()
      loaded[name]=value==nil and true or value
      return loaded[name]
    end
    local updated=bundled("system.services.updated")
    local saved,problem=updated.createRollback("before manual installation",plan.changed)
    assert(saved,"INSTALL-BACKUP: "..tostring(problem))
  end
  -- Existing/migration checkpoints are never implicitly deleted. No-history
  -- mode prevents new checkpoints in the current Update service.
  if plan.retainRollback==false and options and options.purgeHistory==true and fs.exists("/var/backups/update") then fs.delete("/var/backups/update") end
  assert(not fs.exists(root), "Installation started while preparing; recover before retrying")
  local changed, touched = {}, {}
  local ok, err = pcall(function()
    fs.makeDir(root)
    if packedCodec then write(root.."/format","MintCraft install transaction 3") end
    for index, path in ipairs(plan.changed) do
        progress("stage",path,index-1,#plan.changed)
        if not upgrading then write(root .. "/stage/" .. path, files[path]) end
        if not upgrading and path:match("%.lua$") then
          local fn, problem = loadfile(root .. "/stage/" .. path)
          assert(fn, tostring(problem))
        end
        table.insert(changed, path)
    end
    local entries = {}
    for index, path in ipairs(changed) do
      progress("backup",path,index-1,#changed)
      local exists = fs.exists("/" .. path)
      assert(not exists or not fs.isDir("/" .. path), "Destination is a directory: " .. path)
      if exists then
        local backup = root .. "/backup/" .. path
        fs.makeDir(fs.getDir(backup))
        fs.copy("/" .. path, backup)
      end
      table.insert(entries, { path = path, existed = exists })
    end
    write(root .. "/journal.cfg", textutils.serialize(entries))
    for index, entry in ipairs(entries) do
      progress("install",entry.path,index-1,#entries)
      table.insert(touched, entry)
      write("/" .. entry.path, files[entry.path])
      -- The durable journal/backup, not the validated staging copy, drives undo.
      -- Reclaim each consumed copy so a fresh install fits a standard CC disk.
      fs.delete(root .. "/stage/" .. entry.path)
    end
    write(root .. "/committed", "committed")
  end)
  if not ok then
    local rollbackErrors = {}
    for i = #touched, 1, -1 do
      local entry = touched[i]
      local restored, problem = pcall(function()
        local path = "/" .. entry.path
        assert(not fs.exists(path) or not fs.isDir(path), "Destination changed to directory")
        if entry.existed then
          local h = assert(fs.open(root .. "/backup/" .. entry.path, "r"), "Missing recovery backup")
          local data = h.readAll() h.close()
          write(path, data)
        elseif fs.exists(path) then fs.delete(path) end
      end)
      if not restored then table.insert(rollbackErrors, tostring(problem)) end
    end
    if #rollbackErrors == 0 then
      if fs.exists(root) then fs.delete(root) end
    else
      error(tostring(err) .. "; recovery required: " .. table.concat(rollbackErrors, "; "))
    end
    error(err)
  end
  progress("install","Files committed",#plan.changed,#plan.changed)
  if options and type(options.onCommitted)=="function" then pcall(options.onCommitted,plan.version) end
  pcall(fs.delete, root)
  return true
end

function M.recover()
  if not fs.exists(root) then return true, "No pending installation" end
  local h = fs.open(root .. "/journal.cfg", "r")
  if not h then
    local marker=fs.open(root.."/format","r")
    if marker then
      local kind=marker.readAll() marker.close()
      if kind=="MintCraft install transaction 3" and not fs.exists(root.."/committed") then
        -- Protocol 3 does not touch live files before publishing its journal.
        fs.delete(root) return true,"Discarded incomplete staging; live files untouched"
      end
    end
    return false,"No recovery journal; inspect "..root
  end
  local parsed, entries = pcall(function() return textutils.unserialize(h.readAll()) end)
  h.close()
  if not parsed or type(entries) ~= "table" then return false, "Invalid recovery journal" end
  local seen, count = {}, 0
  for index, entry in pairs(entries) do
    if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #entries
      or type(entry) ~= "table" or not validPath(entry.path) or seen[entry.path] or type(entry.existed) ~= "boolean" then
      return false, "Invalid recovery entry"
    end
    seen[entry.path], count = true, count + 1
    if fs.exists("/" .. entry.path) and fs.isDir("/" .. entry.path) then return false, "Recovery target is a directory" end
    if entry.existed and (not fs.exists(root .. "/backup/" .. entry.path) or fs.isDir(root .. "/backup/" .. entry.path)) then
      return false, "Missing backup: " .. entry.path
    end
  end
  if count ~= #entries then return false, "Incomplete recovery journal" end
  local ok, err = pcall(function()
    if fs.exists(root .. "/committed") then fs.delete(root) return end
    for _, entry in ipairs(entries) do
      local target = "/" .. entry.path
      if entry.existed then
        local backup = assert(fs.open(root .. "/backup/" .. entry.path, "r"))
        local data = backup.readAll() backup.close()
        write(target, data)
      elseif fs.exists(target) then fs.delete(target) end
    end
    fs.delete(root)
  end)
  return ok, ok and "Previous files restored; reboot required" or tostring(err)
end

return M
