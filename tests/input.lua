package.path = "./?.lua;" .. package.path
local input = require("system.kernel.input")
local display = {target = "monitor", monitorSide = "monitor_3"}
assert(not input.normalize({"monitor_touch", "monitor_2", 5, 6}, display))
assert(not input.normalize({"monitor_touch", "monitor_3", 5, 6}, {target = "computer"}))
local event = input.normalize({"monitor_touch", "monitor_3", 5, 6}, display)
assert(event.name == "mouse_click" and event.args[1] == 1)
assert(event.args[2] == 5 and event.args[3] == 6 and event.monitorTouch)
assert(event.monitorSide == "monitor_3")
assert(input.normalize({"char", "x"}, display).args[1] == "x")
assert(not input.normalize({"mouse_click",1,5,6},display),"native computer mouse leaked to the monitor")
assert(input.normalize({"peripheral_detach", "monitor_3"}, display).name == "peripheral_detach")
print("input routing tests passed")
