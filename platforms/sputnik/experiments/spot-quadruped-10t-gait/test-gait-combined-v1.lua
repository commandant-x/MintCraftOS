local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.pitch=0
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,0,0 end;e.getPosition=function()return 0,181,0 end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/gait-combined-v1.lua','t',e));local function step(t)e.time=t;run()end
step(0);e.values.Enable=1;step(1);for t=2,600 do step(t) end
local count=0
for t=601,800 do step(t);local active=0;for _,leg in ipairs({'FL','FR','RL','RR'}) do for _,j in ipairs({'hip','knee'}) do if e.outputs[leg..' '..j..' clutch']==0 then active=active+1 end end end;assert(active<=1);count=count+active end
assert(count>0);e.pitch=20;step(801);assert(e.outputs['Gait fault']==1);for _,leg in ipairs({'FL','FR','RL','RR'}) do for _,j in ipairs({'roll','hip','knee'}) do assert(e.outputs[leg..' '..j..' clutch']==15) end end
print('Experimental gait sequences one joint at a time and halts gait on excessive measured tilt; no physical walking claim')
