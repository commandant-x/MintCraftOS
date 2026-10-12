package.path="./?.lua;"..package.path
colors={red=2,white=1}
keys={escape=256}
package.loaded["system.gui.theme"]={get=function() return 1 end}
local width,height
package.loaded["system.gui.renderer"]={
  crop=function(text,w) return text:sub(1,math.max(0,w)) end,
  fill=function(x,y,w,h) assert(x>=1 and y>=1 and x+w-1<=width and y+h-1<=height,"fill out of bounds") end,
  writeAt=function(x,y,text) assert(x>=1 and y>=1 and x+#text-1<=width and y<=height,"text out of bounds") end,
}
local menu=require("system.gui.action_menu")
local items={}
for i=1,14 do items[i]={id=i,label="Action "..i,menuLabel="Detailed action "..i,primary=i<4} end
for _,size in ipairs({{12,9},{20,10},{26,17},{44,20},{80,30},{120,36}}) do
  width,height=table.unpack(size)
  local state=menu.new()
  menu.bar(state,1,2,width,items)
  menu.handle(state,{name="mouse_click",args={1,state.trigger.x,2}})
  assert(state.open)
  local seen={}
  for first=1,#items do
    state.first=first menu.overlay(state,width,height)
    local cells={}
    for _,box in ipairs(state.menuBoxes) do
      seen[box.id]=true
      for y=box.y,box.y+box.h-1 do for x=box.x,box.x+box.w-1 do
        local key=x..":"..y assert(not cells[key],"overlapping menu buttons") cells[key]=true
      end end
    end
  end
  for i=1,#items do assert(seen[i],"inaccessible action") end
  state.first=1 menu.overlay(state,width,height)
  local box=state.menuBoxes[1]
  local id,handled=menu.handle(state,{name="mouse_click",args={1,box.x,box.y+1}})
  assert(id==box.id and handled and not state.open,"two-row touch target")
end
width,height=80,25
local pages,commands=menu.new(),menu.new()
menu.bar(pages,1,1,width,items,{selector=true,label="Views"})
menu.bar(commands,1,2,width,items)
commands.open=true menu.overlay(commands,width,height)
local name,id,handled=menu.route({{name="pages",state=pages},{name="commands",state=commands}},{name="mouse_click",args={1,1,1}})
assert(name=="commands" and handled and id==nil and not pages.open,"overlay click leaked into view selector")
menu.bar(pages,1,4,width,items,{selector=true,label="Filters",keepOpen=true})
pages.open=true menu.overlay(pages,width,height)
local box=pages.menuBoxes[1]
assert(menu.handle(pages,{name="mouse_click",args={1,box.x,box.y}})==box.id and pages.open)
menu.handle(pages,{name="key",args={keys.escape}}) assert(not pages.open)
print("responsive action menus, touch hitboxes, complete reachability and modal input passed")
