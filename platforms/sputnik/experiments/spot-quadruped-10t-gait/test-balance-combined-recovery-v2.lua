local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0;e.x=0;e.y=181;e.z=0
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return e.x,e.y,e.z end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/balance-combined-recovery-v2.lua','t',e));local function step(t)e.time=t;run()end
step(0);e.values.Enable=1;step(1);for t=2,600 do step(t) end
e.x=-.2;step(601);local extension,flexion=false,false
for t=602,730 do step(t);if e.outputs['Correction axis']==3 then extension=true end;if e.outputs['Correction axis']==6 then flexion=true end end
assert(extension and flexion,'first impact must extend and rearm by bending')
e.z=-.2;step(731);local second=false
for t=732,760 do step(t);if e.outputs['Correction axis']==3 then second=true end end
assert(second,'second impact must trigger after rearm')
e.getPosition=function()error('lost')end;step(761);assert(e.outputs['Tilt guard']==1 and e.outputs['FL knee clutch']==15)
print('Two simulated impacts trigger coordinated hip/knee extension and re-bending; physical recovery still requires testing')
