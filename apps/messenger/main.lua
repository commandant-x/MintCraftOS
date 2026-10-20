local renderer=require('system.gui.renderer')
local keyboard=require('system.gui.keyboard')
local ui=require('system.gui.components')
local messaged=require('system.services.messaged')
local workers=require('system.libraries.app_worker')
local pixel=require('apps.messenger.pixel')
local M={}
function M.run(ctx)
  local app={input='',status='Connecting public chat...',scroll=1,messages={},seen=0,revision=0,keyboard={},follow=true}
  local worker,timer,win
  local function allowed(permission)
    return ctx.security.require(permission,'Messenger')
  end
  function app:append(from,text,own)
    self.messages[#self.messages+1]={from=tostring(from):sub(1,64),text=tostring(text):sub(1,4096),own=own==true}
    if #self.messages>80 then table.remove(self.messages,1) end
    self.revision=self.revision+1
  end
  function app:sync()
    local ok,err=allowed('rednet.receive')
    if not ok then self.status=tostring(err) return end
    local snapshot=messaged.snapshot(self.seen)
    if snapshot.dropped then self:append('System','Older messages expired from the receive buffer.') end
    for _,message in ipairs(snapshot.messages) do self:append(message.from,message.text) end
    self.seen=snapshot.sequence self.connection=snapshot.side self.warning=snapshot.securityWarning
    if not self.busy and not self.operationError then self.status=snapshot.status end
  end
  function app:action(id)
    if id=='clear' then self.messages={} self.revision=self.revision+1 self.scroll=1 self.follow=true return end
    if id=='keyboard' then self.softKeyboard=not self.softKeyboard return end
    if id=='live' then self.follow=true self.scroll=1 return end
    if self.busy or id~='send' and id~='rescan' then return end
    if id=='send' and self.input=='' then return end
    local ok,err=allowed('rednet.send') if not ok then self.status=tostring(err) return end
    self.busy=true self.operationError=nil self.status=id=='send' and 'Sending...' or 'Opening modem...'
    local accepted,problem=worker:submit({action=id,text=id=='send' and self.input or nil})
    if not accepted then self.busy=false self.status=tostring(problem) end
  end
  app.keyboard.onText=function(text) app.input=(app.input..text):sub(1,4096) end
  app.keyboard.onBackspace=function() app.input=app.input:sub(1,-2) end
  app.keyboard.onEnter=function() app:action('send') end
  function app:draw(w,h)
    if h<5 then renderer.writeAt(1,1,renderer.crop('Enlarge Messenger',w),colors.black,colors.lightGray) return end
    self.toolbar=ui.toolbar(1,1,w,{{id='send',label='Send'},{id='clear',label='Clear'},{id='rescan',label='Modem'}})
    renderer.writeAt(1,2,renderer.crop(self.status,w),colors.black,colors.lightGray)
    local kbH=keyboard.height() local listH=math.max(0,h-kbH-5)
    renderer.writeAt(1,3,renderer.crop('PUBLIC: unauthenticated / unencrypted',w),colors.red,colors.lightGray)
    self.scroll=math.max(1,math.min(self.scroll,math.max(1,#self.messages-listH+1)))
    local first=math.max(1,#self.messages-listH+2-self.scroll)
    for i=1,listH do local row=self.messages[first+i-1]
      renderer.writeAt(1,i+3,renderer.crop(row and (row.from..': '..row.text) or '',w),colors.black,colors.lightGray)
    end
    renderer.writeAt(1,math.max(4,h-kbH),renderer.crop('> '..self.input,w),colors.white,colors.gray)
    self.keyboard.x=1 self.keyboard.y=h-kbH+1 self.keyboard.hint='Message'
    if self.keyboard.y>=5 then keyboard.draw(1,self.keyboard.y,w,self.keyboard) end
  end
  function app:handle(event)
    if self.graphicsActive and not event.name:match('^mouse_') then return self:handlePixels(event) end
    if event.name=='mouse_scroll' then self.scroll=math.max(1,self.scroll+event.args[1]) return true end
    if event.name=='char' or event.name=='paste' then self.keyboard.onText(event.args[1]) return true end
    if event.name=='key' then
      if event.args[1]==keys.backspace then self.keyboard.onBackspace() return true end
      if event.args[1]==keys.enter then self:action('send') return true end
    elseif event.name=='mouse_click' then
      if event.monitorTouch and keyboard.handle(event,self.keyboard) then return true end
      local id=ui.toolbarHit(self.toolbar,event.args[2],event.args[3]) if id then self:action(id) return true end
    end return false
  end
  worker=workers.new(ctx,'Messenger transport',function(request)
    local ok,err=allowed('rednet.send') if not ok then return false,err end
    if request.action=='rescan' then return messaged.open() end
    return messaged.send(request.text)
  end,function(request,ran,ok,message)
    app.busy=false
    if not ran then message=tostring(ok)..'; transmission outcome unknown; not retried' ok=false end
    app.status=tostring(message or (ok and 'Ready' or 'Transport refused')) app.operationError=not ok
    if request.action=='send' and ok then
      app:append('me',request.text,true)
      if app.input==request.text then app.input='' end app.follow=true app.scroll=1
    end
    app:sync()
  end)
  pixel.attach(app)
  local sw,sh=term.getSize()
  win=ctx.windowManager:create({title='Messenger',w=math.min(90,sw),h=math.min(32,sh-1),x=2,y=2,app=app})
  ctx.onCleanup(function() if timer then ctx.cancelTimer(timer) end end)
  app:sync() app:action('rescan') timer=ctx.startTimer(0.5)
  while not win.closed do
    local event=ctx.pullEvent()
    if event and event.name=='timer' and event.args[1]==timer then
      if not win.minimized then app:sync() end timer=ctx.startTimer(0.5)
    elseif event and (event.name=='rednet_message' or event.name=='peripheral' or event.name=='peripheral_detach') then
      if not win.minimized then app:sync() end
    end
  end
end
return M
