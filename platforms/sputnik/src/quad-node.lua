-- Actual Link actuator adapter. Experimental near-level control, not certified flight.
local s=_G.MintCraftQuad
local names={'Avant gauche','Avant droite','Arriere gauche','Arriere droite'}
if not s then
 s={rotors={},low=0,phase='off',label=ui.label('Quad experimental: modele mesure obligatoire'),
  checked=ui.checkbox('Reprise physique et modele/geometrie verifies; essais experimentaux'),
  noise=ui.textfield(140),process=ui.textfield(140),speed=ui.textfield(140),climb=ui.textfield(140),tilt=ui.textfield(140)}
 s.physical=ui.checkbox('Calcul physique: petits rotors verticaux identiques, quad symetrique centre, reglages par defaut verifies')
 s.physicalFields={}
 for _,entry in ipairs({{'source','RPM source avant transmission','256'},{'thrust','Coefficient poussee Aero','1'},{'airflow','Coefficient ecoulement Aero','0.1'},{'armX','Demi-largeur depuis centre de masse (blocs)',''},{'armZ','Demi-longueur depuis centre de masse (blocs)',''},{'height','Hauteur rotors moins hauteur Sputnik (blocs)','0'},{'gravity','Gravite Sable par defaut','11'}}) do
  local f={label=ui.label(entry[2]),value=ui.textfield(140)} f.value.setValue(entry[3]);s.physicalFields[entry[1]]=f
 end
 s.noise.setValue('0.0025') s.process.setValue('4') s.speed.setValue('2') s.climb.setValue('1') s.tilt.setValue('8')
 s.help=ui.label('R / Q / vitesse retour maintien / montee / inclinaison deplacement')
 for i,name in ipairs(names) do s.rotors[i]={label=ui.label(name..': Link puis trim,min,max,dY,dPitch,dRoll,repli'),a=ui.itempicker(),b=ui.itempicker(),row=ui.textfield(300)} end
 _G.MintCraftQuad=s
end
addElement(s.label) addElement(s.checked) addElement(s.help) addElement(s.physical)
for _,key in ipairs({'source','thrust','airflow','armX','armZ','height','gravity'}) do local f=s.physicalFields[key] addElement(f.label) addElement(f.value) end
for _,key in ipairs({'noise','process','speed','climb','tilt'}) do addElement(s[key]) end
for _,r in ipairs(s.rotors) do addElement(r.label) addElement(r.a) addElement(r.b) addElement(r.row) end
local emit=output
if false then output('Status','string') output('Active',0) output('Altitude',0) output('Target altitude',0) output('Kalman ready',0) output('Flight qualified',0) output('Maximum thrust',0) output('Weight',0) output('Pressure',0) output('Last fault','string') output('Horizontal speed',0) end
local keyboardBindings=input('Keyboard bindings','string')
local enableBinding=input('Enable binding','string')
local enabled=input('Flight Enable') local keys=input('Commands valid')
local forward=input('Forward demand') local left=input('Left demand') local vertical=input('Vertical demand')
local function finite(v) return Quad.finite(v) end
local function item(v) return type(v)=='string' and #v<=192 and v~='minecraft:air' and v:match('^[a-z0-9_.%-]+:[a-z0-9_./%-]+$') end
local function read(name)
 if type(_G[name])~='function' then return end
 local ok,a,b,c=pcall(_G[name]) if ok then return a,b,c end
