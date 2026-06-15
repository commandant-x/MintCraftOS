local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")

local M = {}

function M.run(ctx)
  local app = {}

  function app:draw(w, h)
    renderer.writeAt(1, 1, "Settings", colors.black, colors.lightGray)
    renderer.writeAt(1, 3, "Theme: " .. theme.currentId, colors.black, colors.lightGray)
    renderer.button(1, 5, 14, "Mint", theme.currentId == "mint")
    renderer.button(16, 5, 14, "Dark", theme.currentId == "dark")
    renderer.writeAt(1, h, "Click a theme to apply", colors.gray, colors.lightGray)
  end

  function app:handle(event)
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    if y == 5 and x <= 14 then
      theme.set("mint")
      ctx.notifications:push("success", "Settings", "Mint theme applied", 3)
      return true
    elseif y == 5 and x >= 16 and x <= 29 then
      theme.set("dark")
      ctx.notifications:push("success", "Settings", "Dark theme applied", 3)
      return true
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Settings", w = math.min(46, sw - 4), h = math.min(12, sh - 3), x = 8, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
