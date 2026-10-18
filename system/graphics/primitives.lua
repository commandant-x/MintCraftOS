local M={}
function M.line(s,x1,y1,x2,y2,c)
  local dx,dy,lo,hi=x2-x1,y2-y1,0,1
  local function clip(p,q)
    if p==0 then return q>=0 end
    local t=q/p
    if p<0 then if t>hi then return false end lo=math.max(lo,t)
    else if t<lo then return false end hi=math.min(hi,t) end
    return true
  end
  if not (clip(-dx,x1) and clip(dx,s.width-1-x1) and clip(-dy,y1) and clip(dy,s.height-1-y1)) then return end
  x2,y2=math.floor(x1+hi*dx+0.5),math.floor(y1+hi*dy+0.5)
  x1,y1=math.floor(x1+lo*dx+0.5),math.floor(y1+lo*dy+0.5)
  dx,dy=math.abs(x2-x1),-math.abs(y2-y1)
  local sx,sy=x1<x2 and 1 or -1,y1<y2 and 1 or -1
  local err=dx+dy
  while true do
    s:pixel(x1,y1,c)
    if x1==x2 and y1==y2 then return end
    local twice=err*2
    if twice>=dy then err=err+dy x1=x1+sx end
    if twice<=dx then err=err+dx y1=y1+sy end
  end
end
function M.rect(s,x,y,w,h,c)
  if w<=0 or h<=0 then return end
  s:rect(x,y,w,1,c) s:rect(x,y+h-1,w,1,c)
  s:rect(x,y,1,h,c) s:rect(x+w-1,y,1,h,c)
end
function M.circle(s,x,y,r,c,filled)
  assert(type(r)=="number" and r>=0 and r<=4096,"Invalid circle radius")
  -- Scan only visible rows even for large off-screen circles.
  for py=math.max(0,math.ceil(y-r)),math.min(s.height-1,math.floor(y+r)) do
    local half=math.sqrt(math.max(0,r*r-(py-y)^2))
    local left,right=math.ceil(x-half),math.floor(x+half)
    if filled then s:rect(left,py,right-left+1,1,c)
    else
      s:pixel(left,py,c) s:pixel(right,py,c)
      if py==math.ceil(y-r) or py==math.floor(y+r) then s:rect(left,py,right-left+1,1,c) end
    end
  end
end
function M.bitmap(s,x,y,rows)
  for i=math.max(1,1-y),math.min(#rows,s.height-y) do s:span(x,y+i-1,rows[i]) end
end
return M