end
local tick=read('getUniverseTime') local mass=read('getShipMass')
local x,y,z=read('getPosition') local pitch,yaw,roll=read('getOrientation') local dimension=read('getDimension')
local ix,iy,iz=read('getInertiaTensor')
local pose={ix=ix,iz=iz,tick=tick,mass=mass,x=x,y=y,z=z,pitch=pitch,yaw=yaw,roll=roll,dimension=dimension}
local server=finite(tick) and tick>0 and finite(mass) and mass>0
local rows,pairs_,seen,parts={}, {},{},{}
local physical=s.physical.isChecked()
local valid=true local problems={}
local function reject(code,why) valid=false problems[#problems+1]=code..': '..why end
if not s.checked.isChecked() then reject('CONFIRM','case reprise/modele non cochee sur serveur') end
if type(transmitWirelessRedstone)~='function' then reject('API','emission Link indisponible') end
-- Reject collisions across keyboard, physical enable and all four rotor outputs.
local function binding(id)
 if type(id)~='string' or #id>386 then return false end
 local a,b=id:match('^([^,]+),([^,]+)$')
 return item(a) and item(b)
end
if not binding(enableBinding) then reject('ENABLE_BIND','fil Binding du levier absent/invalide') else seen[enableBinding]='levier' end
local count=0
if type(keyboardBindings)~='string' or #keyboardBindings>2400 then reject('KEY_BIND','description clavier absente/invalide') else
 for id in keyboardBindings:gmatch('[^|]+') do
  count=count+1
  if not binding(id) then reject('KEY_PAIR','paire clavier '..count..' invalide')
  elseif seen[id] then reject('DUP','clavier '..count..' utilise frequence de '..seen[id]) end
  seen[id]='clavier '..count
 end
end
if count~=6 then reject('KEY_COUNT',tostring(count)..'/6 frequences clavier recues') end
parts[#parts+1]=tostring(keyboardBindings)..':'..tostring(enableBinding)
for i,r in ipairs(s.rotors) do
 local a,b=r.a.getItem(),r.b.getItem() local text=r.row.getValue()
 parts[#parts+1]=tostring(a)..','..tostring(b)..':'..tostring(text)
 local id=tostring(a)..','..tostring(b)
 if not item(a) or not item(b) then reject('ROTOR_'..i,'paire objets absente/invalide')
 elseif seen[id] then reject('DUP_'..i,'rotor '..i..' utilise frequence de '..seen[id]) end
 seen[id]='rotor '..i pairs_[i]={a,b}
 rows[i]={}
 if physical then rows[i]={}
 elseif type(text)~='string' or #text>256 then reject('ROW_'..i,'ligne manuelle invalide') else
  -- Empty fields must not silently shift response columns.
  local count=0 for token in (text..','):gmatch('(.-),') do count=count+1 rows[i][count]=tonumber(token) or false end
  if count~=7 then reject('ROW_'..i,'7 nombres requis ou activer Calcul physique') end
 end
end
local config={}
for _,key in ipairs({'noise','process','speed','climb','tilt'}) do config[key]=tonumber(s[key].getValue()) parts[#parts+1]=tostring(config[key])
 if not finite(config[key]) or config[key]<=0 then reject('PARAM_'..key,'valeur positive requise') end end
local physicsWhy
if physical then
 config.physics={}
 for _,key in ipairs({'source','thrust','airflow','armX','armZ','height','gravity'}) do
  config.physics[key]=tonumber(s.physicalFields[key].value.getValue())
  parts[#parts+1]=tostring(config.physics[key])
  if not finite(config.physics[key]) then reject('PHYS_'..key,'valeur numerique requise') end
 end
 if server then
  local result
  rows,result=Quad.Physics.rows(config.physics,pose)
  if not rows then physicsWhy=result end
 else rows=nil end
end
parts[#parts+1]=tostring(physical)
local model,modelWhy=Quad.model(rows,physical)
modelWhy=physicsWhy or modelWhy
if not model then reject('MODEL',tostring(modelWhy)) end
local rejection=#problems>0 and table.concat(problems,' | ') or nil
if not valid and not s.owner and not s.fault then s.reason=rejection or 'Configuration incomplete' s.phase='off' s.low=0 end
local signature=table.concat(parts,'|')
local function send(values)
 if not s.owner then return false end
 -- No Link ACK is available: RPC success is not proof of rotor response.
 local ok=true
 for i,pair in ipairs(s.owner.pairs) do
  local good=pcall(transmitWirelessRedstone,pair[1],pair[2],values[i]) if not good then ok=false end
 end
 s.lastRequested={} for i,value in ipairs(values) do s.lastRequested[i]=value end
 s.radioOverride=nil
 if type(receiveWirelessRedstone)=='function' then
  for i,pair in ipairs(s.owner.pairs) do
   local good,value=pcall(receiveWirelessRedstone,pair[1],pair[2])
   if good and finite(value) and value%1==0 and value>values[i] and value<=15 then
    s.radioOverride='RADIO_'..i..': demande '..values[i]..' reseau '..value
    break
   end
  end
 end
 return ok
end
local function fallback(why)
 -- Capture the first failure BEFORE sending fallback or discarding the controller.
 if not s.fault then
  local function n(value) return finite(value) and string.format('%.1f',value) or '?' end
  s.fault={cause=tostring(why),tick=tick,mass=mass,pitch=pitch,roll=roll,requested=s.lastRequested,
   target=s.core and s.core.target.y or nil,diagnostics=s.core and s.core.diagnostics or nil}
  s.fault.message='FAULT: '..tostring(why)..' | pitch='..n(pitch)..' roll='..n(roll)..' m='..n(mass)..(s.radioOverride and ' | '..s.radioOverride or '')
 end
 if s.owner then
  local values={} for i,r in ipairs(s.owner.rows) do values[i]=r[7] end
  send(values)
 end
 s.core=nil s.phase='fault' s.low=0 s.reason=s.fault.message
end
local advancing=server and (not s.tick or tick>s.tick)
local gap=server and s.tick and (tick<s.tick or tick-s.tick>10)
if s.owner and s.phase=='active' and (not server or not valid or s.signature~=signature or gap or not finite(enabled) or enabled<0 or enabled>15) then
 local cause
 if not finite(tick) or tick<=0 then cause='CLOCK: horloge serveur absente/invalide'
 elseif not finite(mass) or mass<=0 then cause='MASS: masse serveur absente/invalide'
 elseif not valid then cause=rejection or 'CONFIG: parametres invalides'
 elseif s.signature~=signature then cause='CONFIG_CHANGED: reglages/frequences modifies en vol'
 elseif gap then cause=(tick<s.tick and 'CLOCK_REGRESSION: ' or 'CLOCK_GAP: ')..tostring(s.tick)..' -> '..tostring(tick)
 else cause='ENABLE_VALUE: autorisation hors 0..15' end
 fallback(cause)
end
if server then
 if not finite(enabled) or enabled<0 or enabled>15 then
  if not s.owner and not s.fault then s.reason='ENABLE_VALUE: autorisation non numerique ou hors 0..15' end
 elseif enabled==0 then
  if s.owner and s.phase=='active' then fallback('Desactive: repli configure, pas de coupure des pales') end
  -- Disarming acknowledges a fault even if configuration now needs repair.
  -- Keep refreshing the frozen fallback channels; zero radio is full RPM here.
  if advancing and not gap then s.low=s.low+1 else s.low=0 end
  if s.low>=2 then
   s.fault=nil s.phase=valid and 'ready' or 'off'
   s.reason=valid and 'Pret: activer sans touche' or rejection or 'Configuration incomplete'
  end
 elseif finite(enabled) and enabled>0 and enabled<=15 and valid and not gap then
  local level=finite(pitch) and finite(roll) and math.abs(pitch)<=10 and math.abs(roll)<=10
  if s.phase~='active' then
   if s.fault then s.reason=s.fault.message
   elseif s.phase~='ready' then s.reason='BASELINE: mettre levier a 0 puis activer sans touche'
   elseif keys==1 and (forward~=0 or left~=0 or vertical~=0) then s.reason='KEYS_HELD: relacher touches F='..tostring(forward)..' L='..tostring(left)..' Y='..tostring(vertical)
   elseif not level then s.reason='LEVEL_WAIT: remettre le quad a plat (pitch='..tostring(pitch)..' roll='..tostring(roll)..'; depart +/-10 deg)' end
  end
  -- Permission is binary and independent of keyboard readiness. With no valid
  -- movement command, capture this position and stabilise at neutral demand.
  -- A valid held key still requires release before starting the controller.
  local neutral=keys~=1 or (forward==0 and left==0 and vertical==0)
  if s.phase=='ready' and neutral and level then
   local core,why=Quad.new(rows,pose,config)
   if core then
    s.info=nil s.core=core s.owner={pairs=pairs_,rows=core.model.rows} s.phase='active' s.reason='Boucle experimentale en cours'
    local trims={} for i,r in ipairs(core.model.rows) do trims[i]=math.max(r[2],math.min(r[3],math.floor(r[1]+.5))) end
    if not send(trims) then fallback('Echec transmission initiale') end
   else fallback(why) end
  end
  if s.phase=='active' and advancing and s.core.tick~=tick then
   -- On keyboard invalidity, brake/hold; never turn a missing command into rotor STOP.
   local command=keys==1 and {forward=forward,left=left,vertical=vertical} or {forward=0,left=0,vertical=0}
   local values,info=s.core:step(pose,command)
   if not values then fallback(info)
   elseif not send(values) then fallback('Echec transmission Link; reprise physique')
   else
    s.owner.rows=s.core.model.rows s.info=info
    local function n(value) return finite(value) and string.format('%.1f',value) or '?' end
    -- Requests, not actuator ACKs: expose the whole path on the existing panel.
    s.reason=(s.radioOverride and s.radioOverride..' | ' or '')..'RUN '..info.motion..(info.liftLimited and ' LIFT_LIMIT' or '')..' Vh='..n(info.horizontalSpeed)..' m='..n(mass)..' K='..tostring(keys)..' F='..n(command.forward)..' L='..n(command.left)..' Y='..n(command.vertical)..' R='..table.concat(values,'/')..' h='..n(info.altitude)..'>'..n(info.targetY)
   end
  end
 end
elseif not s.owner and not s.fault then
 s.reason=finite(tick) and tick>0 and ('MASS: masse serveur absente ('..tostring(mass)..'); verifier assemblage simule') or 'CLIENT/CLOCK: contexte client ou horloge serveur absente'
end
if s.owner and s.phase~='active' then
 local values={} for i,r in ipairs(s.owner.rows) do values[i]=r[7] end
 send(values)
end
if server then s.tick=tick end
s.signature=signature
s.label.setText(s.reason or modelWhy or 'Configurer les quatre sorties et le modele mesure')
if not server and not s.owner then
 -- Keep a typed reason available even when mass/clock prerequisites fail.
 emit('Last fault',s.fault and s.fault.message or '')
 emit('Status',s.reason) emit('Active',0) emit('Kalman ready',0) emit('Flight qualified',0) emit('Horizontal speed',0)
 return
end
emit('Last fault',s.fault and s.fault.message or '')
local active=s.phase=='active'
emit('Active',active and 1 or 0) emit('Flight qualified',0)
emit('Kalman ready',active and s.info and s.info.ready and 1 or 0)
emit('Horizontal speed',active and s.info and s.info.horizontalSpeed or 0)
emit('Altitude',s.info and s.info.altitude or 0) emit('Target altitude',s.core and s.core.target.y or s.fault and s.fault.target or 0)
local diagnostics=s.core and s.core.diagnostics or s.fault and s.fault.diagnostics
emit('Maximum thrust',diagnostics and diagnostics.maxThrust or 0) emit('Weight',diagnostics and diagnostics.required or 0) emit('Pressure',diagnostics and diagnostics.pressure or 0)
emit('Status',s.reason or modelWhy or 'Inactif')
if type(display)=='function' and server then
 display('MC_QUAD',s.reason or 'Inactif')
 if diagnostics and diagnostics.rotors then
  for i,r in ipairs(diagnostics.rotors) do display('MC_ROTOR_'..i,'Fmax '..string.format('%.1f',r.maximum)..' / RPM0 '..string.format('%.1f',r.rpm)..' / signal '..string.format('%.2f',r.trim)) end
 end
 if diagnostics then display('MC_FORCE','Fmax '..string.format('%.1f',diagnostics.maxThrust)..' / poids '..string.format('%.1f',diagnostics.required)..' / P '..string.format('%.3f',diagnostics.pressure)) end
end
