local Window = require("system.wm.window")
local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")
local taskbar = require("system.gui.taskbar")

local WindowManager = {}
WindowManager.__index = WindowManager

function WindowManager.new()
  return setmetatable({ windows = {}, nextId = 1, taskButtons = {}, taskPage = 1 }, WindowManager)
end

function WindowManager:create(opts)
  opts.id = self.nextId
  self.nextId = self.nextId + 1
  local win = Window.new(opts)
  table.insert(self.windows, win)
  return win
end

function WindowManager:focus(win)
  if win.closed or win.minimized then return end
  for i, item in ipairs(self.windows) do
    if item == win then
      table.remove(self.windows, i)
      break
    end
  end
  table.insert(self.windows, win)
end

function WindowManager:active()
  for i = #self.windows, 1, -1 do
    local win = self.windows[i]
    if not win.closed and not win.minimized then return win end
  end
end

function WindowManager:invalidate(appId)
  for _,win in ipairs(self.windows) do
    if not appId or win.appId==appId then win.dirty=true end
  end
end

function WindowManager:draw()
  for i = #self.windows, 1, -1 do
    if self.windows[i].closed then table.remove(self.windows, i) end
  end

  for index, win in ipairs(self.windows) do
    local covered=false
    for upper=index+1,#self.windows do
      local other=self.windows[upper]
      local a,b=win.pixelBounds,other.pixelBounds
      if not other.closed and not other.minimized then
        if win.pixelManaged and other.pixelManaged and a and b then
          if b.x<=a.x and b.y<=a.y and b.x+b.w>=a.x+a.w and b.y+b.h>=a.y+a.h then covered=true break end
        elseif not win.pixelManaged and other.x<=win.x and other.y<=win.y and
          other.x+other.w>=win.x+win.w and other.y+other.h>=win.y+win.h then covered=true break end
      end
    end
    if not covered then win:draw() end
  end

  local w, h = term.getSize()
  local layout = taskbar.layout(w)
  local x, maxRight = layout.first, layout.last
  self.taskButtons = {}
  self.taskArrows = {}
  local ordered = {}
  for _, win in ipairs(self.windows) do
    if not win.closed then ordered[#ordered + 1] = win end
  end
  table.sort(ordered, function(a, b) return a.id < b.id end)
  local available = maxRight - x + 1
  if available < 5 then return end
  local capacity = math.max(1, math.floor(available / 11))
  if #ordered > capacity then
    capacity = math.max(1, math.floor((available - 4) / 11))
    self.taskArrows = {{x = x, delta = -1}, {x = maxRight, delta = 1}}
    renderer.writeAt(x, h, "<", theme.get("taskbarFg"), theme.get("buttonBg"))
    renderer.writeAt(maxRight, h, ">", theme.get("taskbarFg"), theme.get("buttonBg"))
    x, maxRight = x + 2, maxRight - 2
  end
  self.taskPages = math.max(1, math.ceil(#ordered / capacity))
  self.taskPage = math.min(self.taskPages, math.max(1, self.taskPage))
  local first = (self.taskPage - 1) * capacity + 1
  for index = first, math.min(#ordered, first + capacity - 1) do
      local win = ordered[index]
      local label = (win.minimized and "_" or "") .. win.title
      local width = math.min(10, maxRight - x + 1)
      local bg = win == self:active() and theme.get("accent") or theme.get("buttonBg")
      renderer.writeAt(x, h, renderer.crop(label, width), theme.get("taskbarFg"), bg)
      table.insert(self.taskButtons, { x = x, w = width, win = win })
      x = x + width + 1
  end
end

function WindowManager:handle(event)
  if event.name == "mouse_scroll" then
    local _, x, y = table.unpack(event.args)
    if y == ({term.getSize()})[2] then return false end
    for i = #self.windows, 1, -1 do
      local win = self.windows[i]
      if win:contains(x, y) then
        win:handle(event)
        return true
      end
    end
    return false
  end
  if event.name == "mouse_click" then
    local _, x, y = table.unpack(event.args)
    if y == ({ term.getSize() })[2] then
      for _, arrow in ipairs(self.taskArrows or {}) do
        if x == arrow.x then
          self.taskPage = math.max(1, math.min(self.taskPages, self.taskPage + arrow.delta))
          return true
        end
      end
      for _, box in ipairs(self.taskButtons or {}) do
        if x >= box.x and x < box.x + box.w then
          box.win.minimized = false
          self:focus(box.win)
          return true
        end
      end
      return false
    end
    local active = self:active()
    if active and active.movePending then
      return active:handle(event)
    end
    for i = #self.windows, 1, -1 do
      local win = self.windows[i]
      if win:contains(x, y) then
        self:focus(win)
        win:handle(event)
        return true
      end
    end
  else
    if event.name == "timer" or event.name == "peripheral" or event.name == "peripheral_detach" then
      -- Background app timers must not depend on keyboard focus.
      for _, win in ipairs(self.windows) do
        if not win.closed then win:handle(event) end
      end
      return false
    end
    local win = self:active()
    if win then
      win:handle(event)
      return true
    end
  end
  return false
end

return WindowManager
