local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0;e.x=0;e.y=181;e.z=0
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return e.x,e.y,e.z end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/balance-recovery-delayed.lua','t',e));local function step(t)e.time=t;run()end
step(0);e.values.Enable=1;step(1);e.pitch=13
for t=2,19 do e.x=e.x+1;step(t);assert(e.outputs.Emergency==1 and e.outputs['Tilt guard']==0 and e.outputs['Correction axis']==0) end
local acted=false
for t=20,40 do step(t);if e.outputs['Correction axis']>0 then acted=true end end
assert(acted,'must resume recovery once horizontal motion slows')
e.getPosition=function()error('lost')end;step(41);assert(e.outputs['Tilt guard']==1 and e.outputs['Correction axis']==0)
print('Recovery waits during fast sliding and resumes when slow; missing position stops outputs')
