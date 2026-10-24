-- Native adapter for ONE horizontal reversible mechanical bank. No lift controls.
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function level(v) return finite(v) and v%1==0 and v>=0 and v<=15 end
local function item(v) return type(v)=='string' and #v<=192 and v:match('^[a-z0-9_.%-]+:[a-z0-9_./%-]+$') and v~='minecraft:air' end
local s=_G.MintCraftBank
if not s then
 s={low=0,controls={},checks={},fields={}}
 _G.MintCraftBank=s
 s.title=ui.label('Banc horizontal: aucun canal de sustentation')
 s.note=ui.label('Etat serveur sur Display Link: MC_BANK_'..BANK_DEFAULT)
 s.checks.horizontal=ui.checkbox('Propulsion horizontale seulement')
 s.checks.failsafe=ui.checkbox('RUN 0 arrete via inverseur redstone/clutch')
 s.checks.second=ui.checkbox('Deux arbres independants: second retour requis')
 s.controls.spin2={label=ui.label('Second tachymetre si arbre independant'),first=ui.itempicker(),second=ui.itempicker()}
 for _,role in ipairs({'power','run','reverse','spin'}) do
  s.controls[role]={label=ui.label(({power='Transmission',run='Autorisation clutch via inverseur redstone',reverse='Inverseur mecanique',spin='Comparateur tachymetre'})[role]..': frequence'),first=ui.itempicker(),second=ui.itempicker()}
 end
 local function field(key,title,value)
  s.fields[key]={label=ui.label(title),value=ui.textfield(140)} s.fields[key].value.setValue(value)
 end
 field('group','Numero du groupe',tostring(BANK_DEFAULT))
 field('stop','Signal transmission arret VERIFIE','') field('test','Signal transmission essai faible','')
 field('duration','Duree MAX sous puissance, echec seulement','2') field('travel','Distance MAX du petit essai (m)','8')
end
addElement(s.title) addElement(s.note) addElement(s.checks.horizontal) addElement(s.checks.failsafe) addElement(s.checks.second)
addElement(s.controls.spin2.label) addElement(s.controls.spin2.first) addElement(s.controls.spin2.second)
for _,role in ipairs({'power','run','reverse','spin'}) do local p=s.controls[role] addElement(p.label) addElement(p.first) addElement(p.second) end
for _,key in ipairs({'group','stop','test','duration','travel'}) do local p=s.fields[key] addElement(p.label) addElement(p.value) end
local emit=output
if false then output('Bindings','string') output('Status','string') end
local consent=input('Enable binding','string')
local enabled=input('Enable') local selected=input('Selected group') local session=input('Session')
local tick=type(getUniverseTime)=='function' and getUniverseTime() or nil
local mass=type(getShipMass)=='function' and getShipMass() or nil
-- Client-side evaluation must not overwrite server status pins or issue commands.
if not finite(tick) or tick<=0 or not finite(mass) or mass<=0 then
 s.note.setText('Configuration client; etat reel via Display Link MC_BANK_'..BANK_DEFAULT)
 if s.owner then
  if type(transmitWirelessRedstone)=='function' then
   pcall(transmitWirelessRedstone,s.owner.run[1],s.owner.run[2],0)
   pcall(transmitWirelessRedstone,s.owner.power[1],s.owner.power[2],s.owner.stop)
  end
  if s.job then s.job:abort('Server clock/mass unavailable') end
  s.ready=false s.low=0 s.failure=s.session
  emit('Ready',0) emit('Failed session',s.failure or 0)
 end
 return
