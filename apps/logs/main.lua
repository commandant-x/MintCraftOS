local renderer = require("system.gui.renderer")
local log = require("system.libraries.log")
local menu = require("system.gui.action_menu")
local theme = require("system.gui.theme")

local M = {}

function M.run(ctx)
  local app = { filter = "all", menu = menu.new() }
  local actions = {
    { id = "all", label = "All" },
    { id = "error", label = "Error" },
    { id = "warn", label = "Warn" },
    { id = "info", label = "Info" },
    { id = "debug", label = "Debug" },
    { id = "refresh", label = "Refresh" },
  }

  local function parse(line)
    return log.parse(line)
  end

  local function format(row)
    local text = tostring(row.time or "") .. " " .. tostring(row.level or "?") .. " " .. tostring(row.source or "?") .. ": " .. tostring(row.message or "")
    return (text:gsub("[%c]", " "))
  end

  local function matches(row, filter)
    if filter == "all" then return true end
    return tostring(row.level or "") == filter
  end

  function app:draw(w, h)
    renderer.fill(1, 1, w, h, theme.get("windowBg"))
    menu.bar(self.menu, 1, 1, w, actions, {selector=true,label="Filter: " .. self.filter,title="Log filters",selected=self.filter})
    if h >= 2 then renderer.writeAt(1, 2, renderer.crop("System Logs - " .. self.filter, w), theme.get("windowFg"), theme.get("windowBg")) end
    if self.revision ~= log.revision() or self.cachedFilter ~= self.filter then
      self.lines = {}
      for _, line in ipairs(log.tail(120)) do
        local row = parse(line)
        if matches(row, self.filter) then table.insert(self.lines, format(row)) end
      end
      self.revision, self.cachedFilter = log.revision(), self.filter
    end
    local lines = self.lines
    local start = math.max(1, #lines - h + 3)
    local y = 3
    for i = start, #lines do
      if y > h then break end
      renderer.writeAt(1, y, renderer.crop(lines[i], w), theme.get("windowFg"), theme.get("windowBg"))
      y = y + 1
      if y > h then break end
    end
    if h >= 5 then menu.overlay(self.menu, w, h) end
  end

  function app:handle(event)
    local action, handled = menu.handle(self.menu, event)
    if action == "refresh" then log.invalidate()
    elseif action then self.filter = action end
    return handled
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Logs", w = math.min(72, sw - 4), h = math.min(18, sh - 3), x = 5, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
