local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.roll=0
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return 0,0,e.roll end;e.getPosition=function()return 0,181,0 end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/ground-roll-crouched-v1.lua','t',e));local function step(t)e.time=t;run()end
step(0);e.values.Enable=1;step(1);for t=2,500 do step(t) end
local count=0;for t=501,981 do step(t);local n=0;for _,leg in ipairs({'FL','FR','RL','RR'}) do if e.outputs[leg..' roll clutch']==0 then n=n+1;count=count+1 end end;assert(n<=1) end
assert(count==16,'eight two-tick roll pulses expected');e.roll=15;step(982);assert(e.outputs['Tilt guard']==1);print('Grounded roll calibration sends eight isolated two-tick pulses; physical response remains to measure')
