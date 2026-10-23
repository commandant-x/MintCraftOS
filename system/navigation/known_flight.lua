-- Known-output characterization -> measured feedback trials -> local hold.
-- Private service object; no hardware IO and no persisted/client certificates.
local A=require('system.libraries.addon')
local Characterization=require('system.navigation.output_characterization')
local Controller=require('system.navigation.measured_controller')
local Qualification=require('system.navigation.closed_loop_qualification')
local Response=require('system.navigation.response_model')
local Tilt=require('system.navigation.tilt_response')
local Progress=require('system.navigation.motion_progress')
local M={}
local function same(a,b)
 for id,value in pairs(a) do if b[id]~=value then return false end end
 for id,value in pairs(b) do if a[id]~=value then return false end end return true
end
function M.new(channels,vehicleId,duration,automatic)
 local self,why=Characterization.new(channels,vehicleId,duration) if not self then return nil,why end
 local measureStep,measureStatus,abort,measureReuse=self.step,self.status,self.abort,self.reuseCandidate
 self.automatic=automatic==true
 function self:reuseCandidate(candidate,pose,k)
  local controller,why=Controller.new(candidate.model,pose,k)
  if not controller then return false,'Historical domain not applicable to current pose: '..tostring(why) end
  return measureReuse(self,candidate)
 end
 function self:abort(reason)
  abort(self,reason) self.active=false
  if self.qualification then self.qualification:abort(reason) end
 end
 function self:step(k,pose,ack,now,ackAt)
  if self.state~='running' then return end
  if not self.controller then
   measureStep(self,k,pose,ack,now,ackAt)
   if self.state=='complete' and self.automatic then
    local controller,issue=Controller.new(self.model,pose,k)
    if not controller then self:abort('Measured controller unavailable: '..tostring(issue)) return end
    self.controller=controller
    self.qualification,issue=Qualification.new(controller)
    if not self.qualification then self:abort(issue) return end
    self.state,self.phase,self.reason='running','qualifying','Checking measured feedback before local hold'
    self.quantizer={} self.controlAt=nil
    self.tiltObserver=Tilt.new(self.vehicleId,controller.reference)
   end
   return
  end
  local values,issue=self.controller:step(k,pose,ack,now)
  if not values then self:abort(issue) return end
  if self.phase=='qualifying' then
   if self.tiltObserver and not self.tiltAttempted then self.tiltObserver:observe(k,pose,ack,now) end
   self.qualification:step(self.controller:status(),k and k.observedAt,ack)
   self.reason=self.qualification.reason
   if self.qualification.state=='aborted' then self:abort(self.reason) return end
   if self.qualification.state=='complete' then
    local enabled=false
    if not self.tiltAttempted then
     self.tiltAttempted=true
     self.tiltModel,self.tiltError=self.tiltObserver:fit()
     if self.tiltModel then
      local settle=0
      for _,check in ipairs(self.qualification.checks) do if check.axis=='pitch' or check.axis=='roll' then settle=math.max(settle,check.settleDuration or 0) end end
      self.tiltModel.attitudeSettle=settle
      enabled,self.tiltError=self.controller:enableTilt(self.tiltModel,k)
     end
     if enabled then
      self.attitudeQualification=self.qualification
      self.qualification=assert(Qualification.new(self.controller,{forward=true,right=true}))
      self.reason='Qualifying lateral guidance from passively measured tilt response'
     end
    end
    if not enabled then self.active=true self.progress=Progress.new() self.phase='holding' self.reason='Measured local hold; only physically qualified axes active' end
   end
  end
  if self.phase=='qualifying' and k.position then
   self.worldBounds.minY=math.min(self.worldBounds.minY,k.position.y) self.worldBounds.maxY=math.max(self.worldBounds.maxY,k.position.y)
  end
  if self.active and ack and (not self.healthAt or k.observedAt-self.healthAt>=.5) then
   local previous=self.healthPrevious self.healthAt=k.observedAt
   local error,rates=self.controller.error,self.controller.rates
   self.progress:observe(error,rates,k.observedAt)
   local oscillating=self.progress.axes
   if self.controller.axes.vertical and oscillating[3]=='nondecaying-oscillation' or self.controller.axes.pitch and oscillating[4]=='nondecaying-oscillation' or self.controller.axes.roll and oscillating[6]=='nondecaying-oscillation' then self:abort('Observed vertical/attitude oscillations do not decay despite confirmed outputs') return end
   local distance=math.sqrt(error[1]^2+error[2]^2)
   local toward=distance>1e-6 and (error[1]*rates[1]+error[2]*rates[2])/distance or 0
   local stalled=distance>.25 and rates[1]^2+rates[2]^2<.05^2 and (self.controller.tiltDemand and (math.abs(self.controller.tiltDemand[1])>.002 or math.abs(self.controller.tiltDemand[2])>.002) or math.abs(self.controller.requested[1])>.02 or math.abs(self.controller.requested[2])>.02)
   local escaping=previous and distance>previous.distance+.01 and toward< -.1 and toward<=previous.toward+.01 and (self.controller.tiltSaturated or self.controller.residual>.02)
   self.horizontalFault=(self.controller.axes.forward or self.controller.axes.right) and (stalled or escaping or oscillating[1]=='nondecaying-oscillation' or oscillating[2]=='nondecaying-oscillation') and (self.horizontalFault or 0)+1 or 0
   if self.horizontalFault>=8 and not self.degraded then
    if not self.controller.axes.vertical then self:abort('Horizontal response lost; no qualified vertical fallback') return end
    self.degraded='Horizontal commands lost measurable authority; verified local vertical feedback retained'
    self.controller.axes.forward=false self.controller.axes.right=false self.controller.axes.yaw=false self.controller.tiltSuspended=true
    self.controller.position.x=k.position.x self.controller.position.z=k.position.z
    self.phase='degraded' self.reason=self.degraded
   end
   local essential=false
   for _,i in ipairs({3,4,6}) do
    local axis=Response.axes[i]
    if self.controller.axes[axis] and math.abs(error[i])>(i==3 and .5 or 5) and error[i]*rates[i]<0 and previous and math.abs(rates[i])>=math.abs(previous.rates[i])-.01 and
     math.abs(self.controller.requested[i]-self.controller.actualResponse[i])>self.controller.allocationModel.scale[i]*.02 then essential=true end
   end
   self.essentialFault=essential and (self.essentialFault or 0)+1 or 0
   if self.essentialFault>=8 then self:abort('Measured vertical/attitude authority exhausted despite confirmed outputs') return end
   self.healthPrevious={distance=distance,toward=toward,rates=A.copy(rates)}
  end
  if not ack or self.controlAt and k.observedAt<=self.controlAt then return end
  local signals,why=Response.quantize(self.controller.allocationModel,values,self.quantizer)
  if not signals or self.quantizer.clipped then self:abort(why or 'Measured output quantizer lost its local response domain') return end
  self.controlAt=k.observedAt
  if not same(signals,self.values) then
   self.values=signals self.generation=self.generation+1 self.appliedAt=nil self.confirmedAt=nil
  end
 end
 function self:massChanged(mass,referenceMass,k,cause)
  if not self.active or not self.controller.axes.vertical or not k or not A.vec(k.position) then return false,'No qualified vertical hold available for passive mass adaptation' end
  self.progress=Progress.new()
  self.massAdaptation=self.massAdaptation or {referenceMass=referenceMass,target=self.controller.position.y}
  self.massAdaptation.mass=mass self.massAdaptation.cause=cause or 'Observed mass changed' self.phase='adaptation'
  self.controller.axes.forward=false self.controller.axes.right=false self.controller.axes.yaw=false self.controller.tiltSuspended=true
  self.controller.position.x=k.position.x self.controller.position.z=k.position.z
  self.reason=self.massAdaptation.cause..': passive adaptation at unchanged altitude; horizontal guidance suspended, no new motion test'
  return true
 end
 function self:setTargets(request)
  if not self.active or self.state~='running' then return false,'Complete measured closed-loop qualification first' end
  if type(request)~='table' or not A.finite(request.altitude) then return false,'Finite world altitude required' end
  if request.speed~=nil or request.heading~=nil then return false,'Use only qualified local hold; horizontal mission guidance is not yet selected' end
  if not self.controller.axes.vertical then return false,'No qualified vertical output authority' end
  if request.altitude<self.worldBounds.minY or request.altitude>self.worldBounds.maxY then return false,'Altitude outside the actually observed local flight domain' end
  local target=A.copy(self.controller.position) target.y=request.altitude
  local ok,why=self.controller:target(target,self.controller.orientation)
  if ok then self.progress=Progress.new() end
  return ok,why
 end
 function self:status()
  local out=measureStatus(self)
  out.active=self.active==true out.automatic=self.automatic out.worldBounds=A.copy(self.worldBounds) out.massAdaptation=A.copy(self.massAdaptation) out.degraded=self.degraded out.horizontalFaultSamples=self.horizontalFault or 0 out.essentialFaultSamples=self.essentialFault or 0
  out.progress=self.progress and self.progress:status() or nil
  out.controller=self.controller and self.controller:status() or nil
  out.tiltDiagnostic=self.tiltError out.tiltSamples=self.tiltObserver and self.tiltObserver.n or 0
  out.attitudeQualification=self.attitudeQualification and self.attitudeQualification:status() or nil
  out.qualification=self.qualification and self.qualification:status() or nil
  return out
 end
 return self
end
return M
