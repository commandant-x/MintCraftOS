-- Server-independent flight controller. Native adapter alone owns all Link writes.
local M={schema=1}
local V=Vehicle
local clip,finite=V.clip,V.finite
local function wrap(x) return (x+180)%360-180 end
local function vec(x,y,z) return {x=x,y=y,z=z} end
function M.pose(p)
 for _,key in ipairs({'tick','x','y','z','pitch','yaw','roll','mass','ix','iy','iz'}) do if not finite(p[key]) then return nil,'Télémétrie '..key..' absente' end end
 if p.tick<=0 or p.mass<=0 or p.ix<=0 or p.iy<=0 or p.iz<=0 or p.dimension~='minecraft:overworld' then return nil,'Contexte physique Overworld requis' end
 p.q=V.quaternion(p.pitch,p.yaw,p.roll);p.gravity=p.gravity or 11
 return p
end
function M.new(groups,p,config)
 local valid,why=V.validate(groups,config.protected);if not valid then return nil,why end
 p,why=M.pose(p);if not p then return nil,why end
 if math.abs(p.pitch)>10 or math.abs(p.roll)>10 then return nil,'Depart a plat +/-10 deg requis' end
 local s={groups=V.copy(groups),config=V.copy(config),referenceMass=p.mass,tick=p.tick,previous=p,velocity=vec(0,0,0),omega=vec(0,0,0),angularAcceleration=vec(0,0,0),acceleration=vec(0,0,0),
  filters={},target=vec(p.x,p.y,p.z),home=vec(p.x,p.y,p.z),mode='HOLD',phase='HOLDING',directions={},shifts={},spool={},quant={},events={},revision=0,integral=0,angleBias=vec(0,0,0),course=p.yaw,heading=p.yaw,progress=Progress.new(),samples=0}
 for _,axis in ipairs({'x','y','z'}) do s.filters[axis]=Filter.filter(p[axis],.0025,4);s.velocity[axis]=finite(p['v'..axis]) and p['v'..axis] or 0;s.filters[axis].v=s.velocity[axis] end
 for _,g in ipairs(groups) do s.directions[g.id]=1;s.spool[g.id]=(g.kind=='linear' or g.kind=='surface') and g.neutral or Physics.rpm(g.source,g.neutral) end
 local initial,metadata,offset=V.matrix(s.groups,p,s.velocity,p.mass,s.directions)
 if not initial then return nil,metadata end
 local gravity=Geometry.bodyVector(vec(0,p.gravity,0),p.q)
 local wanted={gravity.z-offset[1],gravity.x-offset[2],gravity.y-offset[3],-offset[4],-offset[5],-offset[6]}
 local allocation,result=V.solve(initial,wanted);if not allocation then return nil,result end
 if math.abs(result.actual[3]-wanted[3])>math.max(.5,p.gravity*.1) then return nil,'Portance modele insuffisante au depart' end
 if math.max(math.abs(result.actual[4]-wanted[4]),math.abs(result.actual[5]-wanted[5]),math.abs(result.actual[6]-wanted[6]))>.1 then return nil,'Equilibre sustentation invalide' end
 for i,m in ipairs(metadata) do m.column=initial.columns[i].response end
 s.initialSignals=V.signals(metadata,allocation,s.quant)
 if not s.initialSignals then return nil,'Initialisation niveaux impossible' end
 s.capabilities=V.capabilities(initial,s.groups)
 function s:event(reason)
  self.events[#self.events+1]={tick=self.tick,reason=reason};if #self.events>64 then table.remove(self.events,1) end
 end
 function s:apply(c,p)
  if type(c)~='table' or not finite(c.revision) or c.revision%1~=0 or c.revision<=self.revision then return false,'Commande ancienne/dupliquee' end
  local modes={HOLD=true,ALTITUDE=true,HEADING=true,ROUTE=true,PAUSE=true,RESUME=true,CANCEL=true,RETURN=true,CALIBRATE=true,CAL_PAUSE=true,CAL_RESUME=true,CAL_ABORT=true,MANUAL=true}
  if not modes[c.mode] then return false,'Mode inconnu' end
  for _,key in ipairs({'altitude','speed','heading'}) do if not finite(c[key]) then return false,'Consigne '..key..' invalide' end end
  if c.speed<0 then return false,'Vitesse positive ou 0 libre requise' end
  local route,zones,why
  if c.mode=='ROUTE' or c.mode=='RETURN' then
   if not self.capabilities.travel then return false,'Guidage horizontal indisponible sur ce montage' end
   if not self.calibration or not self.calibration.complete or not self.calibration.horizontalVerified then return false,'Essais aller-retour requis' end
   route,why=Mission.parse(c.route or '');if not route then return false,why end
   zones,why=Mission.parse(c.zones or '',true);if not zones then return false,why end
   if c.mode=='RETURN' then route={{x=self.home.x,y=self.home.y,z=self.home.z,speed=c.speed}} end
   if #route==0 then return false,'Route vide' end
  end
  if c.mode=='HOLD' or c.mode=='ALTITUDE' or c.mode=='HEADING' or c.mode=='MANUAL' or c.mode=='CALIBRATE' then if self.mission then self.mission:pause('Consigne directe prioritaire') end end
  if c.mode~='CALIBRATE' and c.mode~='CAL_RESUME' and c.mode~='CAL_PAUSE' and self.calibration and not self.calibration.complete then self.calibration:pause('Consigne directe prioritaire') end
  if c.mode=='PAUSE' then if self.mission then self.mission:pause('Pause operateur') end
  elseif c.mode=='RESUME' then if not self.mission or self.mission.completed then return false,'Aucune mission a reprendre' end;self.mission:resume()
  elseif c.mode=='CANCEL' then self.mission=nil
  elseif c.mode=='ROUTE' or c.mode=='RETURN' then self.mission=Mission.new(route,zones,self.config.margin or 1,self.home);self.mission.surface=self.capabilities.surface
  elseif c.mode=='CALIBRATE' then self.calibration=Calibration.new(self.groups,p,self.capabilities or {},self.snapshot or self.config.candidate)
  elseif c.mode=='CAL_PAUSE' then if self.calibration then self.calibration:pause() end
  elseif c.mode=='CAL_RESUME' then if self.calibration and self.calibration.aborted then return false,'Essais abandonnes: relancer' end;if self.calibration then self.calibration:resume() end
  elseif c.mode=='CAL_ABORT' then if self.calibration then self.calibration:pause('Abandon, mesures conservees');self.calibration.aborted=true;self.calibration.phase='ABORTED' end
  end
  self.revision=c.revision;self.archived=nil;self.accepted=V.copy(c)
  self.mode=c.mode=='RESUME' and 'ROUTE' or c.mode=='RETURN' and 'ROUTE' or c.mode
  local previousY=self.target.y;self.target=vec(p.x,p.y,p.z)
  if c.mode~='HOLD' and c.mode~='CALIBRATE' and c.mode~='ROUTE' and c.mode~='RETURN' then self.target.y=previousY end
  if c.mode=='ALTITUDE' or c.mode=='HEADING' then self.target.y=c.altitude end
  self.speed=c.speed;self.heading=wrap(c.heading);self.navigationHeading=p.yaw;self.progress=Progress.new();self:event('Consigne acceptee '..c.revision..' '..c.mode)
  return true
 end
 function s:step(p,command,lastSignals,feedback)
  local cfg=self.config
  local pending=self.shifts
  local groupList=self.groups
  local mass0=self.referenceMass
  local cal=self.calibration
  local mission=self.mission
  local omegaNow=self.omega
  local accelNow=self.angularAcceleration
  local why;p,why=M.pose(p);if not p then return nil,why end
  if p.dimension~=self.previous.dimension then return nil,'Dimension modifiee' end
  local dt=(p.tick-self.tick)/20;if dt<=0 or dt>.5 then return nil,'Horloge repetee/regressee/perdue' end
  for _,key in ipairs({'forward','left','vertical'}) do if not finite(command[key]) or math.abs(command[key])>1 then return nil,'Commande clavier invalide' end end
  local oldV=V.copy(self.velocity)
  for _,axis in ipairs({'x','y','z'}) do
   local k=self.filters[axis]
   if math.abs(p[axis]-k.x-k.v*dt)>20 then return nil,'Discontinuite de pose' end
   if not Filter.update(k,p[axis],dt) then return nil,'Estimateur perdu' end
   self.velocity[axis]=k.v;self.acceleration[axis]=self.acceleration[axis]+dt/(.1+dt)*((k.v-oldV[axis])/dt-self.acceleration[axis])
  end
  local worldRate=Geometry.angularVelocity(self.previous.q,p.q,dt);if not worldRate then return nil,'Rotation non observable' end
  local rate=Geometry.bodyVector(worldRate,p.q)
  for _,axis in ipairs({'x','y','z'}) do local old=omegaNow[axis];omegaNow[axis]=old+dt/(.05+dt)*(rate[axis]-old);accelNow[axis]=accelNow[axis]+dt/(.1+dt)*((omegaNow[axis]-old)/dt-accelNow[axis]) end
  self.tick=p.tick;self.samples=self.samples+1
  local v=self.velocity;local speed=math.sqrt(v.x^2+v.z^2);local yaw=math.rad(p.yaw)
  local forward,left=command.forward,command.left
  local manual=forward~=0 or left~=0 or command.vertical~=0
  if manual and not self.wasManual then self.heading=p.yaw;self.course=p.yaw end
  self.wasManual=manual
  if manual then
   if mission and not mission.paused then mission:pause('Priorite clavier: reprise explicite requise') end
   if cal and not cal.complete and not cal.paused then cal:pause('Priorite clavier; reprise essais explicite') end
   self.target=vec(p.x,self.target.y,p.z);self.target.y=self.target.y+command.vertical*(cfg.climb or 1)*dt
  end
  local provisional=V.matrix(groupList,p,v,mass0,nil)
  if not provisional then return nil,'Modele physique indisponible' end
  local caps=V.capabilities(provisional,groupList)
  local drive,yawAvailable=caps.drive,caps.yaw.available
  self.capabilities=caps;self.bodyYawControlled=yawAvailable
  -- Passive stop measurements: motion evidence, not an RX/shaft acknowledgement.
  self.brakeSamples=self.brakeSamples or {}
  local phase=cal and cal.phase or ''
  local measuring=manual or phase=='FORWARD' or phase=='RETURN' or phase=='BACK' or phase=='BACK_RETURN' or mission and not mission.paused
  if speed>.3 and (measuring or self.brakeTrial) then
   if not self.brakeTrial or speed>self.brakeTrial.speed+.03 then self.brakeTrial={speed=speed,x=p.x,z=p.z,distance=0,tick=p.tick,ux=v.x/speed,uz=v.z/speed}
   else local t=self.brakeTrial;if (t.ux*v.x+t.uz*v.z)/math.max(.001,speed)<.96 then t.invalid=true end;t.distance=t.distance+math.sqrt((p.x-t.x)^2+(p.z-t.z)^2);t.x,t.z=p.x,p.z;if not t.reaction and speed<t.speed*.95 then t.reaction=(p.tick-t.tick)/20 end end
  elseif speed<=.1 and self.brakeTrial then
   local t=self.brakeTrial;self.brakeTrial=nil
   if t.distance>.02 and not t.invalid then
    self.brakeSamples[#self.brakeSamples+1]={deceleration=t.speed^2/(2*t.distance),speed=t.speed,reaction=t.reaction or 0}
    if #self.brakeSamples>8 then table.remove(self.brakeSamples,1) end
    if #self.brakeSamples>=2 then local a,r=math.huge,0;for _,sample in ipairs(self.brakeSamples) do a=math.min(a,sample.deceleration);r=math.max(r,sample.reaction) end;cfg.braking=math.min(cfg.braking or a,a);self.reaction=r end
   end
  end
  local desired=nil;local probe
  if cal and not cal.paused and not cal.complete and not manual then desired,probe=cal:step(p,v,omegaNow,true);self.phase='CALIBRATING'
  elseif mission and not manual then desired=mission:step(p,v);self.phase=mission.phase
  else self.phase='HOLDING' end
  local worldAx,worldAz=0,0;local desiredYaw=p.yaw;local aligning=false
  local tilt=cfg.tilt or 8;local acceleration=p.gravity*math.tan(math.rad(tilt))
  if desired then
   if Mission.distance(desired,self.target)>0 then self.progressKey=nil end
   self.target=vec(desired.x,desired.y,desired.z)
   local dx,dz=desired.x-p.x,desired.z-p.z;local distance=math.sqrt(dx*dx+dz*dz)
   local brake=cfg.braking or acceleration;local reaction=self.reaction or .5
   local requestedSpeed=math.min(.6*distance,math.sqrt((brake*reaction)^2+2*brake*math.max(0,distance-.05))-brake*reaction)
   if desired.speed and desired.speed>0 then requestedSpeed=math.min(requestedSpeed,desired.speed) end
   if caps.surface and not yawAvailable and distance>.5 and math.abs(dx*math.sin(yaw)+dz*math.cos(yaw))<.2*distance then forward=1 end
   local tx,tz=distance>.01 and dx/distance*requestedSpeed or 0,distance>.01 and dz/distance*requestedSpeed or 0
   worldAx,worldAz=1.2*(tx-v.x),1.2*(tz-v.z)
   if caps.surface and not yawAvailable and distance>.5 and math.abs(dx*math.sin(yaw)+dz*math.cos(yaw))<.2*distance then worldAx,worldAz=acceleration*.3*math.sin(yaw),acceleration*.3*math.cos(yaw) end
   if desired.heading and (yawAvailable or caps.surface) then desiredYaw=desired.heading;if caps.surface and caps.reverse and math.abs(wrap(desiredYaw-(self.navigationHeading or p.yaw)))>90 then desiredYaw=wrap(desiredYaw+180) end;self.navigationHeading=desiredYaw;left=clip(-wrap(desiredYaw-p.yaw)/45,-1,1);forward=0
   elseif yawAvailable or caps.surface then
    if distance>.5 then local bearing=math.deg(Geometry.atan2(dx,dz));if caps.reverse and math.abs(wrap(bearing-(self.navigationHeading or p.yaw)))>90 then bearing=wrap(bearing+180) end;self.navigationHeading=bearing end
    desiredYaw=self.navigationHeading or self.heading;left=clip(-wrap(desiredYaw-p.yaw)/45,-1,1);forward=clip((tx*math.sin(yaw)+tz*math.cos(yaw)-(v.x*math.sin(yaw)+v.z*math.cos(yaw)))*.5,-1,1) end
   if drive and yawAvailable and not caps.surface and math.abs(wrap(desiredYaw-p.yaw))>20 then
    aligning=true;self.phase='ALIGNING';worldAx,worldAz=-1.2*v.x,-1.2*v.z
   end
  elseif manual then
   if (yawAvailable or caps.surface) and cfg.steering~=false then self.heading=wrap(self.heading-left*30*dt);desiredYaw=self.heading
   elseif cfg.steering~=false then
    if speed>.3 then self.course=self.course-left*math.deg(acceleration/math.max(.3,speed))*dt end
    local angle=math.rad(self.course)
    worldAx=acceleration*forward*math.sin(angle)-left*acceleration*math.cos(angle)
    worldAz=acceleration*forward*math.cos(angle)+left*acceleration*math.sin(angle)
    if forward==0 and speed<.3 then worldAx,worldAz=0,0 end
   end
   if yawAvailable or caps.surface or cfg.steering==false then worldAx=acceleration*(forward*math.sin(yaw)-left*math.cos(yaw));worldAz=acceleration*(forward*math.cos(yaw)+left*math.sin(yaw)) end
  elseif self.mode=='HEADING' then
   desiredYaw=(yawAvailable or caps.surface) and self.heading or p.yaw
   local angle=math.rad(self.heading);local request=self.speed or 0
   worldAx=1.2*(request*math.sin(angle)-v.x);worldAz=1.2*(request*math.cos(angle)-v.z)
   forward=clip((request*math.cos(angle-yaw)-(v.x*math.sin(yaw)+v.z*math.cos(yaw)))*.5,-1,1)
   left=yawAvailable and clip(-wrap(self.heading-p.yaw)/45,-1,1) or 0
  else
   desiredYaw=(yawAvailable or caps.surface) and self.heading or p.yaw
   if speed>.12 then
    self.braking=true;worldAx=-1.2*(v.x+.4*self.acceleration.x);worldAz=-1.2*(v.z+.4*self.acceleration.z);self.target.x=p.x;self.target.z=p.z
   else
    self.braking=false;worldAx=.3*(self.target.x-p.x)-.9*v.x;worldAz=.3*(self.target.z-p.z)-.9*v.z
   end
   if drive then forward=clip((worldAx*math.sin(yaw)+worldAz*math.cos(yaw))*.5,-1,1) end
  end
  if not caps.travel or self.verticalLimited then worldAx,worldAz=0,0;forward,left=0,0 end
  local length=math.sqrt(worldAx^2+worldAz^2);if length>acceleration then worldAx,worldAz=worldAx*acceleration/length,worldAz*acceleration/length end
  local up=V.world(vec(0,1,0),p.q)
  if up.y<=.1 then return nil,'Sustentation retournee: maintien impossible' end
  local recovering=math.acos(clip(up.y,-1,1))>math.rad(math.max(12,tilt+5))
  if recovering then
   worldAx,worldAz=0,0;forward,left=0,0;self.phase='DEGRADED';self.recovering=true
   if mission then mission:pause('Recuperation assiette') end
   if cal then cal:pause('Recuperation assiette') end
  elseif self.recovering and math.acos(clip(up.y,-1,1))<math.rad(5) then self.recovering=false;self:event('Assiette recuperee') end
  local pitchTarget,rollTarget=0,0
  if not drive and caps.pitch.available and caps.roll.available then
   pitchTarget=math.deg(math.atan((worldAx*math.sin(yaw)+worldAz*math.cos(yaw))/p.gravity))
   rollTarget=-math.deg(math.atan((worldAx*math.cos(yaw)-worldAz*math.sin(yaw))/p.gravity));worldAx,worldAz=0,0
  end
  local error=V.attitudeError(p.q,V.quaternion(pitchTarget,desiredYaw,rollTarget))
  local px,pz,modular,dedicatedYaw=3,3,false,false
  for _,g in ipairs(groupList) do dedicatedYaw=dedicatedYaw or g.role=='yaw-left' or g.role=='yaw-right' end
  for _,g in ipairs(groupList) do if g.role=='lift' and g.kind~='linear' and g.kind~='surface' then
   local thrust,flow=V.coefficients(g);local damping=thrust*Physics.pressure(p.y+g.y)*g.members/flow
   px=px+1.5*g.z^2*damping/p.ix;pz=pz+1.5*g.x^2*damping/p.iz;modular=modular or g.kind=='bearing'
  end end
  local dr,da=modular and 8 or 4.5,modular and 1.2 or .6
  local yawDemand=dedicatedYaw and 6*error.y-8*omegaNow.y-1.2*accelNow.y or .5*error.y-3*omegaNow.y-accelNow.y
  local angular=vec(clip(px,4,40)*error.x-dr*omegaNow.x-da*accelNow.x,yawDemand,clip(pz,4,40)*error.z-dr*omegaNow.z-da*accelNow.z)
  -- Adapt only after a measured mass change, during holding/baseline; never
  -- turn a tracking transient or a commissioning pulse into a learned trim.
  if math.abs(p.mass-mass0)>mass0*1e-6 then self.massAdapted=true end
  for _,axis in ipairs({'x','z'}) do
   local capable=axis=='x' and caps.pitch.available or axis=='z' and caps.roll.available
   if self.massAdapted and capable and not manual and (not desired or cal and cal.phase=='BASELINE') and not probe and not recovering and not self.verticalLimited and math.abs(error[axis])>.00175 and math.abs(error[axis])<.1 and math.abs(omegaNow[axis])<.1 and (not self.info or self.info.residual<.5) then self.angleBias[axis]=clip(self.angleBias[axis]+2*error[axis]*dt,-2,2) end
   angular[axis]=angular[axis]+self.angleBias[axis]
  end
  if not caps.pitch.available then angular.x=0 end;if not yawAvailable and not caps.surface then angular.y=0 end;if not caps.roll.available then angular.z=0 end
  local yError=self.target.y-self.filters.y.x
  local desiredVy=clip(yError,-(cfg.climb or 1),cfg.climb or 1)
  local ay=2*(desiredVy-v.y)+self.integral-.4*self.acceleration.y
  local body=Geometry.bodyVector(vec(worldAx,0,worldAz),p.q)
  if not caps.right.available then body.x=0 end
  if not drive and not caps.forward.available then body.z=0 end
  local right=V.world(vec(1,0,0),p.q);local front=V.world(vec(0,0,1),p.q)
  body.y=(ay+p.gravity-body.x*right.y-body.z*front.y)/up.y
  local reversing={}
  local driveCount,arms=0,vec(0,0,0)
  for _,g in ipairs(groupList) do if g.role=='drive' then driveCount=driveCount+1;arms.x=arms.x+(g.y*g.dz-g.z*g.dy)^2;arms.y=arms.y+(g.z*g.dx-g.x*g.dz)^2;arms.z=arms.z+(g.x*g.dy-g.y*g.dx)^2 end end
  for _,g in ipairs(groupList) do
   local alpha=select(3,V.coefficients(g));local previous=lastSignals and lastSignals[tostring(g.id)] or g.neutral
   local rpm=(g.kind=='linear' or g.kind=='surface') and previous or Physics.rpm(g.source,previous)
   self.spool[g.id]=self.spool[g.id]+(1-(1-alpha)^(dt*20))*(rpm-self.spool[g.id])
   if g.role=='drive' and g.reverseA~='' then
    local intention=p.mass*(body.x*g.dx+body.y*g.dy+body.z*g.dz)/math.max(1,driveCount)
    if arms.x>1e-9 then intention=intention+(g.y*g.dz-g.z*g.dy)*angular.x*p.ix/arms.x end
    if arms.y>1e-9 then intention=intention+(g.z*g.dx-g.x*g.dz)*angular.y*p.iy/arms.y end
    if arms.z>1e-9 then intention=intention+(g.x*g.dy-g.y*g.dx)*angular.z*p.iz/arms.z end
    local sign=intention<-.05 and -1 or intention>.05 and 1 or self.directions[g.id]
    if not pending[g.id] and sign~=self.directions[g.id] then pending[g.id]={d=sign,t=p.tick} end
    local shift=pending[g.id]
    if shift then
     reversing[g.id]=true
     local sample=feedback and feedback[g.id]
     local valid=sample and sample.tick<=p.tick and p.tick-sample.tick<=2 and finite(sample.rpm) and sample.rpm>=0
     local observed=valid and sample.tick>shift.t
     local stopped=observed and sample.rpm<=.5 or not valid and self.spool[g.id]<=.5 and p.tick>shift.t
     if stopped then self.directions[g.id]=shift.d;pending[g.id]=nil;if observed then self.spool[g.id]=sample.rpm end;self:event(observed and 'Inversion: arret observe' or 'Inversion: arret estime') end
    end
   end
  end
  local model,meta,offset=V.matrix(groupList,p,v,mass0,self.directions)
  if not model then return nil,meta end
  for i,m in ipairs(meta) do
   if reversing[m.group.id] then for j=1,6 do model.columns[i].response[j]=0 end end
   m.column=model.columns[i].response
  end
  local wanted={body.z,body.x,body.y,angular.x,angular.y,angular.z}
  for j=1,6 do wanted[j]=wanted[j]-offset[j] end
  local values,allocation=V.solve(model,wanted);if not values then return nil,allocation end
  if probe then values[probe.index]=clip(values[probe.index]+probe.delta,0,15) end
  local signals,why=V.signals(meta,values,self.quant);if not signals then return nil,why end
  for _,g in ipairs(groupList) do if reversing[g.id] then signals[tostring(g.id)]=g.kind=='linear' and 0 or 15 end end
  if math.abs(allocation.actual[3]-wanted[3])<.1 then self.integral=clip(self.integral+.2*yError*dt,-3,3) end
  self.verticalLimited=math.abs(allocation.actual[3]-wanted[3])>math.max(1,math.abs(wanted[3])*.25)
  if self.verticalLimited then self.phase='DEGRADED';if mission then mission:pause('Reserve verticale insuffisante') end end
  local key=cal and not cal.complete and cal.phase or mission and tostring(mission.index)..':'..tostring(mission.segment) or self.mode
  if key~=self.progressKey then self.progress=Progress.new();self.progressKey=key end
  self.progress:observe({mission and Mission.distance(p,self.target) or self.target.z-p.z,mission and 0 or self.target.x-p.x,yError,math.deg(error.x),math.deg(error.y),math.deg(error.z)},{v.z,v.x,v.y,math.deg(omegaNow.x),math.deg(omegaNow.y),math.deg(omegaNow.z)},p.tick/20)
  local progress=self.progress:status()
  local stalled=aligning and progress.axes[5] or not aligning and (progress.axes[1] or progress.axes[2])
  if mission and not mission.completed and not mission.paused and Mission.distance(p,self.target)>.5 and stalled then mission:pause('Aucun progres; maintien') end
  if cal and not cal.complete and not cal.paused and stalled then cal:pause('Pas de convergence mesuree; resultats conserves') end
  self.previous=p
  local info={phase=self.phase,mode=self.mode,targetY=self.target.y,altitude=p.y,verticalSpeed=v.y,speed=speed,bodyYaw=p.yaw,course=self.course,bodyYawControlled=yawAvailable,
   capabilities=caps,residual=allocation.normalizedResidual,saturated=allocation.saturated,pitchTarget=pitchTarget,rollTarget=rollTarget,mass=p.mass,
   massChanged=self.massAdapted==true,rxConfirmed=false,shaftConfirmed=false,reason=cal and not cal.complete and cal.reason or mission and (mission.paused and mission.events[#mission.events] or mission.phase) or 'Modele declare; validation distincte'}
  info.reversing=reversing;self.info=info;return signals,info
 end
 return s
end
return M
