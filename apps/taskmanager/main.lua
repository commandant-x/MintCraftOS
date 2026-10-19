local renderer=require("system.gui.renderer")
local ui=require("system.gui.components")
local theme=require("system.gui.theme")
local metrics=require("apps.taskmanager.metrics")
local pixel=require("apps.taskmanager.pixel")
local M={}
function M.run(ctx)
  local app={page="processes",selectedPid=nil,scroll=1,history={},message="Ready",onlyLive=false}
  local win,timer
  local actions={{id="kill",label="Kill"},{id="refresh",label="Refresh"}}
  function app:filteredRows()
    if not self.graphicsActive then return self.snapshot.rows end
    local rows={}
    for _,row in ipairs(self.snapshot.rows) do if not self.onlyLive or row.state=="ready" then rows[#rows+1]=row end end
    return rows
  end
  function app:refresh(force)
    local now=os.clock()
    if not force and self.snapshot and now>=self.snapshot.timestamp and now-self.snapshot.timestamp<1 then return false end
    self.snapshot=metrics.sample(ctx,self.baseline,now,self.observed)
    self.observed=self.snapshot
    if self.snapshot.gap then self.baseline=self.snapshot end
    if metrics.record(self.history,self.snapshot) then self.baseline=self.snapshot end
    local retained=false
    for _,row in ipairs(self:filteredRows()) do if row.pid==self.selectedPid then retained=true if row.state~="ready" then self.confirm=nil end end end
    if not retained then self.selectedPid=nil self.confirm=nil end
    if win then win.dirty=true end
    return true
  end
  function app:kill(pid)
    self:refresh(true)
    if self.selectedPid~=pid then self.message="Selection changed; kill cancelled" return end
    local target
    for _,row in ipairs(self.snapshot.rows) do if row.pid==pid then target=row end end
    if not target or target.state~="ready" or target.protected then self.message="Process not running or protected" return end
    local ok,err=ctx.kill(pid)
    self.message=ok and "Killed PID "..pid or tostring(err)
    if ctx.notifications then ctx.notifications:push(ok and "success" or "error","Task Manager",self.message,4) end
    self:refresh(true)
  end
  function app:draw(w,h)
    if self.confirm then
      if h<5 then self.confirm=nil return end
      renderer.writeAt(1,2,renderer.crop("Kill PID "..self.confirm.pid.." - "..self.confirm.name.."?",w),theme.get("windowFg"),theme.get("windowBg"))
      self.confirmBar=ui.toolbar(1,h-1,w,{{id="confirm",label="Confirm"},{id="cancel",label="Cancel"}}) return
    end
    self.toolbar=ui.toolbar(1,1,w,actions)
    local s=self.snapshot
    renderer.writeAt(1,2,renderer.crop("Live: "..s.ready.." / "..#s.rows.." | CPU unavailable",w),theme.get("windowFg"),theme.get("windowBg"))
    if h>=4 then renderer.writeAt(1,3,renderer.crop(s.memory,w),theme.get("windowFg"),theme.get("windowBg")) end
    if h>=5 then renderer.writeAt(1,4,renderer.crop(s.disk,w),theme.get("windowFg"),theme.get("windowBg")) end
    if h<9 then self.listBottom=0 return end
    local io=s.acquisition
    renderer.writeAt(1,5,renderer.crop("Reads "..tostring(io.reads or "?").." | Active "..tostring(io.inFlight or "?").." | Queue "..tostring(io.queue or "?"),w),theme.get("windowFg"),theme.get("windowBg"))
    renderer.writeAt(1,6,renderer.crop("PID STATE APP NAME",w),theme.get("windowFg"),theme.get("buttonBg"))
    local rows=self:filteredRows() local visible=math.max(0,h-8)
    self.scroll=math.max(1,math.min(self.scroll,math.max(1,#rows-visible+1))) self.listBottom=6+visible
    for i=self.scroll,math.min(#rows,self.scroll+visible-1) do
      local row=rows[i] local bg=row.pid==self.selectedPid and theme.get("accent") or theme.get("windowBg")
      renderer.writeAt(1,7+i-self.scroll,renderer.crop(tostring(row.pid).." "..row.state.." "..tostring(row.appId or "-").." "..row.name,w),theme.get("windowFg"),bg)
    end
    local selected
    for _,row in ipairs(rows) do if row.pid==self.selectedPid then selected=row end end
    if selected then renderer.writeAt(1,h-1,renderer.crop("Active wall ms: "..tostring(selected.runtimeMs or "?").." | Perms: "..table.concat(selected.permissions or {},","),w),theme.get("windowFg"),theme.get("windowBg")) end
    renderer.writeAt(1,h,renderer.crop(tostring(self.message):gsub("[%c]"," "),w),theme.get("windowFg"),theme.get("windowBg"))
  end
  function app:handle(event)
    if self.graphicsActive and not event.name:match("^mouse_") then return self:handlePixels(event) end
    if self.confirm then
      if event.name=="key" and event.args[1]==keys.escape then self.confirm=nil return true end
      if event.name=="mouse_click" then
        local id=ui.toolbarHit(self.confirmBar,event.args[2],event.args[3])
        if id=="confirm" then local pid=self.confirm.pid self.confirm=nil self:kill(pid) elseif id=="cancel" then self.confirm=nil end
      end return true
    end
    if event.name=="mouse_scroll" then self.scroll=math.max(1,self.scroll+event.args[1]) return true end
    if event.name~="mouse_click" then return false end
    local _,x,y=table.unpack(event.args)
    local action=ui.toolbarHit(self.toolbar,x,y)
    if action=="kill" and self.selectedPid then
      for _,row in ipairs(self.snapshot.rows) do if row.pid==self.selectedPid and row.state=="ready" and not row.protected then self.confirm={pid=row.pid,name=row.name} end end return true
    elseif action=="refresh" then self:refresh(true) return true end
    if y>=7 and y<=(self.listBottom or 0) then
      local row=self:filteredRows()[self.scroll+y-7]
      if row then self.selectedPid=row.pid return true end
    end
    return false
  end
  pixel.attach(app)
  app:refresh(true)
  local w,h=term.getSize()
  win=ctx.windowManager:create({title="Task Manager",w=math.min(100,w-4),h=math.min(32,h-3),x=8,y=4,app=app})
  ctx.onCleanup(function() if timer then ctx.cancelTimer(timer) end end)
  timer=ctx.startTimer(1)
  while not win.closed do
    local event=ctx.pullEvent()
    if event and event.name=="timer" and event.args[1]==timer then if not win.minimized then app:refresh(true) end timer=ctx.startTimer(1) end
  end
end
return M
