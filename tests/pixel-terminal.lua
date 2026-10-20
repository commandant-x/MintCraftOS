package.path='./?.lua;'..package.path
keys={} for i,name in ipairs({'enter','escape','up','down','left','right','home','end','delete','pageUp','pageDown','leftCtrl','rightCtrl','c','l','u'}) do keys[name]=i end
local Surface=require('system.graphics.surface') local fonts=require('system.graphics.fonts')
local calls={} local app={lines={},lineIds={},lineColors={},outputRevision=1,cwd='/home/user',input='command',follow=true,keyboard={},
  visibleInput=function(self) return self.input,false end,refreshSuggestion=function() end,
  action=function(self,id) calls[#calls+1]=id if id=='keyboard' then self.pixelKeyboard=not self.pixelKeyboard end end,
  handleText=function(_,event) calls[#calls+1]=event.name return true end}
app.keyboard.onControl=function(id) calls[#calls+1]='control:'..id end
for i=1,100 do app.lines[i]=string.rep('output '..i..' ',12) app.lineIds[i]=i app.lineColors[i]=i%2==0 and 'text' or 'muted' end
require('apps.terminal.pixel').attach(app)
local p={panel=1,text=2,muted=3,accent=4,desktop=5,button=6,ink=7,border=8}
local function render(w,h)
  app:drawPixels(Surface.new(w,h),w,h,p)
  for _,hit in ipairs(app.pixelHits) do local r=hit.rect assert(r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,'terminal control outside client') end
  for _,hit in ipairs(app.keyboard.pixelBoxes) do local r=hit.rect assert(r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,'terminal keyboard outside client') end
end
local function event(name,...) return app:handlePixels({name=name,args={...}}) end
for _,size in ipairs({{200,120},{306,140},{600,360},{960,500}}) do
  local w,h=table.unpack(size) app.pixelKeyboard=false render(w,h)
  local layout=app.outputLayout render(w,h) assert(app.outputLayout==layout,'static output relaid out')
  event('key',keys.pageUp) render(w,h) assert(not app.follow)
  local row=app.rowHits[1] event('mouse_click',1,row.rect.x+1,row.rect.y+1) assert(app.selection.first==row.id)
  app.pixelKeyboard=true render(w,h) assert(#app.keyboard.pixelBoxes>0)
  app.pixelKeyboard=false app.commandMenu=true app.menuIndex=1 app.menuFirst=1 render(w,h)
  local n=#calls event('paste','hidden') assert(#calls==n,'menu leaked input')
  event('key',keys.down) render(w,h) event('key',keys.enter) assert(calls[#calls]=='home','keyboard menu selected hidden action')
end
app.visibleInput=function() return 'unlock ***',true end app.input='unlock SECRET'
local draw=fonts.draw fonts.draw=function(surface,x,y,text,...) assert(not text:find('SECRET',1,true),'password reached framebuffer') return draw(surface,x,y,text,...) end
render(306,140) fonts.draw=draw
app.commandMenu=false event('key',keys.leftCtrl) event('key',keys.c) event('key_up',keys.leftCtrl)
assert(calls[#calls]=='control:c' and not app.controlHeld)
app.lines={} app.lineIds={} app.lineColors={}
for i=1,100 do app.lines[i]=string.rep('x',4096) app.lineIds[i]=i app.lineColors[i]='text' end
app.outputRevision=app.outputRevision+1 render(200,120)
assert(#app.outputLayout.rows<=8192 and app.outputLayout.truncated,'visual history bound exceeded')
render(150,80) local n=#calls event('key',keys.enter) assert(#calls==n,'hidden undersize command executed')
print('Terminal pixels: bounded cached reflow, output selection, small layouts, tactile keyboard, menu isolation, private input and modifiers passed')
