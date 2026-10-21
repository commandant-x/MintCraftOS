local bootOption=...
if not table.unpack and unpack then table.unpack = unpack end
-- A previous graphical session must never hide boot/recovery diagnostics.
if term and term.setFrozen then pcall(term.setFrozen,false) end
if term and term.setGraphicsMode then pcall(term.setGraphicsMode,0) end

if bootOption=="--recovery" then
  return assert(loadfile("/system/boot/recovery.lua"))("manual")
end
if bootOption=="--text" then
  local ok,err=assert(loadfile("/system/boot/recovery.lua"))("--text-rescue")
  assert(ok,err)
end

if not require then
  local loaded = {}

  function require(name)
    if loaded[name] then return loaded[name] end

    local path = "/" .. name:gsub("%.", "/") .. ".lua"
    if not fs.exists(path) then
      error("module not found: " .. name .. " (" .. path .. ")", 2)
    end

    local chunk, err = loadfile(path)
    if not chunk then error(err, 2) end

    loaded[name] = true
    local result = chunk()
    if result ~= nil then loaded[name] = result end
    return loaded[name]
  end
end

local ok, err = pcall(function()
  -- A tree rollback can temporarily move /system itself out of the way.
  local restoreStage = "/var/tmp/mintcraft-restore"
  if not fs.exists("/system") and fs.exists(restoreStage .. "/previous") then
    local metadata = assert(fs.open(restoreStage .. "/target.cfg", "r"), "Missing interrupted restore target")
    local target = textutils.unserialize(metadata.readAll()) metadata.close()
    assert(target == "/system" and fs.isDir(restoreStage .. "/previous"), "Invalid interrupted system restore")
    fs.move(restoreStage .. "/previous", "/system")
  end
  -- Do not load the installer or any other potentially half-written module yet.
  local installRoot = "/var/tmp/mintcraft-install"
  if fs.exists(installRoot) then
    local h = assert(fs.open(installRoot .. "/journal.cfg", "r"), "Incomplete installation; inspect " .. installRoot)
    local entries = textutils.unserialize(h.readAll()) h.close()
    assert(type(entries) == "table", "Invalid installation journal")
    local seen, count = {}, 0
    for index, entry in pairs(entries) do
      assert(type(index) == "number" and index % 1 == 0 and index >= 1 and index <= #entries
        and type(entry) == "table" and type(entry.path) == "string" and type(entry.existed) == "boolean", "Invalid installation entry")
      local path = entry.path
      assert(not seen[path] and path:sub(1,1) ~= "/" and path:sub(-1) ~= "/"
        and not path:find("//",1,true) and not path:find("[%c:\\]"), "Invalid installation path")
      for part in path:gmatch("[^/]+") do assert(part ~= "." and part ~= "..", "Invalid installation path") end
      assert(path == "VERSION" or path == "boot.lua" or path == "startup.lua" or path:match("^system/")
        or path:match("^apps/") or path:match("^home/") or path:match("^packages/"), "Protected installation path")
      assert(not fs.exists("/" .. path) or not fs.isDir("/" .. path), "Installation target is a directory")
      if entry.existed then
        assert(fs.exists(installRoot .. "/backup/" .. path) and not fs.isDir(installRoot .. "/backup/" .. path), "Missing installation backup")
      end
      seen[path], count = true, count + 1
    end
    assert(count == #entries, "Incomplete installation journal")
    if not fs.exists(installRoot .. "/committed") then
      for _, entry in ipairs(entries) do
        local target = "/" .. entry.path
        if entry.existed then
          local input = assert(fs.open(installRoot .. "/backup/" .. entry.path, "r"))
          local data = input.readAll() input.close()
          fs.makeDir(fs.getDir(target))
          local output = assert(fs.open(target, "w"))
          local written, problem = pcall(output.write, data)
          local closed, closeErr = pcall(output.close)
          assert(written and closed, tostring(written and closeErr or problem))
        elseif fs.exists(target) then fs.delete(target) end
      end
    end
    fs.delete(installRoot)
  end
  -- Recover with uncached, dependency-free modules before loading boot code/defaults.
  local safeWrite = assert(loadfile("/system/libraries/safe_write.lua"))()
  local recovered, problem = safeWrite.recoverRestore()
  assert(recovered, problem)
  recovered, problem = safeWrite.recoverAll("/")
  assert(recovered, problem)
  local installer = assert(loadfile("/system/libraries/installer.lua"))()
  recovered, problem = installer.recover()
  assert(recovered, problem)
  if fs.exists("/var/tmp/mintcraft-rollback.cfg") then
    recovered, problem = assert(loadfile("/system/boot/recovery.lua"))("--resume-rollback")
    assert(recovered, problem)
  end
  local manifest = assert(loadfile("/system/package/manifest.lua"))()
  recovered, problem = safeWrite.recoverTransaction("/var/tmp/mintcraft-package", function(path)
    return path == "packages/installed.db" or manifest.ownedPath(path)
  end)
  assert(recovered, problem)
  local bootloader = require("system.boot.bootloader")
  bootloader.start()
end)

if not ok then
  if term and term.setFrozen then pcall(term.setFrozen,false) end
  if term and term.setGraphicsMode then pcall(term.setGraphicsMode,0) end
  if not fs.exists("/var") then fs.makeDir("/var") end
  if not fs.exists("/var/logs") then fs.makeDir("/var/logs") end
  local crash = fs.open("/var/logs/last_crash.log", "w")
  if crash then
    crash.writeLine(tostring(err))
    crash.close()
  end
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.red)
  term.clear()
  term.setCursorPos(1, 1)
  print("MintCraft OS boot error")
  print(tostring(err))

  if fs.exists("/system/boot/recovery.lua") then
    local recovery, loadErr = loadfile("/system/boot/recovery.lua")
    if recovery then
      recovery(tostring(err))
    else
      print(tostring(loadErr))
    end
  end
end
