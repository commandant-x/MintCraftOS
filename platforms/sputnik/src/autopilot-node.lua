-- Sole physical writer in the universal graph. No client-side actuation.
local s=_G.MintCraftPilot
if not s then s={label=ui.label('Autopilote: montage puis OFF'),archive=ui.textfield(500),low=0,phase='DISARMED',requestSeen=''};s.archive.setValue('');_G.MintCraftPilot=s end
addElement(s.label);addElement(s.archive)
local emit=output
if false then output('Status','string') output('Acknowledged revision',0) output('Active',0) output('Altitude',0) output('Target altitude',0) output('Capabilities','string') output('Report','string') output('Geometry','string') output('Telemetry','string') output('Body yaw controlled',0) output('Flight qualified',0) output('Route','string') output('Position','string') output('Trace','string') end
local settings=input('Settings','string');local request=input('Request','string')
local enable=input('Enable');local enableBinding=input('Enable binding','string');local keyboard=input('Keyboard bindings','string');local keys=input('Commands valid')
local command={forward=input('Forward demand'),left=input('Left demand'),vertical=input('Vertical demand')}
local cut=input('Mechanical cut');local stop=input('Stop horizontal')
local feedback={}
for _,text in ipairs({input('Observations A','string'),input('Observations B','string')}) do
 if type(text)=='string' and #text<=4096 then for line in text:gmatch('[^\n]+') do
  local id,rpm,at=line:match('^([^,]+),([^,]+),([^,]+)$');id,rpm,at=tonumber(id),tonumber(rpm),tonumber(at)
  if id and id%1==0 and id>=1 and id<=32 and rpm and rpm>=0 and rpm<100000 and at then feedback[id]={rpm=rpm,tick=at} end
 end end
end
local liveBinding=s.core and s.activeEnableBinding or enableBinding
if type(liveBinding)=='string' and type(receiveWirelessRedstone)=='function' then
 local a,b=liveBinding:match('^([^,]+),([^,]+)$');local ok,value=pcall(receiveWirelessRedstone,a,b)
 enable=ok and value or -1
