-- Actual Link actuator adapter. Experimental near-level control, not certified flight.
local s=_G.MintCraftQuad
local names={'Avant gauche','Avant droite','Arriere gauche','Arriere droite'}
if not s then
 s={rotors={},low=0,phase='off',label=ui.label('Quad experimental: modele mesure obligatoire'),
  checked=ui.checkbox('Modele local et reprise physique verifies; essais experimentaux'),
  noise=ui.textfield(140),process=ui.textfield(140),speed=ui.textfield(140),climb=ui.textfield(140),tilt=ui.textfield(140)}
 s.noise.setValue('0.0025') s.process.setValue('4') s.speed.setValue('2') s.climb.setValue('1') s.tilt.setValue('8')
 s.help=ui.label('Bruit position R / acceleration Q / vitesse / montee / inclinaison max')
 for i,name in ipairs(names) do s.rotors[i]={label=ui.label(name..': Link puis trim,min,max,dY,dPitch,dRoll,repli'),a=ui.itempicker(),b=ui.itempicker(),row=ui.textfield(300)} end
 _G.MintCraftQuad=s
end
addElement(s.label) addElement(s.checked) addElement(s.help)
for _,key in ipairs({'noise','process','speed','climb','tilt'}) do addElement(s[key]) end
for _,r in ipairs(s.rotors) do addElement(r.label) addElement(r.a) addElement(r.b) addElement(r.row) end
local emit=output
if false then output('Status','string') output('Active',0) output('Altitude',0) output('Target altitude',0) output('Kalman ready',0) output('Flight qualified',0) end
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
local pose={tick=tick,mass=mass,x=x,y=y,z=z,pitch=pitch,yaw=yaw,roll=roll,dimension=dimension}
local server=finite(tick) and tick>0 and finite(mass) and mass>0
local rows,pairs_,seen,parts={}, {},{},{}
local valid=s.checked.isChecked() and type(transmitWirelessRedstone)=='function'
-- Reject collisions across keyboard, physical enable and all four rotor outputs.
local function binding(id)
 if type(id)~='string' or #id>386 then return false end
 local a,b=id:match('^([^,]+),([^,]+)$')
 return item(a) and item(b)
end
if not binding(enableBinding) then valid=false else seen[enableBinding]=true end
local count=0
if type(keyboardBindings)~='string' or #keyboardBindings>2400 then valid=false else
 for id in keyboardBindings:gmatch('[^|]+') do
  count=count+1
  if not binding(id) or seen[id] then valid=false end seen[id]=true
 end
end
if count~=6 then valid=false end
parts[#parts+1]=tostring(keyboardBindings)..':'..tostring(enableBinding)
for i,r in ipairs(s.rotors) do
 local a,b=r.a.getItem(),r.b.getItem() local text=r.row.getValue()
 parts[#parts+1]=tostring(a)..','..tostring(b)..':'..tostring(text)
 if not item(a) or not item(b) or seen[tostring(a)..','..tostring(b)] then valid=false end
 seen[tostring(a)..','..tostring(b)]=true pairs_[i]={a,b}
 rows[i]={}
 if type(text)~='string' or #text>256 then valid=false else
  -- Empty fields must not silently shift response columns.
  local count=0 for token in (text..','):gmatch('(.-),') do count=count+1 rows[i][count]=tonumber(token) or false end
  if count~=7 then valid=false end
 end
end
local config={}
for _,key in ipairs({'noise','process','speed','climb','tilt'}) do config[key]=tonumber(s[key].getValue()) parts[#parts+1]=tostring(config[key])
 if not finite(config[key]) or config[key]<=0 then valid=false end end
local model,modelWhy=Quad.model(rows) if not model then valid=false end
local signature=table.concat(parts,'|')
local function send(values)
 if not s.owner then return false end
 -- No Link ACK is available: RPC success is not proof of rotor response.
 local ok=true
 for i,pair in ipairs(s.owner.pairs) do
  local good=pcall(transmitWirelessRedstone,pair[1],pair[2],values[i]) if not good then ok=false end
 end
 return ok
end
local function fallback(why)
 if s.owner then
  local values={} for i,r in ipairs(s.owner.rows) do values[i]=r[7] end
  send(values)
 end
 s.core=nil s.phase='fault' s.low=0 s.reason=why
end
local advancing=server and (not s.tick or tick>s.tick)
local gap=server and s.tick and (tick<s.tick or tick-s.tick>10)
if s.owner and (not server or not valid or s.signature~=signature or gap or not finite(enabled) or enabled<0 or enabled>15) then
 fallback('Configuration/contexte/horloge perdu; repli mesure, reprise physique')
end
if server then
 if enabled==0 then
  if s.owner and s.phase=='active' then fallback('Desactive: repli configure, pas de coupure des pales') end
  if advancing and valid and not gap then s.low=s.low+1 else s.low=0 end
  if s.low>=2 then s.phase='ready' s.reason='Pret: activer sans touche' end
 elseif finite(enabled) and enabled>0 and enabled<=15 and valid and not gap then
  if s.phase=='ready' and keys==1 and forward==0 and left==0 and vertical==0 then
   local core,why=Quad.new(rows,pose,config)
   if core then
    s.info=nil s.core=core s.owner={pairs=pairs_,rows=model.rows} s.phase='active' s.reason='Stabilisation experimentale active'
    local trims={} for i,r in ipairs(model.rows) do trims[i]=r[1] end
    if not send(trims) then fallback('Echec transmission initiale') end
   else fallback(why) end
  end
  if s.phase=='active' and advancing and s.core.tick~=tick then
   -- On keyboard invalidity, brake/hold; never turn a missing command into rotor STOP.
   local command=keys==1 and {forward=forward,left=left,vertical=vertical} or {forward=0,left=0,vertical=0}
   local values,info=s.core:step(pose,command)
   if not values then fallback(info)
   elseif not send(values) then fallback('Echec transmission Link; reprise physique')
   else s.info=info s.reason=info.massChanged and 'Masse modifiee: adaptation du trim en vol' or keys~=1 and 'Clavier indisponible: freinage/maintien demande' or 'Stabilisation experimentale active' end
  end
 end
elseif not s.owner then s.reason='Configuration client; etat serveur via MC_QUAD' end
if s.owner and s.phase~='active' then
 local values={} for i,r in ipairs(s.owner.rows) do values[i]=r[7] end
 send(values)
end
if server then s.tick=tick end
s.signature=signature
s.label.setText(s.reason or modelWhy or 'Configurer les quatre sorties et le modele mesure')
if not server and not s.owner then return end
local active=s.phase=='active'
emit('Active',active and 1 or 0) emit('Flight qualified',0)
emit('Kalman ready',active and s.info and s.info.ready and 1 or 0)
emit('Altitude',s.info and s.info.altitude or 0) emit('Target altitude',s.core and s.core.target.y or 0)
emit('Status',s.reason or modelWhy or 'Inactif')
if type(display)=='function' and server then display('MC_QUAD',s.reason or 'Inactif') end
