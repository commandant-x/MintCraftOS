package.path = "./?.lua;" .. package.path
package.loaded["system.gui.theme"] = {get = function() return 1 end}
local calls, x, y = {}, 1, 1
term = {
  getSize = function() return 10, 5 end,
  setCursorPos = function(a, b) x, y = a, b end,
  setTextColor = function() end, setBackgroundColor = function() end,
  blit = function(value, fg, bg)
    assert(#value == #fg and #value == #bg)
    assert(x >= 1 and y >= 1 and y <= 5 and x + #value - 1 <= 10)
    calls[#calls + 1] = {x = x, y = y, text = value}
  end,
}
local r = require("system.gui.renderer")
r.writeAt(-1, 1, "abcdef")
assert(calls[1].text == "cdef")
r.writeAt(9, 5, "abcd")
assert(calls[2].text == "ab")
r.writeAt(1, 6, "hidden")
r.fill(-2, -2, 5, 5, 1)
assert(#calls == 4 and calls[3].text == "  " and calls[4].y == 2)
r.fill(11, 1, 5, 5, 1)
assert(#calls == 4)
assert(r.crop("abcdef", -2) == "" and r.crop("abcdef", 0) == "")
print("renderer clipping tests passed")
