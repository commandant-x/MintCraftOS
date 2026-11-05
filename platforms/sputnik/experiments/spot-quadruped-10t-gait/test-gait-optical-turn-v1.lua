local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.sensor=0;e.yaw=0
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return 0,e.yaw,0 end;e.getPosition=function()return 0,181,0 end;e.transmitWirelessRedstone=function()end;e.receiveWirelessRedstone=function()return e.sensor end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/gait-optical-turn-v1.lua','t',e));local function step(t)e.time=t;run()end
step(0);e.values.Enable=1;step(1);for t=2,610 do step(t) end;e.sensor=6;step(611);assert(e.outputs['Obstacle stop']==1 and e.outputs['Turn active']==0)
for t=612,640 do step(t);assert(e.outputs['Turn active']==0) end;step(641);assert(e.outputs['Turn active']==1);e.yaw=26;step(642);assert(e.outputs['Turn active']==0 and e.outputs['Turn done']==1)
print('Optical trigger waits before differential turn and halts after target angle; side clearance remains unmeasured')
