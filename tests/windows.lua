package.path = "./?.lua;" .. package.path
package.loaded["system.gui.theme"] = { get = function() return 1 end }
package.loaded["system.gui.renderer"] = {}
local sw, sh = 80, 30
term = { getSize = function() return sw, sh end }
local manager = require("system.wm.window_manager").new()
local counts = { a = 0, b = 0 }
local function app(id)
  return { handle = function(_, e) counts[id] = counts[id] + 1 return false end }
end
local a = manager:create({ x = 1, y = 1, w = 30, h = 20, app = app("a") })
local b = manager:create({ x = 1, y = 1, w = 30, h = 20, app = app("b") })
b.minimized = true
assert(manager:active() == a)
assert(manager:handle({ name = "mouse_click", args = { 1, 3, 3 } }))
assert(counts.a == 1 and counts.b == 0, "minimized window intercepted click")
assert(manager:handle({ name = "char", args = { "x" } }))
assert(counts.a == 2, "keyboard focus lost after minimize")
manager:handle({ name = "timer", args = { 42 } })
assert(counts.a == 3 and counts.b == 1, "background timer not delivered")
b.closed = true
manager:handle({ name = "timer", args = { 43 } })
assert(counts.b == 1)
local c = manager:create({x = 40, y = 1, w = 30, h = 20, app = app("b")})
assert(manager:active() == c)
assert(manager:handle({name = "mouse_scroll", args = {1, 3, 3}}))
assert(counts.a == 5 and counts.b == 1, "scroll went to active window instead of hovered window")
assert(manager:active() == c, "scroll stole keyboard focus")
assert(not manager:handle({name = "mouse_scroll", args = {1, 79, 25}}))
assert(counts.a == 5 and counts.b == 1)
c.x = 1
assert(manager:handle({name = "mouse_scroll", args = {1, 3, 3}}))
assert(counts.a == 5 and counts.b == 2, "scroll passed through overlapping window")
a:toggleMaximize()
sw, sh = 24, 12
a:clamp()
assert(a.w == 24 and a.h == 11)
a:toggleMaximize()
assert(a.x + a.w - 1 <= sw and a.y + a.h - 1 < sh)
a.x, a.y = -90, 900
a:clamp()
assert(a.x >= 1 and a.y >= 1 and a.y + a.h - 1 < sh)
print("window tests passed")
