package.path = "./?.lua;" .. package.path
local w, h, created, shown, resized = 51,19,0,0,0
local changed = false
local foreground, fail = "0", false
local native = {getSize = function() return w,h end,
  getCursorPos = function() return 1, 1 end, getCursorBlink = function() return false end,
  setCursorPos = function() end, setCursorBlink = function() end,
  blit = function(t,f,b) if fail then error("monitor detached") end assert(#t == w and #f == w and #b == w) shown = shown + 1 end}
local current = native
term = {current = function() return current end, redirect = function(t) current = t end}
window = {create = function(parent, x, y, width, height, visible)
  assert(parent == native and not visible)
  created = created + 1
  return {
    setVisible = function(value) assert(not value, "full-screen flush forbidden") end,
    getLine = function(y) return (changed and y == 3 and "x" or " ") .. string.rep(" ", w - 1), string.rep(y == 3 and foreground or "0", w), string.rep("f", w) end,
    reposition = function() resized = resized + 1 end,
  }
end}
local screen = require("system.gui.compositor").new()
screen:draw(function() assert(current ~= native and shown == 0) end)
assert(current == native and shown == h)
screen:draw(function() end)
assert(created == 1 and shown == h, "unchanged frame rewritten")
changed = true
screen:draw(function() end)
assert(shown == h + 1, "one row change should cause one blit")
w = 80
screen:draw(function() end)
assert(resized == 1)
local before = shown
assert(not pcall(function() screen:draw(function() error("render failure") end) end))
assert(current == native and shown == before, "partial frame published or redirect leaked")
screen:invalidate()
screen:draw(function() end)
assert(shown == before + h and screen:stats().frames == 5)
foreground = "e"
screen:draw(function() end)
assert(shown == before + h + 1, "colour-only change ignored")
foreground, fail = "b", true
assert(not pcall(function() screen:draw(function() end) end))
assert(current == native)
fail = false
local beforeRetry = shown
screen:draw(function() end)
assert(shown == beforeRetry + h, "partial output failure did not force a repaint")
print("compositor tests passed")
local selected = native
local resolved = require("system.gui.compositor").new(function() return selected end)
current = {getSize = function() return 10, 5 end}
resolved:draw(function() end)
assert(current == native, "compositor used an app terminal instead of the selected screen")
