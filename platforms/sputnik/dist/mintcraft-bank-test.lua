local Probe=(function()
-- Small horizontal propulsion experiment. All hardware IO belongs to the node adapter.
-- Sense A/B, not a fabricated global vehicle front or a flight certificate.
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function wrap(v) return (v+180)%360-180 end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
local function point(v) return {x=v.x,y=v.y,z=v.z} end
local function bounded(v,lo,hi) return finite(v) and v>=lo and v<=hi end
function M.new(config,obs)
 if type(config)~='table' or not bounded(config.stop,0,15) or config.stop%1~=0 or not bounded(config.test,0,15) or config.test%1~=0 or config.test==config.stop or
  not bounded(config.maxProbe,.5,10) or not bounded(config.maxTravel,1,32) then return nil,'Explicit stop/test levels and test envelope required' end
 if type(obs)~='table' or not finite(obs.tick) or obs.tick<=0 or obs.tick%1~=0 or not finite(obs.mass) or obs.mass<=0 or type(obs.namespace)~='string' or #obs.namespace<1 or #obs.namespace>128 then return nil,'Actual server observation required' end
 for _,key in ipairs({'x','y','z','pitch','yaw','roll'}) do if not finite(obs[key]) then return nil,'Invalid initial observed '..key end end
 local self={config=config,phase='restA',reason='Waiting for real shaft and vessel rest',home=point(obs),mass=obs.mass,namespace=obs.namespace,pitch=obs.pitch,roll=obs.roll,
  report={kind='horizontal-functional-probe',flightQualified=false,identityAvailable=false,samples=0},rest=0,done=false,failed=false}
 function self:abort(why) self.failed=true self.phase='failed' self.reason=why return self:command() end
 function self:command()
  local running=self.phase=='pulseA' or self.phase=='pulseB'
  return {run=running and 15 or 0,power=running and self.config.test or self.config.stop,direction=self.direction}
 end
 function self:requested(tick)
  -- Attempted RPC only. Actual spinning and movement are required independently.
  if not self.requestTick then self.requestTick=tick end
 end
 function self:enter(phase,obs)
  self.phase=phase self.requestTick=nil self.rest=0 self.moving=0
  if phase=='selectA' or phase=='pulseA' then self.direction=0 end
  if phase=='selectB' or phase=='pulseB' then self.direction=15 end
  if phase=='restore' then self.direction=0 end
  if phase=='pulseA' or phase=='pulseB' then self.origin=point(obs) self.yaw=obs.yaw self.spinning=false end
  if phase=='coastA' or phase=='coastB' then self.stopPoint=point(obs) self.braking=0 end
 end
 function self:step(obs)
  if self.failed or self.done then return self:command() end
  if type(obs)~='table' then return self:abort('Server observations unavailable') end
  for _,key in ipairs({'tick','x','y','z','pitch','yaw','roll','mass','spin'}) do if not finite(obs[key]) then return self:abort('Nonfinite/missing observed '..key) end end
  if obs.tick%1~=0 or obs.spin<0 or obs.spin>15 or obs.namespace~=self.namespace or obs.mass<=0 then return self:abort('Shaft/world/vehicle observations changed') end
  if math.abs(obs.mass-self.mass)>self.mass*.02 then return self:abort('Mass changed during propulsion probe; no recertification') end
  if distance(obs,self.home)>self.config.maxTravel or math.abs(obs.y-self.home.y)>.5 or math.abs(wrap(obs.pitch-self.pitch))>8 or math.abs(wrap(obs.roll-self.roll))>8 then return self:abort('Operator probe envelope exceeded; propulsion stopped, lift untouched') end
  local old=self.previous
  if old and obs.tick<old.tick then return self:abort('Server clock regressed') end
  if old and obs.tick==old.tick then return self:command() end
  self.previous={tick=obs.tick,x=obs.x,y=obs.y,z=obs.z,yaw=obs.yaw,pitch=obs.pitch,roll=obs.roll}
  if not old then return self:command() end
  local dt=(obs.tick-old.tick)/20
  if dt>.5 then return self:abort('Server observation gap') end
  if not self.requestTick or obs.tick<=self.requestTick then return self:command() end
  local speed=distance(obs,old)/dt local vertical=math.abs(obs.y-old.y)/dt
  local angular=math.max(math.abs(wrap(obs.yaw-old.yaw)),math.abs(wrap(obs.pitch-old.pitch)),math.abs(wrap(obs.roll-old.roll)))/dt
  local steady=obs.spin==0 and speed<=.1 and vertical<=.1 and angular<=1
  self.report.samples=self.report.samples+1
  if self.phase=='pulseA' or self.phase=='pulseB' then
   if obs.spin==15 then self.spinning=true end
   local moved=distance(obs,self.origin)
   if self.spinning and obs.spin==15 and moved>=.25 then self.moving=self.moving+1 else self.moving=0 end
   if self.moving>=3 then
    local dx,dz=obs.x-self.origin.x,obs.z-self.origin.z local yaw=math.rad(self.yaw)
    local record={worldX=dx,worldZ=dz,bodyX=dx*math.cos(yaw)-dz*math.sin(yaw),bodyZ=dx*math.sin(yaw)+dz*math.cos(yaw),distance=moved,signal=self.config.test,spinningObserved=true}
    if self.phase=='pulseA' then self.report.A=record self:enter('coastA',obs)
    else
     local a=self.report.A
     local cosine=(record.bodyX*a.bodyX+record.bodyZ*a.bodyZ)/(record.distance*a.distance)
     record.opposition=cosine self.report.B=record
     if cosine>-.6 then return self:abort('Sense B did not oppose the measured motion of A') end
     self:enter('coastB',obs)
    end
   elseif (obs.tick-self.requestTick)/20>=self.config.maxProbe then return self:abort('No sufficient spinning + movement before maximum energized probe duration') end
  else
   self.rest=steady and self.rest+1 or 0
   if self.phase=='coastA' or self.phase=='coastB' then self.braking=math.max(self.braking,distance(obs,self.stopPoint)) end
   if self.rest>=6 then
    if self.phase=='restA' then self:enter('selectA',obs)
    elseif self.phase=='selectA' then self:enter('pulseA',obs)
    elseif self.phase=='coastA' then self.report.A.brakingDistance=self.braking self:enter('selectB',obs)
    elseif self.phase=='selectB' then self:enter('pulseB',obs)
    elseif self.phase=='coastB' then self.report.B.brakingDistance=self.braking self:enter('restore',obs)
    elseif self.phase=='restore' then self.phase='done' self.done=true self.report.functionalReverseMeasured=true end
   end
  end
  self.reason=self.phase=='done' and 'Two opposed movements and actual stops observed; not a flight certificate' or self.phase
  return self:command()
 end
 return self
end
return M

end)()
local BANK_DEFAULT=1
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
