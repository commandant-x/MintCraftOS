local theme = require("system.gui.theme")
local renderer = require("system.gui.renderer")

local Window = {}
Window.__index = Window

function Window.new(opts)
  local w, h = term.getSize()
  local width = opts.w or math.min(38, w - 8)
  local height = opts.h or math.min(12, h - 5)
  width = math.max(12, math.min(width, w))
  height = math.max(5, math.min(height, h - 1))
  return setmetatable({
    id = opts.id,
    title = opts.title or "Window",
    x = opts.x or 6,
    y = opts.y or 3,
    w = width,
    h = height,
    minimized = false,
    closed = false,
    dragging = false,
    movePending = false,
    app = opts.app,
    ownerPid = opts.ownerPid,
  }, Window)
end

function Window:clamp()
  local sw, sh = term.getSize()
  local maxX = math.max(1, sw - self.w + 1)
  local maxY = math.max(1, sh - self.h)
  self.x = math.max(1, math.min(self.x, maxX))
  self.y = math.max(1, math.min(self.y, maxY))
end

function Window:contains(x, y)
  return x >= self.x and x < self.x + self.w and y >= self.y and y < self.y + self.h
end

function Window:titleContains(x, y)
  return y == self.y and x >= self.x and x < self.x + self.w
end

function Window:draw()
  if self.closed or self.minimized then return end
  self:clamp()
  renderer.fill(self.x + 1, self.y + 1, self.w, self.h, theme.get("shadow"))
  renderer.fill(self.x, self.y, self.w, self.h, theme.get("windowBg"))
  local title = self.movePending and " Tap destination" or (" " .. self.title)
  renderer.writeAt(self.x, self.y, renderer.crop(title, self.w - 7), theme.get("titleFg"), theme.get("titleBg"))
  renderer.writeAt(self.x + self.w - 6, self.y, " - []X", theme.get("titleFg"), theme.get("titleBg"))

  if self.app and self.app.draw then
    local target = window.create(term.current(), self.x + 1, self.y + 1, self.w - 2, self.h - 2, false)
    local previous = term.redirect(target)
    term.setBackgroundColor(theme.get("windowBg"))
    term.setTextColor(theme.get("windowFg"))
    term.clear()
    local ok, err = pcall(self.app.draw, self.app, self.w - 2, self.h - 2)
    term.redirect(previous)
    if ok then
      target.setVisible(true)
    else
      renderer.writeAt(self.x + 1, self.y + 1, "Draw error: " .. tostring(err), theme.get("error"), theme.get("windowBg"))
    end
  end
end

function Window:handle(event)
  if self.closed or self.minimized then return false end
  if event.name == "mouse_click" then
    local button, x, y = table.unpack(event.args)
    if self.movePending then
      self.x = x - math.floor(self.w / 2)
      self.y = y
      self.movePending = false
      self:clamp()
      return true
    end
    if button == 1 and y == self.y and x >= self.x + self.w - 1 then
      self.closed = true
      return true
    elseif button == 1 and y == self.y and x >= self.x + self.w - 6 and x < self.x + self.w - 3 then
      self.minimized = true
      return true
    elseif button == 1 and y == self.y and x >= self.x + self.w - 3 and x < self.x + self.w - 1 then
      local sw, sh = term.getSize()
      self.x, self.y = 1, 1
      self.w, self.h = sw, math.max(5, sh - 1)
      return true
    elseif button == 1 and self:titleContains(x, y) then
      if event.monitorTouch then
        self.movePending = true
        return true
      end
      self.dragging = { dx = x - self.x, dy = y - self.y }
      return true
    end
  elseif event.name == "mouse_drag" and self.dragging then
    local _, x, y = table.unpack(event.args)
    self.x = x - self.dragging.dx
    self.y = y - self.dragging.dy
    self:clamp()
    return true
  elseif event.name == "mouse_up" then
    self.dragging = false
  end

  if self.app and self.app.handle then
    local localEvent = event
    if event.name:match("^mouse_") then
      local args = { table.unpack(event.args) }
      args[2] = args[2] - self.x
      args[3] = args[3] - self.y
      localEvent = {
        name = event.name,
        args = args,
        raw = event.raw,
        monitorTouch = event.monitorTouch,
        monitorSide = event.monitorSide,
      }
    end
    return self.app:handle(localEvent, self)
  end
  return false
end

return Window
