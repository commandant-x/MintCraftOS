local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0;e.y=181
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return 0,e.y,0 end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/balance-emergency-experimental.lua','t',e));local function step(t)e.time=t;run()end
step(0);e.values.Enable=1;step(1);e.pitch=13
local activated=false
for t=2,39 do step(t);assert(e.outputs['Tilt guard']==0);if e.outputs.Emergency==1 and e.outputs['Correction axis']>0 then activated=true end end
assert(activated,'emergency correction must continue at 13 degrees')
e.pitch=0;e.y=178;for t=40,59 do step(t);assert(e.outputs.Emergency==1 and e.outputs['Tilt guard']==0) end
assert(e.outputs['Correction axis']>0,'drop must call recovery')
e.getOrientation=function()error('sensor lost')end;step(60);assert(e.outputs['Tilt guard']==1 and e.outputs['Correction axis']==0)
print('Emergency remains active above 12 degrees or after a two-block drop; missing pose stops outputs')
