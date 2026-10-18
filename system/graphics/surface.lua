-- Zero-based indexed pixels. Rows are byte strings, never boxed pixel tables.
local M = {}
function M.new(w,h,color)
  assert(type(w)=="number" and type(h)=="number" and w%1==0 and h%1==0
    and w>0 and h>0 and w*h<=1048576,"Invalid framebuffer size")
  local s={width=w,height=h,rows={},dirty={},clip={x=0,y=0,w=w,h=h}}
  function s:setClip(x,y,cw,ch)
    local old=self.clip
    local left,top=math.max(0,math.floor(x)),math.max(0,math.floor(y))
    self.clip={x=left,y=top,w=math.max(0,math.min(w,math.floor(x+cw))-left),
      h=math.max(0,math.min(h,math.floor(y+ch))-top)}
    return old
  end
  local function byte(c)
    assert(type(c)=="number" and c%1==0 and c>=0 and c<=255,"Invalid palette index")
    return string.char(c)
  end
  function s:span(x,y,text)
    x,y=math.floor(x),math.floor(y)
    local c=self.clip
    if y<c.y or y>=c.y+c.h or x>=c.x+c.w or x+#text<=c.x then return end
    if x<c.x then text,x=text:sub(c.x-x+1),c.x end
    text=text:sub(1,c.x+c.w-x)
    if #text==0 then return end
    local old=self.rows[y+1]
    if old:sub(x+1,x+#text)==text then return end
    self.rows[y+1]=old:sub(1,x)..text..old:sub(x+#text+1)
    local d=self.dirty[y+1]
    self.dirty[y+1]={math.min(d and d[1] or x,x),math.max(d and d[2] or x+#text,x+#text)}
  end
  function s:rect(x,y,rw,rh,c)
    x,y,rw,rh=math.floor(x),math.floor(y),math.floor(rw),math.floor(rh)
    local clip=self.clip
    local left,right=math.max(0,x,clip.x),math.min(w,x+rw,clip.x+clip.w)
    if right<=left or rh<=0 then return end
    local row=string.rep(byte(c),right-left)
    for py=math.max(0,y,clip.y),math.min(h,y+rh,clip.y+clip.h)-1 do self:span(left,py,row) end
  end
  function s:pixel(x,y,c) self:span(x,y,byte(c)) end
  function s:invalidate() for y=1,h do self.dirty[y]={0,w} end end
  local blank=string.rep(byte(color or 15),w)
  for y=1,h do s.rows[y]=blank end
  s:invalidate()
  return s
end
return M
