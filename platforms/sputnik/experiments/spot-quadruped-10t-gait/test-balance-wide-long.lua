local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0;e.x=0;e.y=181;e.z=0
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return e.x,e.y,e.z end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/balance-wide-fourway-long.lua','t',e));local function step(t)e.time=t;run()end
local expected={['FL roll']=2,['RL roll']=2,['FR roll']=2,['RR roll']=2,['FL hip']=6,['FR hip']=6,['RL hip']=6,['RR hip']=6};local count={}
step(0);e.values.Enable=1;step(1)
for t=2,121 do
 step(t);for name in pairs(expected) do if e.outputs[name..' clutch']==0 then count[name]=(count[name] or 0)+1 end end
end
for name,n in pairs(expected) do assert(count[name]==n,name..': '..tostring(count[name])) end
for name in pairs(expected) do assert(e.outputs[name..' clutch']==15) end
e.getPosition=function()error('lost')end;step(122);assert(e.outputs['Tilt guard']==1);for name in pairs(expected) do assert(e.outputs[name..' clutch']==15) end
print('Long-stance preparation pulses and invalid-position closure pass; physical stability assessed separately')
