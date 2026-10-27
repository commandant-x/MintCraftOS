local function read(path) local f=assert(io.open(path));local text=f:read('*a');f:close();return text end
local function field(v) local x={v=v};x.getValue=function() return x.v end;x.setValue=function(t) x.v=t end;x.setText=x.setValue;x.getItem=x.getValue;x.setItem=x.setValue;x.isChecked=x.getValue;x.setChecked=x.setValue;return x end
local function environment()
 local e=setmetatable({},{__index=function(_,k) if type(k)=='string' and k:match('^MintCraft') then return nil end;return _G[k] end});e._G=e;e.outputs={};e.values={}
 e.ui={label=field,textfield=function() return field('') end,itempicker=function() return field(nil) end,checkbox=function() return field(false) end,slider=function(_,min) return field(min) end,button=function() local x=field(false);x.wasClicked=function() local clicked=x.clicked;x.clicked=false;return clicked end;return x end};e.addElement=function() end;e.input=function(k) return e.values[k] or '' end;e.output=function(k,v) e.outputs[k]=v end;e.transmitWirelessRedstone=function() error('Editor wrote motor') end
 return e
end
local code=read('platforms/sputnik/dist/mintcraft-mount-workbench.lua');local e=environment();local run=assert(load(code,'workbench','t',e));run();local s=e.MintCraftWorkbench
s.fields.sails.value.setValue('24');s.fields.source.value.setValue('224');run();s.select.setValue(2);run();s.fields.sails.value.setValue('16');run();s.select.setValue(1);run()
assert(s.fields.sails.value.getValue()=='24' and s.fields.source.value.getValue()=='224','Switch discarded inactive motor draft')
assert(e.outputs['Groups A']=='','Inactive draft became an active motor')
local a,b=s.a.getValue(),s.b.getValue();local fresh=environment();local again=assert(load(code,'reload','t',fresh));again();local f=fresh.MintCraftWorkbench;f.a.setValue(a);f.b.setValue(b);again();assert(f.fields.sails.value.getValue()=='24','Reload lost draft')
f.active.setChecked(true);f.links.power.a.setItem('minecraft:paper');f.links.power.b.setItem('minecraft:stone');again();assert(fresh.outputs['Groups A']:match('^MCV1;1;'))
fresh.values.Settings='MCU1;1;11;4;20;8;4;1;1;1;1';f.name.setValue('machine');f.save.clicked=true;again();assert(f.library.getValue():find('S=MCU1',1,true))
f.fields.sails.value.setValue('8');again();f.restore.clicked=true;again();assert(f.fields.sails.value.getValue()=='24','Named mount lost model')
assert(fresh.outputs['Settings draft']:match('^MCSET1|1|MCU1;'),'Named mount did not restore setup draft')
fresh.values['Shaft samples A']='1,0,100';again();assert(fresh.outputs['Observations A']=='1,0,100')
fresh.values['Shaft samples A']='1,0,nan';again();assert(fresh.outputs['Observations A']=='','Nonfinite shaft sample became evidence')
print('Workbench: inactive draft retention, switching, fresh reload, named complete mount and strict optional shaft samples passed')
