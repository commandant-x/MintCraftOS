local function read(path) local f=assert(io.open(path));local text=f:read('*a');f:close();return text end
local fixture=assert(MintCraftJournalFixture)
local function field(value)
 local f={value=value};f.getValue=function() return f.value end;f.setValue=function(v) f.value=v end;f.setText=f.setValue;f.getItem=f.getValue;f.setItem=f.setValue;f.isChecked=f.getValue;f.setChecked=f.setValue;return f
end
local clock=100
local e=setmetatable({},{__index=function(_,k) if type(k)=='string' and k:match('^MintCraft') then return nil end;return _G[k] end});e._G=e;e.values={};e.outputs={}
e.ui={label=field,textfield=function() return field('') end,checkbox=function() return field(false) end,slider=function(_,min) return field(min) end,button=function() local f=field(false);f.wasClicked=function() local v=f.clicked;f.clicked=false;return v end;return f end,viewport=function() return {clear=function() end,setZoom=function() end,setRotation=function() end,addItem=function() end} end}
e.addElement=function() end;e.getUniverseTime=function() return clock end;e.getShipMass=function() return 32 end;e.display=function() end
e.transmitWirelessRedstone=function() error('Observer attempted physical actuation') end
e.input=function(name,kind) local v=e.values[name];if v~=nil then return v end;return kind=='string' and '' or 0 end;e.output=function(name,v) e.outputs[name]=v end
local run=assert(load(read('platforms/sputnik/dist/mintcraft-flight-operations.lua'),'operations','t',e))
e.values.Settings=fixture.settings;e.values['Groups A']=table.concat(fixture.descriptors,'\n');e.values['Groups B']=''
local function tick(changes) clock=clock+1;e.values['Flight report']=fixture.frame(clock,changes);run() end
for i=1,140 do tick() end
local s=e.MintCraftOperations;assert(s.journal.count==140 and s.diagnostic.ready)
s.freeze.clicked=true;tick();assert(s.export.getValue():match('^MCLOG1;'),'No server export produced')
local snapshot=s.export.getValue();s.export.setValue('CLIENT_CACHE');tick();assert(s.export.getValue()==snapshot,'Client cache replaced server evidence')
for i=1,140 do tick({pitch=8*math.sin(i*math.pi/8)}) end
assert(e.outputs['Stop horizontal']==1 and e.outputs['Mechanical cut']==0,'Severe oscillation did not pause only the horizontal demand')
s.reset.clicked=true;tick({pitch=8});assert(e.outputs['Stop horizontal']==1,'Unsafe protection acknowledgement resumed motion')
e.values['Flight report']='INVALID';clock=clock+1;run();assert(e.outputs['Stop horizontal']==1,'Missing report released latched protection')
s.protect.setChecked(false);s.reset.clicked=true;tick();assert(e.outputs['Stop horizontal']==0,'Explicit operator override ignored')
e.values['Cut requested']=1;tick();assert(e.outputs['Mechanical cut']==1);e.values['Cut requested']='';tick();assert(e.outputs['Mechanical cut']==0,'Malformed cut became a motor cut')
s.clear.clicked=true;tick();assert(s.export.getValue()=='' and s.journal.snapshot==nil,'Clear retained old export')
print('Operations runtime: server evidence cache ownership, bounded export, fresh supervisor frames, latched horizontal protection, explicit override and distinct mechanical cut passed')
