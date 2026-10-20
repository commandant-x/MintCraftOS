package.path='./?.lua;'..package.path
keys={escape=1,tab=2,enter=3,backspace=4,pageUp=5,pageDown=6}
local Surface=require('system.graphics.surface') local Pixel=require('apps.messenger.pixel')
local actions={} local app={input='',messages={},revision=1,follow=true,status='No modem',keyboard={},action=function(self,id)
  actions[#actions+1]=id if id=='keyboard' then self.softKeyboard=not self.softKeyboard end
end}
app.keyboard.onText=function(text) app.input=(app.input..text):sub(1,4096) end
app.keyboard.onBackspace=function() app.input=app.input:sub(1,-2) end
app.keyboard.onEnter=function() app:action('send') end
Pixel.attach(app)
local p={panel=1,text=2,muted=3,accent=4,desktop=5,button=6,ink=7,border=8}
for i=1,80 do app.messages[i]={from='Unverified sender '..i,text=string.rep('Wrapped message ',30),own=i%2==0} end
local function event(name,...) app:handlePixels({name=name,args={...}}) end
local function render(w,h)
  app:drawPixels(Surface.new(w,h),w,h,p)
  for _,hit in ipairs(app.pixelHits) do local r=hit.rect assert(r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,'hitbox outside client') end
  for _,hit in ipairs(app.keyboard.pixelBoxes) do local r=hit.rect assert(r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,'keyboard outside client') end
end
for _,size in ipairs({{200,120},{306,140},{600,360},{960,500}}) do
  local w,h=table.unpack(size) app.softKeyboard=false render(w,h)
  assert(app.bodyHeight>app.bodyArea.h and app.pixelScroll>0 and app.scrollbar)
  local cached=app.messageLayout render(w,h) assert(app.messageLayout==cached,'unchanged text relaid out')
  event('key',keys.pageUp) render(w,h) assert(not app.follow)
  app.softKeyboard=true render(w,h) assert(#app.keyboard.pixelBoxes>0,'touch keyboard missing')
  event('paste','hello') assert(app.input=='hello') app.input=''
  event('key',keys.escape) assert(not app.softKeyboard)
end
app.input='hello' app.busy=true render(306,140)
local before=#actions
for _,hit in ipairs(app.pixelHits) do if hit.id=='send' then event('mouse_click',1,hit.rect.x+1,hit.rect.y+1) end end
assert(#actions==before,'busy send remained active')
render(150,80) event('key',keys.enter) assert(#actions==before,'undersize hidden control active')
print('Messenger pixels: cached wrapped history, small/large bounds, tactile keyboard, paste, scrolling and busy/undersize guards passed')
