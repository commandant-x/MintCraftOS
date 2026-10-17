-- Run in a disposable CraftOS-PC data directory, with the repository at /source.
local function result(message)
  local h = assert(fs.open("/smoke-result.txt", "w"))
  h.write(message)
  h.close()
end
local ok, err = pcall(function()
  shell.setDir("/")
  assert(shell.run("/source/install.lua"), "installation failed")
  http = nil
  _G.http = nil
  local apps = require("system.libraries.apps")
  local boot = require("system.boot.bootloader")
  parallel.waitForAny(function() boot.start() end, function()
    for i = 1, 30 do
      if apps.ctx and apps.get("files") then break end
      sleep(0.1)
    end
    assert(apps.ctx and apps.get("files"), "desktop did not boot")
    assert(not require("system.services.networkd").getStatus().http, "HTTP still enabled")
    assert(apps.get("navigation") and apps.get("combat"), "addon apps not registered")
    for _, service in ipairs(apps.ctx.services:list()) do
      assert(service.state == "running" or (service.state=="degraded" and service.error), service.name .. ": " .. tostring(service.error))
    end
    for _, id in ipairs({"navigation", "combat", "files", "terminal", "settings", "devices", "logs", "services", "taskmanager", "messenger", "editor"}) do
      local launched, pid = apps.launch(id, {path="/home/user/documents/smoke.txt"})
      assert(launched, tostring(pid))
      os.queueEvent("mintcraft_test")
      sleep(1.1)
      local proc = apps.ctx.scheduler.processes[pid]
      assert(proc.state == "ready", id .. ": " .. tostring(proc.error))
      assert(proc.window and not proc.window.closed, id .. " closed")
      proc.window:toggleMaximize()
      os.queueEvent("mintcraft_test")
      sleep(1.1)
      assert(not proc.window.closed, id .. " maximized: " .. tostring(proc.error))
      if term.screenshot then term.screenshot() end
      apps.ctx.scheduler:kill(pid)
    end
    result("PASS: installed, booted offline, service health reflects missing addons, eleven apps opened and maximized")
  end)
end)
if not ok then result("FAIL: " .. tostring(err)) end
os.shutdown()
