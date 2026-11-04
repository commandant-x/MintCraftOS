local function test(name,count)
 local e=setmetatable({},{__index=_G});e._G=e;e.tick=100;e.values={Enable=0,Forward=1,['Ticks per phase']=10};e.outputs={}
 e.input=function(k)return e.values[k] end;e.output=function(k,v)e.outputs[k]=v end;e.getUniverseTime=function()return e.tick end
 e.ui={label=function()return {setText=function()end}end};e.addElement=function()end
 local run=assert(loadfile('platforms/sputnik/experiments/walkers/'..name..'.lua','t',e))
 local function step(n)for i=1,n do e.tick=e.tick+1;run() end end
 local function legs()return e.outputs['Leg 1 swing']+e.outputs['Leg 2 swing']+e.outputs['Leg 3 swing']+e.outputs['Leg 4 swing'] end
 step(1);assert(e.outputs.Active==0 and legs()==0)
 e.values.Enable=1;step(1);assert(e.outputs.Active==1 and e.outputs['Leg 1 swing']==1)
 for i=2,count do step(10);assert(e.outputs['Leg '..i..' swing']==1 and legs()==1) end
 step(10);assert(e.outputs['Leg 1 swing']==1)
 e.values.Forward=-1;step(10);assert(e.outputs['Leg '..count..' swing']==1)
 e.values.Forward=0;step(1);assert(legs()==0)
 e.values.Forward=1;e.tick=e.tick+2;run();assert(e.outputs.Active==0 and legs()==0)
 step(1);assert(e.outputs.Active==0,'gap must require OFF')
 e.values.Enable=0;step(1);e.values.Enable=1;step(1);assert(e.outputs.Active==1)
 e.values['Ticks per phase']=0/0;step(1);assert(e.outputs.Active==0 and legs()==0)
 assert(e.outputs['Walk qualified']==0)
end
test('bipede',2);test('quadrupede',4)
print('Gait phase: fresh ticks, OFF rearm, forward/reverse sequencing and fault inhibit passed; no physical gait test')
