local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0;e.y=181
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return 0,e.y,0 end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/balance-measured-experimental.lua','t',e));local function step(t)e.time=t;run()end
step(0);e.values.Enable=1;step(1);e.pitch=2;e.roll=2;local seen=false
for t=2,39 do step(t);if e.outputs['Correction axis']>0 then seen=true end end
assert(seen);e.pitch=13;for t=40,59 do step(t);assert(e.outputs.Emergency==1 and e.outputs['Tilt guard']==0) end
e.getOrientation=function()error('lost')end;step(60);assert(e.outputs['Tilt guard']==1 and e.outputs['Correction axis']==0)
print('Measured-map selection, emergency mode, and invalid-pose shutdown pass; physical recovery unproven')
