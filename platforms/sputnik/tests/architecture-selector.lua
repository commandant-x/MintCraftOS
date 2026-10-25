-- Selection, persistence restoration and live profile changes; no world-flight claim.
local function env()
 local e=setmetatable({},{__index=function(_,k) if type(k)=='string' and k:match('^MintCraft') then return nil end return _G[k] end});e._G=e
 e.values={};e.outputs={};e.writes={};e.tick=100
 e.input=function(k) return e.values[k] or 0 end;e.output=function(k,v) e.outputs[k]=v end
 local function field(value)
  local f={value=value};f.getValue=function() return f.value end;f.setValue=function(v) f.value=v end
  f.isChecked=f.getValue;f.setChecked=f.setValue;f.getItem=f.getValue;f.setText=f.setValue;return f
 end
 e.ui={label=field,slider=function(_,minimum) return field(minimum) end,textfield=function() return field('') end,checkbox=function() return field(false) end,itempicker=function() return field('minecraft:air') end}
 e.addElement=function() end;e.display=function() end
 e.getUniverseTime=function() return e.tick end;e.getShipMass=function() return 32 end
 e.getPosition=function() return 0,80,0 end;e.getOrientation=function() return 0,0,0 end
 e.getDimension=function() return 'minecraft:overworld' end
 e.transmitWirelessRedstone=function(a,b,v) e.writes[#e.writes+1]={a,b,v} end
 return e
end
local function node(e,path) local h=assert(io.open(path));local text=h:read('*a');h:close();return assert(load(text,path,'t',e)) end
local e=env();local selector=node(e,'platforms/sputnik/dist/mintcraft-architecture-selector.lua')
selector();assert(e.outputs.Architecture==1 and e.outputs['Flight backend available']==1)
local s=e.MintCraftArchitecture
for i,name in ipairs({'Quad','Ballon','Venator','Helicoptere'}) do
 s.selector.setValue(i);selector()
 assert(e.outputs.Architecture==i and e.outputs.Selection==name)
 assert(e.outputs['Flight backend available']==(i==1 and 1 or 0))
end
assert(#e.writes==0,'selector emitted actuator commands')
s.selector.setValue(2.8);selector();assert(e.outputs.Architecture==3)
s.selector.setValue(0/0);selector();assert(e.outputs.Architecture==-1 and e.outputs['Flight backend available']==0)
-- The actual WSlider NBT round trip is separately verified in Java. Recreated
-- native elements are loaded after their creation, then used on subsequent ticks.
e.MintCraftArchitecture=nil;selector();e.MintCraftArchitecture.selector.setValue(3);selector();selector()
assert(e.outputs.Architecture==3,'startup default overwrote a restored native widget')
local q=env();local run=node(q,'platforms/sputnik/dist/mintcraft-quad-control.lua')
q.values['Enable binding']='minecraft:stone,minecraft:lever'
local keys={} for i=1,6 do keys[i]='minecraft:stone,minecraft:key_'..i end
q.values['Keyboard bindings']=table.concat(keys,'|');q.values['Commands valid']=1
q.values.Architecture=1;run()
local state=q.MintCraftQuad;state.checked.setChecked(true)
local rows={{8,4,12,.4,-8,8,8},{8,4,12,.4,-8,-8,8},{8,4,12,.4,8,8,8},{8,4,12,.4,8,-8,8}}
for i,r in ipairs(state.rotors) do r.a.setValue('minecraft:stone');r.b.setValue('minecraft:rotor_'..i);r.row.setValue(table.concat(rows[i],',')) end
local function tick() q.tick=q.tick+1;run() end
for _,id in ipairs({2,3,4,99,0/0}) do
 q.values.Architecture=id;q.values['Flight Enable']=0;tick();tick();tick()
 q.values['Flight Enable']=1;tick()
 assert(q.outputs.Active==0 and #q.writes==0,'unsupported architecture started quad')
 assert(q.outputs.Status:find('ARCHITECTURE',1,true))
end
q.values.Architecture=1;q.values['Flight Enable']=0;tick();tick();tick()
q.values['Flight Enable']=1;tick();assert(q.outputs.Active==1)
local owner=state.owner
q.values.Architecture=3;tick();tick()
assert(q.outputs.Active==1 and state.owner==owner and state.architecture==1,'live selection interrupted/retargeted lift')
assert(q.outputs.Status:find('ARCHITECTURE_EN_ATTENTE',1,true))
q.values['Flight Enable']=0;tick();tick();tick()
assert(q.outputs.Active==0 and state.architecture==3)
for i=#q.writes-3,#q.writes do assert(q.writes[i][2]=='minecraft:rotor_'..(i-(#q.writes-4)) and q.writes[i][3]==8,'OFF lost frozen old fallback') end
q.values['Flight Enable']=1;tick();assert(q.outputs.Active==0)
q.values.Architecture=1;tick();assert(q.outputs.Active==0,'profile change acknowledged without OFF')
q.values['Flight Enable']=0;tick();tick();tick();q.values['Flight Enable']=1;tick();assert(q.outputs.Active==1)
print('Architecture selector: four names, restored choice, no actuation, unavailable backend refusal, pending live change, old fallback and OFF rearm passed')
