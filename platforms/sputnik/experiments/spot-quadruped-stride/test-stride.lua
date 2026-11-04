local dir='platforms/sputnik/experiments/spot-quadruped-stride/'
for _,f in ipairs({{'lane-16rpm.lua',240},{'lane-24rpm.lua',160}}) do for _,state in ipairs({{-4,0},{0,0},{4,0},{0,4},{0,-4}}) do
 local e=setmetatable({},{__index=_G});e._G=e;e.value={Enable=0,Start=0};e.out={};e.time=0;e.yaw=0;e.pitch=0;e.roll=0;e.x=0
 e.input=function(k)return e.value[k] end;e.output=function(k,v)e.out[k]=v end;e.getUniverseTime=function()return e.time end;e.getOrientation=function()return e.pitch,e.yaw,e.roll end;e.getPosition=function()return e.x,180,0 end;e.transmitWirelessRedstone=function()end
 local run=assert(loadfile(dir..f[1],'t',e));local function tick(t)e.time=t;run()end
 tick(0);e.value.Enable=1;tick(1);e.value.Start=1;tick(2);e.value.Start=0;e.yaw=state[1];e.x=state[2]
 local count={};local legs={'FL','FR','RL','RR'};local axes={'hip','knee'}
 for _,l in ipairs(legs) do for _,a in ipairs(axes) do count[l..a]={last=false,groups={}} end end
 for t=3,2+f[2] do
  tick(t);local active=0
  for _,l in ipairs(legs) do for _,a in ipairs(axes) do local k=l..a;local q=count[k];local on=e.out[l..' '..a..' clutch']==0;if on then active=active+1;if not q.last then q.groups[#q.groups+1]=0 end;q.groups[#q.groups]=q.groups[#q.groups]+1 end;q.last=on end end
  assert(active<=1,'multiple gates active')
 end
 for k,q in pairs(count) do assert(#q.groups==4,f[1]..' '..k..' missed pulse');assert(q.groups[1]==q.groups[2] and q.groups[3]==q.groups[4],f[1]..' '..k..' asymmetry') end
 assert(math.abs(e.out['Lane error']-state[2])<0.001)
 e.pitch=13;tick(3+f[2]);assert(e.out['Tilt guard']==1 and e.out.Running==0)
end end
print('Lane control: isolated axes, matched pulses, measured position and tilt guard pass in Lua')
