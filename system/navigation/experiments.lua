-- Observes the existing authorized motor probes. No commands or extra pulses.
local A=require('system.libraries.addon')
local G=require('system.navigation.geometry')
local Contract=require('system.ascendancy.contracts')
local M={}
local function interval(value,at)
 return type(value)=='table' and A.finite(value.first) and A.finite(value.last) and value.first>=0 and value.last<=at and value.first<value.last
end
local axes={'forward','right','vertical','pitch','yaw','roll'}
local function stats() return {n=0,mean={0,0,0,0,0,0},m2={0,0,0,0,0,0},rates={0,0,0,0,0,0},responseAt=0,velocityAt=0} end
local function add(s,v,rates,responseAt,velocityAt)
 local mean,m2,rateMean={},{},{} local n=s.n+1
 for i=1,6 do
  local delta=v[i]-s.mean[i] mean[i]=s.mean[i]+delta/n m2[i]=s.m2[i]+delta*(v[i]-mean[i])
  rateMean[i]=s.rates[i]+(rates[i]-s.rates[i])/n
  if not A.finite(mean[i]) or not A.finite(m2[i]) or not A.finite(rateMean[i]) then return false end
 end
 s.responseAt=s.responseAt+(responseAt-s.responseAt)/n s.velocityAt=s.velocityAt+(velocityAt-s.velocityAt)/n
 s.n,s.mean,s.m2,s.rates=n,mean,m2,rateMean return true
end
local function project(linear,angular,q)
 linear=G.bodyVector(linear,q) angular=G.bodyVector(angular,q)
 if not linear or not angular then return end
 local values={linear.z,linear.x,linear.y,math.deg(angular.x),math.deg(angular.y),math.deg(angular.z)}
 for _,value in ipairs(values) do if not A.finite(value) then return nil end end
 return values
