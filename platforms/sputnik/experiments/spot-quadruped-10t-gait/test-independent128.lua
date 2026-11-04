local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0,Start=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0
e.input=function(n)return e.values[n] end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return 40,181,42 end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/independent128-guarded.lua','t',e));local function step(t)e.time=t;run()end
local function closed()for _,n in ipairs({'FL roll','FL hip','FL knee','FR roll','FR hip','FR knee','RL roll','RL hip','RL knee','RR roll','RR hip','RR knee'}) do assert(e.outputs[n..' clutch']==15) end end
step(0);e.values.Enable=1;step(1);e.values.Start=1;step(2);e.values.Start=0;assert(e.outputs.Running==1)
local pulses={}
for t=3,193 do step(t);local active=0;for _,n in ipairs({'FL roll','FL hip','FL knee','FR roll','FR hip','FR knee','RL roll','RL hip','RL knee','RR roll','RR hip','RR knee'}) do if e.outputs[n..' clutch']==0 then active=active+1;pulses[n]=(pulses[n] or 0)+1 end end;assert(active<=1) end
for _,leg in ipairs({'FL','FR','RL','RR'}) do assert(pulses[leg..' hip']==4 and pulses[leg..' knee']==4 and not pulses[leg..' roll']) end
step(194);closed();assert(e.outputs.Running==0)
e.values.Enable=0;step(195);e.values.Enable=1;step(196);e.values.Start=1;step(197);e.values.Start=0;e.pitch=13;step(198);closed();assert(e.outputs['Tilt guard']==1 and e.outputs.Running==0)
print('Independent 128: one axis at a time, matched pulses, orientation guard pass')
