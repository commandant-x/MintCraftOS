local renderer = require("system.gui.renderer")
local ui = require("system.gui.components")

local M = {}

function M.run(ctx)
  local app = { selected = nil, scroll = 1 }
  local actions = {
    { id = "start", label = "Start" },
    { id = "stop", label = "Stop" },
    { id = "restart", label = "Restart" },
  }
  local protected = { deviced = true, notifd = true, logd = true }

  function app:draw(w, h)
    self.toolbar = ui.toolbar(1, 1, w, actions)
    renderer.writeAt(1, 2, renderer.crop("SERVICE       STATE      AUTO", w), colors.black, colors.gray)
    local rows = ctx.system.services:list()
    for i = 1, math.min(#rows, h - 4) do
      local s = rows[self.scroll + i - 1]
      if s then
        local bg = s.name == self.selected and colors.cyan or colors.lightGray
        local mark = protected[s.name] and " protected" or ""
        renderer.writeAt(1, i + 2, renderer.crop(s.name .. "       " .. s.state .. "      " .. tostring(s.autostart) .. mark, w), colors.black, bg)
      end
    end
    local selected
    for _, s in ipairs(rows) do if s.name == self.selected then selected = s end end
    if selected then
      renderer.writeAt(1, h, renderer.crop("Last error: " .. tostring(selected.error or "-"), w), colors.gray, colors.lightGray)
    end
  end

  function app:handle(event)
    if event.name == "mouse_scroll" then
      self.scroll = math.max(1, self.scroll + event.args[1])
      return true
    end
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    local action = ui.toolbarHit(self.toolbar, x, y)
    if action and self.selected then
      if protected[self.selected] and action ~= "start" then
        if ctx.notifications then ctx.notifications:push("warn", "Services", self.selected .. " is protected", 3) end
        return true
      end
      if action == "start" then
        ctx.system.services:start(self.selected)
      elseif action == "stop" then
        ctx.system.services:stop(self.selected)
      elseif action == "restart" then
        ctx.system.services:stop(self.selected)
        ctx.system.services:start(self.selected)
      end
      return true
    end
    if y >= 3 then
      local rows = ctx.system.services:list()
      local s = rows[self.scroll + y - 3]
      if s then self.selected = s.name return true end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Services", w = math.min(46, sw - 4), h = math.min(14, sh - 3), x = 10, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
