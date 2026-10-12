local renderer=require("system.gui.renderer")
local theme=require("system.gui.theme")
local ui=require("system.gui.components")
local M={}

function M.new()
  return {open=false,first=1,boxes={}}
end

local function button(box,selected)
  local bg=box.danger and colors.red or selected and theme.get("accent") or theme.get("buttonBg")
  local fg=box.danger and colors.white or selected and theme.get("titleFg") or theme.get("buttonFg")
  renderer.fill(box.x,box.y,box.w,box.h or 1,bg)
  local text=" "..box.label
  if (box.h or 1)>1 and #text>box.w then
    local cut=text:sub(1,box.w):match("^.*() ") or box.w
    renderer.writeAt(box.x,box.y,renderer.crop(text:sub(1,cut),box.w),fg,bg)
    renderer.writeAt(box.x,box.y+1,renderer.crop(" "..text:sub(cut+1),box.w),fg,bg)
  else renderer.writeAt(box.x,box.y,renderer.crop(text,box.w),fg,bg) end
end

function M.bar(state,x,y,w,items,options)
  options=options or {}
  state.items=items state.title=options.title or "Actions" state.selected=options.selected
  state.keepOpen=options.keepOpen
  state.boxes={} state.w=w
  local cursor=x
  local menuWidth=math.min(w,#(options.label or "More")+2)
  if options.selector then
    state.trigger={x=x,y=y,w=w,h=1,label=options.label or "Views"}
  else
    for _,item in ipairs(items) do
      if item.primary~=false then
        local width=#item.label+2
        if cursor+width>x+w-menuWidth-1 then break end
        local box={id=item.id,label=item.label,x=cursor,y=y,w=width,h=1,danger=item.danger}
        state.boxes[#state.boxes+1]=box button(box,item.active)
        cursor=cursor+width+1
      end
    end
    state.trigger={x=x+w-menuWidth,y=y,w=menuWidth,h=1,label=options.label or "More"}
  end
  button(state.trigger,state.open)
  return state.boxes
end

function M.overlay(state,w,h)
  if not state.open then return end
  local top=math.min(state.trigger.y+1,math.max(1,h-4))
  local available=h-top
  local columns=w>=44 and 3 or w>=24 and 2 or 1
  local stride=available>=5 and 3 or 2
  local rows=math.max(1,math.floor((available-2)/stride))
  local capacity=columns*rows
  local visibleRows=math.min(rows,math.ceil(#state.items/columns))
  local height=math.min(available,2+visibleRows*stride)
  state.first=math.max(1,math.min(state.first,math.max(1,#state.items-capacity+1)))
  state.capacity=capacity state.menuBoxes={}
  renderer.fill(1,top,w,height,theme.get("windowBg"))
  renderer.writeAt(1,top,renderer.crop(state.title,math.max(1,w-7)),theme.get("titleFg"),theme.get("titleBg"))
  state.close={x=math.max(1,w-5),y=top,w=math.min(6,w),h=1,label="Close"}
  button(state.close)
  local track=math.floor(w/columns)
  for slot=0,capacity-1 do
    local item=state.items[state.first+slot]
    if not item then break end
    local column=slot%columns local row=math.floor(slot/columns)
    local box={id=item.id,label=item.menuLabel or item.label,x=1+column*track,y=top+1+row*stride,
      w=(column==columns-1 and w-column*track or track)-1,h=2,danger=item.danger}
    box.w=math.max(1,box.w)
    state.menuBoxes[#state.menuBoxes+1]=box
    button(box,item.id==state.selected or item.active)
  end
  state.pager={}
  if #state.items>capacity then
    for index,label in ipairs({"Previous","Next"}) do
      local width=math.min(10,math.floor(w/2))
      local box={x=index==1 and 1 or w-width+1,y=top+height-1,w=width,h=1,label=label,delta=index==1 and -capacity or capacity}
      state.pager[#state.pager+1]=box button(box)
    end
  end
end

function M.handle(state,event)
  if state.open then
    if event.name=="key" and event.args[1]==keys.escape then state.open=false return nil,true end
    if event.name=="mouse_scroll" then state.first=math.max(1,state.first+event.args[1]*(state.capacity or 1)) return nil,true end
    if event.name=="mouse_click" then
      local _,x,y=table.unpack(event.args)
      if ui.hit(state.close,x,y) or ui.hit(state.trigger,x,y) then state.open=false return nil,true end
      for _,box in ipairs(state.pager or {}) do if ui.hit(box,x,y) then state.first=math.max(1,state.first+box.delta) return nil,true end end
      for _,box in ipairs(state.menuBoxes or {}) do if ui.hit(box,x,y) then state.open=state.keepOpen==true return box.id,true end end
      state.open=false
    end
    return nil,true
  end
  if event.name~="mouse_click" then return nil,false end
  local _,x,y=table.unpack(event.args)
  if ui.hit(state.trigger,x,y) then state.open=true state.first=1 return nil,true end
  for _,box in ipairs(state.boxes or {}) do if ui.hit(box,x,y) then return box.id,true end end
  return nil,false
end

function M.dismiss(...)
  for _,state in ipairs({...}) do state.open=false end
end

function M.route(entries,event)
  -- The open overlay owns input before any underlying strip or app hitbox.
  for _,entry in ipairs(entries) do if entry.state.open then
    local id,handled=M.handle(entry.state,event)
    return entry.name,id,handled
  end end
  for _,entry in ipairs(entries) do
    local id,handled=M.handle(entry.state,event)
    if handled then
      for _,other in ipairs(entries) do if other~=entry then other.state.open=false end end
      return entry.name,id,true
    end
  end
  return nil,nil,false
end

return M
