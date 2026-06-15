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

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Services", w = math.min(46, sw - 4), h = math.min(14, sh - 3), x = 10, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