else enable=-1 end
local descriptors={}
for _,text in ipairs({input('Groups A','string'),input('Groups B','string')}) do
 if type(text)=='string' and #text<=38432 then for line in text:gmatch('[^\n]+') do descriptors[#descriptors+1]=line end
 elseif type(text)=='string' and text~='' then descriptors[#descriptors+1]='INVALID_OVERSIZE' end
end
local function read(name) if type(_G[name])=='function' then local ok,a,b,c=pcall(_G[name]);if ok then return a,b,c end end end
local tick=read('getUniverseTime');local mass=read('getShipMass')
local x,y,z=read('getPosition');local pitch,yaw,roll=read('getOrientation');local ix,iy,iz=read('getInertiaTensor')
local vx,vy,vz=read('getVelocity')
local pose={vx=vx,vy=vy,vz=vz,tick=tick,mass=mass,x=x,y=y,z=z,pitch=pitch,yaw=yaw,roll=roll,ix=ix,iy=iy,iz=iz,dimension=read('getDimension')}
local finite,copy=Vehicle.finite,Vehicle.copy
local server=finite(tick) and tick>0 and finite(mass) and mass>0
local function pieces(text,sep,max)
 if type(text)~='string' or #text>(max or 16000) then return {} end
 local out={};for value in (text..sep):gmatch('(.-)'..sep) do out[#out+1]=value end;return out
end
local function config()
 local p=pieces(settings,';',1024)
 if (#p~=10 and #p~=11) or p[1]~='MCU1' then return nil,'Reglages montage absents' end
 local c={profile=tonumber(p[2]),gravity=tonumber(p[3]),climb=tonumber(p[4]),tilt=tonumber(p[5]),margin=tonumber(p[6]),braking=tonumber(p[7]),released=p[10]=='1',steering=p[11]~='0',protected={}}
 for _,key in ipairs({'profile','gravity','climb','tilt','margin','braking'}) do if not finite(c[key]) then return nil,'Reglage '..key..' invalide' end end
 if c.profile%1~=0 or c.profile<1 or c.profile>5 or c.gravity<=0 or c.gravity>100 or c.climb<=0 or c.climb>5 or c.tilt<=0 or c.tilt>20 or c.margin<0 or c.braking<=0 then return nil,'Domaine reglages invalide' end
 if p[8]~='1' or p[9]~='1' then return nil,'Confirmer montage/reprise et zone degagee' end
 local a,b
 if type(enableBinding)=='string' then a,b=enableBinding:match('^([^,]+),([^,]+)$') end
 if not Vehicle.pair(a,b) then return nil,'Frequence Enable absente' end;c.protected[1]=enableBinding
 if type(keyboard)=='string' and keyboard~='' then
  local count=0;for pair in keyboard:gmatch('[^|]+') do local ka,kb=pair:match('^([^,]+),([^,]+)$');if not Vehicle.pair(ka,kb) then return nil,'Frequence clavier invalide' end;count=count+1;c.protected[#c.protected+1]=pair end
  if count~=6 then return nil,'Clavier: 6 paires requises ou aucune' end
 end
 local groups={};local signature={settings,enableBinding,tostring(keyboard)}
 for _,text in ipairs(descriptors) do
  if type(text)=='string' and text~='' then local g,why=Vehicle.decode(text);if not g then return nil,why end;groups[#groups+1]=g;signature[#signature+1]=Vehicle.encode(g) end
 end
 local ok,why=Vehicle.validate(groups,c.protected);if not ok then return nil,why end
 for _,g in ipairs(groups) do if g.x^2+g.y^2+g.z^2>c.margin^2 then return nil,'Rayon de coque insuffisant' end end
 return c,groups,table.concat(signature,'|')
end
local function pairKey(g) return table.concat({g.powerA,g.powerB,g.reverseA,g.reverseB,g.clutchA,g.clutchB},',') end
local function sameMappings(groups)
 if not s.owner then return true end
 if #groups~=#s.owner then return false end
 for i,g in ipairs(groups) do if pairKey(g)~=pairKey(s.owner[i]) then return false end end
 return true
end
local function send(signals,mechanical)
 if not s.owner or type(transmitWirelessRedstone)~='function' then return false end
 local ok,sent=true,{}
 local function tx(a,b,value) if a~='' then if not pcall(transmitWirelessRedstone,a,b,value) then ok=false end end end
 for _,g in ipairs(s.owner) do
  local signal=mechanical and ((g.kind=='linear' or g.kind=='surface') and 0 or 15) or signals and signals[tostring(g.id)] or g.fallback
  if not finite(signal) or signal%1~=0 or signal<0 or signal>15 then signal=g.fallback;ok=false end
  tx(g.powerA,g.powerB,signal);sent[tostring(g.id)]=signal
  local direction=s.core and s.core.directions[g.id] or s.directions and s.directions[g.id] or 1
  tx(g.reverseA,g.reverseB,direction<0 and 15 or 0)
  local stopped=mechanical or g.role=='drive' and signal==((g.kind=='linear' or g.kind=='surface') and 0 or 15)
  tx(g.clutchA,g.clutchB,stopped and 15-g.run or g.run)
 end
 s.lastSignals=sent
 return ok
end
local function fail(why)
 if not s.firstFault then s.firstFault=tostring(why) end
 if s.core then s.directions=copy(s.core.directions);s.savedEvents=copy(s.core.events) end
 s.core=nil;s.phase='DEGRADED';s.low=0;s.reason='Defaut: '..tostring(why)..'; repli configure, OFF requis';send(nil,s.cutLatched)
end
local c,groups,signature=config()
local valid=c~=nil
local advancing=server and (not s.tick or tick>s.tick)
local gap=server and s.tick and (tick<s.tick or tick-s.tick>10)
if server then
 if cut~=0 then
  if s.core then s.directions=copy(s.core.directions) end
  s.core=nil;s.cutLatched=true;s.phase='MECHANICAL_CUT';s.low=0;send(nil,true);s.reason='Coupure mecanique; altitude non maintenue'
 elseif not finite(enable) or enable<0 or enable>15 then fail('Enable invalide')
 elseif gap then fail('Horloge perdue/regressee')
 elseif enable==0 then
  if s.core then s.directions=copy(s.core.directions);s.core=nil end
  s.phase='DISARMED';send(nil,s.cutLatched)
  if valid and not c.released then s.releaseConsumed=false end
  if advancing then s.low=s.low+1 end
  if s.low>=2 then if valid then s.readySignature=signature end;s.firstFault=nil;s.reason=valid and 'Pret: activer sans touche' or tostring(groups) end
 elseif not s.core then
  if not valid then s.reason=tostring(groups)
  elseif s.low<2 or s.readySignature~=signature then s.reason='Armement: OFF physique requis'
  elseif keys==1 and (command.forward~=0 or command.left~=0 or command.vertical~=0) then s.reason='Armement: relacher touches'
  elseif not sameMappings(groups) and (not c.released or s.releaseConsumed) then s.reason='Remappage: confirmer anciens recepteurs retires'
  else
   c.candidate=s.archive.getValue();pose.gravity=c.gravity
   local core,why=Flight.new(groups,pose,c)
   if not core then s.reason=why
   else if sameMappings(groups) and s.owner and s.directions then for i,g in ipairs(groups) do core.directions[g.id]=s.directions[s.owner[i].id] or 1 end end;s.cutLatched=false;s.releaseConsumed=c.released;s.core=core;s.activeKeyboard=keyboard;s.activeEnableBinding=enableBinding;s.owner=copy(groups);for _,g in ipairs(s.owner) do if g.fallback==-1 then g.fallback=core.initialSignals[tostring(g.id)] end end;s.signature=signature;s.phase='HOLDING';s.low=0;s.lastSignals=copy(core.initialSignals);s.requestSeen=request;s.reason='Maintien initialise; montage non certifie' end
  end
 end
 if s.core and advancing then
  pose.gravity=s.core.config.gravity
  if type(request)=='string' and request~='' and request~=s.requestSeen then
   s.requestSeen=request;local r=pieces(request,'|',25000)
   if #r==8 and r[1]=='MCC1' then
    local accepted,why=s.core:apply({revision=tonumber(r[2]),mode=r[3],altitude=tonumber(r[4]),speed=tonumber(r[5]),heading=tonumber(r[6]),route=r[7],zones=r[8]},pose)
    s.commandError=not accepted and why or nil
   else s.commandError='Format de consigne invalide' end
  end
  if stop~=0 then if s.core.calibration and not s.core.calibration.complete then s.core.calibration:pause('STOP horizontal') end;if s.core.mission then s.core.mission:pause('STOP horizontal') end;s.core.mode='HOLD';command={forward=0,left=0,vertical=0} end
  if keys~=1 then command={forward=0,left=0,vertical=0} end
  -- Sample validated keyboard channels directly: avoid an extra graph stage.
  if keys==1 and type(receiveWirelessRedstone)=='function' then
   local levels={};for pair in (s.activeKeyboard or keyboard):gmatch('[^|]+') do local a,b=pair:match('^([^,]+),([^,]+)$');local ok,value=pcall(receiveWirelessRedstone,a,b);if not ok or not finite(value) or value<0 or value>15 or value%1~=0 then levels={};break end;levels[#levels+1]=value>0 and 1 or 0 end
   if #levels==6 then command={forward=levels[1]-levels[2],left=levels[3]-levels[4],vertical=levels[5]-levels[6]} else command={forward=0,left=0,vertical=0} end
  end
  if stop~=0 then command={forward=0,left=0,vertical=0} end
  -- A new core starts at this tick; first control update is the following tick.
  if s.core.tick~=tick then
   local ok,signals,info=pcall(s.core.step,s.core,pose,command,s.lastSignals,feedback)
   if not ok then fail('Erreur calcul: '..tostring(signals))
   elseif not signals then fail(info)
   elseif not send(signals) then fail('Emission Link en echec')
   else
    s.info=info;s.phase=info.phase;s.reason=info.phase..' m='..string.format('%.1f',mass)..' h='..string.format('%.2f',y)..'>'..string.format('%.2f',info.targetY)..' V='..string.format('%.2f',info.speed)..' | '..info.reason
   end
  else send(s.lastSignals) end
 end
 if s.owner and not s.core then send(nil,s.cutLatched) end
 s.tick=tick
elseif s.owner then fail('Contexte serveur/masse perdu') else s.reason='Client: voir serveur' end
local reason=s.reason or 'Configurer le montage'
if s.core and signature~=s.signature then reason=reason..' | Montage en attente OFF' end
if s.commandError then reason=reason..' | '..s.commandError end
if s.firstFault then reason=reason..' | FIRST='..s.firstFault end
s.label.setText(reason)
local core=s.core;local cal=core and core.calibration;local caps={};if core and core.capabilities then for _,name in ipairs(Response.axes) do caps[#caps+1]=name..'='..tostring(core.capabilities[name].available) end end
local report='MCREPORT1 | '..reason..' | ACK='..tostring(core and core.revision or 0)..' | RX_ACK=false | Gearshift_ACK=false | Terrain=inconnu'
if core and core.massAdapted then report=report..' | Trim masse actif' end
if s.info then report=report..' | Residual='..tostring(s.info.residual)..' Sat='..tostring(s.info.saturated) end
for _,event in ipairs(core and core.events or s.savedEvents or {}) do report=report..'\n'..event.tick..':'..event.reason end
for _,g in ipairs(s.owner or {}) do report=report..'\nG'..g.id..' TX='..tostring(s.lastSignals and s.lastSignals[tostring(g.id)])..' Etat_est='..tostring(core and core.spool[g.id] or '?') end
if server and cal and (cal.complete or cal.paused) and not core.archived then core.snapshot=Calibration.archive(cal,cal.mass);core.archived=true end
if server and core and core.snapshot then s.archive.setValue(core.snapshot) end
local geometry={};for _,g in ipairs(s.owner or {}) do geometry[#geometry+1]=table.concat({g.x,g.y,g.z},',') end
emit('Status',reason);emit('Active',core and 1 or 0);emit('Report',report)
if server then
 emit('Acknowledged revision',core and core.revision or 0);emit('Altitude',y or 0);emit('Target altitude',core and core.target.y or 0)
 local route,trace={},{}
 if core and core.mission then for _,p in ipairs(core.mission.route) do route[#route+1]=table.concat({p.x,p.y,p.z},',') end;for _,p in ipairs(core.mission.trace) do trace[#trace+1]=table.concat({p.x,p.y,p.z},',') end end
 emit('Route',table.concat(route,';'));emit('Position',table.concat({x,y,z},','));emit('Trace',table.concat(trace,';'))
 emit('Capabilities',table.concat(caps,' '));emit('Geometry',table.concat(geometry,';'));emit('Telemetry',reason);emit('Body yaw controlled',core and core.bodyYawControlled and 1 or 0);emit('Flight qualified',0)
 if type(display)=='function' then pcall(display,'MC_AUTOPILOT',reason);pcall(display,'MC_CAPABILITIES',table.concat(caps,' ')) end
end
