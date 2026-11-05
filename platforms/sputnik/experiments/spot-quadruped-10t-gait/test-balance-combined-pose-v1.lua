local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0
e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return 0,0,0 end;e.getPosition=function()return 0,181,0 end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/balance-combined-pose-v1.lua','t',e));local function step(t)e.time=t;run()end
local legs={'FL','FR','RL','RR'};local hip={};local knee={};step(0);e.values.Enable=1;step(1)
for t=2,800 do step(t);for _,leg in ipairs(legs) do
 assert(e.outputs[leg..' roll clutch']==15,leg..' lateral axis activated')
 if e.outputs[leg..' hip clutch']==0 then assert(e.outputs[leg..' knee clutch']==0);hip[leg]=(hip[leg] or 0)+1 end
 if e.outputs[leg..' knee clutch']==0 then knee[leg]=(knee[leg] or 0)+1 end
end end
for _,leg in ipairs(legs) do assert(hip[leg]==4 and knee[leg]==8,leg) end
e.getPosition=function()error('lost')end;step(801);for _,leg in ipairs(legs) do for _,joint in ipairs({'roll','hip','knee'}) do assert(e.outputs[leg..' '..joint..' clutch']==15) end end
print('Combined pose: lateral gates closed; hip pulses overlap knee pulses; physical support requires testing')
