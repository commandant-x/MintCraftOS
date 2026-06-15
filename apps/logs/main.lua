local renderer = require("system.gui.renderer")
local log = require("system.libraries.log")
local ui = require("system.gui.components")

local M = {}

function M.run(ctx)
  local app = { filter = "all" }
  local actions = {
    { id = "all", label = "All" },
    { id = "error", label = "Error" },
    { id = "warn", label = "Warn" },
    { id = "info", label = "Info" },
    { id = "refresh", label = "Refresh" },
  }

  local function matches(line, filter)
    if filter == "all" then return true end
    return line:lower():find("\"" .. filter .. "\"", 1, true) ~= nil
  end

  function app:draw(w, h)
    self.toolbar = ui.toolbar(1, 1, w, actions)
    renderer.writeAt(1, 2, renderer.crop("System Logs - " .. self.filter, w), colors.black, colors.lightGray)
    local raw = log.tail(120)
    local lines = {}
    for _, line in ipairs(raw) do if matches(line, self.filter) then table.insert(lines, line) end end
    local start = math.max(1, #lines - h + 3)
    local y = 3
    for i = start, #lines do
      renderer.writeAt(1, y, renderer.crop(lines[i], w), colors.black, colors.lightGray)
      y = y + 1
      if y > h then break end
    end
  end

  function app:handle(event)
    if event.name == "mouse_click" then
      local _, x, y = table.unpack(event.args)
      local action = ui.toolbarHit(self.toolbar, x, y)
      if action then
        if action ~= "refresh" then self.filter = action end
        return true
      end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Logs", w = math.min(72, sw - 4), h = math.min(18, sh - 3), x = 5, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
