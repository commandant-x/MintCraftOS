-- Logical UI scaling; physical framebuffer, palette and display mode stay intact.
local Surface=require('system.graphics.surface')
local M={}
function M.valid(value) return value==1 or value==1.5 or value==2 end
function M.new(value)
 local self={requested=M.valid(value) and value or 1,effective=1}
 function self:deactivate() self.effective=1 self.backend=nil self.proxy=nil end
 function self:set(value)
  if not M.valid(value) then return false,'UI scale must be 1, 1.5 or 2' end
  self.requested=value self.backend=nil return true
 end
 function self:prepare(backend)
  local physical=backend.surface
  local scale=self.requested
  if backend.mode==0 or math.floor(physical.width/scale)<154 or math.floor(physical.height/scale)<131 then scale=1 end
  self.effective=scale
  if scale==1 then self.backend=backend self.proxy=nil return backend end
  local w,h=math.floor(physical.width/scale),math.floor(physical.height/scale)
  if self.backend~=backend or not self.proxy or self.proxy.surface.width~=w or self.proxy.surface.height~=h or self.factor~=scale then
   self.backend,self.factor=backend,scale
   self.proxy=setmetatable({surface=Surface.new(w,h,15)},{__index=backend})
   self.proxy.palette=function(_,...) return backend:palette(...) end
   physical:rect(0,0,physical.width,physical.height,15)
  end
  return self.proxy
 end
 function self:flush()
  if self.effective==1 or not self.proxy then return end
  local source,target,factor=self.proxy.surface,self.backend.surface,self.effective
  for y,dirty in pairs(source.dirty) do
   local chunks={}
   for x=dirty[1],dirty[2]-1 do
    chunks[#chunks+1]=source.rows[y]:sub(x+1,x+1):rep(math.floor((x+1)*factor)-math.floor(x*factor))
   end
   local row=table.concat(chunks) local left=math.floor(dirty[1]*factor)
   for py=math.floor((y-1)*factor),math.floor(y*factor)-1 do target:span(left,py,row) end
  end
  source.dirty={}
 end
 function self:event(event)
  if self.effective==1 or not event.pixelX or not event.pixelY then return event end
  local copy={} for k,v in pairs(event) do copy[k]=v end
  copy.pixelX=math.floor(event.pixelX/self.effective) copy.pixelY=math.floor(event.pixelY/self.effective)
  return copy
 end
 return self
end
return M
