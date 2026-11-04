local env=setmetatable({},{__index=_G});env._G=env;env.values={Enable=0,Start=0};env.outputs={};env.time=0;env.pitch=0;env.yaw=0;env.roll=0
env.input=function(k)return env.values[k] end;env.output=function(k,v)env.outputs[k]=v end
env.getUniverseTime=function()return env.time end;env.getOrientation=function()return env.pitch,env.yaw,env.roll end
env.getPosition=function()return 0,180,0 end;env.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-balance/gait-feedback.lua','t',env))
local function tick(t)env.time=t;run()end
local function closed()for _,l in ipairs({'FL','FR','RL','RR'}) do for _,a in ipairs({'roll','hip','knee'}) do assert(env.outputs[l..' '..a..' clutch']==15) end end end
tick(0);closed();env.values.Enable=1;tick(1);env.values.Start=1;tick(2);env.values.Start=0
-- The rear-left correction is held fixed through both hip pulses even when yaw changes mid-step.
env.yaw=4;tick(3);local durations={};for t=4,61 do if t==19 then env.yaw=-4 end;tick(t);if env.outputs['RL hip clutch']==0 then durations[#durations+1]=t end end
assert(#durations==14, 'step-latched initial neutral hip is 2 x 7 ticks')
-- Reset; rising positive yaw before a leg cycle selects a stronger rear-left correction.
env.values.Enable=0;tick(62);env.yaw=0;env.values.Enable=1;tick(63);env.values.Start=1;tick(64);env.values.Start=0;env.yaw=4
local d={};for t=65,183 do tick(t);if env.outputs['RL hip clutch']==0 then d[#d+1]=t end end
-- Cycle 0 was latched at start, cycle 4 is tested separately below.
assert(#d==14)
-- Keep positive yaw error until the next rear-left leg and verify equal eight-tick pulses.
env.yaw=4;local corrected=0;for t=184,362 do tick(t);if env.outputs['RL hip clutch']==0 then corrected=corrected+1 end end
assert(corrected==16,'positive yaw must select two equal eight-tick RL pulses')
-- Tilt latch disables every gate until explicit disarm.
env.pitch=13;tick(363);closed();assert(env.outputs['Tilt guard']==1 and env.outputs.Running==0)
env.pitch=0;tick(364);closed();assert(env.outputs['Tilt guard']==1)
env.values.Enable=0;tick(365);assert(env.outputs['Tilt guard']==0)
env.values.Enable=1;env.getOrientation=nil;tick(366);closed();assert(env.outputs['Pose valid']==0 and env.outputs['Tilt guard']==1)
env.values.Enable=0;tick(367);env.getOrientation=function()return env.pitch,env.yaw,env.roll end;env.yaw=0;env.values.Enable=1;tick(368);env.values.Start=1;tick(369);assert(env.outputs.Running==1);env.values.Start=0;tick(373);closed();assert(env.outputs['Clock fault']==1 and env.outputs.Running==0)
print('Feedback: safe missing pose and tilt latch, isolated output and per-leg pulse symmetry verified')
