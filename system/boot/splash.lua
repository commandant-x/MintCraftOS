local M = {}

function M.draw(title, subtitle)
  term.setBackgroundColor(colors.green)
  term.setTextColor(colors.white)
  term.clear()

  local w, h = term.getSize()
  local y = math.max(2, math.floor(h / 2) - 1)
  term.setCursorPos(math.max(1, math.floor((w - #title) / 2)), y)
  term.write(title)
  term.setCursorPos(math.max(1, math.floor((w - #subtitle) / 2)), y + 2)
  term.write(subtitle)
  sleep(0.35)
end

return M
