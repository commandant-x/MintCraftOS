-- End-to-end NATIVE Lua nodes with old-output graph transfer. Synthetic world only.
local function read(path) local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local P=assert(loadfile('platforms/sputnik/src/aero_physics.lua'))()
local w={tick=100,x=0,y=80,z=0,pitch=0,roll=0,mass=65,ix=250,iz=250,bus={},writes={},rates={x=0,y=0,z=0,pitch=0,roll=0},rpm={}}
local function env(name,path)
 local e=setmetatable({},{__index=function(_,key)
  if type(key)=='string' and key:match('^MintCraft') then return nil end
  return _G[key]
 end});e._G=e;e.values={};e.outputs={}
 e.input=function(k) return e.values[k] or 0 end;e.output=function(k,v) e.outputs[k]=v end
 e.ui={label=function() return {setText=function(v) assert(type(v)=='string') end} end,
 checkbox=function() local c={v=false};c.isChecked=function() return c.v end;return c end,
 textfield=function() local c={v=''};c.getValue=function() return c.v end;c.setValue=function(v) c.v=v end;return c end,
 itempicker=function() local c={v='minecraft:air'};c.getItem=function() return c.v end;return c end}
 e.addElement=function() end;e.display=function() end
 e.getShipMass=function() return w.mass end;e.getInertiaTensor=function() return w.ix,500,w.iz end
 e.getPosition=function() return w.x,w.y,w.z end;e.getOrientation=function() return w.pitch,0,w.roll end
 e.getVelocity=function() return w.rates.x,w.rates.y,w.rates.z end
 e.getUniverseTime=function() return w.tick end;e.getDimension=function() return 'minecraft:overworld' end
 e.receiveWirelessRedstone=function(a,b) return w.bus[a..','..b] or 0 end
 e.transmitWirelessRedstone=function(a,b,value)
  assert(name=='quad','read-only node issued an actuator request')
  assert(value%1==0 and value>=0 and value<=15)
  w.bus[a..','..b]=value;w.writes[#w.writes+1]={a,b,value}
 end
 e.run=assert(load(read(path),name,'t',e));e.run();return e
end
local consent=env('consent','platforms/sputnik/dist/mintcraft-test-enable.lua')
local keyboard=env('keyboard','platforms/sputnik/dist/mintcraft-typewriter.lua')
local quad=env('quad','platforms/sputnik/dist/mintcraft-quad-control.lua')
local audit=env('audit','platforms/sputnik/dist/mintcraft-flight-telemetry.lua')
consent.MintCraftConsent.a.v='minecraft:pink_wool';consent.MintCraftConsent.b.v='minecraft:pink_wool'
local enable='minecraft:pink_wool,minecraft:pink_wool'
-- Native adapter converts physical strength to permission, not throttle.
for strength=1,15 do
 w.bus[enable]=strength;consent.run();assert(consent.outputs.Enable==1,'consent leaked analog strength')
end
for _,strength in ipairs({0,.5,16,-1}) do
 w.bus[enable]=strength;consent.run();assert(consent.outputs.Enable==0,'invalid consent accepted')
end
w.bus[enable]=0;consent.run()
local keyNames={'W','S','Q','D','Space','Shift'}
local keyItems={'blue_wool','orange_wool','lime_wool','red_wool','white_wool','black_wool'}
local keyChannels={}
for i,name in ipairs(keyNames) do
 local k=keyboard.MintCraftTypewriter.keys[name];k.a.v='minecraft:stick';k.b.v='minecraft:'..keyItems[i]
 keyChannels[name]=k.a.v..','..k.b.v
end
keyboard.MintCraftTypewriter.verified.v=true
local qs=quad.MintCraftQuad;qs.checked.v=true;qs.physical.v=true
qs.physicalFields.armX.value.v='3';qs.physicalFields.armZ.value.v='3'
local rotorItems={'iron_ingot','copper_ingot','gold_ingot','diamond'};local rotorChannels={}
for i,r in ipairs(qs.rotors) do r.a.v='minecraft:paper';r.b.v='minecraft:'..rotorItems[i];rotorChannels[i]=r.a.v..','..r.b.v end
local spec={source=256,thrust=1,airflow=.1,armX=3,armZ=3,height=0,gravity=11}
local function snapshot(e) local out={} for k,v in pairs(e.outputs) do out[k]=v end return out end
local function step()
 w.tick=w.tick+1
 local c,k,q=snapshot(consent),snapshot(keyboard),snapshot(quad)
 consent.values={}
 keyboard.values={Enable=c.Enable}
 quad.values={['Flight Enable']=c.Enable,['Enable binding']=c.Binding,['Keyboard bindings']=k.Bindings,['Commands valid']=k['Commands valid'],['Forward demand']=k['Forward demand'],['Left demand']=k['Left demand'],['Vertical demand']=k['Vertical demand']}
 audit.values={['Controller active']=q.Active,['Target altitude']=q['Target altitude'],['Keyboard valid']=k['Commands valid'],['Forward demand']=k['Forward demand'],['Left demand']=k['Left demand'],['Vertical demand']=k['Vertical demand']}
 consent.run();keyboard.run();quad.run();audit.run()
 if quad.outputs.Active~=1 then return end
 local force,mx,mz=0,0,0;local p,r=math.rad(w.pitch),math.rad(w.roll)
 local up={-math.sin(r),math.cos(p)*math.cos(r),math.sin(p)*math.cos(r)}
 for i,loc in ipairs({{-3,3},{3,3},{-3,-3},{3,-3}}) do
  local signal=assert(w.bus[rotorChannels[i]],'rotor request missing')
  local target=signal==0 and 256 or 256*(15-signal)/16
  w.rpm[i]=w.rpm[i] or w.mass*11/(4*P.pressure(w.y))
  w.rpm[i]=w.rpm[i]+.15*(target-w.rpm[i])
  local axial=w.rates.x*up[1]+w.rates.y*up[2]+w.rates.z*up[3]+math.rad(w.rates.roll)*loc[1]-math.rad(w.rates.pitch)*loc[2]
  local pressure=P.pressure(w.y+loc[1]*math.sin(r)*math.cos(p)-loc[2]*math.sin(p))
  local airflow=.1*w.rpm[i]
  local f=airflow>0 and w.rpm[i]*pressure*math.max(0,math.min(1,(airflow-axial)/airflow)) or 0
  force=force+f;mx=mx-loc[2]*f;mz=mz+loc[1]*f
 end
 local accel={x=up[1]*force/w.mass-.3*w.rates.x,y=up[2]*force/w.mass-11-.2*w.rates.y,z=up[3]*force/w.mass-.3*w.rates.z,pitch=math.deg(mx/w.ix)-.2*w.rates.pitch,roll=math.deg(mz/w.iz)-.2*w.rates.roll}
 for _,key in ipairs({'x','y','z','pitch','roll'}) do w.rates[key]=w.rates[key]+accel[key]*.05;w[key]=w[key]+w.rates[key]*.05 end
end
for _=1,8 do step() end
assert(#w.writes==0,'unarmed graph emitted rotor commands')
w.bus[enable]=15
for _=1,10 do step() end
assert(quad.outputs.Active==1 and keyboard.outputs['Commands valid']==1,'complete graph did not activate: '..tostring(quad.outputs.Status))
assert(consent.outputs.Enable==1 and w.bus[enable]==15,'physical ON strength was not isolated from controller permission')
assert(audit.outputs.Mass==65 and audit.outputs['Inertia X']==250 and audit.outputs['Inertia Y']==500 and audit.outputs['Pose valid']==1,'audit lost native mass/inertia')
assert(type(audit.outputs['Horizontal speed'])=='number','native horizontal speed missing from audit')
local start=w.y;local initialTarget=quad.outputs['Target altitude']
w.bus[keyChannels.Space]=15
for _=1,40 do step() end
assert(quad.outputs['Target altitude']>initialTarget+1.5,'Space lost between receiver, graph inputs and controller')
assert(audit.outputs.Telemetry:find('Y=1.0',1,true),'live input was hidden in audit')
w.bus[keyChannels.Space]=0
for _=1,500 do step() end
assert(math.abs(w.y-(start+2))<.3,'complete graph did not climb and hold')
w.bus[keyChannels.W]=15
for _=1,40 do step() end
assert(audit.outputs.Telemetry:find('F=1.0',1,true))
w.bus[keyChannels.W]=0
for _=1,500 do step() end
assert(w.z>.3 and math.abs(w.rates.z)<.2,'complete graph did not advance/brake')
w.mass=60;w.ix=230;w.iz=230
for _=1,500 do step() end
assert(audit.outputs.Mass==60 and audit.outputs['Inertia X']==230,'live mass/inertia were frozen')
assert(math.abs(w.y-(start+2))<.3,'graph lost altitude after mass update')
-- Disconnecting a diagnostic input cannot certify its unseen value.
audit.values['Keyboard valid']=0;audit.run();assert(audit.outputs.Telemetry:find('K=0.0',1,true))
print('Complete quad graph: native enable/6-key receiver/controller/audit, one-tick propagation, Space changing target and lift, W changing motion, braking/hold, live mass/inertia update; synthetic radio/physics only')

-- Missing telemetry remains unknown, not a made-up positive mass.
w.mass=0;audit.run();assert(audit.outputs.Mass==0 and audit.outputs['Pose valid']==0)
audit.getInertiaTensor=function() error('sensor unavailable') end
audit.run();assert(audit.outputs.Telemetry:find('Ixyz=?/?/?',1,true) and audit.outputs['Pose valid']==0)
