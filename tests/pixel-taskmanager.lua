package.path="./?.lua;"..package.path
local Pixel=require("apps.taskmanager.pixel") local Surface=require("system.graphics.surface")
keys={escape=1,tab=2,enter=3,up=4,down=5,pageUp=6,pageDown=7,home=8,["end"]=9}
local now=60 os.clock=function() return now end
local kills={} local refreshes=0
local app={page="processes",scroll=1,history={},message="Ready",onlyLive=false,snapshot={timestamp=60,rows={},ready=19,memory="Lua heap: 128 KiB",errors={},render={backend="PIXEL256",generation=1},acquisition={runners={}}}}
for i=1,24 do app.snapshot.rows[i]={pid=i,name="process"..i,state=i<20 and "ready" or "stopped",protected=i==1,permissions={"process.list"},runtimeMs=0,resumes=3} end
for i=1,60 do app.history[i]={timestamp=i,heapKB=128+i,readRate=i%4,pixelRate=i*10,renderRate=i%5} end
function app:filteredRows() local out={} for _,row in ipairs(self.snapshot.rows) do if not self.onlyLive or row.state=="ready" then out[#out+1]=row end end return out end
function app:refresh() refreshes=refreshes+1 end
function app:kill(pid) if self.selectedPid==pid then kills[#kills+1]=pid end end
Pixel.attach(app)
local p={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
local function draw(w,h)
  fs={getFreeSpace=function() error("native draw sampled disk") end}
  app:drawPixels(Surface.new(w,h,15),w,h,p)
  for _,hit in ipairs(app.pixelHits) do assert(hit.rect.x>=0 and hit.rect.y>=0 and hit.rect.x+hit.rect.w<=w and hit.rect.y+hit.rect.h<=h,"task control outside client") end
end
local function click(id)
  for i=#app.pixelHits,1,-1 do local hit=app.pixelHits[i] if hit.id==id then return app:handlePixels({name="mouse_click",args={1,hit.rect.x+2,hit.rect.y+2}}) end end error("missing "..id)
end
for _,size in ipairs({{200,170},{306,200},{588,271},{960,500}}) do
  for _,page in ipairs({"processes","performance","renderer","io"}) do app.page=page app.inspect=false app.menu=false draw(size[1],size[2]) end
end
app.page="processes" app.selectedPid=1 draw(960,500) click("kill") assert(not app.confirm and #kills==0)
app.selectedPid=3 draw(960,500) click("kill") draw(960,500) assert(#kills==0 and #app.pixelHits==2)
click("cancel") draw(960,500) click("kill") draw(960,500) click("confirm") assert(kills[1]==3)
draw(960,500) click("kill") app.selectedPid=4 draw(960,500) click("confirm") assert(#kills==1,"confirmation retargeted by row selection")
draw(960,500) click("kill") draw(156,110) app:handlePixels({name="key",args={keys.enter}}) assert(#kills==1 and not app.confirm,"hidden kill confirmation executed")
draw(960,500) click("views") draw(960,500)
app:handlePixels({name="key",args={keys.down}}) app:handlePixels({name="key",args={keys.enter}}) assert(app.page=="performance")
draw(306,200) app:handlePixels({name="mouse_scroll",args={1,20,100}}) assert(app.pageScroll>0)
app.page="processes" app.inspect=false draw(960,500)
app:handlePixels({name="key",args={keys.home}}) assert(app.selectedPid==1)
app:handlePixels({name="key",args={keys["end"]}}) assert(app.selectedPid==24)
draw(960,500) click("kill") assert(not app.confirm,"exited process enabled Kill")
app.snapshot.timestamp=1 app.selectedPid=3 draw(960,500) click("kill") assert(not app.confirm,"stale snapshot enabled Kill")
app.snapshot.timestamp=60 draw(960,500) now=64 click("kill") assert(not app.confirm,"cached hitbox bypassed live snapshot-age check")
print("native Task Manager: charts, bounded layouts, PID-bound confirmation, protected/exited/stale gating and keyboard passed")
