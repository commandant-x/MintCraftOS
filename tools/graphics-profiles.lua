-- Synthetic graphics-only workload. No Minecraft FPS or sensor timing claim.
package.path='./?.lua;'..package.path
local Backend=require('system.graphics.backend')
local Policy=require('system.graphics.policy')
print('profile\twidth\theight\tmax_hz\tframes\tdraw_calls\tbytes\tcpu_ms')
for _,profile in ipairs({'stable','balanced','performance'}) do
 for _,size in ipairs({{306,171},{960,540}}) do
  local w,h=table.unpack(size) local mode=0 local calls,bytes=0,0
  local output={}
  for y=1,h do output[y]=string.rep(string.char(15),w) end
  local target={getSize=function(m) return m and m>0 and w or 51,m and m>0 and h or 19 end,
   getGraphicsMode=function() return mode end,setGraphicsMode=function(v) mode=v end,
   drawPixels=function(x,y,rows)
    calls=calls+1
    for i,row in ipairs(rows) do bytes=bytes+#row local previous=output[y+i] output[y+i]=previous:sub(1,x)..row..previous:sub(x+#row+1) end
   end}
  local options=Policy.options({graphicsProfile=profile})
  local backend=Backend.new(target,'auto',options)
  local started=os.clock()
  for frame=1,100 do
   -- Repeat a static frame, then alternate a small real pixel rectangle.
   backend.surface:rect(0,0,w,h,15)
   backend.surface:rect(12,12,30,20,frame<=50 and 9 or frame%16)
   assert(backend:present())
  end
  for y=1,h do for x=1,w do
   local expected=x>=13 and x<=42 and y>=13 and y<=32 and 100%16 or 15
   assert(output[y]:byte(x)==expected,'profile changed final framebuffer')
  end end
  print(string.format('%s\t%d\t%d\t%d\t100\t%d\t%d\t%.3f',profile,w,h,options.maxHz,calls,bytes,(os.clock()-started)*1000))
 end
end
