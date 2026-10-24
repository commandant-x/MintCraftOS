local Q=assert(loadfile('platforms/sputnik/src/quad_control.lua'))()
local k=assert(Q.filter(0,.0025,4))
for i=1,200 do assert(Q.update(k,i*.05,.05)) assert(k.a>=0 and k.c>=0) end
assert(math.abs(k.v-1)<.01,'Kalman constant velocity estimate failed')
assert(not Q.update(k,0/0,.05) and not Q.update(k,0,.6))
local rows={{8,4,12,.4,-8,8,8},{8,4,12,.4,-8,-8,8},{8,4,12,.4,8,8,8},{8,4,12,.4,8,-8,8}}
local model=assert(Q.model(rows))
local values,scale=Q.allocate(model,{.4,0,0})
local actual=0 for i,r in ipairs(rows) do actual=actual+r[4]*(values[i]-r[1]) end
assert(math.abs(actual-.4)<1e-8 and scale==1,'measured allocation changed requested vertical acceleration')
local inverted={} for i,r in ipairs(rows) do inverted[i]={8,4,12,-r[4],-r[5],-r[6],8} end
local inverseModel=assert(Q.model(inverted))
local invertedSignals=Q.allocate(inverseModel,{.4,0,0})
assert(invertedSignals[1]<8,'reversed transmission treated as increasing thrust')
assert(not Q.model({rows[1],rows[1],rows[1],rows[1]}),'rank deficient model accepted')
local pose={tick=100,x=0,y=80,z=0,pitch=0,yaw=0,roll=0,mass=100,dimension='minecraft:overworld'}
local core=assert(Q.new(rows,pose)) local v={x=0,y=0,z=0,pitch=0,roll=0}
local function step(command)
 pose.tick=pose.tick+1
 local signals,info=core:step(pose,command) assert(signals,info)
 local a={0,0,0}
 for i,r in ipairs(rows) do
  assert(signals[i]>=r[2] and signals[i]<=r[3] and signals[i]%1==0)
  for j=1,3 do a[j]=a[j]+r[j+3]*(signals[i]-r[1]) end
 end
 local p,r=math.rad(pose.pitch),math.rad(pose.roll)
 local thrust=(9.81+a[1])*100/pose.mass
 local acc={x=-math.sin(r)*thrust-.3*v.x,y=math.cos(r)*math.cos(p)*thrust-9.81-.2*v.y,z=math.sin(p)*math.cos(r)*thrust-.3*v.z,pitch=a[2]-.2*v.pitch,roll=a[3]-.2*v.roll}
 for _,axis in ipairs({'x','y','z','pitch','roll'}) do v[axis]=v[axis]+acc[axis]*.05 pose[axis]=pose[axis]+v[axis]*.05 end
 return info
end
local neutral={forward=0,left=0,vertical=0}
for _=1,100 do step(neutral) end
for _=1,20 do step({forward=0,left=0,vertical=1}) end
for _=1,400 do step(neutral) end
assert(math.abs(pose.y-81)<.2,'altitude target not held: '..pose.y)
local startZ=pose.z
for _=1,50 do step({forward=.5,left=0,vertical=0}) end
for _=1,500 do step(neutral) end
assert(pose.z>startZ+.5,'tilt did not move quad forward')
assert(math.abs(v.z)<.15 and math.abs(pose.y-81)<.25,'braking/altitude lost')
local startX=pose.x
for _=1,50 do step({forward=0,left=.5,vertical=0}) end
for _=1,500 do step(neutral) end
assert(pose.x<startX-.5 and math.abs(v.x)<.15,'strafe/braking failed')
pose.mass=90
local info=step(neutral) assert(info.massChanged and math.abs(core.target.y-81)<1e-9,'mass change swept/rescued instead of retaining target')
for _=1,600 do step(neutral) end
assert(math.abs(pose.y-81)<.25 and math.abs(v.y)<.15,'mass adaptation did not recover altitude')
assert(not core:step(pose,neutral),'duplicate timestamp accepted')
pose.tick=pose.tick+20 assert(not core:step(pose,neutral),'clock gap accepted')
print('Native quad: Kalman covariance/velocity, measured rank, integer bounded allocation, altitude capture, tilt forward/strafe/braking, mass change retaining altitude; simplified near-level physics only')
-- Native hardware adapter fixtures: no action before config and low-high gate.
_G.MintCraftQuad=nil
ui={label=function() return {setText=function(v) assert(type(v)=='string','native UI expects label text') end} end,checkbox=function() local c={value=false};c.isChecked=function() return c.value end;return c end,
 textfield=function() local c={value=''};c.getValue=function() return c.value end;c.setValue=function(v) c.value=v end;return c end,
 itempicker=function() local c={value='minecraft:air'};c.getItem=function() return c.value end;return c end}