end
local config={}
local valid=s.checks.horizontal.isChecked() and s.checks.failsafe.isChecked() and type(consent)=='string' and #consent>0 and #consent<=386
local bindings,seen={},{}
if type(consent)=='string' then seen[consent]=true end
for _,role in ipairs({'power','run','reverse','spin'}) do
 local a,b=s.controls[role].first.getItem(),s.controls[role].second.getItem()
 if not item(a) or not item(b) then valid=false else
  local id=a..','..b
  if seen[id] then valid=false end seen[id]=true bindings[#bindings+1]=id config[role]={a,b}
 end
end
if s.checks.second.isChecked() then
 local a,b=s.controls.spin2.first.getItem(),s.controls.spin2.second.getItem()
 if not item(a) or not item(b) then valid=false else
  local id=a..','..b if seen[id] then valid=false end seen[id]=true bindings[#bindings+1]=id config.spin2={a,b}
 end
end
for key,p in pairs(s.fields) do config[key]=tonumber(p.value.getValue()) end
valid=valid and finite(config.group) and config.group%1==0 and config.group>=1 and config.group<=8 and level(config.stop) and level(config.test) and config.stop~=config.test and
 finite(config.duration) and config.duration>=.5 and config.duration<=10 and finite(config.travel) and config.travel>=1 and config.travel<=32
local signature=table.concat(bindings,'|')..':'..tostring(config.group)..':'..tostring(config.stop)..':'..tostring(config.test)..':'..tostring(config.duration)..':'..tostring(config.travel)..':'..tostring(consent)
local function send(c,role,value)
 local pair=c and c[role]
 if not pair or not level(value) or type(transmitWirelessRedstone)~='function' then return false end
 return pcall(transmitWirelessRedstone,pair[1],pair[2],value)
end
local function stopOld()
 if s.owner then send(s.owner,'run',0) send(s.owner,'power',s.owner.stop) end
end
local function failed(why)
 stopOld() if s.job then s.job:abort(why) s.failure=s.session end
 s.ready=false s.low=0 s.reason=why
end
local changed=s.signature and s.signature~=signature
local regression=s.tick and tick<s.tick
if changed or regression or not valid then failed(changed and 'Configuration changed' or regression and 'Clock regressed' or 'Bindings/explicit setup incomplete') end
s.signature=signature
local advancing=not s.tick or tick>s.tick s.tick=tick
local enable=finite(enabled) and enabled>0 and enabled<=15
if finite(enabled) and enabled==0 and valid and advancing then
 stopOld() s.low=s.low+1
 if s.low>=2 then s.ready=true s.job=nil s.session=nil s.failure=nil s.done=nil s.owner=nil end
elseif not finite(enabled) or enabled<0 or enabled>15 then failed('Physical enable invalid/STOP') end
if enable then s.low=0 end
local chosen=valid and s.ready and enable and selected==config.group and finite(session) and session%1==0 and session>0 and session<=tick
if s.job and not s.job.done and not s.job.failed and enable and (not chosen or s.session~=session or not advancing) then failed('Test selection/session/clock changed during run') chosen=false end
if chosen and (not s.job or s.session~=session) and advancing then
 -- Freeze the hardware mapping for the entire run; no live remapping.
 local ok,x,y,z=pcall(getPosition) local okq,pitch,yaw,roll=pcall(getOrientation)
 local okd,namespace=pcall(getDimension)
 if ok and okq and okd then
  local job,why=Probe.new({stop=config.stop,test=config.test,maxProbe=config.duration,maxTravel=config.travel},
   {tick=tick,x=x,y=y,z=z,pitch=pitch,yaw=yaw,roll=roll,mass=mass,namespace=namespace})
  if job then s.job=job s.owner=config s.session=session s.done=nil s.failure=nil else failed(why) end
 else failed('Native server pose unavailable') end
end
if chosen and s.job and s.session==session and advancing then
 local ok,x,y,z=pcall(getPosition) local okq,pitch,yaw,roll=pcall(getOrientation)
 local okd,namespace=pcall(getDimension)
 local pair=s.owner.spin local oks,spin=pcall(receiveWirelessRedstone,pair[1],pair[2])
 local other=spin
 if s.owner.spin2 then
  local p=s.owner.spin2 local ok2,value=pcall(receiveWirelessRedstone,p[1],p[2]) other=value oks=oks and ok2
 end
 oks=oks and level(spin) and level(other)
 local aggregate=oks and ((spin==0 and other==0) and 0 or (spin>0 and other>0) and 15 or 1) or nil
 local command
 if ok and okq and okd and oks then
  command=s.job:step({tick=tick,x=x,y=y,z=z,pitch=pitch,yaw=yaw,roll=roll,mass=mass,namespace=namespace,spin=aggregate})
 else command=s.job:abort('Actual pose/shaft observation failed') end
 local sent=true
 if command.run==0 then sent=send(s.owner,'run',0) end
 -- While running the same direction is retained; switching is only at rest.
 if command.direction~=nil then sent=send(s.owner,'reverse',command.direction) and sent end
 sent=send(s.owner,'power',command.power) and sent
 if command.run>0 and sent then sent=send(s.owner,'run',command.run) end
 if sent then s.job:requested(tick) else s.job:abort('Command API failed'); stopOld() end
 s.reason=({restA='Attente arret arbre et vehicule',selectA='Selection sens A au repos',pulseA='Mesure deplacement sens A',coastA='Attente arret apres A',selectB='Selection sens B au repos',pulseB='Mesure deplacement oppose B',coastB='Attente arret apres B',restore='Retour sens A, moteur arrete',done='Deux sens et arrets observes; pas de pilote arme'})[s.job.phase] or s.job.reason
 if s.job.done then s.done=session end
 if s.job.failed then s.failure=session s.ready=false stopOld() end
elseif s.owner then stopOld() end
-- No persistent model or in-game flight certificate is written.
local status=s.reason or (s.ready and 'Pret, attente selection' or 'Configuration puis Enable 0 requis')
s.note.setText(status)
if type(display)=='function' then pcall(display,'MC_BANK_'..tostring(config.group or BANK_DEFAULT),status) end
output('Group index',valid and config.group or 0)
output('Ready',valid and s.ready and 1 or 0)
emit('Bindings',valid and table.concat(bindings,'|') or '')
output('Done session',s.done or 0)
output('Failed session',s.failure or 0)
emit('Status',status)
output('Flight qualified',0)
