 for _,g in ipairs(s.groups) do if g.kind~='bearing' or g.role~='lift' or g.dx~=0 or g.dy~=1 or g.dz~=0 then return nil,'FPV: helices verticales requises' end end
 if #s.groups~=4 or not s.capabilities.pitch.available or not s.capabilities.roll.available then return nil,'FPV: autorite insuffisante' end
 for i,g in ipairs(s.groups) do local m=metadata[i];s.spool[g.id]=allocation[i]*m.unit/(g.members*m.thrust*m.pressure)+math.max(0,m.axial)/m.airflow end
 s.refEnabled=true
 for _,g in ipairs(s.groups) do local a=s.groups[1];s.refEnabled=s.refEnabled and g.sails==a.sails and g.source==a.source and g.members==a.members and g.thrust==a.thrust and g.airflow==a.airflow and g.alpha==a.alpha end
 if not s.refEnabled then return nil,'FPV: quatre modulaires identiques requises' end
 s.refAngle=vec(0,0,0);s.refRate=vec(0,0,0)
 s.forceFilter=0;s.supportRatio=1;s.pendingCommand=V.copy(s.initialSignals)
 function s:step(p,command,lastSignals)
  local cfg=self.config;local why;p,why=M.pose(p);if not p then return nil,why end
  if p.dimension~=self.previous.dimension then return nil,'Dimension modifiee' end
  local dt=(p.tick-self.tick)/20;if dt<=0 or dt>.5 then return nil,'Horloge repetee/regressee/perdue' end
  for _,key in ipairs({'forward','left','vertical'}) do if not finite(command[key]) or math.abs(command[key])>1 then return nil,'Commande clavier invalide' end end
  for _,axis in ipairs({'x','y','z'}) do
   local old=self.velocity[axis];local k=self.filters[axis]
   if math.abs(p[axis]-k.x-k.v*dt)>20 then return nil,'Discontinuite de pose' end
   if not Filter.update(k,p[axis],dt) then return nil,'Estimateur perdu' end
   self.velocity[axis]=finite(p['v'..axis]) and .75*p['v'..axis]+.25*k.v or k.v
   self.acceleration[axis]=self.acceleration[axis]+dt/(.12+dt)*((self.velocity[axis]-old)/dt-self.acceleration[axis])
  end
  local worldRate=Geometry.angularVelocity(self.previous.q,p.q,dt);if not worldRate then worldRate=vec(0,0,0);self:event('Rotation ambigue: tentative de redressement depuis attitude courante') end
  local rate=Geometry.bodyVector(worldRate,p.q)
  for _,axis in ipairs({'x','y','z'}) do
   local old=self.omega[axis];self.omega[axis]=old+dt/(.025+dt)*(rate[axis]-old)
   self.angularAcceleration[axis]=self.angularAcceleration[axis]+dt/(.12+dt)*((self.omega[axis]-old)/dt-self.angularAcceleration[axis])
  end
  p.wx,p.wy,p.wz=self.omega.x,self.omega.y,self.omega.z
  self.tick=p.tick;self.samples=self.samples+1
  local caps=self.capabilities;local v=self.velocity;local yaw=math.rad(p.yaw)
  local up=V.world(vec(0,1,0),p.q);local manual=command.forward~=0 or command.left~=0 or command.vertical~=0
  local mission,cal=self.mission,self.calibration
  if manual and not self.wasManual then self.course=p.yaw end
  self.wasManual=manual
  if manual then
   if mission and not mission.paused then mission:pause('Priorite clavier; reprise explicite') end
   if cal and not cal.complete and not cal.paused then cal:pause('Priorite clavier; reprise essais explicite') end
   self.target.x,self.target.z=p.x,p.z
   if command.vertical~=0 then self.target.y=p.y+command.vertical*(cfg.climb or 4)*dt end
  end
  local desired,probe
  if cal and not cal.paused and not cal.complete and not manual then desired,probe=cal:step(p,v,self.omega,true);self.phase='CALIBRATING'
  elseif mission and not manual then desired=mission:step(p,v);self.phase=mission.phase
  else self.phase='HOLDING' end
  local tilt=cfg.tilt or 25;local acceleration=p.gravity*math.tan(math.rad(tilt))
  local speed=math.sqrt(v.x^2+v.z^2);local ax,az=0,0
  if desired then
   self.target=vec(desired.x,desired.y,desired.z)
   local dx,dz=desired.x-p.x,desired.z-p.z;local distance=math.sqrt(dx*dx+dz*dz)
   local brake=cfg.braking or acceleration
   local request=math.min(1.2*distance,math.sqrt(2*brake*math.max(0,distance-.05)))
   if desired.speed and desired.speed>0 then request=math.min(request,desired.speed) end
   ax=1.2*((distance>.01 and dx/distance*request or 0)-v.x)
   az=1.2*((distance>.01 and dz/distance*request or 0)-v.z)
  elseif command.forward~=0 or command.left~=0 then
   local f,l=command.forward,command.left
   if cfg.steering~=false then
    if speed>.3 then self.course=self.course-l*math.deg(acceleration/math.max(.3,speed))*dt end
    local angle=math.rad(self.course)
    ax=acceleration*(f*math.sin(angle)-l*math.cos(angle));az=acceleration*(f*math.cos(angle)+l*math.sin(angle))
    if f==0 and speed<.3 then ax,az=0,0 end
   else ax=acceleration*(f*math.sin(yaw)-l*math.cos(yaw));az=acceleration*(f*math.cos(yaw)+l*math.sin(yaw)) end
  elseif self.mode=='HEADING' then
   local heading=math.rad(self.heading);ax=1.2*((self.speed or 0)*math.sin(heading)-v.x);az=1.2*((self.speed or 0)*math.cos(heading)-v.z)
  else
   if speed>.12 then ax,az=-2.3*(v.x+.4*self.acceleration.x),-2.3*(v.z+.4*self.acceleration.z);self.target.x,self.target.z=p.x,p.z
   else ax=.3*(self.target.x-p.x)-.9*v.x;az=.3*(self.target.z-p.z)-.9*v.z end
  end
  local recovering=up.y<math.cos(math.rad(math.max(45,tilt+15))) or self.recovering and (up.y<.985 or math.abs(self.omega.x)+math.abs(self.omega.z)>.3 or math.abs(v.y)>6)
  if recovering then
   if not self.recovering then self:event('Redressement; altitude non garantie pendant retournement') end
   self.recovering=true;self.phase='RECOVERING';ax,az=0,0
   if mission then mission:pause('Redressement') end;if cal then cal:pause('Redressement') end
  elseif self.recovering then self.recovering=false;self:event('Assiette recuperee; maintien de la consigne') end
  local model,meta,offset=V.matrix(self.groups,p,v,self.referenceMass,self.directions);if not model then return nil,meta end
  if recovering then
   for i,m in ipairs(meta) do
    local g=m.group;local old=m.unit;m.axial=m.axial+self.omega.z*g.x-self.omega.x*g.z
    m.unit=Physics.force(g.source,m.pressure,m.axial,m.thrust,m.airflow)*g.members/15
    for j=1,6 do model.columns[i].response[j]=old>0 and model.columns[i].response[j]*m.unit/old or 0 end
   end
  end
  -- Predict only from the issued command history. This is not observed shaft RPM.
  local force=0
  for i,m in ipairs(meta) do
   local g=m.group;local alpha=select(3,V.coefficients(g));local previous=self.pendingCommand[tostring(g.id)] or self.initialSignals[tostring(g.id)]
   local rpm=self.quant.rpm and self.quant.rpm[i] or self.spool[g.id]
   rpm=rpm+(1-(1-alpha)^(dt*20))*(Physics.rpm(g.source,previous)-rpm)
   self.spool[g.id]=rpm
   local actualAxial=m.axial+(recovering and 0 or self.omega.z*g.x-self.omega.x*g.z)
   local f=Physics.force(rpm,m.pressure,actualAxial,m.thrust,m.airflow)*g.members
   force=force+f
  end
  self.pendingCommand=V.copy(lastSignals or self.initialSignals)
  self.forceFilter=self.forceFilter+dt/(.12+dt)*(force/p.mass*up.y-p.gravity-self.forceFilter)
  if up.y>.85 and not recovering and self.samples>5 and math.abs(self.omega.x)+math.abs(self.omega.z)<.6 and self.acceleration.y>-p.gravity*.7 and self.acceleration.y<p.gravity*2 then
   local ratio=clip((self.forceFilter+p.gravity)/(self.acceleration.y+p.gravity),.6,5)
   self.supportRatio=self.supportRatio+dt/((ratio<self.supportRatio and .15 or .4)+dt)*(ratio-self.supportRatio)
  end

  local length=math.sqrt(ax*ax+az*az);if length>acceleration then ax,az=ax*acceleration/length,az*acceleration/length end
  local pitchTarget=math.deg(math.atan((ax*math.sin(yaw)+az*math.cos(yaw))/p.gravity))
  local rollTarget=-math.deg(math.atan((ax*math.cos(yaw)-az*math.sin(yaw))/p.gravity))
  if recovering then pitchTarget,rollTarget=0,0 end
  self.liftLimited=false
  if not recovering then
   local function supported(fraction)
    local q=V.quaternion(pitchTarget*fraction,p.yaw,rollTarget*fraction)
    local axis=V.world(vec(0,1,0),q);local axial=v.x*axis.x+v.y*axis.y+v.z*axis.z;local available=0
    for _,g in ipairs(self.groups) do
     local thrust,flow=V.coefficients(g);local height=p.y+V.world(vec(g.x,g.y,g.z),q).y
     available=available+Physics.force(g.source,Physics.pressure(height),axial,thrust,flow)*g.members
    end
    return available*axis.y>=p.mass*p.gravity*self.supportRatio*1.1
   end
   if not supported(1) then
    local lo,hi=0,1
    for _=1,6 do local mid=(lo+hi)/2;if supported(mid) then lo=mid else hi=mid end end
    pitchTarget,rollTarget=pitchTarget*lo,rollTarget*lo;self.liftLimited=true
   end
  end

  local referenceAcceleration={x=0,z=0}
  if recovering or not self.refEnabled then self.refAngle=vec(0,0,0);self.refRate=vec(0,0,0)
  else
   local targets={x=math.rad(pitchTarget),z=math.rad(rollTarget)};local arms={x=0,z=0}
   for _,g in ipairs(self.groups) do arms.x=math.max(arms.x,math.abs(g.z));arms.z=math.max(arms.z,math.abs(g.x)) end
   for _,axis in ipairs({'x','z'}) do
    local limit=p.mass*p.gravity*self.supportRatio*arms[axis]/(axis=='x' and p.ix or p.iz)*.8
    local acceleration=clip(4/(0.35^2)*(targets[axis]-self.refAngle[axis])-4/0.35*self.refRate[axis],-limit,limit)
    self.refRate[axis]=self.refRate[axis]+acceleration*dt
    self.refAngle[axis]=self.refAngle[axis]+self.refRate[axis]*dt
    referenceAcceleration[axis]=acceleration
   end
   pitchTarget,rollTarget=math.deg(self.refAngle.x),math.deg(self.refAngle.z)
  end
  local wantedUp=V.world(vec(0,1,0),V.quaternion(pitchTarget,p.yaw,rollTarget))
  local cross=vec(up.y*wantedUp.z-up.z*wantedUp.y,up.z*wantedUp.x-up.x*wantedUp.z,up.x*wantedUp.y-up.y*wantedUp.x)
  local dot=clip(up.x*wantedUp.x+up.y*wantedUp.y+up.z*wantedUp.z,-1,1)
  local n=math.sqrt(cross.x^2+cross.y^2+cross.z^2)
  local error=n>1e-6 and Geometry.bodyVector(vec(cross.x*math.acos(dot)/n,cross.y*math.acos(dot)/n,cross.z*math.acos(dot)/n),p.q) or vec(dot<0 and math.pi or 0,0,0)
  local px,pz,modular=3,3,false
  for _,g in ipairs(self.groups) do
   local thrust,flow=V.coefficients(g);local damping=thrust*Physics.pressure(p.y+g.y)*g.members/flow
   px=px+1.5*g.z^2*damping/p.ix;pz=pz+1.5*g.x^2*damping/p.iz;modular=modular or g.kind=='bearing'
  end
  local dr,da=modular and 8 or 6,modular and 1.2 or .6
  local angular=vec(clip(px,4,40)*error.x-dr*self.omega.x-da*self.angularAcceleration.x,0,clip(pz,4,40)*error.z-dr*self.omega.z-da*self.angularAcceleration.z)
  for _,axis in ipairs({'x','z'}) do
   if self.refEnabled and self.supportRatio>1.1 and not manual and not recovering and not probe and (not desired or cal and cal.phase=='BASELINE') and math.abs(error[axis])<.15 and math.abs(self.omega[axis])<.1 then self.angleBias[axis]=clip(self.angleBias[axis]+.5*error[axis]*dt,-2,2) end
   angular[axis]=clip(angular[axis]+self.angleBias[axis]+dr*self.refRate[axis]+(1+da)*referenceAcceleration[axis],recovering and -48 or -12,recovering and 48 or 12)
  end
  local yError=self.target.y-self.filters.y.x
  local desiredVy=command.vertical~=0 and command.vertical*(cfg.climb or 4) or clip(2*yError,-(cfg.climb or 4),cfg.climb or 4)
  local ay=4*(desiredVy-v.y)+self.integral-.15*self.acceleration.y
  if math.abs(v.y)>8 then ay=clip(ay,-p.gravity*.8,p.gravity*2) end
  local collective=math.max(0,(ay+p.gravity)*self.supportRatio/math.max(.2,up.y))
  if recovering then
   local capacity=0;for _,c in ipairs(model.columns) do capacity=capacity+c.response[3]*15 end
   collective=up.y>.3 and math.min(capacity*.6,(p.gravity+clip(-3*v.y,0,p.gravity*2))*self.supportRatio/up.y) or math.min(p.gravity*5,capacity*.25)
  end
  local wanted={0,0,collective,angular.x,0,angular.z}
  for j=1,6 do wanted[j]=wanted[j]-offset[j] end
  local values,allocation=V.solve(model,wanted);if not values then return nil,allocation end
  if probe then values[probe.index]=clip(values[probe.index]+probe.delta,0,15) end
  for i,m in ipairs(meta) do m.column=model.columns[i].response end
  self.quant.trackingFast=(command.forward~=0 or command.left~=0) and self.supportRatio<1.1;self.quant.verticalFast=command.vertical~=0;self.quant.refRate=self.refRate;self.quant.dt=dt;self.quant.spool=self.spool;self.quant.recovering=recovering
  local signals,why=V.signals(meta,values,self.quant);if not signals then return nil,why end
  if not recovering and math.abs(allocation.actual[3]-wanted[3])<.1 then self.integral=clip(self.integral+.3*yError*dt,-p.gravity*.8,p.gravity*2) end
  local capacity=0;for _,c in ipairs(model.columns) do capacity=capacity+c.response[3]*15 end
  self.verticalLimited=collective>capacity*.98
  if self.verticalLimited and not recovering then self.phase='DEGRADED';if mission then mission:pause('Reserve verticale insuffisante') end end
  if desired and not recovering then
   local key=cal and not cal.complete and cal.phase or mission and tostring(mission.index)..':'..tostring(mission.segment)
   if key~=self.progressKey then self.progressKey=key;self.progress=Progress.new() end
   self.progress:observe({self.target.x-p.x,self.target.z-p.z,0,0,0,0},{v.x,v.z,0,0,0,0},p.tick/20)
   local flags=self.progress:status().axes
   if (flags[1] or flags[2]) and Mission.distance(p,self.target)>.5 then (cal and not cal.complete and cal or mission):pause('Pas de convergence mesuree; maintien') end
  end
  self.previous=p
  local info={phase=self.phase,mode=self.mode,targetY=self.target.y,altitude=p.y,verticalSpeed=v.y,speed=speed,bodyYaw=p.yaw,course=self.course,bodyYawControlled=false,
   capabilities=caps,residual=allocation.normalizedResidual,saturated=allocation.saturated,pitchTarget=pitchTarget,rollTarget=rollTarget,mass=p.mass,
   massChanged=math.abs(p.mass-self.referenceMass)>self.referenceMass*1e-6,rxConfirmed=false,shaftConfirmed=false,reason=recovering and 'Redressement actif; perte altitude possible' or cal and not cal.complete and cal.reason or self.liftLimited and 'Inclinaison adaptee a la portance disponible' or 'Correction passive de sustentation; cause non identifiee'}
  self.info=info;return signals,info
 end
 return s
end
return M
