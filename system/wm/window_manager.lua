local Window = require("system.wm.window")
local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")

local WindowManager = {}
WindowManager.__index = WindowManager

function WindowManager.new()
  return setmetatable({ windows = {}, nextId = 1 }, WindowManager)
end

function WindowManager:create(opts)
  opts.id = self.nextId
  self.nextId = self.nextId + 1
  local win = Window.new(opts)
  table.insert(self.windows, win)
  return win
end

function WindowManager:focus(win)
  for i, item in ipairs(self.windows) do
    if item == win then
      table.remove(self.windows, i)
      break
    end
  end
  table.insert(self.windows, win)
end

function WindowManager:draw()
  for i = #self.windows, 1, -1 do
    if self.windows[i].closed then table.remove(self.windows, i) end
  end

  for _, win in ipairs(self.windows) do
    win:draw()
  end

  local w, h = term.getSize()
  local x = 10
  for _, win in ipairs(self.windows) do
    if win.minimized then
      local label = "[" .. win.title .. "]"
      renderer.writeAt(x, h, renderer.crop(label, math.min(#label, 14)), theme.get("taskbarFg"), theme.get("taskbarBg"))
      x = x + math.min(#label, 14) + 1
    end
  end
end

function WindowManager:handle(event)
  if event.name == "mouse_click" then
    local _, x, y = table.unpack(event.args)
    for i = #self.windows, 1, -1 do
      local win = self.windows[i]
      if win.minimized and y == ({ term.getSize() })[2] then
        win.minimized = false
        self:focus(win)
        return true
      end
      if win:contains(x, y) then
        self:focus(win)
        return win:handle(event)
      end
    end
  else
    local win = self.windows[#self.windows]
    if win then return win:handle(event) end
  end
  return false
end

return WindowManager
