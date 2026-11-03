for _,cycle in ipairs({40,24,20,16,12}) do
 local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0,Start=0};e.outputs={};e.time=0;e.pitch=0;e.yaw=0;e.roll=0
 e.input=function(n)return e.values[n] end;e.output=function(n,v)e.outputs[n]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return 40,181,42 end;e.transmitWirelessRedstone=function()end
 local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-10t-gait/course25-'..cycle..'tick.lua','t',e));local function step(t)e.time=t;run()end
 local names={'FL roll','FL hip','FL knee','FR roll','FR hip','FR knee','RL roll','RL hip','RL knee','RR roll','RR hip','RR knee'};local pulses={}
 step(0);e.values.Enable=1;step(1);e.values.Start=1;step(2);e.values.Start=0
 for t=3,501 do step(t);local active=0;for _,n in ipairs(names) do if e.outputs[n..' clutch']==0 then active=active+1;pulses[n]=(pulses[n] or 0)+1 end end;assert(active<=1) end
 for _,leg in ipairs({'FL','FR','RL','RR'}) do assert((pulses[leg..' hip'] or 0)>0 and (pulses[leg..' knee'] or 0)>0 and not pulses[leg..' roll']) end
 step(502);assert(e.outputs.Running==0);for _,n in ipairs(names) do assert(e.outputs[n..' clutch']==15) end
 e.values.Enable=0;step(503);e.values.Enable=1;step(504);e.values.Start=1;step(505);e.values.Start=0;e.pitch=13;step(506);assert(e.outputs['Tilt guard']==1 and e.outputs.Running==0);for _,n in ipairs(names) do assert(e.outputs[n..' clutch']==15) end
 print('cycle '..cycle..': 500-tick schedule, one axis at a time and tilt guard pass')
end
