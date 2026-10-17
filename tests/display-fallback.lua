package.path = "./?.lua;" .. package.path
local current, selected, failure, renders, notices = nil, nil, nil, 0, 0
local writes = 0
local function terminal(isMonitor)
  return {
    getSize = function()
      if isMonitor and failure == "size" then error("detached size") end
      return 4, 3
    end,
    getCursorPos = function() return 1, 1 end,
    getCursorBlink = function() return false end,
    setCursorPos = function() end, setCursorBlink = function() end,
    blit = function()
      writes = writes + 1
      if isMonitor and failure == "flush" and writes == 2 then error("detached blit") end
    end,
  }
end
local native, monitor = terminal(false), terminal(true)
current, selected = native, monitor
term = {native = function() return native end, current = function() return current end,
  redirect = function(target) current = target end}
local creates = 0
window = {create = function()
  creates = creates + 1
  local lines = {"    ", "    ", "    "}
  return {setVisible = function() end, reposition = function() end,
    writeRow = function(y, value) lines[y] = value end,
    getLine = function(y) return lines[y], "0000", "ffff" end}
end}
local screen = require("system.gui.compositor").new(function() return selected end,
  function(target) assert(target == monitor) notices = notices + 1 selected = native end)
failure = "size"
assert(screen:draw(function() renders = renders + 1 current.writeRow(1, "test") end))
assert(renders == 1 and current == native and notices == 1)
selected, failure, writes = monitor, "flush", 0
screen:invalidate()
assert(screen:draw(function() renders = renders + 1 end) == false)
assert(renders == 2 and current == native and notices == 2)
failure, writes = nil, 0
assert(screen:draw(function() renders = renders + 1 current.writeRow(2, "tick") end))
assert(writes == 3 and renders == 3, "failed partial flush was not invalidated")
writes = 0
assert(screen:draw(function() current.writeRow(3, "time") end))
assert(writes == 1, "partial clock update repainted unchanged rows")
assert(screen:draw(function() end))
assert(writes == 1, "partial update lost retained rows")
local before = notices
local ok, err = pcall(function() screen:draw(function() error("app fault") end) end)
assert(not ok and tostring(err):find("app fault") and notices == before and current == native)
selected = monitor
screen:invalidate()
writes = 0
assert(screen:draw(function() end) and writes == 3)
assert(current == monitor and creates >= 3, "target switch reused stale surface")
-- A stale resolver must use the cached fallback even without term.native.
local stale = require("system.gui.compositor").new(function() return monitor end)
failure, writes = "flush", 0
assert(stale:draw(function() end) == false)
term.native = nil
failure, writes = nil, 0
assert(stale:draw(function() end) and current == native and writes == 3)
-- Native failures remain visible, but partial output invalidates every row.
local nativeScreen = require("system.gui.compositor").new(function() return native end)
local blit = native.blit
native.blit = function()
  blit()
  if writes == 2 then error("native partial flush") end
end
writes = 0
local nativeOK, nativeError = pcall(function() nativeScreen:draw(function() end) end)
assert(not nativeOK and tostring(nativeError):find("native partial flush") and writes == 2)
native.blit, writes = blit, 0
assert(nativeScreen:draw(function() end) and writes == 3 and current == native)
print("display fallback tests passed")
