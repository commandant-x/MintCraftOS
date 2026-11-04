local e=setmetatable({},{__index=_G});e._G=e;e.values={Enable=0,Start=0,['Terrain valid']=1,['Terrain obstacle']=0,['Terrain distance']=20,['Terrain lateral']=0,['Terrain sample tick']=0};e.outputs={};e.time=0
 e.input=function(k)return e.values[k] end;e.output=function(k,v)e.outputs[k]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return 0,0,0 end;e.getPosition=function()return 40,180,40 end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-obstacles/gait-bypass-experimental.lua','t',e));local function tick(t)e.time=t;e.values['Terrain sample tick']=t;run()end
local function closed()for _,l in ipairs({'FL','FR','RL','RR'}) do for _,a in ipairs({'roll','hip','knee'}) do assert(e.outputs[l..' '..a..' clutch']==15) end end end
tick(0);e.values.Enable=1;tick(1);e.values.Start=1;tick(2);assert(e.outputs.Running==1);e.values.Start=0;e.values['Terrain obstacle']=1;tick(3);assert(e.outputs['Bypass active']==1 and e.outputs['Bypass target x']==56 and e.outputs.Running==1)
e.values['Terrain distance']=6;tick(4);closed();assert(e.outputs['Terrain stop']==1 and e.outputs.Running==0);e.values['Terrain obstacle']=0;tick(5);closed();assert(e.outputs['Terrain stop']==1)
e.values.Enable=0;tick(6);e.values.Enable=1;tick(7);e.time=20;run();closed();assert(e.outputs['Terrain stop']==1)
print('Bypass control: lateral target, proximity stop, latching and stale sensor pass in Lua')
