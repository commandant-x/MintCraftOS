local reason = ...

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
    local function restoreRaw()
      local latestPath = "/var/backups/update/latest.cfg"
      if not fs.exists(latestPath) then return false, "No rollback backup." end
      local handle = fs.open(latestPath, "r")
      if not handle then return false, "Cannot read rollback metadata." end
      local data = handle.readAll()
      handle.close()
      local ok, latest = pcall(textutils.unserialize, data)
      if not ok or type(latest) ~= "table" or not latest.id then return false, "Invalid rollback metadata." end
      local backupDir = "/var/backups/update/" .. latest.id
      local manifestPath = backupDir .. "/manifest.cfg"
      local manifest = latest
      if fs.exists(manifestPath) then
        local mf = fs.open(manifestPath, "r")
        if mf then
          local parsed = mf.readAll()
          mf.close()
          local mok, value = pcall(textutils.unserialize, parsed)
          if mok and type(value) == "table" then manifest = value end
        end
      end
      if type(manifest.paths) ~= "table" then return false, "Invalid rollback manifest." end
      for _, path in ipairs(manifest.paths) do
        local source = backupDir .. path
        if not fs.exists(source) then return false, "Missing backup " .. source end
        if fs.exists(path) then fs.delete(path) end
        local dir = fs.getDir(path)
        if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
        fs.copy(source, path)
      end
      return true, "Rollback restored " .. tostring(manifest.fromVersion or "previous") .. ". Reboot now."
    end
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
