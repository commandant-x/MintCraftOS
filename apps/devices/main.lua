local renderer=require('system.gui.renderer')
local theme=require('system.gui.theme')
local ui=require('system.gui.components')
local deviced=require('system.services.deviced')
local combat=require('system.services.combatd')
local avionics=require('system.services.avionicsd')
local sable=require('system.services.sabled')
local workers=require('system.libraries.app_worker')
local model=require('apps.devices.model')
local pixel=require('apps.devices.pixel')
local M={}
function M.run(ctx)
  local app={rows={},scroll=1,detailScroll=0,query='',category='all',message='Reading inventory',methods={},probes={},header={},inventoryGeneration=0}
  local win,timer,worker
  local function dirty() if win then win.dirty=true end end
  function app:filteredRows() return model.filter(self.rows,self.query,self.category) end
  function app:selectedRow() for _,row in ipairs(self.rows) do if row.name==self.selected then return row end end end
  function app:requestRead(scan)
    self.wantScan=self.wantScan or scan
    if self.busy then return end
    self.busy=true
    local request={scan=self.wantScan==true,selected=self.selected} self.wantScan=false
    if request.scan then self.inventoryGeneration=self.inventoryGeneration+1 self.probes={} self.methods={} end
    local ok,err=worker:submit(request)
    if not ok then self.busy=false self.message=tostring(err) end
    dirty()
  end
  function app:select(index)
    local rows=self:filteredRows() local row=rows[math.max(1,math.min(#rows,index))]
    local selected=row and row.name or nil
    if selected~=self.selected then self.methods={} self.probes={} self.methodError=nil self.methodOwner=nil end
    self.selected=selected self.detailScroll=0 self.focus='list'
    if row then
      index=math.max(1,math.min(#rows,index))
      if index<self.scroll then self.scroll=index elseif index>=self.scroll+(self.visible or 1) then self.scroll=index-(self.visible or 1)+1 end
    end
    self:requestRead(false)
  end
  function app:filterChanged()
    self.scroll=1 self.detailScroll=0
    local found=false for _,row in ipairs(self:filteredRows()) do if row.name==self.selected then found=true end end
    if not found then self.selected=nil self.inspect=false end
  end
  function app:detailText()
    local text=model.details(self:selectedRow(),self.selected and self.methods[self.selected],self.selected and self.probes[self.selected])
    if self.methodError and self.methodOwner==self.selected then text=text..'\nMetadata error: '..self.methodError end
    return text..'\n\nDisplay: '..tostring(self.header.summary or 'pending')..'\n'..tostring(self.header.addons or '')..
      '\nRead state: '..tostring(self.readMessage or 'pending')..'\nStatus: '..tostring(self.message)
  end
  function app:activate(id)
    if id=='rescan' then self:requestRead(true)
    elseif id=='display' then
      local ok,err=ctx.apps.launch('settings',{page='display'}) self.message=ok and 'Display settings opened' or tostring(err)
    elseif id=='probe' then
      if not self:selectedRow() or self.probePending then return end
      local ok,result=combat.requestProbe({pid=ctx.pid},self.selected)
      self.message=ok and ('Probe #'..result..' queued') or tostring(result)
      if ok then self.probePending={id=result,name=self.selected,generation=self.inventoryGeneration,since=os.clock()} end
    elseif id=='details' then self.inspect=not self.inspect self.focus=self.inspect and 'details' or 'list' end
    dirty()
  end
  function app:draw(w,h)
    renderer.fill(1,1,w,h,theme.get('windowBg')) self.lastH=h
    self.buttons=ui.toolbar(1,1,w,{{id='rescan',label='Rescan'},{id='display',label='Display'},{id='probe',label='Probe'}})
    renderer.writeAt(1,2,renderer.crop(self.header.summary or 'Reading display',w),theme.get('windowFg'))
    local rows=self:filteredRows() self.visible=math.max(1,h-5)
    self.scroll=math.max(1,math.min(self.scroll,math.max(1,#rows-self.visible+1)))
    for i=self.scroll,math.min(#rows,self.scroll+self.visible-1) do
      local row=rows[i] local bg=row.name==self.selected and theme.get('accent') or theme.get('windowBg')
      renderer.writeAt(1,3+i-self.scroll,renderer.crop(row.name..' | '..row.type..' | '..row.role,w),theme.get('windowFg'),bg)
    end
    if h>=4 then renderer.writeAt(1,h,renderer.crop(self.message,w),theme.get('windowFg')) end
  end
  function app:handle(event)
    if self.graphicsActive and not event.name:match('^mouse_') then return self:handlePixels(event) end
    if event.name=='mouse_scroll' then self.scroll=math.max(1,self.scroll+event.args[1]) return true end
    if event.name~='mouse_click' then return false end
    local x,y=event.args[2],event.args[3] local action=ui.toolbarHit(self.buttons,x,y)
    if action then self:activate(action) return true end
    if y>=3 and y<(self.lastH or 3) then self:select(self.scroll+y-3) return true end
    return false
  end
  pixel.attach(app)
  worker=workers.new(ctx,'Device metadata',function(request)
    local allowed,denied=ctx.security.require('devices.list','inventory') if not allowed then error(denied,0) end
    if request.scan then deviced.scan() combat.rescan() avionics.rescan() sable.rescan() end
    local source=deviced.list() local result={rows={},partial=#source>512,error=deviced.scanError}
    for i=1,math.min(512,#source) do local row=source[i] row.role=model.role(row) result.rows[#result.rows+1]=row end
    local good,display=pcall(deviced.getDisplay)
    local stats=ctx.system.renderStats and ctx.system.renderStats() or {}
    result.header={summary=good and (tostring(display.monitorSide or display.terminalSide or display.target)..' '..display.width..'x'..display.height..' cells | '..tostring(stats.backend or 'TEXT')) or 'Display read failed: '..tostring(display)}
    if stats.pixelWidth and stats.pixelHeight then result.header.summary=result.header.summary..' | '..stats.pixelWidth..'x'..stats.pixelHeight..' pixels' end
    local flight,air=sable.status(),avionics.status()
    result.header.addons='Sable available: '..tostring(flight.available)..' | sublevel: '..tostring(flight.inSublevel)..' | Avionics: '..tostring(air.available)
    if request.selected then
      local ok,methods=pcall(peripheral.getMethods,request.selected)
      result.methodOwner=request.selected result.methods={}
      if ok and type(methods)=='table' then
        for i=1,math.min(#methods,128) do if type(methods[i])=='string' then result.methods[#result.methods+1]=methods[i]:sub(1,100) end end table.sort(result.methods)
        if #methods>128 then result.methods[#result.methods+1]='[metadata truncated at 128 methods]' end
      else result.methodError=tostring(methods):sub(1,1024) end
    end
    return result
  end,function(request,ok,result)
    app.busy=false
    if not ok then app.message='Inventory read failed: '..tostring(result):sub(1,2048) dirty() return end
    app.rows=result.rows app.header=result.header app.partial=result.partial
    app.readMessage=result.error and ('Last retained scan: '..result.error) or result.partial and 'Inventory capped at 512 devices' or 'Inventory ready'
    if request.scan or app.message=='Reading inventory' then app.message=app.readMessage end
    local present={} for _,row in ipairs(app.rows) do present[row.name]=true end
    for name in pairs(app.methods) do if not present[name] then app.methods[name]=nil app.probes[name]=nil end end
    if app.selected and not present[app.selected] then app.selected=nil app.inspect=false end
    if result.methodOwner and result.methodOwner==app.selected and present[result.methodOwner] then app.methods[result.methodOwner]=result.methods end
    app.methodOwner=result.methodOwner app.methodError=result.methodError
    dirty()
  end)
  local w,h=term.getSize()
  win=ctx.windowManager:create({title='Devices',w=math.min(96,w-4),h=math.min(30,h-3),x=4,y=3,app=app})
  ctx.onCleanup(function() if timer then ctx.cancelTimer(timer) end combat.release(ctx.pid) end)
  app:requestRead(false) timer=ctx.startTimer(1)
  while not win.closed do
    local event=ctx.pullEvent()
    if event and event.name=='timer' and event.args[1]==timer then
      if app.probePending and os.clock()-app.probePending.since>8 then app.probePending=nil app.message='Probe timed out; no automatic retry. Inspect service/Logs.' dirty() end
      if not win.minimized then app:requestRead(false) end timer=ctx.startTimer(1)
    elseif event and (event.name=='peripheral' or event.name=='peripheral_detach' or event.name=='mintcraft_display_resize') then app:requestRead(true)
    elseif event and event.name=='mintcraft_combat_result' and event.args[1]==ctx.pid and app.probePending and event.args[2]==app.probePending.id then
      local pending=app.probePending app.probePending=nil app.message=tostring(event.args[4])
      local result=combat.snapshot().probe
      if pending.generation~=app.inventoryGeneration then app.message='Inventory changed; run Probe again'
      elseif event.args[3] and result and result.name==pending.name and result.operationId==pending.id and result.ownerPid==ctx.pid and app.selected==pending.name then app.probes={[pending.name]=result} app.detailScroll=0 end
      dirty()
    end
  end
end
return M
