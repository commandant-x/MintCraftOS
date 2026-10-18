local layout=require("system.gui.keyboard_layout")
local widgets=require("system.graphics.widgets")
local M={}
function M.boxes(x,y,w,h,state)
  if w<100 or h<70 then state.pixelBoxes={} return {} end
  local result={} local rowHeight=math.max(10,math.floor(h/7))
  for row,entries in ipairs(layout.layout(state)) do
    local count=row<=5 and math.max(10,#entries) or 4
    for i,entry in ipairs(entries) do
      local left,right=math.floor((i-1)*w/count),math.floor(i*w/count)
      local label=(#entry.label*6+2<=right-left-1) and entry.label or entry.short or entry.label
      result[#result+1]={id=entry.id,text=entry.text,label=label,active=entry.active,
        rect={x=x+left,y=y+(row-1)*rowHeight,w=right-left-1,h=rowHeight-1}}
    end
  end
  state.pixelBoxes=result
  return result
end
function M.draw(surface,x,y,w,h,state,palette)
  for _,key in ipairs(M.boxes(x,y,w,h,state)) do widgets.button(surface,key.rect,key.label,palette,key.active,1) end
end
function M.handle(event,state)
  if event.name~="mouse_click" or event.args[1]~=1 then return false end
  for _,key in ipairs(state.pixelBoxes or {}) do
    if widgets.hit(key.rect,event.args[2],event.args[3]) then layout.press(key,state) return true end
  end
  return false
end
return M