addElement=function() end
local inputs={['Flight Enable']=15,['Commands valid']=1,['Forward demand']=0,['Left demand']=0,['Vertical demand']=0}
inputs['Enable binding']='minecraft:stone,minecraft:lever'
local keyBindings={} for i=1,6 do keyBindings[i]='minecraft:stone,minecraft:key_'..i end
inputs['Keyboard bindings']=table.concat(keyBindings,'|')
local outputs,sends={},{}
pose={tick=100,x=0,y=80,z=0,pitch=0,yaw=0,roll=0,mass=100,dimension='minecraft:overworld'}
getUniverseTime=function() return pose.tick end getShipMass=function() return pose.mass end
getPosition=function() return pose.x,pose.y,pose.z end getOrientation=function() return pose.pitch,pose.yaw,pose.roll end getDimension=function() return pose.dimension end
input=function(name) return inputs[name] or 0 end output=function(name,value) outputs[name]=value end
transmitWirelessRedstone=function(a,b,value) sends[#sends+1]={a,b,value} end
display=function() end
local node=assert(loadfile('platforms/sputnik/dist/mintcraft-quad-control.lua'))
local function tick() pose.tick=pose.tick+1;node() end
node() assert(#sends==0)
local s=_G.MintCraftQuad s.checked.value=true
for i,r in ipairs(s.rotors) do r.a.value='minecraft:stone';r.b.value='minecraft:item_'..i;r.row.value=table.concat(rows[i],',') end
tick() assert(#sends==0,'boot-high actuated rotors')
inputs['Flight Enable']=0 tick() tick() tick()
inputs['Flight Enable']=15 tick() assert(outputs.Active==1 and #sends==4)
tick() assert(outputs.Active==1 and #sends==8)
local old=s.owner.pairs[1][2];s.rotors[1].b.value='minecraft:new_item';tick()
assert(outputs.Active==0 and s.phase=='fault')
for i=#sends-3,#sends do assert(sends[i][3]==8,'fault stopped lift instead of explicit fallback') end
assert(sends[#sends-3][2]==old,'remap retargeted old fallback')
-- Enable held must not restart a faulted controller.
tick() assert(outputs.Active==0)
inputs['Flight Enable']=0 tick() tick() tick() inputs['Flight Enable']=15 tick() assert(outputs.Active==1)
pose.mass=0 tick() assert(outputs.Active==0,'lost server context kept active')
assert(outputs['Flight qualified']==0)
-- Cross-role collision is refused before any rotor command.
_G.MintCraftQuad=nil;sends={};pose.mass=100;inputs['Flight Enable']=0;node()
s=_G.MintCraftQuad;s.checked.value=true
for i,r in ipairs(s.rotors) do r.a.value='minecraft:stone';r.b.value=i==1 and 'minecraft:key_1' or 'minecraft:item_'..i;r.row.value=table.concat(rows[i],',') end
tick();tick();tick();inputs['Flight Enable']=15;tick()
assert(#sends==0 and outputs.Active==0,'keyboard frequency collision actuated rotor')
print('Native rotor adapter: four mapped Links, no boot action, physical low-high gate, measured fallback, frozen old mapping, latched fault/rearm and mass-context loss passed; no world flight proof')
-- Native automatic physical mode: blank measured rows, real API mass/inertia.
_G.MintCraftQuad=nil;sends={};pose.mass=65;inputs['Flight Enable']=0
getInertiaTensor=function() return 250,500,250 end
node();s=_G.MintCraftQuad;s.checked.value=true;s.physical.value=true
s.physicalFields.armX.value.value='3';s.physicalFields.armZ.value.value='3'
for i,r in ipairs(s.rotors) do r.a.value='minecraft:stone';r.b.value='minecraft:item_'..i;r.row.value='' end
tick();tick();tick();inputs['Flight Enable']=15;tick()
assert(outputs.Active==1 and #sends==4,'physical model required guessed measured fields')
assert(outputs['Maximum thrust']>outputs.Weight and outputs.Weight==715)
tick();pose.mass=60;tick()
assert(outputs.Active==1 and outputs.Weight==660,'mass/inertia did not update physical model')
s.physicalFields.armX.value.value='4';tick()
assert(outputs.Active==0,'physical geometry changed without requalification')
print('Native automatic physical mode: blank manual rows, API mass/inertia, density-derived trim, four real Link calls and mass update passed')
