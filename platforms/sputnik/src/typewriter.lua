-- Six Link receivers only. No motor commands, no inferred release/heartbeat.
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function item(v) return type(v)=='string' and #v<=192 and v~='minecraft:air' and v:match('^[a-z0-9_.%-]+:[a-z0-9_./%-]+$') end
local names={'W','S','Q','D','Space','Shift'}
local s=_G.MintCraftTypewriter
if not s then
 s={keys={},low=0,armed=false,label=ui.label('Typewriter: six frequences, aucune sortie moteur'),verified=ui.checkbox('Signaux maintenus; retour a zero au relachement verifie')}
 for _,name in ipairs(names) do s.keys[name]={label=ui.label(name..': paire Link unique'),a=ui.itempicker(),b=ui.itempicker()} end
 _G.MintCraftTypewriter=s
end
addElement(s.label) addElement(s.verified)
for _,name in ipairs(names) do local k=s.keys[name] addElement(k.label) addElement(k.a) addElement(k.b) end
local emit=output
if false then
 output('Forward demand',0) output('Left demand',0) output('Vertical demand',0)
 output('Commands valid',0) output('Hold requested',0) output('Flight qualified',0)
end
local enabled=input('Enable')
local tick=type(getUniverseTime)=='function' and getUniverseTime() or nil
local mass=type(getShipMass)=='function' and getShipMass() or nil
local server=finite(tick) and tick>0 and finite(mass) and mass>0
local values,seen,signature={}, {},{}
local valid=s.verified.isChecked() and type(receiveWirelessRedstone)=='function'
for _,name in ipairs(names) do
 local k=s.keys[name] local a,b=k.a.getItem(),k.b.getItem()
 values[name]=0
 if not item(a) or not item(b) then valid=false else
  local id=a..','..b signature[#signature+1]=id
  if seen[id] then valid=false end seen[id]=true
  if server then
   local ok,v=pcall(receiveWirelessRedstone,a,b)
   if not ok or not finite(v) or v%1~=0 or v<0 or v>15 then valid=false
   else values[name]=v>0 and 1 or 0 end
  end
 end
end
local sig=table.concat(signature,'|')
local advancing=server and (not s.tick or tick>s.tick)
local gap=server and s.tick and (tick<s.tick or tick-s.tick>10)
local changed=s.signature and s.signature~=sig
if not server or not valid or gap or changed or not finite(enabled) or enabled<0 or enabled>15 then s.low=0 s.armed=false end
local released=true for _,name in ipairs(names) do if values[name]~=0 then released=false end end
if server and valid and advancing and not gap and not changed then
 if enabled==0 then
  s.armed=false
  if released then s.low=s.low+1 else s.low=0 end
 elseif finite(enabled) and enabled>0 and enabled<=15 then
  if s.low>=2 and released then s.armed=true end
  s.low=0
 end
end
s.signature=sig
if server then s.tick=tick end
local active=server and valid and s.armed and finite(enabled) and enabled>0 and enabled<=15 and not gap and not changed
local forward,left,vertical=0,0,0
if active then
 forward=values.W-values.S left=values.Q-values.D vertical=values.Space-values.Shift
 local norm=math.max(1,math.sqrt(forward*forward+left*left)) forward,left=forward/norm,left/norm
end
s.label.setText(not server and 'Configuration client; etat serveur via Display Link' or not valid and 'Configurer 6 paires uniques et verifier le relachement' or active and 'Clavier actif: commandes relatives au vehicule' or 'Enable=0 et touches relachees, puis Enable>0 sans touche')
-- Client evaluation must not overwrite authoritative server outputs.
if not server then
 if s.wasServer then
  emit('Forward demand',0) emit('Left demand',0) emit('Vertical demand',0)
  emit('Commands valid',0) emit('Hold requested',0) emit('Flight qualified',0)
 end
 s.wasServer=false return
end
s.wasServer=true
emit('Forward demand',forward)
emit('Left demand',left)
emit('Vertical demand',vertical)
emit('Commands valid',active and 1 or 0)
emit('Hold requested',active and forward==0 and left==0 and vertical==0 and 1 or 0)
emit('Flight qualified',0)
if type(display)=='function' then
 local raw={} for _,name in ipairs(names) do raw[#raw+1]=name..'='..values[name] end
 display('MC_KEYS_RAW',table.concat(raw,' '))
 display('MC_KEYS',active and ('F '..forward..' L '..left..' Y '..vertical) or 'Clavier inactif') end
