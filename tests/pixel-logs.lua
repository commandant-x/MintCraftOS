package.path="./?.lua;"..package.path
local Pixel=require("apps.logs.pixel")
local Surface=require("system.graphics.surface")
keys={escape=1,tab=2,enter=3,up=4,down=5,pageUp=6,pageDown=7,home=8,["end"]=9}
local app={filter="all",first=1,follow=true,records={},rows={},detailScroll=0}
for i=1,120 do
  local row={id="record"..i,time="2026-10-19 12:00",level=i%2==0 and "error" or "info",source="fixture",message="Record "..i.."\n"..string.rep("long diagnostic message ",24)}
  app.records[#app.records+1]=row app.rows[#app.rows+1]=row
end
local reads=0
function app:requestRefresh() reads=reads+1 end
function app:setFilter(id)
  self.filter=id self.first=1 self.rows={}
  for _,row in ipairs(self.records) do if id=="all" or row.level==id then self.rows[#self.rows+1]=row end end
end
Pixel.attach(app)
local p={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
local function draw(w,h)
  fs={open=function() error("draw read file") end}
  app:drawPixels(Surface.new(w,h,15),w,h,p)
  for _,hit in ipairs(app.pixelHits) do assert(hit.rect.x>=0 and hit.rect.y>=0 and hit.rect.x+hit.rect.w<=w and hit.rect.y+hit.rect.h<=h,"log control outside window") end
end
local function click(id)
  for i=#app.pixelHits,1,-1 do local hit=app.pixelHits[i] if hit.id==id then return app:handlePixels({name="mouse_click",args={1,hit.rect.x+2,hit.rect.y+2}}) end end
  error("missing log button "..id)
end
for _,size in ipairs({{180,145},{306,171},{540,235},{600,360},{960,500}}) do
  app.inspect=false app.follow=true app.selected=nil draw(size[1],size[2])
  assert(app.first==math.max(1,120-app.visible+1),"live tail not at end")
  local hit=app.rowHits[1]
  app:handlePixels({name="mouse_click",args={1,hit.rect.x+2,hit.rect.y+2}})
  assert(app.selected and not app.follow)
  draw(size[1],size[2]) assert(app.detailArea,"small client cannot inspect complete record")
  app:handlePixels({name="mouse_scroll",args={1,app.detailArea.x+2,app.detailArea.y+2}})
  draw(size[1],size[2]) assert((app.detailScroll or 0)>=0)
  app:handlePixels({name="key",args={keys.escape}})
end
app.inspect=false app.filterOpen=false draw(960,500)
click("filter") draw(960,500) click("level:error") draw(960,500)
assert(app.filter=="error" and #app.rows==60)
click("refresh") assert(reads==1)
local bar=app.scrollbar
app:handlePixels({name="mouse_click",args={1,bar.x+2,bar.y}})
assert(app.first==1 and not app.follow)
app:handlePixels({name="mouse_drag",args={1,bar.x+2,bar.y+bar.h}})
assert(app.first==#app.rows-app.visible+1)
app:handlePixels({name="mouse_up",args={1,bar.x+2,bar.y+bar.h}}) assert(not app.scrollDragging)
app:handlePixels({name="key",args={keys.home}}) assert(app.selected==app.rows[1].id)
draw(960,500)
local thumb=app.scrollThumb local first=app.first
app:handlePixels({name="mouse_click",args={1,thumb.x+2,thumb.y+1}})
assert(app.first==first,"grabbing the scrollbar thumb jumped the list")
app:handlePixels({name="mouse_up",args={1,thumb.x+2,thumb.y+1}})
app:handlePixels({name="key",args={keys["end"]}}) assert(app.selected==app.rows[#app.rows].id and app.follow)
app:setFilter("debug") draw(960,500) assert(#app.rows==0 and app.first==1)
app.scrollDragging=true draw(156,110)
assert(not app.scrollbar and not app.detailArea and #app.pixelHits==0,"undersized window kept hidden input boxes")
assert(pcall(app.handlePixels,app,{name="mouse_drag",args={1,10,10}}))
print("native Logs: bounded layouts, cache-only drawing, filters, full details, wheel/drag scrolling, keyboard and live tail passed")
