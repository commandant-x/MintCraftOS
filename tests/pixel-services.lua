package.path="./?.lua;"..package.path
local Pixel=require("apps.services.pixel") local Surface=require("system.graphics.surface")
keys={escape=1,tab=2,enter=3,up=4,down=5,pageUp=6,pageDown=7,home=8,["end"]=9}
local requests={} local refreshes=0
local app={scroll=1,rows={},control={busy=false},message="Ready",request=function(self,action) requests[#requests+1]={action=action,name=self.selected} end,refresh=function() refreshes=refreshes+1 end}
for i=1,24 do app.rows[i]={name="service"..i,state=i%3==0 and "degraded" or "running",autostart=true,pid=i,lastSuccess=42,error=i%3==0 and string.rep("long service error ",80) or nil,protected=i==1} end
Pixel.attach(app)
local p={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
local function draw(w,h)
  app:drawPixels(Surface.new(w,h,15),w,h,p)
  for _,hit in ipairs(app.pixelHits) do assert(hit.rect.x>=0 and hit.rect.y>=0 and hit.rect.x+hit.rect.w<=w and hit.rect.y+hit.rect.h<=h,"service control outside client") end
end
local function click(id)
  for i=#app.pixelHits,1,-1 do local hit=app.pixelHits[i] if hit.id==id then return app:handlePixels({name="mouse_click",args={1,hit.rect.x+2,hit.rect.y+2}}) end end error("missing "..id)
end
for _,size in ipairs({{200,150},{306,171},{528,235},{600,360},{960,500}}) do
  app.inspect=false app.selected=nil draw(size[1],size[2])
  local row=app.rowHits[1] app:handlePixels({name="mouse_click",args={1,row.rect.x+2,row.rect.y+2}})
  assert(app.selected=="service1") draw(size[1],size[2]) assert(app.detailArea)
  click("stop") assert(not app.confirm and #requests==0,"protected service could stop")
  app:handlePixels({name="key",args={keys.escape}})
end
app.selected="service3" app.inspect=false draw(960,500)
click("restart") draw(960,500) assert(#app.pixelHits==2 and #requests==0,"restart executed before confirmation")
click("cancel") assert(not app.confirm and #requests==0)
draw(960,500) click("restart") draw(960,500) click("confirm") assert(#requests==1 and requests[1].action=="restart" and requests[1].name=="service3")
draw(960,500) click("stop") app.selected="service4" draw(960,500) click("confirm") assert(#requests==1,"changed service selection reused confirmation")
app.control={busy=true,phase="running",action="stop",name="service3"} draw(960,500) click("start") assert(#requests==1,"busy transition was duplicated")
app.control={busy=false} draw(960,500) click("refresh") assert(refreshes==1)
app.focus="list" app:handlePixels({name="key",args={keys.home}}) assert(app.selected=="service1")
app:handlePixels({name="key",args={keys["end"]}}) assert(app.selected=="service24")
app.selected="service3" draw(960,500) click("stop") assert(app.confirm)
draw(156,110) assert(#app.pixelHits==0 and not app.scrollbar and not app.detailArea and not app.confirm)
app:handlePixels({name="key",args={keys.enter}}) assert(#requests==1,"hidden confirmation executed after shrinking window")
print("native Services: bounded layouts, details, protected/disabled controls, confirmation binding and keyboard passed")
