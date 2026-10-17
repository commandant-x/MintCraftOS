package.path="./?.lua;"..package.path
colors={white=1,orange=2,magenta=4,lightBlue=8,yellow=16,lime=32,pink=64,gray=128,lightGray=256,cyan=512,purple=1024,blue=2048,brown=4096,green=8192,red=16384,black=32768}
keys={escape=256}
local width,height=100,30
local function check(x,y,text) assert(x>=1 and y>=1 and x+#text-1<=width and y<=height,"NEXUS text outside viewport") end
local renderer={crop=function(s,w) return tostring(s):sub(1,math.max(0,w)) end,writeAt=check,
  color=function(c) for i=0,15 do if c==2^i then return string.format('%x',i) end end error('Bad color') end,
  fill=function(x,y,w,h) assert(x>=1 and y>=1 and x+w-1<=width and y+h-1<=height,"NEXUS fill outside viewport") end,
  button=function(x,y,w,label) check(x,y,label:sub(1,w)) end,
  blitAt=function(x,y,text,fg,bg) assert(#text==#fg and #text==#bg) check(x,y,text) end}
package.loaded['system.gui.renderer']=renderer
package.loaded['system.gui.theme']={get=function(key) return key=='windowBg' and colors.black or colors.white end}
local calls={}
local snapshot={role='master',master=0,group='factory',online=2,managed=2,discovered=3,revision=1,message='Ready',
 drives={{name='drive_0',mount='/disk'}},jobs={{type='ping',node=1,state='completed',result={ok=true}}},
 computers={{id=1,label='factory pump',state='ONLINE',authorized=true,powered=true},{id=2,label='furnace',state='ONLINE',authorized=true,powered=true},
 {id=3,label='unmanaged',state='DISCOVERED',authorized=false,powered=false}}}
package.loaded['system.services.nexusd']={version='0.1.0',snapshot=function() return snapshot end,
 request=function(_,action,args) calls[#calls+1]={action=action,args=args} return true end,
 select=function() calls[#calls+1]={action='select'} return true end,setup=function() return true end}
textutils={serialize=function() return '{ok=true}' end}
term={getSize=function() return width,height end}
local app
local win={closed=false}
local ctx={pid=4,args={deploy=true,group='factory'},windowManager={create=function(_,options) app=options.app return win end},
 startTimer=function() return 1 end,onCleanup=function() end,pullEvent=function() return coroutine.yield() end}
local co=coroutine.create(function() require('apps.nexus.main').run(ctx) end)
assert(coroutine.resume(co)) assert(app and app.page=='computers')
for _,size in ipairs({{18,9},{26,20},{100,35}}) do
 width,height=table.unpack(size)
 for _,page in ipairs({'dashboard','computers','map','missions','setup'}) do
  app.page=page app:draw(width,height)
 end
end
snapshot.computers={}
for i=1,64 do snapshot.computers[i]={id=i,label='Agent '..i,state='ONLINE',authorized=true,group='factory'} end
width,height=26,20 app.page='map' app.scroll=1
local visited={} local previousCalls=#calls
for _=1,64 do
 app:draw(width,height)
 for _,box in ipairs(app.boxes) do
  assert(box.y+box.h-1<height-3,'Agent overlaps details or paging controls')
  visited[box.row.id]=true
 end
 local box=app.networkBar[2]
 app:handle({name='mouse_click',args={1,box.x,box.y}})
end
for i=1,64 do assert(visited[i],'Network pagination hid agent '..i) end
assert(#calls==previousCalls,'Network paging changed authorization')
app:draw(width,height)
local node=app.boxes[1]
app:handle({name='mouse_click',args={1,node.x,node.y}})
assert(app.selected==node.row.id and #calls==previousCalls,'Network selection issued a command')
width,height=100,30 app.page='computers'
app.commands.open=true app:draw(width,height)
local target
for _,box in ipairs(app.commands.menuBoxes) do if box.id=='deploy' then target=box end end
assert(target)
app:handle({name='mouse_click',args={1,target.x,target.y}})
assert(app.confirm,'Deployment skipped explicit confirmation')
local previous=#calls app:draw(width,height)
app:handle({name='mouse_click',args={1,1,5}})
assert(#calls==previous,'Confirmation click leaked into computer selection')
local box=app.confirmBar[1]
app:handle({name='mouse_click',args={1,box.x,box.y}})
assert(calls[#calls].action=='deploy' and calls[#calls].args.group=='factory')
assert(not app.confirm)
app.commands.open=true app:draw(width,height)
for _,candidate in ipairs(app.commands.menuBoxes) do if candidate.id=='resetAuto' then target=candidate end end
assert(target.id=='resetAuto')
app:handle({name='mouse_click',args={1,target.x,target.y}})
previous=#calls
for stage=1,2 do
 assert(app.confirm,'Missing destructive confirmation stage '..stage)
 for _=1,100 do
  app:draw(width,height)
  local button=app.confirmBar[1]
  local more=button.id=='more'
  app:handle({name='mouse_click',args={1,button.x,button.y}})
  if not more then break end
 end
 if stage==1 then assert(#calls==previous,'Reset executed before final confirmation') end
end
assert(calls[#calls].action=='resetAuto' and #calls[#calls].args.ids==64,'Frozen destructive scope missing')
print('NEXUS UI: responsive 2D network, 64-node touch paging/selection, bounds, deployment confirmation and modal isolation passed')
