-- Mount the window.lua extracted from the installed CC Graphics jar read-only.
-- This exercises its real palette/window implementation in normal CraftOS-PC.
local api=setmetatable({},{__index=_ENV})
assert(loadfile("/ccgraphics-rom/data/ccgraphics/lua/rom/apis/window.lua","t",api))()
window={create=assert(api.create)}
_G.window=window
assert(loadfile("/source/tests/craftos-graphics.lua","t",_ENV))()
