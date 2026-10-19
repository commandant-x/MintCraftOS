package.path="./?.lua;"..package.path
colors={red=2,white=1}
keys={escape=256}
local width,height,app,win
local draws,tailReads,revision=0,0,1
local themes={windowFg=11,windowBg=12,titleFg=13,titleBg=14,accent=15,buttonFg=16,buttonBg=17}
package.loaded["system.gui.theme"]={get=function(key) assert(themes[key],key) return themes[key] end}
package.loaded["system.gui.renderer"]={
  crop=function(text,w) return tostring(text):sub(1,math.max(0,w)) end,
  fill=function(x,y,w,h) assert(x>=1 and y>=1 and x+w-1<=width and y+h-1<=height,"fill bounds") end,
  writeAt=function(x,y,text,fg,bg)
    assert(x>=1 and y>=1 and x+#text-1<=width and y<=height,"text bounds")
    assert(text:find("[%c]")==nil,"raw control bytes in viewer")
    assert(fg>=11 and bg>=11,"viewer ignored theme") draws=draws+1
  end,
  button=function() end,
}
local invalidates=0
package.loaded["system.libraries.log"]={
  revision=function() return revision end,
  invalidate=function() invalidates=invalidates+1 revision=revision+1 end,
  tail=function() tailReads=tailReads+1 return {"error","info","error"} end,
  parse=function(line) return {time="now",level=line,source="test",message="hello\nworld"} end,
}
term={getSize=function() return width,height end}
local ctx={windowManager={create=function(_,spec) app=spec.app win={closed=false} return win end}}
ctx.startTimer=function() return 1 end
ctx.onCleanup=function() end
ctx.pullEvent=function()
  assert(app.records[1].id~=app.records[3].id,"identical log entries share selection identity")
  app:draw(width,height)
  local reads=tailReads
  for _=1,20 do app:draw(width,height) end
  assert(tailReads==reads,"draw reparsed unchanged logs")
  assert(app:handle({name="mouse_click",args={1,1,1}}))
  app:draw(width,height)
  local seen={}
  for first=1,6 do
    app.menu.first=first app:draw(width,height)
    for _,box in ipairs(app.menu.menuBoxes) do seen[box.id]=true end
  end
  for _,id in ipairs({"all","error","warn","info","debug","refresh"}) do assert(seen[id],id.." inaccessible") end
  app.menu.first=1 app:draw(width,height)
  local box=app.menu.menuBoxes[1]
  app:handle({name="mouse_click",args={1,box.x,box.y}})
  revision=revision+1 app:refresh() app:draw(width,height)
  assert(tailReads>reads,"changed revision ignored")
  win.closed=true
end
local logs=require("apps.logs.main")
for _,size in ipairs({{12,9},{20,10},{26,17},{72,18}}) do
  width,height=table.unpack(size) logs.run(ctx)
end
local requests={} local serviceReads=0
ctx.system={services={
  list=function() serviceReads=serviceReads+1 return {{name="flightd",state="degraded",lastSuccess=42,error="rescue pending",autostart=true}} end,
  controlStatus=function() return {busy=false} end,
  requestAction=function(_,actor,action,name) requests[#requests+1]={action=action,name=name} return false,"rescue pending" end,
  stop=function() error("UI stopped service synchronously") end,
  start=function() error("UI started service synchronously") end,
}}
ctx.pullEvent=function()
  app:draw(width,height)
  local reads=serviceReads for _=1,20 do app:draw(width,height) end
  assert(serviceReads==reads,"service draw queried health")
  app:handle({name="mouse_click",args={1,1,3}})
  app:draw(width,height)
  app:handle({name="mouse_click",args={1,16,1}})
  assert(#requests==1 and requests[1].action=="restart" and requests[1].name=="flightd" and app.message=="rescue pending","service action was not delegated")
  win.closed=true
end
width,height=46,14
require("apps.services.main").run(ctx)
assert(draws>0)
print("viewers: theme, responsive filter reachability, revision reuse, bounds and refused restart passed")
