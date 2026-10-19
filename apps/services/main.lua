local renderer=require("system.gui.renderer")
local ui=require("system.gui.components")
local theme=require("system.gui.theme")
local pixel=require("apps.services.pixel")
local M={}
function M.run(ctx)
  local manager=ctx.system.services
  local app={selected=nil,scroll=1,rows={},control={busy=false},message="Ready"}
  local win,timer
  local actions={{id="start",label="Start"},{id="stop",label="Stop"},{id="restart",label="Restart"}}
  function app:refresh()
    local ok,rows=pcall(manager.list,manager)
    if not ok then self.message="Read failed: "..tostring(rows):gsub("[%c]"," ") if win then win.dirty=true end return false end
    self.rows=rows self.control=manager:controlStatus()
    local retained=false
    for _,row in ipairs(self.rows) do if row.name==self.selected then retained=true end end
    if not retained then self.selected=nil end
    if win then win.dirty=true end
  end
  function app:request(action)
    if not self.selected then self.message="No service selected" return end
    local called,ok,result=pcall(manager.requestAction,manager,{pid=ctx.pid},action,self.selected)
    if not called then result=ok ok=false end
    self.message=ok and ("Queued #"..result..": "..action.." "..self.selected) or tostring(result)
    if ok then self.operation=result end
    self:refresh()
  end
  function app:draw(w,h)
    self.lastH=h
    renderer.fill(1,1,w,h,theme.get("windowBg"))
    self.toolbar=ui.toolbar(1,1,w,actions)
    renderer.writeAt(1,2,renderer.crop("SERVICE       STATE      AUTO",w),theme.get("titleFg"),theme.get("titleBg"))
    self.scroll=math.max(1,math.min(self.scroll,math.max(1,#self.rows-h+5)))
    for i=1,math.max(0,math.min(#self.rows,h-4)) do
      local row=self.rows[self.scroll+i-1]
      if row then
        local bg=row.name==self.selected and theme.get("accent") or theme.get("windowBg")
        renderer.writeAt(1,i+2,renderer.crop(row.name.."       "..row.state.."      "..tostring(row.autostart)..(row.protected and " protected" or ""),w),theme.get("windowFg"),bg)
      end
    end
    if h>=4 then renderer.writeAt(1,h,renderer.crop(tostring(self.message):gsub("[%c]"," "),w),theme.get("windowFg"),theme.get("windowBg")) end
    local selected
    for _,row in ipairs(self.rows) do if row.name==self.selected then selected=row end end
    if selected and h>=5 then
      renderer.writeAt(1,h-1,renderer.crop(("Last: "..tostring(selected.lastSuccess or "unknown").." | Error: "..tostring(selected.error or "none")):gsub("[%c]"," "),w),theme.get("windowFg"),theme.get("windowBg"))
    end
  end
  function app:handle(event)
    if self.graphicsActive and not event.name:match("^mouse_") then return self:handlePixels(event) end
    if event.name=="mouse_scroll" then self.scroll=math.max(1,self.scroll+event.args[1]) return true end
    if event.name~="mouse_click" then return false end
    local _,x,y=table.unpack(event.args)
    local action=ui.toolbarHit(self.toolbar,x,y)
    if action then self:request(action) return true end
    if y>=3 and y<(self.lastH or 3) then
      local row=self.rows[self.scroll+y-3]
      if row then self.selected=row.name return true end
    end
    return false
  end
  pixel.attach(app)
  app:refresh()
  local w,h=term.getSize()
  win=ctx.windowManager:create({title="Services",w=math.min(88,w-4),h=math.min(28,h-3),x=10,y=4,app=app})
  ctx.onCleanup(function() if timer then os.cancelTimer(timer) end end)
  timer=ctx.startTimer(0.5)
  while not win.closed do
    local event=ctx.pullEvent()
    if event and event.name=="timer" and event.args[1]==timer then
      if not win.minimized then app:refresh() end timer=ctx.startTimer(0.5)
    elseif event and event.name=="mintcraft_service_result" and event.args[1]==ctx.pid and event.args[2]==app.operation then
      app.operation=nil app.message=tostring(event.args[4]) app:refresh()
      if ctx.notifications then ctx.notifications:push(event.args[3] and "success" or "error","Services",app.message,5) end
    end
  end
end
return M
