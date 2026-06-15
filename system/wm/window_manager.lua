local Window = require("system.wm.window")
local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")

local WindowManager = {}
WindowManager.__index = WindowManager

function WindowManager.new()
  return setmetatable({ windows = {}, nextId = 1, taskButtons = {} }, WindowManager)
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
  self.taskButtons = {}
  for _, win in ipairs(self.windows) do
    if not win.closed then
      local label = "[" .. win.title .. "]"
      local width = math.min(#label, 14)
      local bg = win.minimized and theme.get("buttonBg") or theme.get("accent")
      renderer.writeAt(x, h, renderer.crop(label, width), theme.get("taskbarFg"), bg)
      table.insert(self.taskButtons, { x = x, w = width, win = win })
      x = x + width + 1
      if x > w - 10 then break end
    end
  end
end

function WindowManager:handle(event)
  if event.name == "mouse_click" then
    local _, x, y = table.unpack(event.args)
    if y == ({ term.getSize() })[2] then
      for _, box in ipairs(self.taskButtons or {}) do
        if x >= box.x and x < box.x + box.w then
          box.win.minimized = false
          self:focus(box.win)
          return true
        end
      end
    end
    local active = self.windows[#self.windows]
    if active and active.movePending then
      return active:handle(event)
    end
    for i = #self.windows, 1, -1 do
      local win = self.windows[i]
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
