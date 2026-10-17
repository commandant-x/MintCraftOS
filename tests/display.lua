package.path = "./?.lua;" .. package.path
package.loaded["system.libraries.log"] = { info = function() end, error = function() end }
local cfg = {}
package.loaded["system.libraries.config"] = {
  load = function() return cfg end,
  save = function(_, value) cfg = value return true end,
}
colors = { black = 32768 }
local native = { getSize = function() return 51, 19 end }
local current = native
term = {
  current = function() return current end,
  redirect = function(target) current = target end,
  getSize = function() return current.getSize() end,
}
local width, height, attached, broken = 100, 60, true, false
local monitor = {
  getSize = function() return width, height end,
  setTextScale = function() if broken then error("detached") end end,
}
peripheral = {
  getNames = function() return attached and {"monitor_7"} or {} end,
  getType = function() return "monitor" end,
  find = function() if attached then return monitor, {} end end,
  getName = function(value) assert(value == monitor) return "monitor_7" end,
  wrap = function() if attached then return monitor end end,
}
local bus = require("system.kernel.event_bus").new()
local devices = require("system.services.deviced")
devices.start({eventBus = bus})
assert(devices.getDisplay().monitorSide == "monitor_7")
assert(devices.getTarget() == monitor)
current = {getSize = function() return 20, 8 end}
assert(devices.getTarget() == monitor, "render redirection replaced the physical screen")
width, height = 120, 80
bus:emit("monitor_resize", "monitor_7")
assert(devices.getDisplay().width == 120)
local snapshot = devices.getDisplay()
snapshot.width = 1
assert(devices.getDisplay().width == 120, "caller mutated display cache")
broken = true
assert(devices.refreshDisplay() == false)
assert(current == native, "failed monitor must restore native terminal")
assert(devices.getDisplay().target == "computer")
current = {getSize = function() return 20, 8 end}
assert(devices.getDisplay().width == 51, "app window size leaked into display status")
attached = false
bus:emit("peripheral_detach", "monitor_7")
assert(devices.getDisplay().target == "computer")
devices.stop()
broken, attached = false, false
devices.start({eventBus = bus})
assert(current == native)
attached = true
bus:emit("peripheral", "monitor_7")
assert(current == monitor and devices.getTarget() == monitor, "hotplug did not select monitor")
local badMonitor = {setTextScale = function() error("unavailable") end}
peripheral.getNames = function() return {"left", "right"} end
peripheral.wrap = function(name) return name == "left" and badMonitor or monitor end
bus:emit("peripheral", "right")
assert(devices.getDisplay().monitorSide == "right", "broken first monitor blocked healthy monitor")
devices.stop()
assert(devices.setTarget("computer"))
assert(devices.getPreference() == "computer" and devices.getTarget() == native)
local selected, problem = devices.setTarget("missing")
assert(selected == false and problem:find("preference saved"))
assert(devices.getPreference() == "missing")
assert(devices.getTarget() == native, "named target substituted another monitor")
assert(devices.setScale(2.2, "right") == false)
assert(cfg.displayScales.right == 2)
assert(devices.setTarget("right"))
assert(devices.getDisplay().scale == 2)
assert(devices.setScale(1.5))
assert(cfg.displayScales.right == 1.5)
assert(devices.setTarget("auto"))
local notified, invalidated = 0, 0
devices.ctx = {invalidateDisplay = function() invalidated = invalidated + 1 end,
  notifications = {push = function() notified = notified + 1 end}}
assert(devices.outputFailed(monitor, "detached"))
assert(devices.getTarget() == native and notified == 1 and invalidated == 1)
assert(not devices.outputFailed(monitor, "duplicate"))
devices.ctx = nil
assert(devices.setPreference("computer"))
assert(devices.getPreference() == "computer")
assert(devices.listDisplays()[2].selected)
assert(devices.setPreference("offline_monitor"))
local displays = devices.listDisplays()
assert(displays[#displays].name == "offline_monitor" and not displays[#displays].available)
for _, bad in ipairs({"", "   ", "monitor\n7", "monitor\0", "monitor\127"}) do
  assert(not devices.setTarget(bad))
  assert(not devices.setPreference(bad))
  assert(not devices.setScale(1, bad))
  assert(devices.getPreference() == "offline_monitor")
end
assert(devices.setTarget("right"))
assert(devices.getDisplay().scale == 1.5, "target scale was not retained")
devices.stop()
assert(current == native and devices.getTarget() == native and not devices.isRedirected())
assert(devices.getPreference() == "right" and cfg.displayScales.right == 1.5)
current = {getSize = function() return 2, 2 end}
devices.stop()
assert(current == native, "stop leaked an application redirect")
print("display tests passed")
