-- Local pose feedback through measured, box-constrained output allocation.
-- This object never writes outputs and does not certify its own flight trials.
local A=require('system.libraries.addon')
local G=require('system.navigation.geometry')
local C=require('system.ascendancy.contracts')
local R=require('system.navigation.response_model')
local M={}
function M.new(model,pose,k)
 local domain=model and model.motionDomain
 local position=k and A.vec(k.position) local q=pose and pose.logicalPose and G.orientation(pose.logicalPose.orientation)
 if not model or model.kind~='measured-output-response' or not domain or not A.finite(domain.delay) or domain.delay<=0 or not A.finite(domain.sampleInterval) or domain.sampleInterval<=0 or not position or not q then return nil,'Measured response, motion domain and pose reference required' end
 if model.vehicleId~=pose.vehicleId or model.vehicleId~=k.vehicleId or pose.frame~='world' or k.frame~='world' then return nil,'Controller frame/vehicle mismatch' end
 local self={model=A.copy(model),position=A.copy(position),orientation=A.copy(q),origin=A.copy(position),reference=A.copy(q),
  omega=1/(4*(domain.delay+domain.sampleInterval)),axes={},error={},rates={},rateTolerance={},values={},integral={},reason='Measured local feedback; not a flight certificate'}
 local count=0
 local initialModel,why=R.orient(model,q) if not initialModel then return nil,why end
 self.allocationModel=initialModel
 for i,axis in ipairs(R.axes) do
  local extent=domain.worldExcursion and domain.worldExcursion[i] local rate=domain.worldMaxRate and domain.worldMaxRate[i]
  if not A.finite(extent) or not A.finite(rate) or extent<0 or rate<0 then return nil,'Invalid measured motion bounds' end
  local feasible=true
  for _,sign in ipairs({-1,1}) do
   local demand={0,0,0,0,0,0} demand[i]=initialModel.scale[i]*.1*sign
   local result=R.allocate(initialModel,demand)
   if not result or result.normalizedResidual>.005 then feasible=false end
  end
  local spread=0
  for _,col in ipairs(model.columns) do
   local sum=0 for j=i<=3 and 1 or 4,i<=3 and 3 or 6 do sum=sum+(col.noise and col.noise[j] or 0)^2 end
   spread=math.max(spread,math.sqrt(sum))
  end
  self.axes[axis]=feasible and initialModel.scale[i]>=3*spread and model.authority.condition and model.authority.condition<=1000 and extent>=(i<=3 and .5 or 2.5) and rate>=(i<=3 and .02 or .1)
  self.rateTolerance[i]=i<=3 and .1 or math.max(.5,math.min(rate*.5,2*initialModel.scale[i]*domain.sampleInterval))
  if self.axes[axis] then count=count+1 end self.integral[i]=0
 end
 if count==0 then return nil,'No bidirectional axis with a measured motion domain large enough for closed-loop tests' end
 for _,col in ipairs(model.columns) do self.values[col.id]=col.neutral end
 function self:enableTilt(tilt,current)
  if not tilt or tilt.kind~='passive-measured-tilt-response' or tilt.vehicleId~=self.model.vehicleId or not self.axes.vertical or not self.axes.pitch or not self.axes.roll or self.axes.forward or self.axes.right then return false,'Tilt strategy requires qualified thrust/attitude without direct lateral allocation' end
  local p=current and A.vec(current.position) if not p then return false,'Current position required for local tilt tests' end
  if not A.finite(tilt.attitudeSettle) or tilt.attitudeSettle<=0 then return false,'Actual attitude settling evidence required before tilt guidance' end
  self.tilt=A.copy(tilt) self.strategy='measured-tilt'
  self.tiltOmega=math.min(self.omega*.25,2/tilt.attitudeSettle)
  self.axes.forward=true self.axes.right=true
  self.origin,self.position=A.copy(p),A.copy(p)
  self.model.motionDomain.worldExcursion[1]=tilt.extent[2] self.model.motionDomain.worldExcursion[2]=tilt.extent[1]
  self.model.motionDomain.worldMaxRate[1]=tilt.maxRate[2] self.model.motionDomain.worldMaxRate[2]=tilt.maxRate[1]
  return true
 end
 function self:target(position,orientation)
  local p=A.vec(position) local rotation=G.orientation(orientation)
  if not p or not rotation then return false,'Invalid measured-controller target' end
  self.position,self.orientation=p,rotation return true
 end
 function self:step(observation,current,ack,now)
  if not C.fresh(observation,now) or observation.available~=true or observation.frame~='world' or observation.vehicleId~=self.model.vehicleId or
   not observation.units or observation.units.velocity~='block/s' or observation.units.angularVelocity~='rad/s' then return nil,'Measured-controller derivatives lost/stale' end
  if not current or current.vehicleId~=self.model.vehicleId or current.inSublevel~=true or current.frame~='world' or not A.finite(current.timestamp) or current.timestamp>now or now-current.timestamp>.5 then return nil,'Measured-controller pose/identity lost' end
  local actual=A.vec(observation.position) local orientation=G.orientation(current.logicalPose and current.logicalPose.orientation)
  if not actual or not orientation then return nil,'Measured-controller position/orientation unavailable' end
  local targetOrientation=self.orientation
  if self.tilt and not self.tiltSuspended then
   local t=self.tilt local v=A.vec(observation.velocity) local a=A.vec(observation.acceleration)
   if not v or not a then return nil,'Tilt motion observations unavailable' end
   local function demand(error,rate,maximum)
    local desired=math.max(-maximum*.5,math.min(maximum*.5,self.tiltOmega*error))
    return 2*self.tiltOmega*(desired-rate)
   end
   local requestedX=demand(self.position.x-actual.x,v.x,t.maxRate[1])
   local requestedZ=demand(self.position.z-actual.z,v.z,t.maxRate[2])
   local x,z=t.coefficients[1],t.coefficients[2]
   local a11,a12,a21,a22=x[1]+a.y,x[2],z[1],z[2]+a.y
   local determinant=a11*a22-a12*a21
   if not A.finite(determinant) or math.abs(determinant)<1e-5 then return nil,'Measured tilt allocation lost rank' end
   local ex=requestedX-x[3]*v.x-x[4]*v.z-x[5]
   local ez=requestedZ-z[3]*v.x-z[4]*v.z-z[5]
   local ux=(ex*a22-ez*a12)/determinant local uz=(ez*a11-ex*a21)/determinant
   if not A.finite(ux) or not A.finite(uz) then return nil,'Invalid measured tilt demand' end
   self.tiltDemand={ux,uz}
   self.tiltSaturated=math.abs(ux)>t.ratio[1] or math.abs(uz)>t.ratio[2]
   ux=math.max(-t.ratio[1],math.min(t.ratio[1],ux)) uz=math.max(-t.ratio[2],math.min(t.ratio[2],uz))
   local n=math.sqrt(1+ux*ux+uz*uz) local up={x=ux/n,y=1/n,z=uz/n}
   local length=math.sqrt(up.z^2+up.x^2+(1+up.y)^2)
   local rotation={x=up.z/length,y=0,z=-up.x/length,w=(1+up.y)/length}
   local b=self.orientation local r=rotation
   targetOrientation={w=r.w*b.w-r.x*b.x-r.y*b.y-r.z*b.z,x=r.w*b.x+r.x*b.w+r.y*b.z-r.z*b.y,
    y=r.w*b.y-r.x*b.z+r.y*b.w+r.z*b.x,z=r.w*b.z+r.x*b.y-r.y*b.x+r.z*b.w}
  end
  local angularError
  if not self.axes.yaw and (self.axes.pitch or self.axes.roll) then
   local upBody=G.bodyVector({x=0,y=1,z=0},self.reference)
   local function world(q) return G.transform(upBody,{position={x=0,y=0,z=0},rotationPoint={x=0,y=0,z=0},scale={x=1,y=1,z=1},orientation=q}) end
   local from,to=world(orientation),world(targetOrientation)
   if not from or not to then return nil,'Measured up-axis observations unavailable' end
   local dot=math.max(-1,math.min(1,from.x*to.x+from.y*to.y+from.z*to.z))
   local cross={x=from.y*to.z-from.z*to.y,y=from.z*to.x-from.x*to.z,z=from.x*to.y-from.y*to.x}
   local length=math.sqrt(cross.x^2+cross.y^2+cross.z^2)
   if dot< -.999 then return nil,'Measured up-axis inverted; no qualified recovery' end
   local factor=length>1e-9 and G.atan2(length,dot)/length or 0
   angularError={x=cross.x*factor,y=cross.y*factor,z=cross.z*factor}
  elseif self.axes.pitch or self.axes.yaw or self.axes.roll then angularError=G.angularVelocity(orientation,targetOrientation,1)
  else angularError={x=0,y=0,z=0} end
  local velocity,angular=A.vec(observation.velocity),A.vec(observation.angularVelocity)
  local error=angularError and {self.position.z-actual.z,self.position.x-actual.x,self.position.y-actual.y,math.deg(angularError.x),math.deg(angularError.y),math.deg(angularError.z)}
  local rates=velocity and angular and {velocity.z,velocity.x,velocity.y,math.deg(angular.x),math.deg(angular.y),math.deg(angular.z)}
  if not error or not rates then return nil,'Measured-controller angular interval ambiguous' end
  if self.last and observation.observedAt<self.last then return nil,'Measured-controller clock regressed' end
  if self.last and observation.observedAt==self.last then return A.copy(self.values) end
  self.error,self.rates=error,rates
  local dt=self.last and observation.observedAt-self.last or 0 self.last=observation.observedAt
  if dt>.5 then return nil,'Measured-controller observation gap' end
  if not ack then return A.copy(self.values) end
  local allocationModel,why=R.orient(self.model,orientation) if not allocationModel then return nil,why end
  self.allocationModel=allocationModel
  local wanted={}
  for i,axis in ipairs(R.axes) do
   wanted[i]=0
   if self.axes[axis] then
    local maximum=self.model.motionDomain.worldMaxRate[i]*.5
    local desired=math.max(-maximum,math.min(maximum,self.omega*error[i]))
    local change=self.omega^3*.1*error[i]*math.max(0,math.min(.5,dt))
    if not self.residual or self.residual<=.005 or error[i]*(self.requested and self.requested[i] or 0)<=0 then
     self.integral[i]=math.max(-self.allocationModel.scale[i]*.5,math.min(self.allocationModel.scale[i]*.5,self.integral[i]+change))
    end
    wanted[i]=2*self.omega*(desired-rates[i])+self.integral[i]
   end
  end
  if self.tilt and not self.tiltSuspended then
   local up=G.transform(self.tilt.upBody,{position={x=0,y=0,z=0},rotationPoint={x=0,y=0,z=0},scale={x=1,y=1,z=1},orientation=orientation})
   if not up or up.y<.95 then return nil,'Tilt left the observed small-angle flight domain' end
   -- Relative thrust changes also have the measured body's current direction.
   -- Lateral position is controlled by attitude, not fictitious direct thrust.
   wanted[1]=wanted[3]*up.z/up.y wanted[2]=wanted[3]*up.x/up.y
  end
  local allocation,why=R.allocate(self.allocationModel,wanted) if not allocation then return nil,why end
  self.saturated=allocation.saturated self.residual=allocation.normalizedResidual self.requested=A.copy(wanted) self.actualResponse=A.copy(allocation.actual)
  for _,col in ipairs(self.model.columns) do self.values[col.id]=col.neutral+allocation.delta[col.id] end
  return A.copy(self.values)
 end
 function self:status()
  return {scope='measured-local-controller-not-flight-certificate',strategy=self.strategy or 'direct-measured-allocation',tiltOmega=self.tiltOmega,tiltSaturated=self.tiltSaturated,frame='world_acceleration_and_world_rotation_vectors',axes=A.copy(self.axes),error=A.copy(self.error),rates=A.copy(self.rates),rateTolerance=A.copy(self.rateTolerance),
   saturated=self.saturated,residual=self.residual,integral=A.copy(self.integral),omega=self.omega,position=A.copy(self.position),orientation=A.copy(self.orientation),reason=self.reason}
 end
 return self
end
return M
