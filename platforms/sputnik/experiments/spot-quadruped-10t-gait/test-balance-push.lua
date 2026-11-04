local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/balance-push-experimental.lua','t',e));local function step(t)e.time=t;run()end
local names={'FL roll','FL hip','FL knee','FR roll','FR hip','FR knee','RL roll','RL hip','RL knee','RR roll','RR hip','RR knee'}
step(0);e.values.Enable=1;step(1);e.roll=2;local seen=false
for t=20,39 do step(t);local n=0;for _,name in ipairs(names) do if e.outputs[name..' clutch']==0 then n=n+1;seen=true end end;assert(n<=1) end
assert(seen);e.roll=13;step(40);assert(e.outputs['Tilt guard']==1);for _,n in ipairs(names) do assert(e.outputs[n..' clutch']==15) end
print('Correction pulse and orientation guard verified; physical direction is not validated')
