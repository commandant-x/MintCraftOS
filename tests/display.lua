package.path = "./?.lua;" .. package.path
package.loaded["system.libraries.log"] = { info = function() end, error = function() end }
package.loaded["system.libraries.config"] = { load = function() return {} end }
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
print("display tests passed")
