package.path='./?.lua;'..package.path
keys={escape=1,tab=2,enter=3,up=4,down=5,pageUp=6,pageDown=7,backspace=8}
local Pixel=require('apps.settings.pixel') local Surface=require('system.graphics.surface')
local actions,reads={},0
local pages={} for _,id in ipairs({'system','display','desktop','network','storage','sound','security','apps','packages','dev','nav','combat'}) do pages[#pages+1]={id=id,label=id} end
local app={page='display',model={},control={busy=false},input='',keyboard={},appMessage='',
  getItems=function(self) return self.model.items end,
  cancelInput=function(self) self.mode=nil self.input='' end,
  requestRead=function() reads=reads+1 end,
  toggleApp=function(_,id) actions[#actions+1]='app:'..id end,
  action=function(self,id) actions[#actions+1]=id if id=='graphics:text' then self.rescuePending=true end end,
  setPage=function(self,id) self.page=id self.bodyScroll=0 end}
app.keyboard.onText=function(text) app.input=app.input..text end
app.keyboard.onBackspace=function() app.input=app.input:sub(1,-2) end
app.keyboard.onEnter=function() actions[#actions+1]='submitted' app:cancelInput() end
local function model(page)
  return {page=page,lines={'Backend: PIXEL256','Pixels: 960x540','Status: '..string.rep('long diagnostic ',40)},
    apps={{id='editor',name='Editor',enabled=true,core=true},{id='browser',name='Browser',enabled=false}},
    audio={enabled=true,defaultSide='left'},items={{id='graphics:auto',label='Automatic pixels',active=true},{id='graphics:pixel16',label='16-color pixels'},
      {id='graphics:text',label='Text rescue'},{id='display:computer',label='Computer',active=true},{id='display:terminal_0',label='terminal_0'},
      {id='scale:0.5',label='Scale 0.5',active=true},{id='scale:1',label='Scale 1'},
      {id='theme:mint',label='Mint',active=true},{id='theme:dark',label='Dark'},
      {id='audio',label='Disable'},{id='lock',label='Lock'},{id='label',label='Set label'}}}
end
Pixel.attach(app,pages)
local p={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
local function draw(w,h)
  fs=setmetatable({},{__index=function() error('draw read filesystem') end})
  peripheral=setmetatable({},{__index=function() error('draw read peripheral') end})
  app:drawPixels(Surface.new(w,h,15),w,h,p)
  for _,hit in ipairs(app.pixelHits) do local r=hit.rect assert(r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,'Settings control outside viewport: '..hit.id) end
  for _,hit in ipairs(app.keyboard.pixelBoxes) do local r=hit.rect assert(r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,'touch key outside viewport') end
end
local function click(id)
  for _,hit in ipairs(app.pixelHits) do if hit.id==id then return app:handlePixels({name='mouse_click',args={1,hit.rect.x+2,hit.rect.y+2}}) end end error('missing '..id)
end
for _,size in ipairs({{200,120},{306,171},{600,360},{960,500}}) do
  for _,page in ipairs(pages) do
    app.page=page.id app.model=model(page.id) app.bodyScroll=0 draw(size[1],size[2])
    app.bodyScroll=100000 draw(size[1],size[2])
  end
  app.rescuePending=true draw(size[1],size[2]) assert(#app.pixelHits==2) click('cancel') assert(not app.rescuePending)
  app.cleanupPending=true draw(size[1],size[2]) click('confirm') assert(actions[#actions]=='cleanupConfirm') app.cleanupPending=false
  app.mode='unlock' app.input='SECRET-password' app.softKeyboard=true
  local widgets=require('system.graphics.widgets') local original=widgets.input
  widgets.input=function(s,r,value,...) assert(not value:find('SECRET',1,true),'password rendered in clear') return original(s,r,value,...) end
  draw(size[1],size[2]) assert(#app.keyboard.pixelBoxes>0,'touch keyboard missing')
  widgets.input=original
  click('inputCancel') assert(not app.mode)
end
app.page='display' app.model=model('display') app.bodyScroll=0 draw(960,500)
click('pages') draw(960,500) app:handlePixels({name='key',args={keys.down}}) draw(960,500)
app:handlePixels({name='key',args={keys.enter}}) assert(app.page=='display' and not app.pagesOpen,'page dropdown keyboard failed')
app.model=model('display') app.model.lines={} app.bodyScroll=0 draw(600,360)
click('select:Requested renderer') draw(600,360) click('action:graphics:text') assert(app.rescuePending)
draw(600,360) click('cancel') assert(not app.rescuePending)
app.model.items={{id='lock',label='Lock'}} app.model.lines={} app.control.busy=true app.bodyScroll=0 draw(600,360)
local before=#actions click('action:lock') assert(#actions==before,'busy settings action submitted')
app.mode='label' app.input='private draft' app.rescuePending=true draw(150,90)
app:handlePixels({name='key',args={keys.enter}}) assert(not app.mode and not app.rescuePending and #actions==before,'hidden dialog submitted after shrink')
assert(reads==0,'draw or ordinary controls acquired settings')
print('native Settings: twelve sections, small layouts, scrolling, dropdown input, busy states, masked input/touch keyboard, confirmation and resize safety passed')
