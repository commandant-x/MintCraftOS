local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0;e.y=181
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return 0,e.y,0 end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/ground-axis-calibration.lua','t',e));local names={'FL roll','FL hip','FR roll','FR hip','RL roll','RL hip','RR roll','RR hip'};local opened={}
local function step(t)e.time=t;run()end
step(0);e.values.Enable=1;step(1)
for t=2,981 do
 step(t);local active=0
 for _,n in ipairs(names) do if e.outputs[n..' clutch']==0 then active=active+1;local key=n..':'..e.outputs[n..' reverse'];opened[key]=(opened[key] or 0)+1 end end
 assert(active<=1)
end
for _,n in ipairs(names) do assert(opened[n..':0']==2 and opened[n..':15']==2,n) end
step(982);for _,n in ipairs(names) do assert(e.outputs[n..' clutch']==15) end
print('Eight ground axes individually pulsed both directions; selected gates never overlap')
