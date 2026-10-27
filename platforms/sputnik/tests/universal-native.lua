-- Actual generated native adapter: ownership, replay, hot commands and stop gates.
local function read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function field(v) local s={v=v};s.getValue=function() return s.v end;s.setValue=function(x) s.v=x end;s.setText=s.setValue;return s end
local state={tick=100,mass=32,y=80,bus={['minecraft:stone,minecraft:lever']=15},writes={}}
local e=setmetatable({},{__index=function(_,k) if type(k)=='string' and k:match('^MintCraft') then return nil end;return _G[k] end});e._G=e;e.values={};e.outputs={}
e.ui={label=field,textfield=function() return field('') end};e.addElement=function() end;e.display=function() end
e.input=function(k) return e.values[k] or 0 end;e.output=function(k,v) e.outputs[k]=v end
e.getUniverseTime=function() return state.tick end;e.getShipMass=function() return state.mass end;e.getPosition=function() return 0,state.y,0 end;e.getOrientation=function() return 0,0,0 end;e.getInertiaTensor=function() return 250,400,230 end;e.getDimension=function() return 'minecraft:overworld' end
e.receiveWirelessRedstone=function(a,b) return state.bus[a..','..b] or 0 end
e.transmitWirelessRedstone=function(a,b,v) assert(v%1==0 and v>=0 and v<=15);state.writes[#state.writes+1]={a,b,v} end
local source=read('platforms/sputnik/dist/mintcraft-autopilot-control.lua')
local run=assert(load(source,'native-writer','t',e));run()
local B=assert(load(source..'\nreturn {Vehicle=_G.MintCraftFlightModules[7],Portable=_G.MintCraftFlightModules[1]}','native-tools','t',e))()
local defs=assert(load(read('platforms/sputnik/src/vehicle_model.lua'),'defs','t',{Portable=B.Portable,math=math,type=type,ipairs=ipairs,pairs=pairs,tostring=tostring,tonumber=tonumber}))()
e.values.Settings='MCU1;1;11;1;8;8;1;1;1;0';e.values['Enable binding']='minecraft:stone,minecraft:lever';e.values['Keyboard bindings']='';e.values.Enable=1
for i=1,4 do local g=defs.defaults(1,i);g.powerA='minecraft:paper';g.powerB='minecraft:rotor_'..i;e.values['Group '..i]=B.Vehicle.encode(g) end
local function tick() local values={};for i=1,4 do values[#values+1]=e.values['Group '..i] end;e.values['Groups A']=table.concat(values,'\n');state.tick=state.tick+1;run() end
e.values.Enable=0;tick();tick();assert(#state.writes==0,'cached OFF authorized boot-high physical Enable')
e.values.Enable=1;tick();assert(#state.writes==0,'boot-high armed native writer')
e.values.Enable=0;state.bus['minecraft:stone,minecraft:lever']=0;tick();tick();e.values.Enable=1;state.bus['minecraft:stone,minecraft:lever']=15;tick();assert(e.outputs.Active==1)
local owner=e.MintCraftPilot.owner;local core=e.MintCraftPilot.core;local filter=core.filters.y
e.values.Request='MCC1|1|ALTITUDE|81|0|0||';tick()
assert(core.target.y==81 and e.outputs['Acknowledged revision']==1 and core.filters.y==filter,'hot target reset live controller')
e.values.Request='MCC1|0|ALTITUDE|99|0|0||';tick();assert(core.target.y==81,'replayed request changed target')
local old=e.values['Group 1'];local changed=assert(B.Vehicle.decode(old));changed.powerB='minecraft:other';e.values['Group 1']=B.Vehicle.encode(changed);tick()
assert(e.MintCraftPilot.owner==owner and e.MintCraftPilot.core==core,'editing draft replaced flight owner')
for i=#state.writes-3,#state.writes do assert(state.writes[i][2]~='minecraft:other','draft retargeted active outputs') end
-- A new Enable mapping also stays a draft until physical OFF on the old mapping.
e.values['Enable binding']='minecraft:stone,minecraft:new_lever';e.values.Enable=0;tick();assert(e.outputs.Active==1,'draft Enable became live')
state.bus['minecraft:stone,minecraft:lever']=0;tick();tick();assert(e.outputs.Active==0)
e.values.Enable=1;tick();assert(e.outputs.Active==0,'remapping abandoned old fallback without confirmation')
e.values['Enable binding']='minecraft:stone,minecraft:lever';e.values['Group 1']=old;e.values.Enable=0;tick();tick()
state.bus['minecraft:stone,minecraft:lever']=15;e.values.Enable=1;tick();assert(e.outputs.Active==1)
assert(e.outputs['Acknowledged revision']==0 and e.MintCraftPilot.core.target.y==state.y,'old request auto-restored after rearm')
e.values['Mechanical cut']=1;tick();assert(e.outputs.Active==0)
for i=#state.writes-3,#state.writes do assert(state.writes[i][3]==15,'mechanical prop cut did not stop') end
e.values['Mechanical cut']=0;tick();assert(e.outputs.Active==0,'cut release rearmed without OFF')
local count=#state.writes
for _=1,25 do tick() end
assert(#state.writes>=count+25*4,'cut/fallback expired without refresh')
for i=#state.writes-3,#state.writes do assert(state.writes[i][3]==15,'cut latch dropped to full-RPM expiry') end
e.values.Enable=0;state.bus['minecraft:stone,minecraft:lever']=0;tick();tick();for i=#state.writes-3,#state.writes do assert(state.writes[i][3]==15,'OFF acknowledged cut by spinning props') end
e.values.Enable=1;state.bus['minecraft:stone,minecraft:lever']=15;tick();assert(e.outputs.Active==1,'fresh OFF/ON did not rearm cut')
assert(e.outputs['Flight qualified']==0)
print('Universal native: single writer, boot gate, initial bounded trim, hot target keeps estimator, stale command refusal, frozen actuator/Enable bindings, mapping handoff, no restored mission and mechanical cut passed')
-- Configuration request buttons commit a saved record, not an ephemeral click.
local f=setmetatable({},{__index=_G});f._G=f;f.outputs={};f.ui={checkbox=function() local s=field(false);s.isChecked=s.getValue;s.setChecked=s.setValue;return s end,label=field,textfield=function() return field('') end,slider=function(_,minimum) return field(minimum) end,button=function() local b={clicked=false};b.wasClicked=function() local v=b.clicked;b.clicked=false;return v end;return b end};f.addElement=function() end;f.input=function() return 0 end;f.output=function(k,v) f.outputs[k]=v end
local commands=assert(load(read('platforms/sputnik/dist/mintcraft-flight-commands.lua'),'commands','t',f));commands()
local panel=f.MintCraftCommands;panel.mode.setValue(2);panel.fields.altitude.value.setValue('84');panel.apply.clicked=true;commands()
assert(f.outputs.Request=='MCC1|1|ALTITUDE|84|0|0||')
commands();assert(f.outputs.Request=='MCC1|1|ALTITUDE|84|0|0||','ephemeral button request disappeared')
print('Native command panel: committed request is persistent, versioned and idempotent across redraws')
-- Montage choices/import and renderer are actual native script sources, no IO.
local function uiEnv()
 local f=setmetatable({},{__index=_G});f._G=f;f.values={};f.outputs={}
 local function bool() local s=field(false);s.isChecked=s.getValue;s.setChecked=s.setValue;return s end
 f.ui={checkbox=function() local s=field(false);s.isChecked=s.getValue;s.setChecked=s.setValue;return s end,label=field,textfield=function() return field('') end,checkbox=bool,slider=function(_,minimum) return field(minimum) end,
  itempicker=function() local s=field(nil);s.getItem=s.getValue;s.setItem=s.setValue;return s end,
  button=function() local b={clicked=false};b.wasClicked=function() local v=b.clicked;b.clicked=false;return v end;return b end,
  viewport=function() local v={models={}};v.clear=function() v.models={} end;v.setZoom=function() end;v.setRotation=function() end;v.addItem=function(...) v.models[#v.models+1]={...} end;return v end}
 f.addElement=function() end;f.input=function(k) return f.values[k] or 0 end;f.output=function(k,v) f.outputs[k]=v end
 f.transmitWirelessRedstone=function() error('configuration/renderer emitted') end
 return f
end
local m=uiEnv();m.values.Architecture=3
local mount=assert(load(read('platforms/sputnik/dist/mintcraft-mount-group.lua'),'mount','t',m));mount()
local form=m.MintCraftMount;form.active.setChecked(true);form.links.power.a.setItem('minecraft:stone');form.links.power.b.setItem('minecraft:rotor')
form.fields.kind.value.setValue(2);form.fields.sails.value.setValue('16');form.fields.thrust.value.setValue('.2');form.fields.airflow.value.setValue('.05');mount()
local decoded=assert(B.Vehicle.decode(m.outputs.Group));assert(decoded.kind=='bearing' and decoded.sails==16)
form.export.clicked=true;mount();local snapshot=form.snapshot.getValue();form.fields.sails.value.setValue('8');mount();form.snapshot.setValue(snapshot);form.import.clicked=true;mount();mount()
assert(B.Vehicle.decode(m.outputs.Group).sails==16,'group import did not restore configuration')
m.values['Shaft RPM']=0;m.values['Shaft sample tick']=100;m.values['Shaft sample valid']=1;mount();assert(m.outputs['Shaft observation']=='1,0,100')
m.values['Shaft sample valid']=0;mount();assert(m.outputs['Shaft observation']=='','default cached zero became shaft evidence')
local bus=uiEnv();bus.values['Group 1']=snapshot;bus.values['Observation 1']='1,0,100'
local busRun=assert(load(read('platforms/sputnik/dist/mintcraft-mount-bus.lua'),'bus','t',bus));busRun()
assert(bus.outputs['Groups A']==snapshot and bus.outputs['Observations A']=='1,0,100')
bus.values['Group 2']=string.rep('x',2401);busRun();assert(bus.outputs['Groups A']:find('INVALID_GROUP',1,true),'oversize descriptor entered transport')
local map=uiEnv();map.values.Geometry='-3,1,5;3,1,5;-3,1,-5;3,1,-5';map.values.Route='1,80,1;2,80,2';map.values.Position='0,80,0';map.values.Trace='0,80,0'
local mapRun=assert(load(read('platforms/sputnik/dist/mintcraft-local-map.lua'),'map','t',map));mapRun();assert(#map.MintCraftLocalMap.viewport.models==4)
map.MintCraftLocalMap.view.setValue(5);mapRun();assert(#map.MintCraftLocalMap.viewport.models==4);mapRun();assert(#map.MintCraftLocalMap.viewport.models==4,'map leaked previous frame models')
print('Native montage/map: enum choices, per-group import/export, explicit shaft sample validity, bounded transport and declared-only renderer passed')
-- Graph widgets persist routes and select/edit points without code changes.
f.input=function(k) if k=='Position' then return '1,82,3' end;return 0 end
panel.current.clicked=true;commands();assert(panel.fields.route.value.getValue()=='1,82,3,0')
panel.pointText.setValue('4,83,6,2');panel.add.clicked=true;commands();assert(panel.fields.route.value.getValue()=='1,82,3,0;4,83,6,2')
panel.name.setValue('essai');panel.save.clicked=true;commands();panel.fields.route.value.setValue('');panel.restore.clicked=true;commands();assert(panel.fields.route.value.getValue()=='1,82,3,0;4,83,6,2')
panel.point.setValue(2);panel.remove.clicked=true;commands();assert(panel.fields.route.value.getValue()=='1,82,3,0')
map.MintCraftLocalMap.view.setValue(4);map.MintCraftLocalMap.hull.setValue('0,0,0;0,1,0');mapRun();assert(#map.MintCraftLocalMap.viewport.models==6)
-- Partial commissioning data survives pause and a stale client widget update.
local calCore=e.MintCraftPilot.core
calCore.calibration={mass=state.mass,groups=calCore.groups,results={[1]={dx=0,dy=.1,dz=0,pitch=0,roll=0,yaw=0}},phase='ABORTED',paused=true,reason='Pause operateur'}
calCore.archived=nil;tick();local candidate=e.MintCraftPilot.archive.getValue();assert(candidate:find('MCAL1,32',1,true)==1)
e.MintCraftPilot.archive.setValue('CLIENT_CACHE');tick();assert(e.MintCraftPilot.archive.getValue()==candidate,'client cache overwrote retained measurements')
e.values.Request='MCC1|2|CALIBRATE|80|0|0||';tick()
assert(calCore.calibration.priors[1] and not calCore.calibration.complete and not calCore.archived,'new calibration reused an old completion flag instead of candidate data')
print('Calibration persistence: partial results, client-cache reassertion and fresh rerun from candidates passed')
-- Supervisor envelopes are fresh bounded data, not an alternate actuator writer.
e.values['Stability request']='MCSUP1,'..(state.tick+1)..',0.7';tick();assert(e.MintCraftPilot.core.scale==.7)
e.values['Stability request']='MCSUP1,'..(state.tick-100)..',0.5';tick();assert(e.MintCraftPilot.core.scale==.7,'Expired supervisor packet changed accepted envelope')
e.values['Stability request']='MCSUP1,'..(state.tick+1)..',1.1';tick();assert(e.MintCraftPilot.core.scale==.7,'Supervisor exceeded declared operator envelope')
e.values['Stability request']='MCSUP1,'..(state.tick+1)..',1';tick();assert(e.MintCraftPilot.core.scale==1)
print('Supervisor request: 0.5..1 bounds, timestamp checks, stale retention and explicit nominal restoration passed')

-- Fallback keeps being emitted after a server-side flight fault, beyond Link expiry.
local before=#state.writes;state.mass=0
for _=1,25 do tick() end
assert(e.outputs.Active==0 and #state.writes>=before+100)
assert(e.outputs.Status:find('FIRST=',1,true),'first fault not reported')
print('Native GUI and fault regressions: current-position point, named route save/load, point selection, declared hull and sustained fallback after telemetry fault passed')
-- Bulk descriptors remain saved graph fields; no import can emit hardware IO.
bus.MintCraftMountBus.capture.clicked=true;bus.values['Group 2']='';busRun();assert(bus.MintCraftMountBus.a.getValue()==snapshot)
bus.MintCraftMountBus.use.setChecked(true);bus.MintCraftMountBus.a.setValue(snapshot);bus.values['Group 1']='';busRun();assert(bus.outputs['Groups A']==snapshot)
bus.MintCraftMountBus.a.setValue(string.rep('x',38433));busRun();assert(bus.outputs['Groups A']=='INVALID_IMPORT')
print('Native global group import/export: persisted descriptors, explicit override and bounded invalid-import refusal passed')
assert(e.outputs.Report:find('FIRST=',1,true),'telemetry-loss report stayed cached')
-- A local-response drive uses zero as its stop; propeller transmission uses 15.
local motor=e.MintCraftPilot.owner[1];motor.kind='linear';motor.role='drive';motor.clutchA='minecraft:stone';motor.clutchB='minecraft:clutch';motor.fallback=0;motor.run=0
tick();local clutch
for _,write in ipairs(state.writes) do if write[2]=='minecraft:clutch' then clutch=write[3] end end
assert(clutch==15,'linear drive zero did not disengage clutch')
motor.fallback=15;tick();for _,write in ipairs(state.writes) do if write[2]=='minecraft:clutch' then clutch=write[3] end end
assert(clutch==0,'linear drive maximum incorrectly disengaged clutch')
print('Native output regression: local-response and inverse-transmission clutch stops are distinct; fault report stays current')
