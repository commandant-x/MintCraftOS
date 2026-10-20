package.path='./?.lua;'..package.path
keys={} for i,name in ipairs({'escape','enter','backspace','tab','up','down','left','right','home','end','pageUp','pageDown','delete','leftCtrl','rightCtrl','leftShift','rightShift','s','f','a','c','x'}) do keys[name]=i end
local Surface=require('system.graphics.surface') local edit=require('apps.editor.editing')
local actions={} local app={lines={},cx=1,cy=1,scroll=1,path='/home/user/test.lua',status='Ready',keyboard={},
  action=function(self,id) actions[#actions+1]=id if id=='cancel' then self.closePrompt=false end end}
for i=1,100 do app.lines[i]='local value_'..i..' = "text" -- note' end
app.keyboard.onText=function(text) actions[#actions+1]='text:'..text end
app.keyboard.onEnter=function() actions[#actions+1]='newline' end
app.keyboard.onBackspace=function() actions[#actions+1]='backspace' end
app.keyboard.onTab=function() actions[#actions+1]='tab' end
require('apps.editor.pixel').attach(app)
local p={panel=1,text=2,muted=3,accent=4,desktop=5,button=6,ink=7,border=8}
local function render(w,h)
  app:drawPixels(Surface.new(w,h),w,h,p)
  for _,hit in ipairs(app.pixelHits) do local r=hit.rect assert(r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,'editor control outside client') end
  for _,hit in ipairs(app.keyboard.pixelBoxes) do local r=hit.rect assert(r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,'editor keyboard outside client') end
end
local function event(name,...) return app:handlePixels({name=name,args={...}}) end
for _,size in ipairs({{200,120},{306,140},{600,360},{960,500}}) do
  local w,h=table.unpack(size) app.pixelKeyboard=false app.searchOpen=false app.closePrompt=false
  render(w,h) assert(app.codeArea and app.visibleRows>0 and app.visibleCols>0)
  local tokens=app.lineTokens[app.scroll].tokens render(w,h) assert(app.lineTokens[app.scroll].tokens==tokens,'unchanged visible row re-tokenized')
  app.searchOpen=true render(w,h) app.pixelKeyboard=true render(w,h)
  assert(#app.keyboard.pixelBoxes>0,'native editor touch keyboard absent')
  app.closePrompt=true render(w,h)
  local n=#actions event('paste','hidden mutation') event('key',keys.enter) assert(#actions==n,'close dialog leaked edit events')
  event('key',keys.escape) assert(not app.closePrompt)
end
app.pixelKeyboard=false app.searchOpen=false render(600,360)
event('key',keys.leftShift) event('key',keys.right) event('key_up',keys.leftShift)
assert(edit.selected(app)=='l','shift selection failed')
event('key',keys.leftCtrl) event('key',keys.c) event('key_up',keys.leftCtrl)
assert(actions[#actions]=='copy' and not app.controlHeld)
local area=app.codeArea event('mouse_click',1,area.x+app.gutter+12,area.y+2)
event('mouse_drag',1,area.x+app.gutter+30,area.y+15) event('mouse_up',1,0,0)
assert(edit.range(app),'drag did not select text')
render(150,80) local n=#actions event('paste','hidden') assert(#actions==n)
print('Editor pixels: bounded visible-row cache, line numbers, small layouts, modal isolation, modifier selection, drag and tactile keyboard passed')
