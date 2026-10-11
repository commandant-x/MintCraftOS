package.path = "./?.lua;" .. package.path
local hour, written, position = 6 + 59 / 60, nil, nil
os.time = function() return hour end
term = {getSize = function() return 51, 19 end}
package.loaded["system.gui.renderer"] = {writeAt = function(x, y, text) position, written = {x,y}, text end}
package.loaded["system.gui.theme"] = {get = function() return 1 end}
package.loaded["system.gui.keyboard"] = {}
package.loaded["system.gui.icon"] = {}
local desktop = require("system.gui.desktop")
assert(desktop.clockText() == "06:59")
hour = 7
desktop.drawClock()
assert(written == "07:00" and position[1] == 46 and position[2] == 19)
hour = 7 + 1 / 60
assert(desktop.clockText() == "07:01")
hour = 24
assert(desktop.clockText() == "00:00")
for minute = 0, 1439 do
  hour = minute / 60
  assert(desktop.clockText() == string.format("%02d:%02d", math.floor(minute / 60), minute % 60))
end
print("fixed width clock tests passed")
