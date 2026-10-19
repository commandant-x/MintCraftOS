package.path="./?.lua;"..package.path
local Native=require("apps.navigation.pixel")
local Surface=require("system.graphics.surface")
local Scene=require("system.graphics.scene")
local now=10
os.clock=function() return now end
keys={escape=1,up=2,down=3,enter=4}
local measurements={pitch={valid=true,value=12,observedAt=10,validUntil=10.5},roll={valid=true,value=25,observedAt=10,validUntil=10.5}}
local sub={timestamp=10,status="ready",sublevel={mass=80,linearVelocity={x=3,y=0,z=4}}}
local telemetry={timestamp=10,altitude=72,altitudeRate=0.2,heading=359,headingSource="fixture"}
local snap,last=Native.sample({measurements=measurements},sub,{state="disarmed"},telemetry,nil,now)
assert(snap.fresh and snap.values.speed==5 and snap.values.mass==80 and snap.values.heading==359)
local held=Native.sample({measurements={}},sub,{},telemetry,last,10.75)
assert(not held.fresh and held.attitude and held.values.heading==nil,"stale numeric measurement treated as live")
local missing=Native.sample({measurements={}},sub,{},telemetry,last,11.1)
assert(not missing.attitude and not missing.values.mass and not missing.values.speed)
local future=Native.sample({measurements=measurements},sub,{},telemetry,nil,9)
assert(not future.attitude and not future.values.altitude and not future.values.speed,"future timestamps accepted")
local selected,command
local app={page="flight",message="Control disarmed",nativeFlight=snap}
local tabs={{id="flight",label="Flight"},{id="vehicle",label="Vehicle"},{id="control",label="Control"}}
Native.attach(app,{page=function(id) selected=id app.page=id end,action=function(id) command=id end},tabs)
local p={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
local function draw(w,h)
  local s=Surface.new(w,h,15)
  app:drawPixels(s,w,h,p)
  for i,a in ipairs(app.nativeHits) do
    assert(a.rect.x>=0 and a.rect.y>=0 and a.rect.x+a.rect.w<=w and a.rect.y+a.rect.h<=h,"toolbar out of bounds")
    for j=i+1,#app.nativeHits do assert(not Scene.intersects(a.rect,app.nativeHits[j].rect),"toolbar overlap") end
  end
  return s
end
for _,size in ipairs({{154,131},{304,149},{600,330},{958,491}}) do
  local w,h=table.unpack(size)
  draw(w,h)
  local builds=app.nativeHorizon.builds
  draw(w,h) assert(app.nativeHorizon.builds==builds,"static attitude geometry rebuilt")
end
local function click(id)
  for _,hit in ipairs(app.nativeHits) do if hit.id==id then
    assert(app:handlePixels({name="mouse_click",args={1,hit.rect.x+1,hit.rect.y+1}})) return
  end end error(id)
end
click("rescan") assert(command=="rescan")
app.graphicsActive=true app.nativeViews=true
assert(app:handleNativeKey({name="key",args={keys.escape}}) and not app.nativeViews)
click("views") draw(600,330)
app:handleNativeKey({name="key",args={keys.down}}) draw(600,330)
app:handleNativeKey({name="key",args={keys.enter}})
assert(selected=="vehicle","keyboard selection lost to viewport pagination")
app.page="flight"
click("views") draw(600,330)
for _,hit in ipairs(app.nativeViewHits) do if hit.id=="vehicle" then
  app:handlePixels({name="mouse_click",args={1,hit.rect.x+1,hit.rect.y+1}})
end end
assert(selected=="vehicle" and app.pixelPages.flight and not app.pixelPages.vehicle)
app.page="flight" draw(600,330) click("control") assert(selected=="control","control navigation not accessible")
assert(command=="rescan","view selection emitted a flight command")
app.page="flight" app.nativeFlight=missing
draw(600,330)
assert(app.nativeHorizon.image.rows[1]==string.rep(string.char(15),app.nativeHorizon.image.width),"missing attitude invented a level horizon")
-- Pure native rendering must not consult a filesystem or a peripheral.
fs=setmetatable({},{__index=function() error("filesystem in instrument draw") end})
peripheral=setmetatable({},{__index=function() error("peripheral in instrument draw") end})
app.nativeFlight=snap draw(600,330)
now=12 draw(600,330)
assert(app.nativeMetricRows[1].value=="unavailable","restored window displayed expired altitude")
print("native navigation: cached pixel geometry, stale/held/missing data, responsive toolbar and non-actuating view navigation passed")
