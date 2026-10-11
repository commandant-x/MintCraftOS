package.path = "./?.lua;" .. package.path
package.loaded["system.libraries.log"] = { info = function() end, error = function() end }
package.loaded["system.libraries.config"] = { load = function() return {} end }

local profile = require("system.libraries.profile")
assert(profile.appEnabled("files"))
assert(profile.appEnabled("combat"))
assert(profile.appEnabled("navigation"))
local services = require("system.services.service_manager").new({})
services:register("combatd", "must.not.load", true)
services:register("deviced", "system.services.deviced", true)
assert(#services:list() == 2 and services:list()[1].name == "combatd")

local scans, redirects = 0, 0
local native = { getSize = function() return 51, 19 end }
term = {
  current = function() return native end,
  getSize = function() return 51, 19 end,
  redirect = function() redirects = redirects + 1 end,
}
peripheral = {
  getNames = function() scans = scans + 1 return { "left" } end,
  getType = function() return "speaker" end,
  find = function() return nil end,
}
local bus = require("system.kernel.event_bus").new()
local devices = require("system.services.deviced")
devices.start({ eventBus = bus })
assert(scans == 1)
local rows = devices.list()
rows[1].type = "tampered"
assert(devices.list()[1].type == "speaker")
assert(scans == 1, "drawing must not acquire peripherals")
bus:emit("peripheral", "left")
assert(scans == 2)
devices.start({ eventBus = bus })
local before = scans
bus:emit("peripheral_detach", "left")
assert(scans == before + 1, "restart duplicated listeners")
devices.stop()
before = scans
bus:emit("peripheral", "left")
assert(scans == before, "stopped service still listening")
peripheral.getNames = function() return {"multi", "gone"} end
peripheral.getType = function(name)
  if name == "gone" then error("detached during scan") end
  return "custom:block", "modem"
end
devices.scan()
assert(devices.hasType("modem") and devices.hasType("custom:block"))
assert(not devices.hasType("speaker") and #devices.list() == 1)
peripheral.getNames = function() error("scan unavailable") end
local _, problem = devices.scan()
assert(problem and devices.scanError and devices.hasType("modem"), "failed scan erased cached inventory")
peripheral.getNames = function() return {} end
devices.scan()
assert(not devices.scanError and not devices.hasType("modem"))
print("foundation tests passed")
