package.path='./?.lua;'..package.path
local Backend=require('system.graphics.backend')
print('batch\tframes\tdraw_calls\tbytes\tpresent_ms\tmax_batch_pixel_bytes\tpeak_lua_KiB')
for _,batch in ipairs({4,8,16,32}) do
 collectgarbage('collect') local heap=collectgarbage('count') local peak=heap
 local mode=0 local count,bytes,maxBatch=0,0,0
 local target={getSize=function(m) return m and m>0 and 960 or 51,m and m>0 and 540 or 19 end,
  getGraphicsMode=function() return mode end,setGraphicsMode=function(m) mode=m end,
  drawPixels=function(x,y,rows)
   local size=0 for _,row in ipairs(rows) do size=size+#row end
   count=count+1 bytes=bytes+size maxBatch=math.max(maxBatch,size)
  end}
 local b=Backend.new(target,'auto',{batchRows=batch}) local seconds=0
 for i=1,60 do
  b.surface:rect(0,0,960,540,i%16)
  local start=os.clock() assert(b:present()) seconds=seconds+os.clock()-start
  peak=math.max(peak,collectgarbage('count'))
 end
 print(string.format('%d\t60\t%d\t%d\t%.3f\t%d\t%.1f',batch,count,bytes,seconds*1000,maxBatch,peak-heap))
end
