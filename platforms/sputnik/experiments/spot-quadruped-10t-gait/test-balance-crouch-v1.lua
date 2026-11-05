local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0;e.x=0;e.y=181;e.z=0
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return e.x,e.y,e.z end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/balance-crouch-v1.lua','t',e));local function step(t)e.time=t;run()end
step(0);e.values.Enable=1;step(1);local knees={'FL knee','FR knee','RL knee','RR knee'};local counts={}
for t=2,401 do
 step(t);local n=0
 for _,k in ipairs(knees) do if e.outputs[k..' clutch']==0 then counts[k]=(counts[k] or 0)+1;n=n+1 end end
 assert(n<=1)
end
for _,k in ipairs(knees) do assert(counts[k]==12,k..' '..tostring(counts[k])) end
assert(e.outputs['FL knee reverse']==15 and e.outputs['FR knee reverse']==0 and e.outputs['RL knee reverse']==15 and e.outputs['RR knee reverse']==0)
e.getOrientation=function()error('lost')end;step(402);assert(e.outputs['Tilt guard']==1);for _,k in ipairs(knees) do assert(e.outputs[k..' clutch']==15) end
print('Four knees receive six separated two-tick pulses each, and close on pose fault; standing not proven')
