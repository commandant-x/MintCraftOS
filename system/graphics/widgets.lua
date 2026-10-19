local fonts=require("system.graphics.fonts")
local primitives=require("system.graphics.primitives")
local textCodec=require("system.graphics.text")
local M={}
function M.hit(r,x,y) return r and x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h end
function M.label(s,x,y,text,width,fg,bg,align)
  text=textCodec.single(text)
  local count=math.max(0,math.floor(width/6))
  if #text>count then text=count>=3 and text:sub(1,count-3).."..." or text:sub(1,count) end
  local offset=align=="center" and math.floor((width-#text*6)/2) or align=="right" and width-#text*6 or 0
  fonts.draw(s,x+offset,y,text,fg,bg)
end
function M.button(s,r,label,p,active,padding)
  local bg=active and p.accent or p.button
  s:rect(r.x,r.y,r.w,r.h,bg)
  local pad=padding or (r.w<18 and 1 or 4)
  M.label(s,r.x+pad,r.y+math.floor((r.h-9)/2),label,r.w-pad*2,active and p.ink or p.text,bg,"center")
end
function M.input(s,r,value,p,focused,placeholder,reserve)
  value=textCodec.single(value) reserve=reserve or 0
  s:rect(r.x,r.y,r.w,r.h,p.desktop)
  if focused then primitives.rect(s,r.x,r.y,r.w,r.h,p.accent) end
  local count=math.max(0,math.floor((r.w-10-reserve)/6))
  local shown=value=="" and textCodec.single(placeholder):sub(1,count) or (count>0 and value:sub(-count) or "")
  local y=r.y+math.floor((r.h-9)/2)
  fonts.draw(s,r.x+5,y,shown,value=="" and p.muted or p.text,p.desktop)
  if focused and count>0 then s:rect(r.x+5+math.min(#value,count)*6,y,1,9,p.accent) end
end
function M.paragraph(s,r,text,fg,bg,options)
  return fonts.drawText(s,r.x,r.y,r.w,r.h,text,fg,bg,options)
end
function M.symbol(s,r,kind,p,active)
  local bg=active and p.accent or p.button
  s:rect(r.x,r.y,r.w,r.h,bg)
  local x,y=math.floor(r.x+r.w/2),math.floor(r.y+r.h/2)
  local c=active and p.ink or p.text
  if kind=="close" then
    primitives.line(s,x-3,y-3,x+3,y+3,c) primitives.line(s,x+3,y-3,x-3,y+3,c)
  elseif kind=="minimize" then s:rect(x-4,y+2,8,1,c)
  elseif kind=="maximize" then primitives.rect(s,x-4,y-3,8,7,c)
  elseif kind=="search" then primitives.circle(s,x-2,y-1,3,c) primitives.line(s,x+1,y+2,x+4,y+5,c)
  elseif kind=="menu" then
    for dy=-4,2,6 do for dx=-4,2,6 do s:rect(x+dx,y+dy,4,4,c) end end
  elseif kind=="previous" or kind=="next" then
    local d=kind=="previous" and -1 or 1
    primitives.line(s,x-d*2,y-3,x+d*2,y,c) primitives.line(s,x+d*2,y,x-d*2,y+3,c)
  elseif kind=="keyboard" then
    primitives.rect(s,x-6,y-3,12,7,c)
    for dx=-4,4,3 do s:pixel(x+dx,y-1,c) s:pixel(x+dx,y+1,c) end
  elseif kind=="up" or kind=="down" then
    local d=kind=="up" and -1 or 1
    primitives.line(s,x-3,y-d*2,x,y+d*2,c) primitives.line(s,x,y+d*2,x+3,y-d*2,c)
  elseif kind=="home" then
    primitives.line(s,x-5,y,x,y-5,c) primitives.line(s,x,y-5,x+5,y,c)
    primitives.rect(s,x-3,y,7,5,c)
  elseif kind=="refresh" then
    primitives.circle(s,x,y,4,c) s:rect(x+2,y-5,4,2,c)
  elseif kind=="new_dir" then
    primitives.rect(s,x-6,y-2,10,7,c) s:rect(x-5,y-5,5,3,c)
    s:rect(x+1,y+1,6,1,c) s:rect(x+3,y-1,1,5,c)
  elseif kind=="new_file" then
    primitives.rect(s,x-5,y-5,7,10,c)
    s:rect(x+1,y+1,6,1,c) s:rect(x+3,y-1,1,5,c)
  elseif kind=="more" then
    for dy=-4,4,4 do s:rect(x-1,y+dy,2,2,c) end
  elseif kind=="check" then
    primitives.line(s,x-5,y,x-1,y+3,c) primitives.line(s,x-1,y+3,x+5,y-4,c)
  end
end
return M
