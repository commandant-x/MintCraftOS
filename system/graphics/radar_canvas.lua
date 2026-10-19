local Surface=require("system.graphics.surface")
local primitives=require("system.graphics.primitives")
local M={}
local indices={}
for i=0,15 do indices[2^i]=i end
function M.index(color) return indices[color] or 0 end
-- Instruments use one-based coordinates and CC colour masks. Keep the same
-- world projection for both terminal mosaics and native indexed framebuffers.
function M.new(w,h,color)
  local c={width=w,height=h,surface=Surface.new(w,h,M.index(color))}
  function c:pixel(x,y,value) self.surface:pixel(math.floor(x)-1,math.floor(y)-1,M.index(value)) end
  function c:rect(x,y,rw,rh,value) self.surface:rect(x-1,y-1,rw,rh,M.index(value)) end
  function c:line(x1,y1,x2,y2,value) primitives.line(self.surface,x1-1,y1-1,x2-1,y2-1,M.index(value)) end
  return c
end
return M
