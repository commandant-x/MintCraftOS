local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0;e.x=0;e.y=181;e.z=0
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return e.x,e.y,e.z end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/balance-step-west-experimental.lua','t',e));local function step(t)e.time=t;run()end
step(0);e.values.Enable=1;step(1);e.x=-.2;step(2);assert(e.outputs['FL roll clutch']==15 and e.outputs['RL roll reverse']==15)
step(3);step(4);step(5);assert(e.outputs['FL roll clutch']==0 and e.outputs['RL roll clutch']==0);step(6);assert(e.outputs['FL roll clutch']==0);step(7);assert(e.outputs['FL roll clutch']==15)
for t=8,40 do e.x=e.x-.2;step(t);assert(e.outputs['FL roll clutch']==15) end
e.getPosition=function()error('lost')end;step(41);assert(e.outputs['Tilt guard']==1 and e.outputs['FL roll clutch']==15)
print('One simultaneous lateral pulse after westward movement; no repeated pulses; invalid pose closes gate')
