-- Bounded, pose-derived observations. No native angular-frame assumptions,
-- actuator writes, model certification or new acquisition.
local A=require('system.libraries.addon')
local G=require('system.navigation.geometry')
local Contract=require('system.ascendancy.contracts')
local M={}
local function difference(a,b,dt) return A.vec({x=(a.x-b.x)/dt,y=(a.y-b.y)/dt,z=(a.z-b.z)/dt}) end
function M.new()
 local self={reason='Need three fresh world poses'}
 function self:reset(why) self.previous=nil self.record=nil self.reason=why end
 function self:observe(pose,now)
  if type(pose)~='table' or pose.frame~='world' or pose.inSublevel~=true or type(pose.vehicleId)~='string' or #pose.vehicleId<1 or #pose.vehicleId>128 or
   not A.finite(now) or not A.finite(pose.timestamp) or pose.timestamp<0 or pose.timestamp>now or now-pose.timestamp>.5 or
   not A.finite(pose.identityAt) or pose.identityAt<0 or pose.identityAt>now or now-pose.identityAt>.5 then self:reset('Fresh world pose and vehicle identity required') return end
  local logical=type(pose.logicalPose)=='table' and pose.logicalPose or {} local position=A.vec(logical.position or logical.pos)
  if not position then self:reset('World position unavailable') return end
  local p=self.previous
  if p and p.vehicleId~=pose.vehicleId then self:reset('Vehicle changed; derivative history cleared') p=nil end
  if p and pose.timestamp==p.at then return end
  local dt=p and pose.timestamp-p.at
  if dt and (dt<.02 or dt>.5) then self:reset('Pose interval outside derivative domain') p=nil dt=nil end
  local row={at=pose.timestamp,vehicleId=pose.vehicleId,position=position,orientation=G.orientation(logical.orientation)}
  local out={schema=1,type='flight-kinematics',source='CC:Sable.getLogicalPose',clock='local_uptime',clockId=Contract.clockId(),
   available=false,vehicleId=row.vehicleId,frame='world',poseAt=row.at,observedAt=row.at,validUntil=row.at+.5,
   units={position='block',velocity='block/s',angularVelocity='rad/s',acceleration='block/s2',angularAcceleration='rad/s2'},
   position=A.copy(position),diagnostics={nativeAngularFrame='not-used'},method='finite-differences-of-world-poses',angularMethod='shortest-quaternion-arc; multiple-turn aliasing unobservable'}
  if p then
   row.velocity=difference(position,p.position,dt) row.velocityAt=(p.at+row.at)/2
   row.angularVelocity=G.angularVelocity(p.orientation,row.orientation,dt)
   out.velocity=A.copy(row.velocity) out.angularVelocity=A.copy(row.angularVelocity)
   out.velocityAt=row.velocityAt out.interval={first=p.at,last=row.at}
   if row.velocity and p.velocity and p.velocityAt then
    local derivativeDt=row.velocityAt-p.velocityAt
    out.acceleration=difference(row.velocity,p.velocity,derivativeDt)
    if row.angularVelocity and p.angularVelocity then out.angularAcceleration=difference(row.angularVelocity,p.angularVelocity,derivativeDt) end
    out.observedAt=(row.velocityAt+p.velocityAt)/2 out.validUntil=out.observedAt+.5
    out.interval.first=p.velocityFrom
    out.body={frame='body_orientation_at_last_pose',orientationAt=row.at,
     linear=G.bodyVector(out.acceleration,row.orientation),angular=G.bodyVector(out.angularAcceleration,row.orientation),
     rotationConvention='positive X/Y/Z right-hand rotations; not Avionics Euler angles'}
    if out.body.linear and out.body.angular then
     local l,r=out.body.linear,out.body.angular
     out.response={forward=l.z,right=l.x,vertical=l.y,pitch=math.deg(r.x),yaw=math.deg(r.y),roll=math.deg(r.z)}
     out.responseUnits={translation='block/s2',rotation='deg/s2'}
     out.available=now<=out.validUntil
    end
   end
   row.velocityFrom=p.at
  end
  out.reason=out.available and 'Six-axis observations available; not a control certificate' or not row.orientation and 'Quaternion unavailable' or 'Need consecutive unambiguous pose derivatives'
  self.previous,self.record,self.reason=row,out,out.reason
 end
 function self:status(now)
  local record=self.record
  if not record or not A.finite(now) or now<record.poseAt or now>record.validUntil then
   return {schema=1,available=false,frame='world',source='CC:Sable.getLogicalPose',clock='local_uptime',clockId=Contract.clockId(),reason=record and 'Pose-derived observation expired' or self.reason,observedAt=record and record.observedAt or 0}
  end
  return A.copy(record)
 end
 return self
end
return M
