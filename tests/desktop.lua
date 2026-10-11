package.path = "./?.lua;" .. package.path
local fills = {}
package.loaded["system.gui.renderer"] = {
  fill = function(x,y,w,h) assert(w > 0 and h > 0) fills[#fills+1] = {y=y,h=h,w=w} end,
  writeAt = function() end, crop = function(t) return t end,
}
package.loaded["system.gui.theme"] = {}
package.loaded["system.gui.icon"] = {}
package.loaded["system.gui.keyboard"] = {
  height = function() return 7 end, draw = function() end, handle = function() return false end,
}
term = {getSize = function() return 51,19 end}
colors = {lightGray=1,black=2,gray=3}
keys = {escape=1,backspace=2,enter=3}
local d = require("system.gui.desktop")
d.setApps({list = function() return {{id="files",name="Files",icon="F",category="Files"}} end})
d.menuOpen = true
d.drawOverlays()
assert(fills[1].y + fills[1].h == 19)
d.searchFocused = true
d.drawOverlays()
assert(fills[2].y + fills[2].h <= 12, "menu overlaps search keyboard")
assert(fills[2].w == 51, "underlying app keyboard exposed beside search")
assert(d.captures({name="char"}))
d.handle({name="paste",args={"files"}})
assert(d.search == "files")
d.handle({name="key",args={keys.escape}})
assert(not d.searchFocused and not d.menuOpen and not d.captures({name="char"}))
d.menuOpen = true
assert(d.handle({name="mouse_click",args={1,50,2}}))
assert(not d.menuOpen, "outside click failed to dismiss menu")
print("desktop overlay tests passed")
