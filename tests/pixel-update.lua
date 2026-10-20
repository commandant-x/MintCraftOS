package.path="./?.lua;"..package.path
keys={escape=1,tab=2,enter=3,up=4,down=5}
local calls={}
local app={status={ok=true,localVersion="1.0.0",remoteVersion="2.0.0",updateAvailable=true,source={sha=string.rep("a",40)}},
  control={busy=false,phase="idle",message=string.rep("line of technical diagnostic ",200)},
  metadata={localVersion="1.0.0",cfg={repo="owner/repo",branch="main"},backup={id="123",fromVersion="0.9.0"}},
  activate=function(self,id) calls[#calls+1]=id if id=="cancel" then self.confirm=nil end end}
require("apps.update.pixel").attach(app)
local Surface=require("system.graphics.surface")
local p={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
local function draw(w,h)
  fs=setmetatable({},{__index=function() error("file access in draw") end})
  app:drawPixels(Surface.new(w,h,15),w,h,p)
  for _,hit in ipairs(app.pixelHits) do local r=hit.rect assert(r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,"Update hitbox outside window") end
  if app.detailArea then assert(app.detailArea.y+app.detailArea.h<=h) end
end
local function click(id)
  for _,hit in ipairs(app.pixelHits) do if hit.id==id then return app:handlePixels({name="mouse_click",args={1,hit.rect.x+2,hit.rect.y+2}}) end end error("missing "..id)
end
for _,size in ipairs({{200,170},{306,171},{528,270},{960,500}}) do
  draw(size[1],size[2]) click("apply") assert(calls[#calls]=="apply")
  local layout=app.detailLayout draw(size[1],size[2]) assert(layout==app.detailLayout,"unchanged diagnostics rewrapped")
  app:handlePixels({name="mouse_scroll",args={1,10,145}}) assert(app.detailScroll>1)
  app.confirm={action="apply",localVersion="1.0.0",version="2.0.0",source={repo="owner/repo",sha=string.rep("a",40)}}
  draw(size[1],size[2]) assert(#app.pixelHits==2 and not app.detailArea) click("cancel")
end
app.control.busy=true draw(600,360)
local before=#calls click("apply") click("check") click("rollback") assert(#calls==before,"busy operation could be duplicated")
app.control.busy=false app.status.source=nil draw(600,360) click("apply") assert(#calls==before,"unverified branch could install")
app.confirm={action="rollback"} app.focus="confirm" draw(150,100)
app:handlePixels({name="key",args={keys.enter}}) assert(not app.confirm and #calls==before,"hidden dialog executed")
print("native Update: responsive bounds, cached wrapped diagnostics, disabled states, modal input isolation and shrink safety passed")
