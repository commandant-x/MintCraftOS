package.path = "./?.lua;" .. package.path
package.loaded["system.gui.theme"] = {get = function() return 1 end}
local s = require("system.gui.subpixel")
for mask = 0, 63 do
  local pixels = {}
  for i = 1, 6 do pixels[i] = math.floor(mask / 2 ^ (i - 1)) % 2 == 1 and 1 or 32768 end
  local char, fg, bg, lost = s.encode(pixels)
  local bits = char:byte() - 128
  assert(bits >= 0 and bits < 32 and lost == 0)
  for i = 1, 6 do
    local digit = i < 6 and math.floor(bits / 2 ^ (i - 1)) % 2 == 1 and fg or bg
    assert(2 ^ tonumber(digit, 16) == pixels[i], "mosaic mapping/inversion failure")
  end
end
local canvas = s.new(7, 5, 32768)
assert(canvas.width == 14 and canvas.height == 15)
canvas:line(-1000000, 8, 1000000, 8, 1)
local originalEncode, calls = s.encode, 0
s.encode = function(...) calls = calls + 1 return originalEncode(...) end
canvas:getLine(3)
assert(calls == 7)
canvas:getLine(3)
assert(calls == 7, "cached row recompiled")
canvas:pixel(1, 8, 1)
canvas:getLine(3)
assert(calls == 7, "unchanged pixel invalidated row")
canvas:pixel(1, 8, 2)
canvas:getLine(3)
assert(calls == 14)
local clone=canvas:clone()
clone:getLine(3)
assert(calls==14,"cloned static row recompiled")
clone:rect(1,7,14,3,4)
local cloneText,cloneFg,cloneBg=clone:getLine(3)
local baseText,baseFg,baseBg=canvas:getLine(3)
assert(cloneText..cloneFg..cloneBg~=baseText..baseFg..baseBg,"clone mutated base pixels")
canvas:clear(32768)
local afterText,afterFg,afterBg=clone:getLine(3)
assert(afterText..afterFg..afterBg==cloneText..cloneFg..cloneBg,"clearing base changed clone")
canvas:pixel(-1, 8, 1)
local _, _, _, lost = s.encode({1, 1, 2, 2, 4, 4})
assert(lost == 2, "multicolour loss must be measurable")
assert(not pcall(s.new, 1000, 1000, 1))
print("subpixel masks, clipping and cache tests passed")
