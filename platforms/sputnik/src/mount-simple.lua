-- Compact editor, same complete MCV1 contract. No physical commands.
local architecture=input('Architecture')
local kinds={'small','bearing','linear','surface'}
local names={'Petite helice','Hélice modulaire','Bruleur / reponse locale connue','Gouverne avec airflow'}
local allowed={};for _,key in ipairs(MountFields) do allowed[key]=true end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function index(value) for i,v in ipairs(kinds) do if v==value then return i end end end
local function encode(g) local row={'MCV1'};for _,key in ipairs(MountFields) do row[#row+1]=tostring(g[key] or '') end;return table.concat(row,';') end
local base=MountDefaults(PROFILE_DEFAULT,GROUP_DEFAULT)
local titles=PROFILE_DEFAULT==3 and {'Avant gauche','Avant droite','Arriere gauche','Arriere droite','Propulsion gauche','Propulsion droite'} or PROFILE_DEFAULT==1 and {'Avant gauche','Avant droite','Arriere gauche','Arriere droite'} or {'Sustentation','Propulsion','Lacet gauche','Lacet droite'}
local s=_G.MintCraftSimpleMount
if not s then
 s={title=ui.label(titles[GROUP_DEFAULT] or 'Moteur'),active=ui.checkbox('Utiliser ce groupe'),type=ui.slider('Type de moteur',1,4,220),kind=ui.label(''),fields={},links={},advancedLabel=ui.label('Expert facultatif: cle=valeur;... (direction, coefficients, repli)'),advanced=ui.textfield(360),exchangeLabel=ui.label('Copie / import du groupe complet'),exchange=ui.textfield(360),export=ui.button('Copier les reglages vers le champ',300),import=ui.button('Charger ce groupe depuis le champ',300),status=ui.label('Choisir la frequence puissance')}
 s.type.setValue(index(base.kind));s.advanced.setValue('');s.exchange.setValue('')
 for _,entry in ipairs({{'x','Position gauche/droite X (blocs)'},{'y','Position verticale Y (blocs)'},{'z','Position avant/arriere Z (blocs)'},{'source','Regime source RPM (max 256)'},{'sails','Voiles de cette helice (modulaire)'},{'members','Moteurs identiques sur cette commande'}}) do
  s.fields[entry[1]]={label=ui.label(entry[2]),value=ui.textfield(180)};s.fields[entry[1]].value.setValue(tostring(base[entry[1]]))
 end
 for _,role in ipairs({'power','reverse','clutch'}) do
  if role~='reverse' or base.role=='drive' then s.links[role]={label=ui.label(({power='Puissance: les deux objets du Link',reverse='Marche arriere (facultatif)',clutch='Clutch (facultatif)'})[role]),a=ui.itempicker(),b=ui.itempicker()} end
 end
 _G.MintCraftSimpleMount=s
end
addElement(s.title);addElement(s.active);addElement(s.links.power.label);addElement(s.links.power.a);addElement(s.links.power.b)
addElement(s.type);addElement(s.kind)
for _,key in ipairs({'source','sails','members','x','y','z'}) do addElement(s.fields[key].label);addElement(s.fields[key].value) end
for _,role in ipairs({'reverse','clutch'}) do local p=s.links[role];if p then addElement(p.label);addElement(p.a);addElement(p.b) end end
addElement(s.status);addElement(s.advancedLabel);addElement(s.advanced);addElement(s.exchangeLabel);addElement(s.exchange);addElement(s.export);addElement(s.import)
local choice=math.max(1,math.min(4,math.floor(s.type.getValue()+.5)));s.type.setValue(choice)
s.kind.setText(names[choice]..' | '..(base.role=='lift' and 'Poussee verticale automatique (0,1,0)' or base.role))
local function initial(kind)
 local g=MountDefaults(PROFILE_DEFAULT,GROUP_DEFAULT);g.kind=kind
 g.thrust=kind=='bearing' and .2 or 1;g.airflow=kind=='bearing' and .05 or .1
 return g
end
local basic={kind=true,x=true,y=true,z=true,source=true,sails=true,members=true}
for role in pairs(s.links) do basic[role..'A']=true;basic[role..'B']=true end
local importError
if s.import.wasClicked() then
 local row={};local text=s.exchange.getValue()
 if #text<=2400 then for value in (text..';'):gmatch('(.-);') do row[#row+1]=value end end
 local kind=row[3];local selected=index(kind)
 if row[1]~='MCV1' or #row~=#MountFields+1 or not selected then importError='Import refuse: copier un groupe MCV1 complet'
 else
  local imported={};for i,key in ipairs(MountFields) do imported[key]=row[i+1] end
  s.type.setValue(selected);choice=selected
  for key,f in pairs(s.fields) do f.value.setValue(imported[key]) end
  for role,p in pairs(s.links) do p.a.setItem(imported[role..'A']~='' and imported[role..'A'] or nil);p.b.setItem(imported[role..'B']~='' and imported[role..'B'] or nil) end
  local defaults=initial(kind);local extras={}
  for _,key in ipairs(MountFields) do if not basic[key] and tostring(defaults[key] or '')~=imported[key] then extras[#extras+1]=key..'='..imported[key] end end
  s.advanced.setValue(table.concat(extras,';'));s.active.setChecked(true)
 end
end
local g=initial(kinds[choice]);local why=importError
for key,f in pairs(s.fields) do local n=tonumber(f.value.getValue());if not finite(n) then why='Corriger '..key..': nombre requis' end;g[key]=n or f.value.getValue() end
for role,p in pairs(s.links) do
 for _,side in ipairs({'A','B'}) do local value=(side=='A' and p.a or p.b).getItem();g[role..side]=value and value~='minecraft:air' and value or '' end
end
local extra=s.advanced.getValue()
if #extra>2400 then why='Expert trop long' else
 for part in extra:gmatch('[^;]+') do
  local key,value=part:match('^%s*([%a][%w]*)%s*=%s*(.-)%s*$')
  if not key or not allowed[key] or basic[key] then why='Expert: cle invalide ou deja dans le formulaire'
  else
   local numeric=key~='kind' and key~='role' and not key:match('[AB]$')
   if numeric then value=tonumber(value);if not finite(value) then why='Expert: nombre requis pour '..key end end
   g[key]=value or ''
  end
 end
end
if g.powerA=='' or g.powerB=='' then why='Choisir les deux objets de la frequence puissance' end
if finite(g.dx) and finite(g.dy) and finite(g.dz) and math.abs(g.dx^2+g.dy^2+g.dz^2-1)>.002 then why='Expert: direction unitaire requise (verticale: 0,1,0)' end
if finite(g.source) and (g.source<=0 or g.source>256) then why='Regime source: entre 0 exclus et 256 RPM' end
if finite(g.sails) and (g.sails<1 or g.sails%1~=0) then why='Voiles: nombre entier positif requis' end
s.kind.setText(names[choice]..' | '..(g.role=='lift' and g.dx==0 and g.dy==1 and g.dz==0 and 'Poussee verticale automatique' or 'Direction / role personnalises: '..tostring(g.role)))
if finite(g.members) and (g.members<1 or g.members>32 or g.members%1~=0) then why='Moteurs par commande: entier entre 1 et 32' end
local text=encode(g)
if s.export.wasClicked() then s.exchange.setValue(text) end
s.status.setText(why or (s.active.isChecked() and 'Reglages emis; validation serveur et maintien a verifier' or 'Groupe desactive'))
local emit=output
if false then output('Group','string') output('Shaft observation','string') end
emit('Group',s.active.isChecked() and (why and 'INVALID_GROUP' or text) or '')
local shaft=input('Shaft RPM');local stamp=input('Shaft sample tick');local observed=input('Shaft sample valid')
local good=observed==1 and finite(shaft) and shaft>=0 and shaft<100000 and finite(stamp) and stamp>0 and finite(g.id) and g.id%1==0
emit('Shaft observation',good and table.concat({g.id,shaft,stamp},',') or '')
