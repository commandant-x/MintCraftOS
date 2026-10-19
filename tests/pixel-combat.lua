package.path="./?.lua;"..package.path
colors={}
for i,name in ipairs({"white","orange","magenta","lightBlue","yellow","lime","pink","gray","lightGray","cyan","purple","blue","brown","green","red","black"}) do colors[name]=2^(i-1) end
keys={escape=1,tab=2,enter=3}
os.clock=function() return 10 end
local Native=require("apps.combat.pixel")
local Surface=require("system.graphics.surface")
local filter=require("system.navigation.radar_filter")
local actions={} local selected
local app={page="radar",filters={},scroll=1,view={zoom=1,yaw=30,pitch=45},message="fixture",snapshot={revision=1,
  radars={{id="a",name="Station A",position={x=0,y=64,z=0},range=1000,heading=40,fov=50,running=true},
    {id="b",name="Station B",position={x=500,y=64,z=400},range=600,heading=180,fov=80,running=true,remote=true}},
  targets={{id="player",label="Alex",labelSource="API",category="player",position={x=100,y=80,z=-200},timestamp=10},
    {id="vessel",label="ID vessel",category="ship",position={x=-200,y=90,z=100},timestamp=10,history={{position={x=-210,y=90,z=100}},{position={x=-200,y=90,z=100}}}}},
  cannons={{id="gun",name="Mount",yaw=10,pitch=15}},devices={},acquisition={targetHz=20,effectiveHz=18,pending=0,elapsed=0.04}},radarId="a",
  handle=function(self,e) actions[#actions+1]=e.command return true end}
Native.attach(app,{action=function(id) actions[#actions+1]=id end,select=function(id) app.targetId=filter.select(app.targetId,id) selected=app.targetId end,station=function() end},
  {{id="radar",label="Radar"},{id="three",label="3D"},{id="targets",label="Targets"},{id="fire",label="Fire"},{id="config",label="Config"}})
local p={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
local function draw(w,h)
  local s=Surface.new(w,h,15)
  local old=peripheral peripheral={call=function() error("draw performed peripheral I/O") end}
  app:drawPixels(s,w,h,p) peripheral=old
  for _,hit in ipairs(app.nativeHits) do assert(hit.rect.x>=0 and hit.rect.y>=0 and hit.rect.x+hit.rect.w<=w and hit.rect.y+hit.rect.h<=h,"control outside window: "..hit.id) end
  return s
end
local function click(id)
  for _,hit in ipairs(app.nativeHits) do if hit.id==id then return app:handlePixels({name="mouse_click",args={1,hit.rect.x+2,hit.rect.y+2}}) end end
  error("missing button "..id)
end
for _,size in ipairs({{306,240},{600,360},{960,500}}) do
  for _,page in ipairs({"radar","three","targets","cannons","fire","probe","network"}) do
    app.page=page app.nativeViews=false draw(size[1],size[2])
  end
end
app.page="radar" draw(960,500)
assert(app.nativeGraph.image.width>500,"radar still uses a character-resolution surface")
local contact=assert(app.nativeContacts[1])
app:handlePixels({name="mouse_click",args={1,contact.rect.x+1,contact.rect.y+1}})
assert(selected==contact.id)
app:handlePixels({name="mouse_click",args={1,contact.rect.x+1,contact.rect.y+1}})
assert(selected==nil,"second tap did not deselect")
click("filter:players") assert(app.filters.players)
draw(960,500) assert(#app.nativeGraph.hits==1,"category filter ignored")
click("filter:players") assert(next(app.filters)==nil)
click("zoomIn") assert(actions[#actions]=="zoomIn")
draw(960,500) local graph=app.nativeGraph draw(960,500) assert(app.nativeGraph==graph,"unchanged radar projection rebuilt")
app.snapshot.revision=2 draw(960,500) assert(app.nativeGraph==graph,"diagnostic-only revision rebuilt geometry")
app.snapshot.targets[1].position.x=130 draw(960,500) assert(app.nativeGraph~=graph,"changed contact did not rebuild geometry")
click("views") draw(960,500) click("page:three") assert(app.page=="three" and not app.nativeViews)
app.page="radar" draw(960,500) click("radarNext") draw(960,500) click("station:2")
assert(app.radarId=="b" and not app.nativeRadars,"station picker did not select radar")
local fired=0 app.confirm={title="Confirm fixture",callback=function() fired=fired+1 end}
draw(960,500) assert(#app.nativeHits==2) click("cancel") assert(fired==0)
app.confirm={title="Confirm fixture",callback=function() fired=fired+1 end} draw(960,500) click("confirm") assert(fired==1)
draw(600,360) app:handlePixels({name="key",args={keys.tab}}) assert(app.nativeFocus)
app.snapshot.radars={} app.snapshot.targets={} app.snapshot.revision=3 draw(600,360)
assert(#app.nativeGraph.hits==0,"missing world origin fabricated contacts")
draw(156,120) assert(#app.nativeHits==0,"undersized diagnostic left overlapping controls")
print("native Combat: pixel radar 2D/3D, filters, selection, cached projection, modal confirmation and bounded layouts passed")
