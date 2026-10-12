package.path="./?.lua;"..package.path
local width,height=26,20
colors={white=1,black=32768,gray=128,lightGray=256}
os.time=function() return 12 end
term={getSize=function() return width,height end}
local iconCalls={}
package.loaded["system.gui.theme"]={get=function() return 1 end}
package.loaded["system.gui.icon"]={draw=function(_,x,y,_,_,w,h)
  assert(x+w-1<=width and y+h-1<height-1,"icon outside desktop") iconCalls[#iconCalls+1]={w=w,h=h}
end}
package.loaded["system.gui.renderer"]={fill=function() end,writeAt=function(x,y,text) assert(x>=1 and y>=1 and x+#text-1<=width and y<=height) end,
  crop=function(text,w) return tostring(text):sub(1,math.max(0,w)) end,button=function() end}
package.loaded["system.gui.keyboard"]={height=function() return 7 end}
local apps={} for i=1,30 do apps[i]={id="app"..i,name="Application"..i,icon="?"} end
local launched,args
local desktop=require("system.gui.desktop")
desktop.setApps({list=function() return apps end,launch=function(id,value) launched=id args=value return true end})
for _,size in ipairs({{26,20},{39,13},{51,19},{120,40}}) do
  width,height=size[1],size[2] desktop.page=1 desktop.draw()
  local seen={}
  for page=1,desktop.pageCount do
    desktop.page=page desktop.draw()
    for _,box in ipairs(desktop.icons) do
      assert(not seen[box.app],"app duplicated across pages") seen[box.app]=true
      assert(box.x+box.w-1<=width and box.y+box.h-1<height-1)
    end
  end
  local count=0 for _ in pairs(seen) do count=count+1 end assert(count==30,"apps unreachable after paging")
end
width,height=26,20 desktop.draw() assert(iconCalls[#iconCalls].w==4 and iconCalls[#iconCalls].h==3)
local chooser=desktop.pageHits.apps desktop.handle({name="mouse_click",args={1,chooser.x,chooser.y}})
assert(launched=="settings" and args.page=="apps")
desktop.menuOpen=true desktop.drawOverlays() desktop.menuScroll=100 desktop.drawOverlays()
local row=desktop.menuRows[#desktop.menuRows] desktop.handle({name="mouse_click",args={1,row.x,row.y}})
assert(launched=="app30","last app unreachable in Start")
print("bounded desktop grids, compact bitmap icons, all pages, chooser and Start scroll passed")
