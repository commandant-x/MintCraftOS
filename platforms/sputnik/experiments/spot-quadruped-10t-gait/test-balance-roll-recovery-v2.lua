local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.roll=0
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return 0,0,e.roll end;e.getPosition=function()return 0,181,0 end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/balance-roll-recovery-v2.lua','t',e));local function step(t)e.time=t;run()end
step(0);e.values.Enable=1;step(1);for t=2,600 do step(t) end;e.roll=12;local ticks=0
for t=601,700 do step(t);if e.outputs['Correction axis']==7 then ticks=ticks+1;assert(e.outputs['RL roll clutch']==0 and e.outputs['RR roll clutch']==15) end end
assert(ticks==8,'four two-tick pulses expected');e.roll=0;step(701);e.roll=-12;step(702);assert(e.outputs['Correction axis']==7 and e.outputs['RL roll reverse']==0)
print('Roll-recovery experiment bounds four single-axis two-tick pulses and resets near level; physical benefit unproven')
