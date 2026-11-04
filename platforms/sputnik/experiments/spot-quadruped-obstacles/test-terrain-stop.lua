local env=setmetatable({},{__index=_G});env._G=env;env.values={Enable=0,Start=0,['Terrain valid']=1,['Terrain obstacle']=0,['Terrain sample tick']=0};env.outputs={};env.time=0
local e=env;e.input=function(k)return e.values[k] end;e.output=function(k,v)e.outputs[k]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return 0,0,0 end;e.getPosition=function()return 0,180,0 end;e.transmitWirelessRedstone=function()end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped-obstacles/gait-terrain-stop.lua','t',e));local function tick(t)e.time=t;e.values['Terrain sample tick']=t;run()end
local function closed()for _,l in ipairs({'FL','FR','RL','RR'}) do for _,a in ipairs({'roll','hip','knee'}) do assert(e.outputs[l..' '..a..' clutch']==15) end end end
tick(0);e.values.Enable=1;tick(1);e.values.Start=1;tick(2);assert(e.outputs.Running==1);e.values.Start=0;tick(3);e.values['Terrain obstacle']=1;tick(4);closed();assert(e.outputs['Terrain stop']==1 and e.outputs.Running==0)
e.values['Terrain obstacle']=0;tick(5);closed();assert(e.outputs['Terrain stop']==1)
e.values.Enable=0;tick(6);assert(e.outputs['Terrain stop']==0);e.values.Enable=1;tick(7);e.values.Start=1;tick(8);assert(e.outputs.Running==1);e.values.Start=0;e.time=20;run();closed();assert(e.outputs['Terrain stop']==1 and e.outputs['Terrain fresh']==0)
e.values.Enable=0;tick(21);e.values['Terrain valid']=0;e.values.Enable=1;tick(22);closed();assert(e.outputs['Terrain stop']==1)
print('Terrain stop: obstacle, stale or invalid scan closes all gates and latches until disarm')
