local cases={{'balance-step-west-inverse.lua',1},{'balance-step-west-inverse-two.lua',2},{'balance-step-west-inverse-three.lua',3},{'balance-step-west-inverse-five.lua',5}}
for _,case in ipairs(cases) do
 local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0;e.x=0;e.y=181;e.z=0
 e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return e.x,e.y,e.z end;e.transmitWirelessRedstone=function()end
 local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/'..case[1],'t',e));local function step(t)e.time=t;run()end
 step(0);e.values.Enable=1;step(1);e.x=-.2;step(2);local active=0
 for t=3,150 do step(t);if e.outputs['FL roll clutch']==0 then active=active+1;assert(e.outputs['RL roll clutch']==0 and e.outputs['FL roll reverse']==15 and e.outputs['RL roll reverse']==0) end end
 assert(active==case[2]*2,case[1]..' actual='..active)
end
print('West-response one-, two-, three-, and five-pulse schedules verified; physical outcomes remain experimental')
