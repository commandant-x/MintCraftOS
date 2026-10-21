package.path="./?.lua;"..package.path
keys={escape=1,enter=2,backspace=3,up=4,down=5}
local Surface=require("system.graphics.surface")
local p={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
local function draw(app,w,h)
  fs=setmetatable({},{__index=function() error("native draw performed disk IO") end})
  peripheral=setmetatable({},{__index=function() error("native draw performed peripheral IO") end})
  app:drawPixels(Surface.new(w,h,15),w,h,p)
  for _,hit in ipairs(app.nativeClientState.hits) do
    assert(hit.rect.x>=0 and hit.rect.y>=0 and hit.rect.x+hit.rect.w<=w and hit.rect.y+hit.rect.h<=h,"control outside client: "..hit.id)
  end
end
local function click(app,id,kind)
  for _,hit in ipairs(app.nativeClientState.hits) do if hit.id==id and (not kind or kind==hit.kind) then
    app:handlePixels({name="mouse_click",args={1,hit.rect.x+1,hit.rect.y+1}}) return true
  end end
  return false
end
local actions,selected={},nil
local store={message="Ready"}
require("apps.store.pixel").attach(store,function() return {{id="pkg",name="Package",version="1",description="Description",installed=true}} end,{{id="install",label="Install"},{id="remove",label="Remove"}})
function store:action(id) actions[#actions+1]=id end
for _,size in ipairs({{200,170},{306,171},{600,360},{960,500}}) do
  draw(store,size[1],size[2]) assert(click(store,"pkg","row")) assert(store.selected=="pkg")
  assert(click(store,"install","action")) assert(actions[#actions]=="install")
end
local t={url="https://example.org",page={lines={"# Heading","[1] A link",string.rep("Long text ",30)},links={{index=1,url="https://example.org/link"}}}}
local browser={tabs={{title="Tab"}},active=1,bookmarks={},status="Ready",address=""}
require("apps.browser.pixel").attach(browser,{tab=function() return t end,home=function() return t.page end,settings={showBookmarks=true,home="mint://home"},
 enqueue=function(action) actions[#actions+1]=action end,bookmark=function() end,crafttube=function() end,newTab=function() end,
 submit=function() actions[#actions+1]="submit" end,link=function(link) selected=link.url end})
draw(browser,306,171) assert(click(browser,2,"row")) assert(selected=="https://example.org/link")
assert(click(browser,"address","field")) browser.graphicsActive=true
assert(browser:handlePixelKey({name="paste",args={"/new"}})) assert(browser.address==t.url.."/new")
assert(browser:handlePixelKey({name="key",args={keys.enter}})) assert(actions[#actions]=="submit")
local tube={cfg={},mode="search",input="",status="Ready",keyboard={onEnter=function() end},rows={{id="v",title="Video",channel="Channel",duration="1:00",views="15",url="https://example.org/v",description="Description"}}}
function tube:action(id) actions[#actions+1]=id end
require("apps.crafttube.pixel").attach(tube,{{id="play",label="Play"}},function(id) actions[#actions+1]=id end)
draw(tube,306,171) assert(click(tube,"v","row")) assert(tube.selected=="v" and actions[#actions]=="details")
draw(tube,200,170) assert(click(tube,"play","action")) assert(actions[#actions]=="play")
local nexus={page="dashboard",snapshot={computers={},message="Ready"},message="",rules={enabled=true},settings={key="top secret",group="factory"},contentLines=function() return {"Status"} end}
function nexus:command(id) actions[#actions+1]=id end
require("apps.nexus.pixel").attach(nexus,{{id="setup",label="Setup"}},function() return {} end,{select=function() end})
draw(nexus,306,171) assert(click(nexus,"page:setup","action")) draw(nexus,306,171)
assert(nexus.nativeClientState.model.fields[2].secret,"NEXUS key is not masked")
local confirmations=0
nexus.confirm={title=string.rep("Dangerous recovery of IDs 1, 2, 3. ",80),fn=function() confirmations=confirmations+1 end}
draw(nexus,306,171)
assert(click(nexus,"confirm","action")) assert(confirmations==0,"unread destructive warning confirmed")
for _=1,100 do draw(nexus,306,171) assert(click(nexus,"confirm","action")) if not nexus.confirm then break end end
assert(confirmations==1,"full confirmation was unreachable")
print("four native network clients: cache-only drawing, bounds, link navigation, masked setup, text input, package actions and read-through confirmation passed")
