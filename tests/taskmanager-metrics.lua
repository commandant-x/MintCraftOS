package.path="./?.lua;"..package.path
local reads,frames,bytes,generation=10,20,1000,1
package.loaded["system.libraries.addon"]={metrics=function() return {reads=reads,inFlight=0,queue=0} end}
local Metrics=require("apps.taskmanager.metrics")
local free,capacity=100,1000 local heap=128 local failing=false
fs={getFreeSpace=function() if failing then error("disk unavailable") end return free end,getCapacity=function() return capacity end}
collectgarbage=function() return heap end
local ctx={listProcesses=function() return {{pid=1,name="waiting",state="ready",runtimeMs=0},{pid=2,name="done",state="stopped"}} end,
  system={renderStats=function() return {backend="PIXEL256",frames=frames,bytes=bytes,generation=generation,pixelWidth=960,pixelHeight=540} end}}
local a=Metrics.sample(ctx,nil,0)
assert(a.ready==1 and a.rows[1].runtimeMs==0 and a.rows[2].runtimeMs==nil and a.used==900 and a.heapKB==128)
assert(a.readRate==nil and a.pixelRate==nil and a.renderRate==nil and not a.cpu)
reads,frames,bytes=14,26,1200
local b=Metrics.sample(ctx,a,2)
assert(b.readRate==2 and b.renderRate==3 and b.pixelRate==100)
generation=2 bytes=100000
local c=Metrics.sample(ctx,b,3)
assert(c.pixelRate==nil,"same-name backend replacement produced fake payload rate")
reads=1 frames=1 bytes=1
local d=Metrics.sample(ctx,c,4) assert(not d.readRate and not d.renderRate and not d.pixelRate)
assert(Metrics.rate(10,10,1)==0 and not Metrics.rate(20,10,0) and not Metrics.rate(20,10,-1) and not Metrics.rate(20,10,6))
assert(not Metrics.rate(10,-1,1) and not Metrics.rate(-1,-2,1))
assert(not Metrics.sample(ctx,d,20).pixelRate)
for _,pair in ipairs({{"unlimited",1000},{100,"unlimited"},{100,0},{100,-1},{100,math.huge},{100,0/0},{2000,1000}}) do
  free,capacity=pair[1],pair[2] local s=Metrics.sample(ctx,nil,1) assert(s.used==nil,"invalid capacity fabricated usage")
end
free,capacity=0,100 local zero=Metrics.sample(ctx,nil,1) assert(zero.free==0 and zero.used==100)
free,capacity=nil,nil heap=nil local absent=Metrics.sample(ctx,nil,1) assert(absent.heapKB==nil and absent.free==nil and absent.used==nil)
assert(absent.memory:find("unavailable") and absent.disk:find("unavailable"))
failing=true local failed=Metrics.sample(ctx,nil,1) assert(#failed.errors>0 and failed.free==nil)
ctx.security={require=function() return false,"denied" end}
ctx.listProcesses=function() error("unauthorized process query") end
assert(#Metrics.sample(ctx,nil,1).rows==0)
ctx.security.require=function() error("policy unavailable") end assert(#Metrics.sample(ctx,nil,1).rows==0)
local history={}
for i=1,100 do Metrics.record(history,{timestamp=i,heapKB=i}) end assert(#history==60 and history[1].timestamp==41)
Metrics.record(history,{timestamp=100,heapKB=1000}) assert(#history==60 and history[#history].heapKB==100)
Metrics.record(history,{timestamp=3,heapKB=3}) assert(#history==1 and history[1].timestamp==3,"backward clock retained incompatible history")
print("Task Manager metrics: honest rates, backend generations, unavailable/unlimited storage, authorization and bounded history passed")
