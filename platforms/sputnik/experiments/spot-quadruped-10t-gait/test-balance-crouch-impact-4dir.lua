for _,delta in ipairs({{-0.2,0},{0.2,0},{0,-0.2},{0,0.2}}) do
 local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0;e.x=0;e.y=181;e.z=0
 e.input=function(n)return e.values[n] or 0 end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return e.x,e.y,e.z end;e.transmitWirelessRedstone=function()end
 local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/balance-crouch-impact-4dir.lua','t',e));local function step(t)e.time=t;run()end
 local knees={'FL knee','FR knee','RL knee','RR knee'};step(0);e.values.Enable=1;step(1)
 for t=2,600 do step(t) end
 assert(e.outputs['Correction axis']==0 and e.outputs.Emergency==0)
 e.x=e.x+delta[1];e.z=e.z+delta[2];step(601);step(602);step(603);step(604)
 for _,k in ipairs(knees) do assert(e.outputs[k..' clutch']==0,k) end
 for t=605,660 do step(t) end
 assert(e.outputs['Correction axis']==0)
 e.getPosition=function()error('lost')end;step(661);assert(e.outputs['Tilt guard']==1);for _,k in ipairs(knees) do assert(e.outputs[k..' clutch']==15) end
end
print('Horizontal motion in four directions triggers knee extension; recovery is single-shot and experimental')
