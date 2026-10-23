-- Authorized known-output measurement sequence. Pure: flightd applies demands.
local A=require('system.libraries.addon')
local G=require('system.navigation.geometry')
local C=require('system.ascendancy.contracts')
local Response=require('system.navigation.response_model')
local M={}
local function stats() return {n=0,mean={0,0,0,0,0,0},m2={0,0,0,0,0,0}} end
local function add(s,values)
 local n=s.n+1
 for i=1,6 do
  local delta=values[i]-s.mean[i]
  s.mean[i]=s.mean[i]+delta/n s.m2[i]=s.m2[i]+delta*(values[i]-s.mean[i])
  if not A.finite(s.mean[i]) or not A.finite(s.m2[i]) then return false end
 end
 s.n=n return true
end
local function project(linear,angular,q)
 local l,r=G.bodyVector(linear,q),G.bodyVector(angular,q)
 if not l or not r then return end
 return {l.z,l.x,l.y,math.deg(r.x),math.deg(r.y),math.deg(r.z)}
end
function M.new(channels,vehicleId,duration)
 if type(channels)~='table' or #channels<1 or #channels>32 or type(vehicleId)~='string' or #vehicleId<1 or #vehicleId>128 or not A.finite(duration) or duration<.5 or duration>2 then return nil,'Known outputs and a 0.5..2 second pulse duration required' end
 local self={state='running',phase='baseline',index=1,steps={},rows={},rejected={},values={},generation=1,baseline=stats(),
  vehicleId=vehicleId,channels=A.copy(channels),duration=duration,reason='Waiting for physically stationary neutral outputs'}
 local ids={}
 for _,c in ipairs(channels) do
  if type(c)~='table' or type(c.id)~='string' or #c.id<1 or #c.id>192 or ids[c.id] then return nil,'Invalid or duplicate known output' end ids[c.id]=true
  for _,key in ipairs({'min','max','neutral','rescue'}) do if not A.finite(c[key]) or c[key]%1~=0 or c[key]<0 or c[key]>15 then return nil,'Invalid output value' end end
  if c.min>c.max or c.neutral<c.min or c.neutral>c.max or c.rescue<c.min or c.rescue>c.max then return nil,'Output outside domain' end
  self.values[c.id]=c.neutral
  for _,sign in ipairs({-1,1}) do
   local signal=c.neutral+sign
   if signal>=c.min and signal<=c.max then self.steps[#self.steps+1]={id=c.id,signal=signal} end
  end
 end
 if #self.steps==0 then return nil,'All assigned outputs have a fixed domain' end
 function self:abort(why) self.state,self.reason='aborted',why end
 function self:applied(generation,at)
  if self.state=='running' and generation==self.generation and not self.appliedAt and A.finite(at) and at>=0 then self.appliedAt=at end
 end
 local function demand(pulse)
  for _,c in ipairs(self.channels) do self.values[c.id]=c.neutral end
  if pulse then self.values[pulse.id]=pulse.signal end
  self.generation=self.generation+1 self.appliedAt=nil self.confirmedAt=nil self.last=nil
 end
 local function finishPulse()
  local s,b=self.pulse,self.pulseBaseline local step=self.steps[self.index]
  if s.n>=4 and b.n>=4 then
   local row={id=step.id,signal=step.signal,vehicleId=self.vehicleId,clock='local_uptime',clockId=C.clockId(),frame='body_orientation_at_neutral_reference',translationUnit='block/s2',rotationUnit='deg/s2',after=self.pulseAckAt,appliedAt=self.appliedAt,first=self.first,last=self.last,
    samples=s.n,baselineSamples=b.n,response={},noise={},singleCommand=true,otherOutputsChanged=false,
    excursion=A.copy(self.excursion),maxRate=A.copy(self.maxRate),worldExcursion=A.copy(self.worldExcursion),worldMaxRate=A.copy(self.worldMaxRate),referenceOrientation=A.copy(self.pulseReference)}
   for i=1,6 do row.response[i]=s.mean[i]-b.mean[i]
    row.noise[i]=math.sqrt(math.max(0,s.m2[i]/(s.n-1)+b.m2[i]/(b.n-1)))
   end
   self.rows[#self.rows+1]=row
  else self.rejected[#self.rejected+1]={id=step.id,signal=step.signal,reason='Fewer than four complete post-ACK derivative intervals'} end
  self.index=self.index+1 self.phase='baseline' self.baseline=stats() self.reference=nil self.reason='Returning to stationary neutral before the next assigned output'
  demand()
 end
 function self:step(k,pose,ack,now,ackAt)
  if self.state~='running' then return end
  if not A.finite(now) or self.clock and now<self.clock then self:abort('Characterization clock regressed') return end self.clock=now
  -- The bounded pulse ends even when the next observation is unavailable.
  if self.phase=='pulse' and self.appliedAt and now-self.appliedAt>=self.duration then finishPulse() end
  if not k or k.available~=true or k.vehicleId~=self.vehicleId or k.frame~='world' or k.clockId~=C.clockId() or not C.fresh(k,now) or
   not k.units or k.units.acceleration~='block/s2' or k.units.angularAcceleration~='rad/s2' or k.units.velocity~='block/s' or k.units.angularVelocity~='rad/s' then
   self:abort('Fresh six-axis pose derivatives and known units required') return
  end
  if not pose or pose.vehicleId~=self.vehicleId or pose.frame~='world' or pose.inSublevel~=true or not A.finite(pose.timestamp) or pose.timestamp>now or now-pose.timestamp>.5 then self:abort('Characterization vehicle identity or pose lost') return end
  local q=G.orientation(pose.logicalPose and pose.logicalPose.orientation)
  if not q then self:abort('Characterization orientation unavailable') return end
  local position=A.vec(k.position)
  if position then
   self.worldBounds=self.worldBounds or {minY=position.y,maxY=position.y}
   self.worldBounds.minY=math.min(self.worldBounds.minY,position.y) self.worldBounds.maxY=math.max(self.worldBounds.maxY,position.y)
  end
  if ack and A.finite(ackAt) and ackAt<=now and self.appliedAt and ackAt>self.appliedAt then self.confirmedAt=self.confirmedAt or ackAt end
  if not ack or not self.appliedAt or not self.confirmedAt or not k.interval or not A.finite(k.interval.first) or k.interval.first<=self.confirmedAt then return end
  if self.last and k.observedAt<=self.last then return end
  if self.last and k.observedAt-self.last>.5 then self.baseline=stats() self.reference=nil end
  if self.phase=='baseline' then
   local linear,angular=A.vec(k.velocity),A.vec(k.angularVelocity)
   if not linear or not angular or linear.x^2+linear.y^2+linear.z^2>.1^2 or angular.x^2+angular.y^2+angular.z^2>math.rad(.5)^2 then
    self.baseline=stats() self.reference=nil self.reason='Neutral outputs are not stationary; no new pulse is authorized' self.last=k.observedAt return
   end
   self.reference=self.reference or q
   local values=project(k.acceleration,k.angularAcceleration,self.reference)
   if not values or not add(self.baseline,values) then self:abort('Invalid neutral derivative statistics') return end
   self.last=k.observedAt
   if self.baseline.n>=8 then
    if self.index>#self.steps then
     self.model,self.modelError=Response.fit(self.channels,self.rows,{vehicleId=self.vehicleId,source='Sable logicalPose derivatives',clock='local_uptime',clockId=C.clockId(),frame='body_orientation_at_neutral_reference',translationUnit='block/s2',rotationUnit='deg/s2'})
     self.state='complete' self.reason=self.model and 'Known-output response measured; closed-loop qualification still required' or self.modelError return
    end
    self.pulseBaseline=A.copy(self.baseline) self.pulse=stats() self.pulseReference=A.copy(self.reference)
    self.phase='pulse' self.reason='Measuring assigned output '..self.steps[self.index].id
    self.pulseAckAt=nil self.first=nil self.pulseOrigin=A.vec(k.position)
    self.excursion={0,0,0,0,0,0} self.maxRate={0,0,0,0,0,0}
    self.worldExcursion={0,0,0,0,0,0} self.worldMaxRate={0,0,0,0,0,0}
    demand(self.steps[self.index])
   end
  elseif self.phase=='pulse' then
   self.pulseAckAt=self.pulseAckAt or self.confirmedAt
   local values=project(k.acceleration,k.angularAcceleration,self.pulseReference)
   if not values or not add(self.pulse,values) then self:abort('Invalid pulse derivative statistics') return end
   local position=A.vec(k.position)
   local travel=position and self.pulseOrigin and {x=position.x-self.pulseOrigin.x,y=position.y-self.pulseOrigin.y,z=position.z-self.pulseOrigin.z}
   local rotation=G.angularVelocity(self.pulseReference,q,1)
   local excursion=travel and rotation and project(travel,rotation,self.pulseReference)
   local rates=project(k.velocity,k.angularVelocity,self.pulseReference)
   if not excursion or not rates then self:abort('Measured output motion domain unavailable') return end
   local worldTravel={travel.z,travel.x,travel.y,math.deg(rotation.x),math.deg(rotation.y),math.deg(rotation.z)}
   local worldRates={k.velocity.z,k.velocity.x,k.velocity.y,math.deg(k.angularVelocity.x),math.deg(k.angularVelocity.y),math.deg(k.angularVelocity.z)}
   for i=1,6 do
    self.excursion[i]=math.max(self.excursion[i],math.abs(excursion[i])) self.maxRate[i]=math.max(self.maxRate[i],math.abs(rates[i]))
    self.worldExcursion[i]=math.max(self.worldExcursion[i],math.abs(worldTravel[i])) self.worldMaxRate[i]=math.max(self.worldMaxRate[i],math.abs(worldRates[i]))
   end
   self.first=self.first or k.interval.first self.last=k.observedAt
  end
 end
 function self:status()
  return {state=self.state,phase=self.phase,reason=self.reason,index=self.index,count=#self.steps,measured=#self.rows,rejected=#self.rejected,
   neutralSamples=self.baseline.n,pulseSamples=self.pulse and self.pulse.n or 0,scope='known-output-characterization-not-flight-certificate',
   axes=self.model and A.copy(self.model.axes) or nil}
 end
 return self
end
return M
