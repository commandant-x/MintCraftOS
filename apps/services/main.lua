local renderer = require("system.gui.renderer")

local M = {}

function M.run(ctx)
  local app = {}

  function app:draw(w, h)
    renderer.writeAt(1, 1, renderer.crop("SERVICE       STATE", w), colors.black, colors.lightGray)
    local rows = ctx.system.services:list()
    for i = 1, math.min(#rows, h - 1) do
      local s = rows[i]
      renderer.writeAt(1, i + 1, renderer.crop(s.name .. "       " .. s.state, w), colors.black, colors.lightGray)
    end
  end

  function app:handle()
    return false
  end

  local win = ctx.windowManager:create({ title = "Services", w = 36, h = 10, x = 16, y = 5, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
