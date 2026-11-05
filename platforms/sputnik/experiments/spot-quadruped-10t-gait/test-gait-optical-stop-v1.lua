local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.sensor=0
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return 0,0,0 end;e.getPosition=function()return 0,181,0 end;e.transmitWirelessRedstone=function()end;e.receiveWirelessRedstone=function()return e.sensor end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/gait-optical-stop-v1.lua','t',e));local function step(t)e.time=t;run()end
step(0);e.values.Enable=1;step(1);for t=2,610 do step(t) end;assert(e.outputs['Obstacle stop']==0);e.sensor=6;step(611);assert(e.outputs['Obstacle stop']==1)
for t=612,630 do step(t);for _,leg in ipairs({'FL','FR','RL','RR'}) do for _,j in ipairs({'roll','hip','knee'}) do assert(e.outputs[leg..' '..j..' clutch']==15) end end end
e.sensor=0;step(631);assert(e.outputs['Obstacle stop']==1);e.values.Enable=0;step(632);assert(e.outputs['Obstacle stop']==0)
print('Optical stop latches and closes the gait gates after threshold; actual mobile sensing must be tested')
