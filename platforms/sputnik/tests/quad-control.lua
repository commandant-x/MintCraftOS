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
-- Failed prerequisites must report the actual condition, without actuator writes.
_G.MintCraftQuad=nil;sends={};pose.mass=65;inputs['Flight Enable']=0
node();s=_G.MintCraftQuad
assert(outputs.Status:find('CONFIRM',1,true),'missing confirmation hidden behind generic message')
s.checked.value=true;s.physical.value=true
s.physicalFields.armX.value.value='2';s.physicalFields.armZ.value.value='3';s.physicalFields.height.value.value='2'
for i,r in ipairs(s.rotors) do r.a.value='minecraft:stone';r.b.value='minecraft:item_'..i;r.row.value='' end
tick()
local oldEnable=inputs['Enable binding'];inputs['Enable binding']='';tick()
assert(outputs.Status:find('ENABLE_BIND',1,true))
inputs['Enable binding']=oldEnable
local oldKeys=inputs['Keyboard bindings'];inputs['Keyboard bindings']='';tick()
assert(outputs.Status:find('KEY_COUNT: 0/6',1,true))
inputs['Keyboard bindings']=oldKeys
s.rotors[1].b.value='minecraft:key_1';tick()
assert(outputs.Status:find('DUP_1',1,true),'cross-role collision reason lost')
s.rotors[1].b.value='minecraft:air';tick();assert(outputs.Status:find('ROTOR_1',1,true))
s.rotors[1].b.value='minecraft:item_1'
s.noise.value='';tick();assert(outputs.Status:find('PARAM_noise',1,true))
s.noise.value='.0025';s.physicalFields.armX.value.value='';tick()
assert(outputs.Status:find('PHYS_armX',1,true))
s.physicalFields.armX.value.value='2';tick();tick();tick()
inputs['Flight Enable']=15;inputs['Commands valid']=1;inputs['Vertical demand']=1;tick()
assert(outputs.Status:find('KEYS_HELD',1,true))
assert(#sends==0,'diagnostics bypassed activation guards')
inputs['Commands valid']=0;tick()
assert(outputs.Active==1,'keyboard readiness blocked neutral stabilisation')
assert(outputs['Target altitude']==pose.y,'neutral stabilisation did not capture altitude')
_G.MintCraftQuad=nil;pose.mass=0;node()
assert(outputs.Status:find('MASS:',1,true),'missing mass silently hid Status output')
print('Detailed refusal diagnostics: confirmation, missing typed bindings, collisions, fields, held key and absent server mass; invalid movement commands allow neutral stabilisation')
-- Regression: after a real control failure, high Enable must not hide it as BASELINE.
_G.MintCraftQuad=nil;pose.mass=65;pose.pitch=0;pose.roll=0;inputs['Flight Enable']=0;inputs['Commands valid']=1;inputs['Vertical demand']=0
node();s=_G.MintCraftQuad;s.checked.value=true;s.physical.value=true
s.physicalFields.armX.value.value='3';s.physicalFields.armZ.value.value='3'
for i,r in ipairs(s.rotors) do r.a.value='minecraft:stone';r.b.value='minecraft:item_'..i;r.row.value='' end
tick();tick();tick();inputs['Flight Enable']=15;tick();tick()
assert(outputs.Active==1)
local targetBeforeFault=outputs['Target altitude']
pose.pitch=30;tick()
local firstFault=outputs.Status
assert(firstFault:find('Near-level attitude envelope exceeded',1,true) and firstFault:find('pitch=30.0',1,true))
assert(outputs.Active==0 and outputs['Last fault']==firstFault)
pose.pitch=0
for _=1,6 do tick();assert(outputs.Status==firstFault and outputs.Active==0,'failure was hidden as BASELINE/rearmed itself') end
assert(outputs['Target altitude']==targetBeforeFault and outputs.Weight==715,'failure erased last target/weight diagnostics')
-- Further faults cannot destroy the original evidence.
s.rotors[1].b.value='minecraft:key_1';tick();assert(outputs.Status==firstFault)
s.rotors[1].b.value='minecraft:item_1';tick();assert(outputs.Status==firstFault)
inputs['Flight Enable']=0;tick();tick();tick()
assert(outputs['Last fault']=='' and s.phase=='ready','explicit low rearm did not clear acknowledged failure')
inputs['Flight Enable']=15;tick();assert(outputs.Active==1)
print('Failure latch regression: original attitude error and measurements survive held-high Enable, later faults and BASELINE logic; explicit low rearm clears it; prior target/weight retained')
-- Disarm must work after configuration/model failure; no restart required.
pose.pitch=30;tick();assert(outputs.Active==0 and outputs.Status:find('FAULT:',1,true))
s.physicalFields.source.value.value='0' -- invalid model after the incident
inputs['Flight Enable']=0;tick();tick();tick()
assert(s.fault==nil and outputs['Last fault']=='' and outputs.Active==0,'invalid model trapped fault acknowledgment')
assert(outputs.Status:find('MODEL',1,true),'bad configuration was silently armed')
local stoppedOwner=s.owner
for i=1,4 do assert(sends[#sends-4+i][3]==stoppedOwner.rows[i][7],'disarm abandoned measured fallback') end
-- Fix configuration with authority OFF. Remaining tilt is a wait, not a new fault.
s.physicalFields.source.value.value='256';tick();tick();tick()
inputs['Flight Enable']=15;tick()
assert(outputs.Active==0 and s.fault==nil and outputs.Status:find('LEVEL_WAIT:',1,true),'tilted recovery required another fault/restart')
pose.pitch=0;tick();assert(outputs.Active==1,'level/neutral recovery failed without script restart')
print('Recovery regression: explicit low acknowledges fault despite invalid model, frozen fallback stays refreshed, invalid configuration cannot arm, tilted aircraft waits for level then rearms without a script restart')

receiveWirelessRedstone=function() return 15 end
tick();assert(outputs.Active==1 and outputs.Status:find('RADIO_1:',1,true),'stronger competing TX not exposed')
receiveWirelessRedstone=function() return 0 end
tick();assert(not outputs.Status:find('RADIO_',1,true),'stale radio warning not cleared')
print('Competing TX diagnostic: stronger network strength reported as a warning, never treated as physical ACK and never bypasses control guards')

-- Permission amplitude must never become a motor command. Pure level descent
-- on a symmetric quad must request collective lift, even without a ready keyboard.
local function permissionTrace(strength)
 _G.MintCraftQuad=nil;sends={};outputs={}
 pose={tick=100,x=0,y=80,z=0,pitch=0,yaw=0,roll=0,mass=65,dimension='minecraft:overworld'}
 inputs['Flight Enable']=0;inputs['Commands valid']=0
 -- Invalid keyboard values are ignored rather than mixed into lift/attitude.
 inputs['Forward demand']=1;inputs['Left demand']=-1;inputs['Vertical demand']=1
 node();s=_G.MintCraftQuad;s.checked.value=true;s.physical.value=true
 s.physicalFields.armX.value.value='3';s.physicalFields.armZ.value.value='3'
 for i,r in ipairs(s.rotors) do r.a.value='minecraft:stone';r.b.value='minecraft:item_'..i;r.row.value='' end
 tick();tick();tick();inputs['Flight Enable']=strength;tick()
 assert(outputs.Active==1 and outputs['Target altitude']==80,'permission did not start neutral hold')
 local trace,first,last={},0,0
 for n=1,60 do
  pose.y=pose.y-.03;tick()
  assert(outputs.Active==1,'level descent stopped stabilisation')
  local base=#sends-3
  for i=1,4 do
   local signal=sends[base+i-1][3]
   assert(signal==sends[base][3],'level descent introduced asymmetric rotor commands')
   trace[#trace+1]=signal
   if n<=10 then first=first+signal end
   if n>50 then last=last+signal end
  end
 end
 assert(last<first,'falling quad did not request more collective thrust (lower signals)')
 assert(outputs['Target altitude']==80,'missing keyboard changed altitude target')
 inputs['Commands valid']=1;inputs['Forward demand']=0;inputs['Left demand']=0;inputs['Vertical demand']=1
 tick();assert(outputs['Target altitude']>80,'keyboard did not take over target movement after neutral hold')
 return table.concat(trace,',')
end
local reference=permissionTrace(1)
for strength=2,15 do assert(permissionTrace(strength)==reference,'Enable strength scaled rotor control') end
print('Binary permission regression: strengths 1..15 produce identical motor traces; no ready keyboard still holds altitude; level descent increases all four rotors together; valid Space later changes target')
