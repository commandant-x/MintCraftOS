local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0;e.x=0;e.y=181;e.z=0
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return e.x,e.y,e.z end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/balance-crouch-sync-v3.lua','t',e));local function step(t)e.time=t;run()end
local knees={'FL knee','FR knee','RL knee','RR knee'};local before={};local after={}
step(0);e.values.Enable=1;step(1)
for t=2,800 do
 step(t);local n=0
 for _,k in ipairs(knees) do if e.outputs[k..' clutch']==0 then n=n+1;local d=t<500 and before or after;d[k]=(d[k] or 0)+1 end end
 assert(n==0 or n==4)
end
for _,k in ipairs(knees) do assert(before[k]==8 and after[k]==4,k..' '..tostring(before[k])..' '..tostring(after[k])) end
assert(e.outputs['FL knee reverse']==0 and e.outputs['FR knee reverse']==15 and e.outputs['RL knee reverse']==0 and e.outputs['RR knee reverse']==15)
e.getPosition=function()error('lost')end;step(801);assert(e.outputs['Tilt guard']==1);for _,k in ipairs(knees) do assert(e.outputs[k..' clutch']==15) end
print('Four knees get four synchronized bending pulses then two opposite pulses; invalid position closes gates')
