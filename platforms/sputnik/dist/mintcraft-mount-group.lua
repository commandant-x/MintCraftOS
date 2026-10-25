local GROUP_DEFAULT=1
local MountFields={'id','kind','role','x','y','z','dx','dy','dz','source','sails','thrust','airflow','gain','neutral','fallback','members','powerA','powerB','reverseA','reverseB','clutchA','clutchB','run','alpha','bias','support'}
local MountDefaults=(function()
local M={}
function M.defaults(profile,index)
 local g={id=index,kind='small',role='lift',x=0,y=0,z=0,dx=0,dy=1,dz=0,source=256,sails=12,thrust=1,airflow=.1,gain=1,neutral=8,fallback=-1,members=1,run=0,alpha=.15,bias=0,support=1,
  powerA='minecraft:air',powerB='minecraft:air',reverseA='',reverseB='',clutchA='',clutchB=''}
 if profile==1 then g.x=index%2==1 and -3 or 3;g.z=index<=2 and 5 or -5
 elseif profile==2 then
  if index==1 then g.kind='linear';g.role='lift';g.gain=1;g.support=1
  elseif index==2 then g.role='drive';g.dy=0;g.dz=1;g.support=0;g.fallback=15
  else g.kind='surface';g.role=index==3 and 'yaw-left' or 'yaw-right';g.dy=1;g.support=0;g.neutral=0;g.fallback=0;g.gain=1 end
 elseif profile==3 then
  if index<=4 then g.x=index%2==1 and -3 or 3;g.z=index<=2 and 5 or -5
  else g.role='drive';g.dx=0;g.dy=0;g.dz=1;g.x=index==5 and -3 or 3;g.z=-5;g.members=2;g.support=0;g.fallback=15 end
 elseif profile==4 then
  if index==1 then g.kind='bearing';g.thrust=.2;g.airflow=.05
  elseif index==2 then g.role='drive';g.dy=0;g.dz=1;g.support=0;g.fallback=15
  else g.kind='linear';g.role=index==3 and 'yaw-left' or 'yaw-right';g.dy=1;g.support=0;g.neutral=0;g.fallback=0 end
 end
 return g
end

return M.defaults
end)()
local enum={kind={'small','bearing','linear','surface'},role={'lift','drive','yaw-left','yaw-right','pitch','roll'}}
local function selected(key,value) for i,v in ipairs(enum[key] or {}) do if v==value then return i end end;return value end
-- Stable native widget order. Configuration only; no Link writes.
local s=_G.MintCraftMount
if not s then
 s={title=ui.label('Montage: frequence(s) puis modele du groupe; aucun actionnement'),active=ui.checkbox('Groupe utilise'),template=ui.button('Charger le modele architecture',300),fields={},links={}}
 local labels={id='Numero unique 1..32',kind='Type: small / bearing / linear',role='Role: lift / drive / yaw-left / yaw-right / pitch / roll',x='Position X depuis COM',y='Position Y depuis COM',z='Position Z depuis COM',dx='Direction force X',dy='Direction force Y',dz='Direction force Z',source='RPM source',sails='Blocs de voile (bearing)',thrust='Poussee: vide = defaut automatique du type',airflow='Airflow: vide = defaut automatique du type',gain='Gain lineaire N ou N.m / niveau',neutral='Neutre connu (linear) / estimation depart',fallback='Repli 0..15 ou -1 trim estime au depart',members='Moteurs partageant cette commande',run='Signal clutch EN MARCHE (0 ou 15)',alpha='Rampe par tick (hors bearing)',bias='Force statique supplementaire N',support='Part relative sustentation (linear)'}
 local defaults=MountDefaults(1,GROUP_DEFAULT)
 for _,key in ipairs({'id','kind','role','x','y','z','dx','dy','dz','source','sails','thrust','airflow','gain','neutral','fallback','members','run','alpha','bias','support'}) do
  local options=enum[key];local label=key=='kind' and 'Moteur: 1 petite helice / 2 modulaire / 3 reponse mesuree / 4 gouverne avec airflow' or key=='role' and 'Role: 1 sustentation / 2 propulsion / 3 gauche / 4 droite / 5 tangage / 6 roulis' or labels[key]
  local f={label=ui.label(label),value=options and ui.slider(label,1,#options,280) or ui.textfield(220)};f.value.setValue(options and selected(key,defaults[key]) or (key=='thrust' or key=='airflow') and '' or tostring(defaults[key]));s.fields[key]=f
 end
 for _,key in ipairs({'power','reverse','clutch'}) do s.links[key]={label=ui.label(({power='Puissance',reverse='Inverseur facultatif',clutch='Clutch facultatif'})[key]..': paire Link'),a=ui.itempicker(),b=ui.itempicker()} end
 s.snapshot=ui.textfield(500);s.snapshot.setValue('');s.export=ui.button('Exporter ce groupe',220);s.import=ui.button('Importer ce groupe',220)
 s.status=ui.label('Activer apres configuration');_G.MintCraftMount=s
end
addElement(s.title) addElement(s.active) addElement(s.template)
for _,key in ipairs({'id','kind','role','x','y','z','dx','dy','dz','source','sails','thrust','airflow','gain','neutral','fallback','members','run','alpha','bias','support'}) do local f=s.fields[key];addElement(f.label);addElement(f.value) end
for _,key in ipairs({'power','reverse','clutch'}) do local p=s.links[key];addElement(p.label);addElement(p.a);addElement(p.b) end
addElement(s.status);addElement(s.snapshot);addElement(s.export);addElement(s.import)
local architecture=input('Architecture')
if s.template.wasClicked() then
 local defaults=MountDefaults(architecture,GROUP_DEFAULT)
 for key,f in pairs(s.fields) do f.value.setValue(enum[key] and selected(key,defaults[key]) or (key=='thrust' or key=='airflow') and '' or tostring(defaults[key])) end
end
local values={'MCV1'}
for _,key in ipairs(MountFields) do
 local f=s.fields[key]
 if f then local value=f.value.getValue();if value=='' and (key=='thrust' or key=='airflow') then local bearing=math.floor(s.fields.kind.value.getValue()+.5)==2;value=key=='thrust' and (bearing and .2 or 1) or (bearing and .05 or .1) end;values[#values+1]=enum[key] and enum[key][math.floor(value+.5)] or value
 else
  local role,which=key:match('^(.-)([AB])$');local link=s.links[role];local item=link and (which=='A' and link.a.getItem() or link.b.getItem()) or ''
  values[#values+1]=role~='power' and item=='minecraft:air' and '' or item or ''
 end
end
local text=table.concat(values,';')
if s.export.wasClicked() then s.snapshot.setValue(text) end
if s.import.wasClicked() then
 local imported={} for v in (s.snapshot.getValue()..';'):gmatch('(.-);') do imported[#imported+1]=v end
 if imported[1]=='MCV1' and #imported==#MountFields+1 then
  for i,key in ipairs(MountFields) do
   if s.fields[key] then s.fields[key].value.setValue(enum[key] and selected(key,imported[i+1]) or imported[i+1])
   else local role,which=key:match('^(.-)([AB])$');local link=s.links[role];if link then local picker=which=='A' and link.a or link.b;picker.setItem(imported[i+1]~='' and imported[i+1] or nil) end end
  end
 end
end
s.status.setText(s.active.isChecked() and 'Groupe configure; observation mecanique separee' or 'Groupe ignore')
local emit=output
if false then output('Group','string') output('Shaft observation','string') end
emit('Group',s.active.isChecked() and text or '')

local shaft=input('Shaft RPM');local stamp=input('Shaft sample tick');local observed=input('Shaft sample valid')
local id=tonumber(s.fields.id.value.getValue())
local good=observed==1 and type(shaft)=='number' and shaft==shaft and shaft>=0 and shaft<100000 and type(stamp)=='number' and stamp>0 and id and id%1==0
emit('Shaft observation',good and table.concat({id,shaft,stamp},',') or '')
