local renderer = require("system.gui.renderer")
local log = require("system.libraries.log")

local M = {}

function M.run(ctx)
  local app = {}

  function app:draw(w, h)
    renderer.writeAt(1, 1, "System Logs", colors.black, colors.lightGray)
    local lines = log.tail(h - 1)
    for i, line in ipairs(lines) do
      renderer.writeAt(1, i + 1, renderer.crop(line, w), colors.black, colors.lightGray)
    end
  end

  function app:handle()
    return false
  end

  local win = ctx.windowManager:create({ title = "Logs", w = 50, h = 14, x = 8, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
