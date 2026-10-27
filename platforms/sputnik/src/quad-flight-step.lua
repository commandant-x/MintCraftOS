 if #s.groups~=4 or not s.capabilities.pitch.available or not s.capabilities.roll.available then return nil,'FPV: autorite insuffisante' end
 for i,g in ipairs(s.groups) do local m=metadata[i];s.spool[g.id]=allocation[i]*m.unit/(g.members*m.thrust*m.pressure)+math.max(0,m.axial)/m.airflow end
 s.response=.35;for _,g in ipairs(s.groups) do local alpha=select(3,V.coefficients(g));s.response=math.max(s.response,-.05/math.log(1-alpha)) end
 s.refAngle=vec(0,0,0);s.refRate=vec(0,0,0)
 -- Passive force bias and effective torque balance; no measured COM claim.
 s.forceFilter=0;s.loadBias=0;s.thrustFilter=0;s.thrustRate=0;s.torqueRate=vec(0,0,0);s.torqueFilter=vec(0,0,0);s.pendingCommand=V.copy(s.initialSignals)
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
  local worldRate=Geometry.angularVelocity(self.previous.q,p.q,dt)
  if worldRate and (worldRate.x^2+worldRate.y^2+worldRate.z^2)*dt^2>(math.pi-.1)^2 then worldRate=nil end
  if not worldRate then worldRate=vec(0,0,0);self.omega=vec(0,0,0);self.angularAcceleration=vec(0,0,0);self:event('Rotation ambigue: tentative de redressement depuis attitude courante') end
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
  local tilt=(cfg.tilt or 25)*(self.scale or 1);local acceleration=p.gravity*math.tan(math.rad(tilt))
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
    if speed>.3 then
     local heading=math.rad(self.course);local along=v.x*math.sin(heading)+v.z*math.cos(heading)
     if f==0 or f*along>0 then self.course=math.deg(Geometry.atan2(v.x,v.z))+(f<0 and 180 or 0) end
    end
    l=l*speed/math.sqrt(speed^2+(acceleration*(self.response+.35)*2)^2)
    local angle=math.rad(self.course)
    ax=acceleration*(f*math.sin(angle)-l*math.cos(angle));az=acceleration*(f*math.cos(angle)+l*math.sin(angle))
    if f==0 and speed<.3 then ax,az=0,0 end
   else ax=acceleration*(f*math.sin(yaw)-l*math.cos(yaw));az=acceleration*(f*math.cos(yaw)+l*math.sin(yaw)) end
  elseif self.mode=='HEADING' then
   local heading=math.rad(self.heading);ax=1.2*((self.speed or 0)*math.sin(heading)-v.x);az=1.2*((self.speed or 0)*math.cos(heading)-v.z)
  else
   if speed>.12 then ax,az=-2.3/(1+math.max(0,self.loadBias)/p.gravity*2)*(v.x+.4*self.acceleration.x),-2.3/(1+math.max(0,self.loadBias)/p.gravity*2)*(v.z+.4*self.acceleration.z);self.target.x,self.target.z=p.x,p.z
   else ax=.3*(self.target.x-p.x)-.9*v.x;az=.3*(self.target.z-p.z)-.9*v.z end
  end
  local recovering=up.y<math.cos(math.rad(math.max(45,tilt+15))) or self.recovering and (up.y<.985 or math.abs(self.omega.x)+math.abs(self.omega.z)>.3 or math.abs(v.y)>6)
  if recovering then
   if not self.recovering then self:event('Redressement; altitude non garantie pendant retournement') end
   self.recovering=true;self.phase='RECOVERING';ax,az=0,0
   if mission then mission:pause('Redressement') end;if cal then cal:pause('Redressement') end
  elseif self.recovering then self.recovering=false;self:event('Assiette recuperee; maintien de la consigne') end
  local model,meta,offset=V.matrix(self.groups,p,v,self.referenceMass,self.directions);if not model then return nil,meta end
  if true then
   for i,m in ipairs(meta) do
    local g=m.group;local old=m.unit;m.axial=m.axial+(recovering and 1 or .5)*(self.omega.z*g.x-self.omega.x*g.z)
    m.unit=Physics.force(g.source,m.pressure,m.axial,m.thrust,m.airflow)*g.members/15
    for j=1,6 do model.columns[i].response[j]=old>0 and model.columns[i].response[j]*m.unit/old or 0 end
   end
  end
  -- Predict only from the issued command history. This is not observed shaft RPM.
  local force=0;local torque=vec(0,0,0)
  for i,m in ipairs(meta) do
   local g=m.group;local alpha=select(3,V.coefficients(g));local previous=self.pendingCommand[tostring(g.id)] or self.initialSignals[tostring(g.id)]
   local rpm=self.spool[g.id]
   rpm=rpm+(1-(1-alpha)^(dt*20))*(Physics.rpm(g.source,previous)-rpm)
   self.spool[g.id]=rpm
   local axial=m.axial+(recovering and 0 or .5)*(self.omega.z*g.x-self.omega.x*g.z)
   local f=Physics.force(rpm,m.pressure,axial,m.thrust,m.airflow)*g.members;force=force+f;torque.x=torque.x-g.z*f;torque.z=torque.z+g.x*f
  end
  torque.x=(torque.x-(p.iz-p.iy)*self.omega.y*self.omega.z)/p.ix
  torque.z=(torque.z-(p.iy-p.ix)*self.omega.x*self.omega.y)/p.iz
  for _,axis in ipairs({'x','z'}) do self.torqueRate[axis]=self.torqueRate[axis]+dt/(.025+dt)*(torque[axis]-self.torqueRate[axis]);self.torqueFilter[axis]=self.torqueFilter[axis]+dt/(.12+dt)*(self.torqueRate[axis]-self.torqueFilter[axis]) end
  self.thrustRate=self.thrustRate+dt/(.025+dt)*(force-self.thrustRate);self.thrustFilter=self.thrustFilter+dt/(.12+dt)*(self.thrustRate-self.thrustFilter)
  local oldBias=V.copy(self.angleBias)
  local relative=math.max(.1,self.thrustFilter/(p.mass*p.gravity))
  for _,axis in ipairs({'x','z'}) do
   local key=axis=='x' and 'ix' or 'iz'
   self.angleBias[axis]=self.angleBias[axis]*(p.mass/self.previous.mass)*(self.previous[key]/p[key]);oldBias[axis]=self.angleBias[axis]
   if self.samples>4 and not recovering and not probe and up.y>.5 then
    local goal=(self.torqueFilter[axis]-self.angularAcceleration[axis])/relative
    self.angleBias[axis]=self.angleBias[axis]+dt/(.2+dt)*(goal-self.angleBias[axis])
   end
  end
  local function compensate(bias)
   for _,c in ipairs(model.columns) do
    c.response[4]=c.response[4]-bias.x/p.gravity*c.response[3]
    c.response[6]=c.response[6]-bias.z/p.gravity*c.response[3]
   end
  end
  compensate(self.angleBias)
  self.trimLimited=not V.solve(model,{0,0,0,0,0,0})
  if self.trimLimited then
   compensate(vec(oldBias.x-self.angleBias.x,0,oldBias.z-self.angleBias.z));self.angleBias=oldBias;ax,az=0,0
  end
  if self.quant.error then
   local debt=self.quant.error;debt[3]=debt[3]*self.previous.mass/p.mass
   for _,index in ipairs({4,6}) do
    local axis=index==4 and 'x' or 'z';local key=index==4 and 'ix' or 'iz'
    debt[index]=debt[index]*self.previous[key]/p[key]-(self.angleBias[axis]-oldBias[axis])/p.gravity*debt[3]*10
   end
  end
  self.pendingCommand=V.copy(lastSignals or self.initialSignals)
  self.forceFilter=self.forceFilter+dt/(.12+dt)*(force/p.mass*up.y-p.gravity-self.forceFilter)
  if not recovering and up.y>.85 then
   local bias=clip(self.forceFilter-self.acceleration.y,-p.gravity*.4,p.gravity*3)
   self.loadBias=self.loadBias+dt/(1+dt)*clip(bias-self.loadBias,-p.gravity*.5,p.gravity*.5)
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
    return available*axis.y>=p.mass*p.gravity*1.1
   end
   if not supported(1) then
    local lo,hi=0,1
    for _=1,6 do local mid=(lo+hi)/2;if supported(mid) then lo=mid else hi=mid end end
    pitchTarget,rollTarget=pitchTarget*lo,rollTarget*lo;self.liftLimited=true
   end
  end

  local referenceAcceleration={x=0,z=0}
  if recovering then self.refAngle=vec(0,0,0);self.refRate=vec(0,0,0)
  else
   local referenceTime=math.max(.45,self.response)
   local targets={x=math.rad(pitchTarget),z=math.rad(rollTarget)};local arms={x=0,z=0}
   for _,g in ipairs(self.groups) do arms.x=math.max(arms.x,math.abs(g.z));arms.z=math.max(arms.z,math.abs(g.x)) end
   for _,axis in ipairs({'x','z'}) do
    local limit=p.mass*p.gravity*arms[axis]/(axis=='x' and p.ix or p.iz)*.8
    local acceleration=clip(4/(referenceTime^2)*(targets[axis]-self.refAngle[axis])-4/referenceTime*self.refRate[axis],-limit,limit)
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
  local px,pz=8,8
  if recovering then for _,g in ipairs(self.groups) do
   local thrust,flow=V.coefficients(g);local damping=thrust*Physics.pressure(p.y+g.y)*g.members/flow
   px=px+1.5*g.z^2*damping/p.ix;pz=pz+1.5*g.x^2*damping/p.iz
  end end
  local dr,da=8,1.2
  local angular=vec(clip(px,4,40)*error.x-dr*self.omega.x-da*self.angularAcceleration.x,0,clip(pz,4,40)*error.z-dr*self.omega.z-da*self.angularAcceleration.z)
  for _,axis in ipairs({'x','z'}) do

   angular[axis]=clip(angular[axis]+dr*self.refRate[axis]+(1+da)*referenceAcceleration[axis],recovering and -48 or -12,recovering and 48 or 12)
  end
  local yError=self.target.y-self.filters.y.x
  local desiredVy=command.vertical~=0 and command.vertical*(cfg.climb or 4) or clip(yError,-(cfg.climb or 4),cfg.climb or 4)
  local gain=(command.vertical~=0 or self.loadBias>p.gravity*.1) and 4 or 2
  local ay=gain*(desiredVy-v.y)+self.integral+self.loadBias-.15*self.acceleration.y
  if math.abs(v.y)>8 then ay=clip(ay,-p.gravity*.8,p.gravity*2) end
  local collective=math.max(0,(ay+p.gravity)/math.max(.2,up.y))
  if recovering then
   local capacity=0;for _,c in ipairs(model.columns) do capacity=capacity+c.response[3]*15 end
   collective=up.y>.3 and math.min(capacity*.6,(p.gravity+clip(-3*v.y,0,p.gravity*2))/up.y) or math.min(p.gravity*5,capacity*.25)
  end
  model.attitudePriority=recovering
  local wanted={0,0,collective,angular.x,0,angular.z}
  for j=1,6 do wanted[j]=wanted[j]-offset[j] end
  local values,allocation=V.solve(model,wanted);if not values then return nil,allocation end
  if probe then values[probe.index]=clip(values[probe.index]+probe.delta,0,15) end
  for i,m in ipairs(meta) do m.column=model.columns[i].response end
  self.quant.trimBoost=math.abs(self.angleBias.x-oldBias.x)+math.abs(self.angleBias.z-oldBias.z)>.1;self.quant.trackingFast=(command.forward~=0 or command.left~=0 or self.quant.trackingFast and speed>.3) and math.abs(self.loadBias)<p.gravity*.1;self.quant.verticalFast=(command.vertical~=0 or math.abs(v.y)>.3) and not recovering;self.quant.refRate=self.refRate;self.quant.spool=self.spool;self.quant.recovering=recovering
  local signals,why=V.signals(meta,values,self.quant);if not signals then return nil,why end
  if not recovering and math.abs(allocation.actual[3]-wanted[3])<.1 then self.integral=clip(self.integral+.15*yError*dt,-p.gravity*.8,p.gravity*2) end
  local capacity=0;for _,c in ipairs(model.columns) do capacity=capacity+c.response[3]*15 end
  self.verticalLimited=collective>capacity*.98
  if (self.verticalLimited or self.trimLimited) and not recovering then self.phase='DEGRADED';if mission then mission:pause(self.trimLimited and 'Correction couple hors support' or 'Reserve verticale insuffisante') end end
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
   trimPitch=self.angleBias.x,trimRoll=self.angleBias.z,trimLimited=self.trimLimited,massChanged=math.abs(p.mass-self.referenceMass)>self.referenceMass*1e-6,rxConfirmed=false,shaftConfirmed=false,loadBias=self.loadBias,reason=recovering and 'Redressement actif; perte altitude possible' or self.trimLimited and 'Equilibrage limite par support declare' or cal and not cal.complete and cal.reason or self.liftLimited and 'Inclinaison adaptee a la portance disponible' or 'Equilibrage dynamique estime'}
  self.info=info;return signals,info
 end
 return s
end
return M
