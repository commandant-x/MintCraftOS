local renderer = require("system.gui.renderer")

local M = {}

function M.run(ctx)
  local app = {}

  function app:draw(w, h)
    renderer.writeAt(1, 1, renderer.crop("PID STATE    NAME", w), colors.black, colors.lightGray)
    local rows = ctx.listProcesses()
    for i = 1, math.min(#rows, h - 1) do
      local p = rows[i]
      renderer.writeAt(1, i + 1, renderer.crop(tostring(p.pid) .. "   " .. p.state .. "   " .. p.name, w), colors.black, colors.lightGray)
    end
  end

  function app:handle()
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Task Manager", w = math.min(58, sw - 4), h = math.min(16, sh - 3), x = 8, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
