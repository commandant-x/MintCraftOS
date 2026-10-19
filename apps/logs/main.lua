local renderer = require("system.gui.renderer")
local log = require("system.libraries.log")
local menu = require("system.gui.action_menu")
local theme = require("system.gui.theme")
local pixel = require("apps.logs.pixel")

local M = {}

function M.run(ctx)
  local app = { filter = "all", menu = menu.new(), records={}, rows={}, lines={}, first=1, follow=true }
  local win,timer
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

  function app:refresh(force)
    local changed=force or self.revision~=log.revision() or self.cachedFilter~=self.filter
    if not changed then return false end
    if force or self.revision~=log.revision() then
      self.records={}
      local occurrences={}
      for _,line in ipairs(log.tail(120)) do
        local row=parse(line)
        occurrences[line]=(occurrences[line] or 0)+1
        self.records[#self.records+1]={id=occurrences[line]..":"..line,time=tostring(row.time or ""),level=tostring(row.level or "?"),source=tostring(row.source or "?"),message=tostring(row.message or "")}
      end
      self.readError=log.tailStatus and log.tailStatus().error or nil
      if self.readError then self.readError=tostring(self.readError):gsub("[%c]"," ") end
      self.revision=log.revision()
    end
    self.rows,self.lines={},{}
    local retained=false
    for _,row in ipairs(self.records) do if matches(row,self.filter) then
      self.rows[#self.rows+1]=row self.lines[#self.lines+1]=format(row)
      if self.selected==row.id then retained=true end
    end end
    if not retained then self.selected=nil self.detailScroll=0 end
    self.cachedFilter=self.filter
    if win then win.dirty=true end
    return true
  end
  function app:setFilter(id)
    self.filter=id self.first=1 self.detailScroll=0 self:refresh()
  end
  function app:requestRefresh()
    log.invalidate() self:refresh(true)
  end

  function app:draw(w, h)
    renderer.fill(1, 1, w, h, theme.get("windowBg"))
    menu.bar(self.menu, 1, 1, w, actions, {selector=true,label="Filter: " .. self.filter,title="Log filters",selected=self.filter})
    if h >= 2 then renderer.writeAt(1, 2, renderer.crop(self.readError and ("Read error: "..self.readError) or ("System Logs - " .. self.filter), w), theme.get("windowFg"), theme.get("windowBg")) end
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
    if self.graphicsActive and not event.name:match("^mouse_") then return self:handlePixels(event) end
    local action, handled = menu.handle(self.menu, event)
    if action == "refresh" then self:requestRefresh()
    elseif action then self:setFilter(action) end
    return handled
  end

  pixel.attach(app)
  app:refresh()
  local sw, sh = term.getSize()
  win = ctx.windowManager:create({ title = "Logs", w = math.min(90, sw - 4), h = math.min(28, sh - 3), x = 5, y = 3, app = app })
  ctx.onCleanup(function() if timer then os.cancelTimer(timer) end end)
  timer=ctx.startTimer(0.5)
  while not win.closed do
    local event=ctx.pullEvent()
    if event and event.name=="timer" and event.args[1]==timer then
      if not win.minimized then app:refresh() end
      timer=ctx.startTimer(0.5)
    end
  end
end

return M
