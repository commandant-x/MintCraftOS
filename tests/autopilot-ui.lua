package.path="./?.lua;"..package.path
keys={escape=1,enter=2,backspace=3,up=4,down=5}
colors={}
for i,name in ipairs({"white","orange","magenta","lightBlue","yellow","lime","pink","gray","lightGray","cyan","purple","blue","brown","green","red","black"}) do colors[name]=2^(i-1) end
local launch,armed,stopped,selection=0,0,0,nil
local now=10 os.clock=function() return now end
local panel=require("apps.navigation.route").new({
 pose=function() return {timestamp=now,identityAt=now,vehicleId="ship-a",inSublevel=true,frame="world",logicalPose={position={x=10,y=100,z=30}}} end,
 arm=function() armed=armed+1 return true end,
 start=function(plan) launch=launch+1 assert(plan.points[1].z==30) return true end,
 stop=function() stopped=stopped+1 return true end,
 disarm=function() return true end,page=function(id) selection=id end,devices=function() end,
})
local Surface=require("system.graphics.surface")
local palette={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
local function draw(w,h)
  fs=setmetatable({},{__index=function() error("native draw disk IO") end})
  peripheral=setmetatable({},{__index=function() error("native draw device IO") end})
  panel:drawPixels(Surface.new(w,h,15),w,h,palette)
  for _,hit in ipairs(panel.nativeClientState.hits) do
    local r=hit.rect assert(r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,"control outside autopilot client")
  end
end
panel:action("route:add") assert(#panel.plan.points==1 and panel.plan.points[1].x==10)
panel:action("route:options") panel:select("field:translationVerified") panel:select("field:clearRouteConfirmed")
panel:action("route:start") assert(panel.pending and launch==0)
panel.plan.points[1].z=999
for _=1,40 do draw(156,158) panel:action(panel.nativeClientState.model.actions[1].id) if not panel.pending then break end end
assert(launch==1,"read-through confirmation never started frozen route")
panel:action("route:stop") assert(stopped==1)
panel:action("route:arm")
while panel.pending do draw(306,171) panel:action(panel.nativeClientState.model.actions[1].id) end
assert(armed==1)
panel:action("route:options") panel:select("field:maxSpeed") assert(panel.editing)
panel.editText="-" assert(not panel:apply()) panel.editText="2.5" assert(panel:apply()) assert(panel.plan.maxSpeed==2.5)
panel.plan.translationVerified=true panel:select("field:driveMode") assert(not panel.plan.translationVerified,"changing driver retained old physical verification")
panel:action("route:sublevel")
panel:refresh({state="armed"},{vehicleId="ship-a"},{status="Partial vehicle inventory",actuators={},links={},burners={}},{{backend="relay",name="wired-relay"}})
for _,size in ipairs({{156,106},{156,121},{156,158},{306,171},{600,360},{960,500}}) do draw(size[1],size[2]) end
panel:action("route:flight") assert(selection=="flight")
panel:action("route:arm") draw(156,121)
local stop=panel.headerHits[1].rect
panel:handlePixels({name="mouse_click",args={1,stop.x+1,stop.y+1}})
assert(not panel.pending and stopped==2,"persistent takeover button was blocked by a confirmation")
print("autopilot UI: frozen route confirmation, all coordinates readable, bounded native controls, draft editing, driver verification reset and passive equipment view passed")
