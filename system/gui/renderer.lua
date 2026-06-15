local theme = require("system.gui.theme")

local M = {}

function M.clear(bg)
  term.setBackgroundColor(bg or theme.get("windowBg"))
  term.clear()
end

function M.writeAt(x, y, text, fg, bg)
  term.setCursorPos(x, y)
  term.setTextColor(fg or theme.get("windowFg"))
  term.setBackgroundColor(bg or theme.get("windowBg"))
  term.write(tostring(text))
end

function M.fill(x, y, w, h, bg)
  term.setBackgroundColor(bg or theme.get("windowBg"))
  for row = y, y + h - 1 do
    term.setCursorPos(x, row)
    term.write(string.rep(" ", w))
  end
end

function M.crop(text, width)
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
