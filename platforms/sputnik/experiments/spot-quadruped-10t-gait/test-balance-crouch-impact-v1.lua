local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0;e.x=0;e.y=181;e.z=0
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return e.x,e.y,e.z end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/balance-crouch-impact-v1.lua','t',e));local function step(t)e.time=t;run()end
local knees={'FL knee','FR knee','RL knee','RR knee'};step(0);e.values.Enable=1;step(1)
for t=2,600 do step(t) end
assert(e.outputs.Emergency==0 and e.outputs['Correction axis']==0)
e.x=-.2;step(601);step(602);step(603);step(604)
for _,k in ipairs(knees) do assert(e.outputs[k..' clutch']==0,k) end
step(605);step(606);for _,k in ipairs(knees) do assert(e.outputs[k..' clutch']==15) end
for t=607,629 do step(t) end;assert(e.outputs['Correction axis']==3)
e.getPosition=function()error('lost')end;step(630);assert(e.outputs['Tilt guard']==1);for _,k in ipairs(knees) do assert(e.outputs[k..' clutch']==15) end
print('Crouch reference rebased; westward motion triggers synchronized opposite knee pulses; sensor fault closes outputs')
