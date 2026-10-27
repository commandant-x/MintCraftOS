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
local PROFILE_DEFAULT=1
-- One editable motor at a time. Always-present storage fields survive tab/reload.
local kinds={'small','bearing','linear','surface'}
local roles={'lift','drive','yaw-left','yaw-right','pitch','roll'}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function encode(g) local values={'MCV1'};for _,key in ipairs(MountFields) do values[#values+1]=tostring(g[key] or '') end;return table.concat(values,';') end
local function decode(text)
 if type(text)~='string' or #text>2400 then return nil end
 local row={};for value in (text..';'):gmatch('(.-);') do row[#row+1]=value end
 if #row~=#MountFields+1 or row[1]~='MCV1' then return nil end
 local g={};for i,key in ipairs(MountFields) do local v=row[i+1];if key~='kind' and key~='role' and not key:match('[AB]$') then v=tonumber(v);if not finite(v) then return nil end end;g[key]=v end
 local validKind,validRole=false,false;for _,v in ipairs(kinds) do if g.kind==v then validKind=true end end;for _,v in ipairs(roles) do if g.role==v then validRole=true end end;if not validKind or not validRole then return nil end
 if not finite(g.id) or g.id%1~=0 or g.id<1 or g.id>32 then return nil end
 return g
end
local function find(list,v) for i,value in ipairs(list) do if value==v then return i end end;return 1 end
local s=_G.MintCraftWorkbench
if not s then
 s={title=ui.label('Montage Personnalise: decrire une fois, verifier puis OFF/ON'),select=ui.slider('Moteur / groupe selectionne',1,32,300),active=ui.checkbox('Activer ce groupe'),kind=ui.slider('1 petite helice / 2 modulaire / 3 reponse connue / 4 gouverne',1,4,380),role=ui.slider('1 sustentation / 2 propulsion / 3 lacet G / 4 lacet D / 5 tangage / 6 roulis',1,6,400),fields={},links={},status=ui.label(''),a=ui.textfield(600),b=ui.textfield(600),exchange=ui.textfield(600),import=ui.button('Importer un groupe MCV1 dans sa position',360),export=ui.button('Copier le groupe selectionne',360),remove=ui.button('Retirer ce groupe du montage',360),reset=ui.button('Charger le modele de ce groupe (brouillon)',360),library=ui.textfield(600),name=ui.textfield(220),settingsDraft=ui.textfield(500),settingsRevision=ui.textfield(100),editorStamp=ui.textfield(160),save=ui.button('Sauvegarder ce montage nomme',360),restore=ui.button('Charger le montage nomme',360),names=ui.label('Bibliotheque: aucune'),expert=ui.textfield(460),seen=nil,current=1,groups={}}
 s.select.setValue(1);s.kind.setValue(1);s.role.setValue(1);s.a.setValue('');s.b.setValue('');s.exchange.setValue('');s.expert.setValue('');s.library.setValue('MCFLEET1');s.name.setValue('vehicule-1');s.settingsDraft.setValue('');s.settingsRevision.setValue('0');s.editorStamp.setValue('')
 for _,entry in ipairs({{'source','Regime source RPM'},{'sails','Blocs de voile de cette helice'},{'members','Moteurs identiques sur cette commande'},{'x','Position X depuis centre declare'},{'y','Position Y depuis centre declare'},{'z','Position Z depuis centre declare'}}) do s.fields[entry[1]]={label=ui.label(entry[2]),value=ui.textfield(180)} end
 for _,key in ipairs({'power','reverse','clutch'}) do s.links[key]={label=ui.label(({power='Puissance: paire Link unique',reverse='Inverseur: paire Link facultative',clutch='Clutch: paire Link facultative'})[key]),a=ui.itempicker(),b=ui.itempicker()} end
 _G.MintCraftWorkbench=s
end
for _,key in ipairs({'title','select','active','kind','role'}) do addElement(s[key]) end
for _,key in ipairs({'source','sails','members','x','y','z'}) do addElement(s.fields[key].label);addElement(s.fields[key].value) end
for _,key in ipairs({'power','reverse','clutch'}) do local p=s.links[key];addElement(p.label);addElement(p.a);addElement(p.b) end
for _,key in ipairs({'expert','status','reset','remove','exchange','export','import','a','b','name','save','restore','names','library','settingsRevision','settingsDraft','editorStamp'}) do addElement(s[key]) end
local basic={id=true,kind=true,role=true,source=true,sails=true,members=true,x=true,y=true,z=true}
for key in pairs(s.links) do basic[key..'A']=true;basic[key..'B']=true end
local function default(id) local g=MountDefaults(PROFILE_DEFAULT,id);--FPV_DEFAULTS
 return g end
local function loadGroup(id,g)
 g=g or default(id);s.current=id;s.select.setValue(id);s.active.setChecked(s.groups[id]~=nil and s.groups[id].enabled~=false);s.kind.setValue(find(kinds,g.kind));s.role.setValue(find(roles,g.role))
 for key,f in pairs(s.fields) do f.value.setValue(tostring(g[key])) end
 for key,p in pairs(s.links) do p.a.setItem(g[key..'A']~='' and g[key..'A'] or nil);p.b.setItem(g[key..'B']~='' and g[key..'B'] or nil) end
 local base=default(id);local extras={};for _,key in ipairs(MountFields) do if not basic[key] and tostring(g[key])~=tostring(base[key]) then extras[#extras+1]=key..'='..tostring(g[key]) end end;s.expert.setValue(table.concat(extras,';'))
end
local function readGroups(a,b)
 if type(a)~='string' or type(b)~='string' or #a>38432 or #b>38432 then return nil,'Import trop long' end
 local groups={};for _,text in ipairs({a,b}) do for line in text:gmatch('[^\r\n]+') do local disabled=line:sub(1,2)=='D,';local g=decode(disabled and line:sub(3) or line);if not g or groups[g.id] then return nil,'Groupe incomplet/duplique' end;g.enabled=not disabled;groups[g.id]=g end end;return groups
end
local function editorHash()
 local values={tostring(s.active.isChecked()),tostring(s.kind.getValue()),tostring(s.role.getValue()),s.expert.getValue()}
 for _,key in ipairs({'source','sails','members','x','y','z'}) do values[#values+1]=s.fields[key].value.getValue() end
 for _,key in ipairs({'power','reverse','clutch'}) do values[#values+1]=s.links[key].a.getItem() or '';values[#values+1]=s.links[key].b.getItem() or '' end
 local text=table.concat(values,';');local n=0;for i=1,#text do n=(n*33+text:byte(i))%2147483647 end;return n
end
local why
local stored=s.a.getValue()..'\0'..s.b.getValue()
if s.seen~=stored then
 local groups,error=readGroups(s.a.getValue(),s.b.getValue());if groups then
  s.groups=groups;s.seen=stored;local id,stamp=s.editorStamp.getValue():match('^MCEDIT1,(%d+),(%d+)$');id,stamp=tonumber(id),tonumber(stamp)
  if id and id>=1 and id<=32 and stamp~=editorHash() then s.current=id else loadGroup(math.floor(s.select.getValue()+.5),groups[math.floor(s.select.getValue()+.5)]) end
 else why=error end
end
local selected=math.max(1,math.min(32,math.floor(s.select.getValue()+.5)))
-- Save the previous editor before loading the newly selected group.
s.kind.setValue(math.max(1,math.min(4,math.floor(s.kind.getValue()+.5))));s.role.setValue(math.max(1,math.min(6,math.floor(s.role.getValue()+.5))))
local g=default(s.current);g.kind=kinds[math.max(1,math.min(4,math.floor(s.kind.getValue()+.5)))];g.role=roles[math.max(1,math.min(6,math.floor(s.role.getValue()+.5)))]
if g.kind=='bearing' then g.thrust=.2;g.airflow=.05 elseif g.kind=='small' then g.thrust=1;g.airflow=.1 end
for key,f in pairs(s.fields) do local value=tonumber(f.value.getValue());if not finite(value) then why='Nombre requis: '..key end;g[key]=value or f.value.getValue() end
for key,p in pairs(s.links) do for _,side in ipairs({'A','B'}) do local value=(side=='A' and p.a or p.b).getItem();g[key..side]=value and value~='minecraft:air' and value or '' end end
local allowed={};for _,key in ipairs(MountFields) do allowed[key]=true end
if #s.expert.getValue()>2400 then why='Expert trop long' else for part in s.expert.getValue():gmatch('[^;]+') do
 local key,value=part:match('^%s*(%w+)%s*=%s*(.-)%s*$')
 if not key or not allowed[key] or basic[key] then why='Cle expert invalide' else if key~='kind' and key~='role' and not key:match('[AB]$') then value=tonumber(value);if not finite(value) then why='Nombre expert invalide' end end;g[key]=value end
end end
if finite(g.dx) and finite(g.dy) and finite(g.dz) and math.abs(g.dx^2+g.dy^2+g.dz^2-1)>.002 then why='Corriger direction: vecteur unitaire requis' end
if finite(g.source) and (g.source<=0 or g.source>256) then why='Regime source hors domaine 0..256' end
if finite(g.sails) and (g.sails<1 or g.sails%1~=0) then why='Voiles: entier positif requis' end
if finite(g.members) and (g.members<1 or g.members>32 or g.members%1~=0) then why='Moteurs identiques: entier 1..32 requis' end
g.enabled=s.active.isChecked();if not why then s.groups[s.current]=g end
if selected~=s.current then if not why then loadGroup(selected,s.groups[selected]) else s.select.setValue(s.current) end end
if s.remove.wasClicked() then s.groups[s.current]=nil;s.active.setChecked(false) end
if s.reset.wasClicked() then s.groups[s.current]=nil;loadGroup(s.current);s.active.setChecked(false) end
if s.export.wasClicked() then s.exchange.setValue(encode(s.groups[s.current] or g)) end
if s.import.wasClicked() then local imported=decode(s.exchange.getValue());if imported then imported.enabled=true;s.groups[imported.id]=imported;loadGroup(imported.id,imported);s.active.setChecked(true) else why='Copier un groupe MCV1 complet' end end
local function transport(groups,activeOnly)
 local a,b={},{};for id=1,32 do if groups[id] and (not activeOnly or groups[id].enabled~=false) then local row=(not activeOnly and groups[id].enabled==false and 'D,' or '')..encode(groups[id]);if #row>2400 then return nil,nil,'Groupe trop long' end;local list=id<=16 and a or b;list[#list+1]=row end end
 a,b=table.concat(a,'\n'),table.concat(b,'\n');if #a>38432 or #b>38432 then return nil,nil,'Montage trop long' end;return a,b
end
local a,b,error=transport(s.groups);why=why or error
if a and b then s.a.setValue(a);s.b.setValue(b);s.seen=a..'\0'..b end
-- Named mounts contain descriptors only; active flight remains frozen by the writer.
local library=s.library.getValue();local mounts,names={},{}
if #library<=38000 and library:match('^MCFLEET1') then
 for name,rows in library:gmatch('\n@([%w_%-]+)\n(.-)\n!') do if #name<=32 then mounts[name]=rows;names[#names+1]=name end end
end
local name=s.name.getValue()
if s.save.wasClicked() then
 if name:match('^[%w_%-]+$') and #name<=32 and (mounts[name] or #names<12) and a and b then
  local configured=input('Settings','string');local saved=type(configured)=='string' and #configured<=1024 and configured:match('^MCU1;') and 'S='..configured..'\n' or ''
  mounts[name]=saved..a..'\n'..b;local keys={};for key in pairs(mounts) do keys[#keys+1]=key end;table.sort(keys);local rows={'MCFLEET1'};for _,key in ipairs(keys) do rows[#rows+1]='@'..key..'\n'..mounts[key]..'\n!' end;local text=table.concat(rows,'\n');if #text<=38000 then s.library.setValue(text);names=keys else why='Bibliotheque pleine: exporter les champs A/B' end
 else why='Nom simple requis; 12 montages maximum' end
end
if s.restore.wasClicked() then
 if mounts[name] then local configured=mounts[name]:match('^S=([^\n]+)\n');local body=configured and mounts[name]:sub(#configured+4) or mounts[name];local imported,err=readGroups(body,'');if imported then s.groups=imported;a,b=transport(imported);s.a.setValue(a);s.b.setValue(b);s.seen=a..'\0'..b;loadGroup(s.current,imported[s.current]);if configured then local rev=(tonumber(s.settingsRevision.getValue()) or 0)+1;s.settingsRevision.setValue(tostring(rev));s.settingsDraft.setValue('MCSET1|'..rev..'|'..configured) end else why=err end else why='Montage nomme inconnu' end
end
local seen,geometry,count={}, {},0
for id=1,32 do local item=s.groups[id];if item and item.enabled~=false then
 count=count+1;geometry[#geometry+1]=table.concat({item.x,item.y,item.z},',')
 for _,key in ipairs({'power','reverse','clutch'}) do local first,second=item[key..'A'],item[key..'B'];if first~='' or second~='' then local pair=first..','..second;if seen[pair] then why='Frequence partagee: groupes '..seen[pair]..' et '..id end;seen[pair]=id end end
end end
s.names.setText('Montages: '..table.concat(names,', '))
s.status.setText(why or ('Groupe '..s.current..' | '..count..' commandes declarees; validation serveur requise. Modifications en vol: attente OFF.'))
local emit=output
if false then output('Groups A','string') output('Groups B','string') output('Geometry','string') output('Settings draft','string') end
s.editorStamp.setValue('MCEDIT1,'..s.current..','..editorHash())
local activeA,activeB=transport(s.groups,true)
emit('Groups A',why and 'INVALID_GROUP' or activeA or '');emit('Groups B',activeB or '');emit('Geometry',table.concat(geometry,';'));emit('Settings draft',s.settingsDraft.getValue())

local function observed(text)
 if type(text)~='string' or #text>4096 then return '' end
 local rows={};for line in text:gmatch('[^\r\n]+') do
  local id,rpm,tick=line:match('^(%d+),([^,]+),([^,]+)$');id,rpm,tick=tonumber(id),tonumber(rpm),tonumber(tick)
  if not id or not s.groups[id] or s.groups[id].enabled==false or not finite(rpm) or rpm<0 or rpm>100000 or not finite(tick) or tick<=0 or tick%1~=0 or #rows>=32 then return '' end
  rows[#rows+1]=table.concat({id,rpm,tick},',')
 end;return table.concat(rows,'\n')
end
if false then output('Observations A','string') output('Observations B','string') end
emit('Observations A',observed(input('Shaft samples A','string')));emit('Observations B',observed(input('Shaft samples B','string')))
