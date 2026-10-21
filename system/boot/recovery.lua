local reason = ...
local function checksum(data)
  local a,b=1,0
  for i=1,#data do a=(a+data:byte(i))%65521 b=(b+a)%65521 end
  return string.format("%08x",b*65536+a)
end

if term and term.setFrozen then pcall(term.setFrozen,false) end
if term and term.setGraphicsMode then pcall(term.setGraphicsMode,0) end

-- Kept dependency-free so a damaged module tree can still restore a checkpoint.
local function restoreRaw(resumeOnly)
  if _G.mintcraftStorageOperation then return false, "Storage operation in progress; backup retained" end
  local root, pending, stage = "/var/backups/update", "/var/tmp/mintcraft-rollback.cfg", "/var/tmp/mintcraft-restore"
  local function readConfig(path)
    local h = assert(fs.open(path, "r"), "Cannot read " .. path)
    local ok, value = pcall(function() return textutils.unserialize(h.readAll()) end)
    h.close()
    assert(ok and value ~= nil, "Invalid metadata: " .. path)
    return value
  end
  local function writeConfig(path, value)
    fs.makeDir(fs.getDir(path))
    local h = assert(fs.open(path, "w"), "Cannot write " .. path)
    local ok, err = pcall(h.write, textutils.serialize(value))
    local closed, problem = pcall(h.close)
    assert(ok and closed, tostring(ok and problem or err))
  end
  local function filePath(path)
    if type(path) ~= "string" or path:find("..", 1, true) or path:find("//", 1, true)
      or path:find("[%c:\\]") or path:sub(-1) == "/" then return false end
    if path == "/system/config" then return false end
    for part in path:gmatch("[^/]+") do
      if part == "." or part == ".." or part:find(".mintcraft-save",1,true) then return false end
    end
    return path == "/VERSION" or path == "/boot.lua" or path == "/startup.lua"
      or ((path:match("^/system/") or path:match("^/apps/")) and not path:match("^/system/config/"))
  end
  local function run()
    if resumeOnly and not fs.exists(pending) then return true, "No pending rollback" end
    local pointer = pending
    if not fs.exists(pointer) then
      pointer = root .. "/latest.cfg"
      if not fs.exists(pointer) then pointer = root .. "/previous.cfg" end
    end
    local info = readConfig(pointer)
    assert(type(info) == "table" and type(info.id) == "string" and info.id:match("^%d+%-?%d*$"), "Invalid rollback id")
    local backupDir = root .. "/" .. info.id
    local manifest = readConfig(backupDir .. "/manifest.cfg")
    assert(type(manifest) == "table" and manifest.id == info.id and type(manifest.paths) == "table"
      and (manifest.kind == nil or manifest.kind == "files"), "Invalid rollback manifest")
    local full = {["/VERSION"]=true,["/boot.lua"]=true,["/startup.lua"]=true,["/system"]=true,["/apps"]=true,["/packages"]=true}
    local seen, count = {}, 0
    for index, path in pairs(manifest.paths) do
      assert(type(index) == "number" and index % 1 == 0 and index >= 1 and index <= #manifest.paths
        and type(path) == "string" and not seen[path], "Invalid rollback sequence")
      if manifest.kind == "files" then
        assert(filePath(path) and type(manifest.existed) == "table" and type(manifest.existed[path]) == "boolean", "Invalid incremental rollback")
        assert(not fs.exists(path) or not fs.isDir(path), "Expected live file")
      else assert(full[path], "Invalid tree rollback path") end
      if manifest.kind ~= "files" or manifest.existed[path] then
        assert(fs.exists(backupDir .. path), "Missing backup: " .. path)
        local directory = manifest.kind ~= "files" and (path == "/system" or path == "/apps" or path == "/packages")
        assert(fs.isDir(backupDir .. path) == (directory or false), "Invalid backup type")
      end
      seen[path], count = true, count + 1
    end
    assert(count > 0 and count == #manifest.paths, "Incomplete rollback manifest")
    if manifest.checksums then
      assert(type(manifest.checksums)=="table" and manifest.kind=="files","Invalid checkpoint checksums")
      for _,path in ipairs(manifest.paths) do
        if manifest.existed[path] then
          local h=assert(fs.open(backupDir..path,"r"))
          local data=h.readAll() h.close()
          assert(checksum(data)==manifest.checksums[path],"Corrupt checkpoint: "..path)
        end
      end
    end
    if fs.exists(stage) then
      local target = readConfig(stage .. "/target.cfg")
      assert(type(target) == "string" and seen[target] and target ~= "/packages", "Invalid pending restore target")
      local old, nextPath = stage .. "/previous", stage .. "/next"
      if fs.exists(old) and not fs.exists(target) then fs.move(old, target)
      elseif fs.exists(old) and fs.exists(nextPath) then error("Ambiguous interrupted restore") end
      fs.delete(stage)
    end
    writeConfig(pending, {id=info.id})
    for _, path in ipairs(manifest.paths) do
      if path ~= "/packages" then
        if manifest.kind == "files" and not manifest.existed[path] then
          if fs.exists(path) then fs.delete(path) end
        else
          fs.makeDir(stage)
          writeConfig(stage .. "/target.cfg", path)
          fs.copy(backupDir .. path, stage .. "/next")
          if path == "/system" and fs.exists("/system/config") then
            if fs.exists(stage .. "/next/config") then fs.delete(stage .. "/next/config") end
            fs.copy("/system/config", stage .. "/next/config")
          end
          if path == "/apps" and fs.exists("/apps") then
            local core = {browser=true,combat=true,crafttube=true,devices=true,editor=true,files=true,logs=true,
              messenger=true,navigation=true,services=true,settings=true,store=true,taskmanager=true,terminal=true,update=true}
            for _, name in ipairs(fs.list("/apps")) do
              if not core[name] then
                if fs.exists(stage .. "/next/" .. name) then fs.delete(stage .. "/next/" .. name) end
                fs.copy("/apps/" .. name, stage .. "/next/" .. name)
              end
            end
          end
          fs.makeDir(fs.getDir(path))
          if fs.exists(path) then fs.move(path, stage .. "/previous") end
          fs.move(stage .. "/next", path)
          fs.delete(stage)
        end
      end
    end
    fs.delete(pending)
    return true, "Rollback restored; reboot required. Backups retained."
  end
  local ok, result, detail = pcall(run)
  if not ok then return false, tostring(result) .. "; backups retained" end
  return result, detail
end

if reason == "--raw-rollback" then return restoreRaw(false) end
if reason == "--resume-rollback" then return restoreRaw(true) end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.yellow)
term.clear()
term.setCursorPos(1, 1)
print("MintCraft OS Recovery")
print("---------------------")
print("Reason: " .. tostring(reason or "manual"))
print("")
print("Commands:")
print("  shell  - open CraftOS shell")
print("  logs   - show last system log lines")
print("  crash  - show last crash log")
print("  rollback - restore last update backup")
print("  reboot - reboot computer")
print("  exit   - return to caller")
print("")

while true do
  term.setTextColor(colors.lime)
  write("recovery> ")
  term.setTextColor(colors.white)
  local cmd = read()

  if cmd == "shell" then
    shell.run("shell")
  elseif cmd == "logs" then
    if fs.exists("/var/logs/system.log") then
      shell.run("type", "/var/logs/system.log")
    else
      print("No logs found.")
    end
  elseif cmd == "crash" then
    if fs.exists("/var/logs/last_crash.log") then
      shell.run("type", "/var/logs/last_crash.log")
    else
      print("No crash log found.")
    end
  elseif cmd == "rollback" then
    local ok, updated = pcall(require, "system.services.updated")
    local success, message
    if ok and updated and updated.rollback then
      success, message = updated.rollback()
    else
      success, message = restoreRaw()
    end
    print(tostring(message))
  elseif cmd == "reboot" then
    os.reboot()
  elseif cmd == "exit" then
    return
  elseif cmd ~= "" then
    print("Unknown command: " .. cmd)
  end
end
