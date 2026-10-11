package.path = "./?.lua;" .. package.path
package.loaded["system.gui.theme"] = {get = function() return 1 end}
colors = { black = 32768, white = 1 }
local reads, writes = 0, 0
fs = { exists = function(path) return path == "icon.spx" end }
paintutils = {loadImage = function(path)
  assert(path == "icon.spx")
  reads = reads + 1
  return {{1, 32768}, {32768, 1}, {1, 32768}}
end}
term = {getSize = function() return 51, 19 end, setCursorPos = function() end,
  blit = function(t, f, b) assert(#t == #f and #t == #b) writes = writes + 1 end}
local icons = require("system.gui.icon")
for i = 1, 100 do assert(icons.draw("icon.nfp", 1, 1, "?", 32768)) end
assert(reads == 1 and writes == 100, "icon reloaded on redraw")
icons.invalidate("icon.nfp")
assert(icons.draw("icon.nfp", 1, 1, "?", 32768) and reads == 2)
print("icon asset cache tests passed")
