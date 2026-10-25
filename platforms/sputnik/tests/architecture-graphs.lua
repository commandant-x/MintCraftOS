-- Run the actual scripts embedded in every architecture-specific clipboard.
local function field(value)
 local s={value=value}
 s.getValue=function() return s.value end;s.setValue=function(v) s.value=v end;s.setText=s.setValue
 s.getItem=s.getValue;s.setItem=s.setValue;s.isChecked=s.getValue;s.setChecked=s.setValue
 return s
end
local function read(path) local f=assert(io.open(path));local value=f:read('*a');f:close();return value end
local ownerSource=read('platforms/sputnik/dist/mintcraft-autopilot-control.lua')
for _,graph in ipairs(assert(MINTCRAFT_ARCHITECTURE_GRAPHS,'Missing generated-graph bootstrap')) do
 local nodes={};local state={tick=100,bus={},writes=0};local widgets=0
 local enablePair='minecraft:stone,minecraft:lever';state.bus[enablePair]=15
 for _,node in ipairs(graph.nodes) do
  local env=setmetatable({},{__index=function(_,k) if type(k)=='string' and k:match('^MintCraft') then return nil end;return _G[k] end});env._G=env
  env.values={};env.outputs={}
  local function widget(v) widgets=widgets+1;return field(v) end
  env.ui={label=widget,textfield=function() return widget('') end,checkbox=function() return widget(false) end,
   itempicker=function() return widget(nil) end,slider=function(_,minimum) return widget(minimum) end,
   button=function() local b=widget(false);b.wasClicked=function() local v=b.clicked;b.clicked=false;return v end;return b end,
   viewport=function() error('Light graph created a map viewport') end}
  env.addElement=function() end;env.display=function() end
  env.input=function(key,typ) local v=env.values[key];if v~=nil then return v end;return typ=='string' and '' or 0 end
  env.output=function(k,v) env.outputs[k]=v end
  env.getUniverseTime=function() return state.tick end;env.getShipMass=function() return 32 end
  env.getPosition=function() return 0,80,0 end;env.getOrientation=function() return 0,0,0 end
  env.getVelocity=function() return 0,0,0 end;env.getInertiaTensor=function() return 250,400,230 end
  env.getDimension=function() return 'minecraft:overworld' end
  env.receiveWirelessRedstone=function(a,b) return state.bus[a..','..b] or 0 end
  env.transmitWirelessRedstone=function(a,b,v)
   assert(node.name==graph.slug..'-autopilot','Second actuator writer')
   assert(v>=0 and v<=15 and v%1==0);state.writes=state.writes+1
  end
  nodes[node.name]={env=env,run=assert(load(node.code,node.name,'t',env)),source=node.code}
 end
 local function at(name) return nodes[graph.slug..'-'..name].env end
 local function frame()
  state.tick=state.tick+1
  for _,node in ipairs(graph.nodes) do
   local n=nodes[node.name]
   for _,edge in ipairs(graph.edges) do if edge[3]==node.name then n.env.values[edge[4]]=nodes[edge[1]].env.outputs[edge[2]] end end
   n.run()
  end
 end
 frame()
 local consent=at('enable').MintCraftConsent;consent.a.setItem('minecraft:stone');consent.b.setItem('minecraft:lever')
 local settings=at('montage').MintCraftSetup
 settings.confirmed.setChecked(true);settings.zone.setChecked(true);settings.fields.margin.value.setValue('8')
 for i=1,graph.groups do
  local mount=at('group-'..i).MintCraftSimpleMount or at('group-'..i).MintCraftMount
  mount.active.setChecked(true);mount.links.power.a.setItem('minecraft:paper');mount.links.power.b.setItem('minecraft:motor_'..i)
  if mount.links.reverse then mount.links.reverse.a.setItem('minecraft:stick');mount.links.reverse.b.setItem('minecraft:reverse_'..i) end
 end
 frame();frame();frame()
 assert(state.writes==0,'Boot-high armed a light graph')
 assert(at('montage').outputs.Architecture==graph.profile,'Wrong preselected architecture')
 assert(at('montage').outputs.Settings:match('^MCU1;'..graph.profile..';'),'Wrong saved settings profile')
 local pilot=at('autopilot');assert(nodes[graph.slug..'-autopilot'].source==ownerSource,'Light graph changed flight controller')
 state.bus[enablePair]=0;frame();frame();frame();state.bus[enablePair]=15;frame()
 assert(pilot.outputs.Active==1,graph.slug..': '..tostring(pilot.outputs.Status))
 local core=pilot.MintCraftPilot.core;assert(#core.groups==graph.groups)
 local filters=core.filters.y
 for i,g in ipairs(core.groups) do
  local expected=graph.profile==2 and ({'lift','drive','yaw-left','yaw-right'})[i] or graph.profile==4 and ({'lift','drive','yaw-left','yaw-right'})[i] or graph.profile==3 and i>4 and 'drive' or 'lift'
  assert(g.role==expected,'Wrong architecture group preset')
  if graph.profile==3 and i>4 then assert(g.members==2,'Venator bank lost its shared members') end
 end
 local commands=at('commands').MintCraftCommands
 commands.mode.setValue(2);commands.fields.altitude.value.setValue('84');commands.apply.clicked=true;frame();frame()
 assert(core.target.y==84 and core.filters.y==filters,'Light graph lost hot target or reset estimator')
 state.bus[enablePair]=0;frame();frame();assert(pilot.outputs.Active==0,'Light graph ignored physical OFF')
 -- Named actions keep all advanced routes available and preserve the estimator.
 local quick
 for _,entry in ipairs(commands.quick or {}) do if entry.mode=='ALTITUDE' then quick=entry.button end end
 assert(quick,'Missing named altitude action');commands.fields.altitude.value.setValue('85');quick.clicked=true
 state.bus[enablePair]=15;frame();frame();assert(pilot.MintCraftPilot.core.target.y==80,'Old command resumed on rearm')
 quick.clicked=true;frame();frame();assert(pilot.MintCraftPilot.core.target.y==85)
 state.bus[enablePair]=0;frame();frame()
 local editor=at('group-1').MintCraftSimpleMount;assert(editor,'Missing compact editor')
 local mountRun=nodes[graph.slug..'-group-1'].run;local env=at('group-1')
 local vehicle=pilot.MintCraftFlightModules[7]
 editor.advanced.setValue('dx=0;dy=1;dz=0;gain=23;neutral=7;alpha=0.2;run=15;fallback=15')
 editor.type.setValue(1.77);mountRun();assert(editor.type.getValue()==2,'Fractional type remained ambiguous')
 local original=assert(vehicle.decode(env.outputs.Group));assert(original.gain==23 and original.kind=='bearing' and original.dy==1)
 editor.export.clicked=true;mountRun();local saved=editor.exchange.getValue()
 editor.advanced.setValue('');editor.fields.sails.value.setValue('5');editor.exchange.setValue(saved);editor.import.clicked=true;mountRun();mountRun()
 assert(env.outputs.Group==saved,'Complete expert configuration lost on compact import/export')
 editor.exchange.setValue('');editor.import.clicked=true;mountRun();assert(env.outputs.Group=='INVALID_GROUP','Empty import silently accepted')
 mountRun();assert(env.outputs.Group==saved,'Rejected import destroyed the current montage')
 editor.advanced.setValue('dx=3;dz=5');mountRun();assert(env.outputs.Group=='INVALID_GROUP' and editor.status.getValue():find('direction',1,true),'Non-unit direction not explained')
 editor.advanced.setValue('');mountRun();local vertical=assert(vehicle.decode(env.outputs.Group));assert(vertical.dx==0 and vertical.dy==1 and vertical.dz==0,'Coordinates leaked into thrust direction')
 settings.fields.tilt.value.setValue('30');nodes[graph.slug..'-montage'].run();assert(settings.help.getValue():find('20',1,true),'Tilt range not explained at entry')
 settings.fields.tilt.value.setValue('8');settings.fields.margin.value.setValue('-.5');nodes[graph.slug..'-montage'].run();assert(settings.help.getValue():find('Rayon',1,true),'Negative hull radius accepted by UI')
 print('Light architecture '..graph.slug..': '..#graph.nodes..' nodes, '..#graph.edges..' links, '..widgets..' widgets; correct presets, sole unchanged writer, boot-high gate, physical OFF and hot altitude passed')
end
