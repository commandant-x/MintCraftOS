local theme = require("system.gui.theme")

local M = {}
local digits = {}
for i = 0, 15 do digits[2 ^ i] = ("0123456789abcdef"):sub(i + 1, i + 1) end

function M.color(color)
  return assert(digits[color], "Expected a single terminal colour")
end

function M.blitAt(x, y, text, fg, bg)
  assert(#text == #fg and #text == #bg, "Blit strings must have equal lengths")
  local w, h = term.getSize()
  if y < 1 or y > h or x > w then return end
  local first, last = math.max(1, 2 - x), math.min(#text, w - x + 1)
  if first > last then return end
  term.setCursorPos(math.max(1, x), y)
  term.blit(text:sub(first, last), fg:sub(first, last), bg:sub(first, last))
end

function M.clear(bg)
  term.setBackgroundColor(bg or theme.get("windowBg"))
  term.clear()
end

function M.writeAt(x, y, text, fg, bg)
  local w, h = term.getSize()
  text = tostring(text)
  if y < 1 or y > h or x > w then return end
  if x < 1 then text, x = text:sub(2 - x), 1 end
  text = text:sub(1, w - x + 1)
  if text == "" then return end
  term.setCursorPos(x, y)
  term.blit(text, string.rep(M.color(fg or theme.get("windowFg")), #text),
    string.rep(M.color(bg or theme.get("windowBg")), #text))
end

function M.fill(x, y, w, h, bg)
  local sw, sh = term.getSize()
  local right, bottom = math.min(sw, x + w - 1), math.min(sh, y + h - 1)
  x, y = math.max(1, x), math.max(1, y)
  w, h = right - x + 1, bottom - y + 1
  if w <= 0 or h <= 0 then return end
  local text = string.rep(" ", w)
  local background = string.rep(M.color(bg or theme.get("windowBg")), w)
  for row = y, y + h - 1 do
    term.setCursorPos(x, row)
    term.blit(text, background, background)
  end
end

function M.crop(text, width)
  if width <= 0 then return "" end
  text = tostring(text or "")
  if #text <= width then return text .. string.rep(" ", width - #text) end
  if width <= 1 then return string.sub(text, 1, width) end
  return string.sub(text, 1, width - 1) .. ">"
end

function M.button(x, y, w, label, active)
  local bg = active and theme.get("accent") or theme.get("buttonBg")
  local fg = active and colors.black or theme.get("buttonFg")
  M.writeAt(x, y, M.crop(" " .. label .. " ", w), fg, bg)
end

return M
