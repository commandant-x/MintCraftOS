local env=setmetatable({},{__index=_G});env._G=env;env.values={Enable=0,Start=0};env.outputs={};env.time=0
env.input=function(k)return env.values[k] end
env.output=function(k,v)env.outputs[k]=v end
env.getUniverseTime=function()return env.time end
local run=assert(loadfile('platforms/sputnik/experiments/spot-quadruped/controller/gait-node.lua','t',env))
local legs={'FL','FR','RL','RR'};local axes={'roll','hip','knee'}
local function closed()
 for _,leg in ipairs(legs) do for _,axis in ipairs(axes) do assert(env.outputs[leg..' '..axis..' clutch']==15) end end
end
run();closed();assert(env.outputs.Running==0)
env.values.Enable=1;env.values.Start=1;run();assert(env.outputs.Running==1)
env.values.Start=0
local activations={FL={hip=0,knee=0},FR={hip=0,knee=0},RL={hip=0,knee=0},RR={hip=0,knee=0}}
local order={'RL','FR','FL','RR'}
for t=1,959 do
 env.time=t;run();local active=0
 for _,leg in ipairs(legs) do for _,axis in ipairs(axes) do
  local v=env.outputs[leg..' '..axis..' clutch'];assert(v==0 or v==15)
  if v==0 then active=active+1;assert(axis~='roll');activations[leg][axis]=activations[leg][axis]+1 end
 end end
 assert(active<=1)
 local cycle=math.floor(t/120);local phase=t%120;local leg=order[cycle%4+1]
 if phase==10 or phase==56 then assert(env.outputs[leg..' knee clutch']==0) end
 if phase==30 or phase==76 then assert(env.outputs[leg..' hip clutch']==0) end
 local initial=(leg=='FL' or leg=='RR') and 15 or 0
 if phase==10 then assert(env.outputs['Common reverse']==initial) end
 if phase==56 then assert(env.outputs['Common reverse']==15-initial) end
end
for _,leg in ipairs(legs) do assert(activations[leg].knee==40 and activations[leg].hip==24) end
env.time=960;run();closed();assert(env.outputs.Running==0)
env.values.Start=1;env.time=961;run();assert(env.outputs.Running==1)
env.values.Start=0;env.time=962;run();assert(env.outputs.Running==1)
env.values.Start=1;env.time=966;run();closed();assert(env.outputs.Running==0 and env.outputs['Clock fault']==1)
env.values.Enable=0;env.time=967;run();closed()
print('Sputnik prototype: 8 sequential leg cycles, isolated gates, stop and clock-gap behavior OK; no hardware test')
