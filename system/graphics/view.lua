-- Local, zero-based drawing surface clipped to a parent client rectangle.
local M={}
function M.new(parent,x,y,w,h)
  local v={width=w,height=h,clip={x=0,y=0,w=w,h=h}}
  function v:span(px,py,text)
    px,py=math.floor(px),math.floor(py)
    local c=self.clip
    if py<c.y or py>=c.y+c.h or px>=c.x+c.w or px+#text<=c.x then return end
    if px<c.x then text,px=text:sub(c.x-px+1),c.x end
    parent:span(x+px,y+py,text:sub(1,c.x+c.w-px))
  end
  function v:rect(px,py,rw,rh,color)
    px,py,rw,rh=math.floor(px),math.floor(py),math.floor(rw),math.floor(rh)
    local c=self.clip local left,right=math.max(0,px,c.x),math.min(w,px+rw,c.x+c.w)
    if right<=left then return end
    local row=string.rep(string.char(color),right-left)
    for line=math.max(0,py,c.y),math.min(h,py+rh,c.y+c.h)-1 do self:span(left,line,row) end
  end
  function v:pixel(px,py,color) self:span(px,py,string.char(color)) end
  function v:setClip(px,py,cw,ch)
    local old=self.clip local left,top=math.max(0,math.floor(px)),math.max(0,math.floor(py))
    self.clip={x=left,y=top,w=math.max(0,math.min(w,math.floor(px+cw))-left),h=math.max(0,math.min(h,math.floor(py+ch))-top)}
    return old
  end
  return v
end
return M