end
function M.new()
 local self={baseline=stats(),groups={},rejected=0}
 function self:observe(probe,s,observation,ack,heat,heatAckAt,motorAckAt)
  -- A command change is a confounder even while its RX proof is pending.
  if A.finite(heat) then
   if probe.phase=='pulse' and self.pulse and heat~=self.pulse.heat then self.pulse.heatChanged=true
   elseif (probe.phase=='baseline' or probe.phase=='brake') and self.heat~=nil and heat~=self.heat then
    self.baseline=stats() self.reference=nil self.neutralAck=nil self.heat=nil
   end
  end
  if not s or not A.finite(s.at) or not A.finite(s.yawRate) or not A.vec(s.velocity) or not A.finite(heat) then return end
  if not ack or not A.finite(heatAckAt) or heatAckAt<0 or heatAckAt>s.at or s.at-heatAckAt>2 or not A.finite(motorAckAt) or motorAckAt<0 or motorAckAt>s.at or s.at-motorAckAt>2 or not observation or observation.available~=true or
   observation.clockId~=Contract.clockId() or observation.vehicleId~=s.vehicleId or observation.frame~='world' or
   not A.finite(observation.observedAt) or observation.observedAt>s.at or s.at-observation.observedAt>.5 or
   not A.finite(observation.velocityAt) or observation.velocityAt>s.at or not observation.units or observation.units.acceleration~='block/s2' or
   observation.units.angularAcceleration~='rad/s2' or observation.units.velocity~='block/s' or observation.units.angularVelocity~='rad/s' then return end
  if not interval(observation.interval,s.at) or not A.vec(observation.angularVelocity) or not A.vec(observation.velocity) or
   not A.vec(observation.acceleration) or not A.vec(observation.angularAcceleration) then return end
  if self.vehicleId and self.vehicleId~=s.vehicleId then return end
  self.vehicleId=s.vehicleId
  if self.last and observation.observedAt<=self.last then return end
  self.last=observation.observedAt
  if probe.phase=='baseline' or probe.phase=='brake' then
   if not s.velocity or not A.finite(s.velocity.y) or math.abs(s.velocity.y)>.1 or s.velocity.x^2+s.velocity.z^2>.1^2 or math.abs(s.yawRate)>.5 or
    not observation.angularVelocity or observation.angularVelocity.x^2+observation.angularVelocity.y^2+observation.angularVelocity.z^2>math.rad(.5)^2 then
    self.baseline=stats() self.reference=nil self.neutralAck=nil return
   end
   self.neutralAck=self.neutralAck or math.max(motorAckAt,heatAckAt)
   if not self.reference then self.reference=G.orientation(s.orientation) self.referenceAt=s.at self.heat=heat self.heatChanged=false end
   if heat~=self.heat then self.baseline=stats() self.reference=G.orientation(s.orientation) self.referenceAt=s.at self.heat=heat self.neutralAck=math.max(motorAckAt,heatAckAt) end
   if not self.reference or observation.interval.first<(self.neutralAck or math.huge) then return end
   local v=project(observation.acceleration,observation.angularAcceleration,self.reference)
   local rates=project(observation.velocity,observation.angularVelocity,self.reference)
   if v and rates and not add(self.baseline,v,rates,observation.observedAt,observation.velocityAt) then self.baseline=stats() self.reference=nil end
  elseif probe.phase=='pulse' and self.pulse then
   local p=self.pulse p.firstAck=p.firstAck or math.max(motorAckAt,heatAckAt) p.heatChanged=p.heatChanged or heat~=p.heat
   if not observation.interval or observation.interval.first<math.max(p.firstAck or math.huge,probe.appliedAt or math.huge) then return end
   local v=project(observation.acceleration,observation.angularAcceleration,p.orientation)
   local rates=project(observation.velocity,observation.angularVelocity,p.orientation)
   if v and rates then
    if add(p.stats,v,rates,observation.observedAt,observation.velocityAt) then p.first=p.first or observation.interval.first p.last=observation.interval.last else p.invalidStatistics=true end
   end
  end
 end
 function self:transition(probe,before,s)
  if before~='pulse' and probe.phase=='pulse' then
   self.pulse={stats=stats(),baseline=A.copy(self.baseline),orientation=A.copy(self.reference),heat=self.heat,heatChanged=self.heatChanged,
    command=A.copy(probe.steps[probe.index]),vehicleId=s.vehicleId,referenceAt=self.referenceAt}
  elseif before=='pulse' and probe.phase=='brake' then
   local p=self.pulse local row=probe.rows[#probe.rows]
   if p and row and A.finite(row.forward) then
    local usable=p.baseline.n>=4 and p.stats.n>=3 and not p.heatChanged and p.orientation~=nil and not p.invalidStatistics
    local result={command=p.command,baselineSamples=p.baseline.n,samples=p.stats.n,usable=usable,notControlCertificate=true,
     from=p.first,to=p.last,referenceOrientation=p.orientation,referenceAt=p.referenceAt,otherHeatChanged=p.heatChanged==true,
     reason=usable and 'Acknowledged single-bank response; external disturbances not excluded' or p.heatChanged and 'Other heat command changed' or p.invalidStatistics and 'Nonfinite response statistics rejected' or p.baseline.n<4 and 'Insufficient stationary neutral observations' or 'Fewer than three complete post-ACK derivative intervals',observedMask=0}
    if p.baseline.n>=2 and p.stats.n>=2 then
     result.response={} result.noiseStdDev={}
     result.operatingVelocity=A.copy(p.stats.rates) result.neutralVelocity=A.copy(p.baseline.rates)
     result.velocityObservedAt=p.stats.velocityAt result.responseObservedAt=p.stats.responseAt
     for i=1,6 do
      local variance=math.max(0,p.baseline.m2[i]/(p.baseline.n-1)+p.stats.m2[i]/(p.stats.n-1))
      local value=p.stats.mean[i]-p.baseline.mean[i]
      if not A.finite(value) or not A.finite(variance) then result.usable=false result.reason='Nonfinite response statistics rejected' result.response,result.noiseStdDev=nil,nil result.observedMask=0 break end
      result.response[i]=value result.noiseStdDev[i]=math.sqrt(variance)
      if usable and math.abs(result.response[i])>=math.max(i<=3 and .01 or .1,3*result.noiseStdDev[i]) then result.observedMask=result.observedMask+2^(i-1) end
     end
    end
    local key=p.command.side..':'..p.command.reverse local old=self.groups[key]
    result.selectionStrength=math.abs(row.forward)
    usable=result.usable
    if not old or usable and not old.usable or usable==old.usable and result.selectionStrength>old.selectionStrength then self.groups[key]=result end
    if not usable then self.rejected=self.rejected+1 end
   end
   self.pulse=nil self.baseline=stats() self.reference=nil self.neutralAck=nil
  end
 end
 function self:summary(vehicleId)
  local groups={} for _,side in ipairs({'left','right'}) do for _,reverse in ipairs({0,15}) do
   local r=self.groups[side..':'..reverse] if r then groups[#groups+1]=A.copy(r) end
  end end
  return {schema=1,scope='motor-experiments-not-control-certificate',vehicleId=vehicleId,clockId=Contract.clockId(),clock='local_uptime',
   frame='body_orientation_at_neutral_reference',axes=A.copy(axes),units={translation='block/s2',rotation='deg/s2'},operatingUnits={translation='block/s',rotation='deg/s'},groups=groups,rejected=self.rejected,
   method='neutral-subtracted means; observed spread (not confidence intervals); no new pulses'}
 end
 return self
end
function M.saved(value,vehicleId)
 if type(value)~='table' or value.schema~=1 or value.vehicleId~=vehicleId or type(value.groups)~='table' or #value.groups>4 or value.scope~='motor-experiments-not-control-certificate' then return nil end
 local copy=Contract.clone(value) if copy then copy.historical=true end return copy
end
return M
