local function makePortableModules()
 local factories,cache={},{}
 factories["system.libraries.addon"]=function(require)
-- Minimal pure-data dependency used by the unchanged navigation mathematics.
local M={}
function M.finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
function M.vec(v)
 if type(v)~='table' then return end
 local x,y,z=v.x or v[1],v.y or v[2],v.z or v[3]
 if M.finite(x) and M.finite(y) and M.finite(z) then return {x=x,y=y,z=z} end
end
function M.copy(value)
 local seen,count={},0
 local function clone(v,depth)
  if type(v)~='table' then return v end
  assert(depth<=24 and not seen[v],'Unsupported cyclic/deep data')
  seen[v]=true local out={}
  for k,item in pairs(v) do count=count+1 assert(count<=32768,'Data budget exceeded') out[k]=clone(item,depth+1) end
  seen[v]=nil return out
 end
 return clone(value,0)
end
return M

 end
 factories["system.ascendancy.contracts"]=function(require)
 local os={clock=function() local t=type(getUniverseTime)=='function' and getUniverseTime() or nil assert(type(t)=='number' and t==t and t>=0 and t<math.huge,'Sputnik server clock unavailable') return t/20 end}
-- Real-data interchange contracts, not an autopilot or a source simulator.
local M={schema=1,maxPayloadBytes=262144,maxMapBytes=65536}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function label(v,limit) return type(v)=='string' and #v>0 and #v<=(limit or 256) and not v:find('%c') end
local computer=os.getComputerID and os.getComputerID() or 'unknown-computer'
local hasEpoch,epoch=pcall(function() return os.epoch and os.epoch('utc') end)
local clockId=tostring(computer)..':'..tostring(hasEpoch and epoch or 'unknown-epoch')..':'..tostring({})
function M.clockId() return clockId end
function M.clone(value)
 local count,bytes,seen=0,0,{}
 local function copy(v,depth)
  local kind=type(v)
  if kind=='number' then assert(finite(v),'Nonfinite payload number') return v end
  if kind=='string' then bytes=bytes+#v assert(bytes<=M.maxPayloadBytes,'Payload text budget exceeded') return v end
  if kind=='nil' or kind=='boolean' then return v end
  assert(kind=='table' and depth<=12 and not getmetatable(v),'Unsupported payload value')
  assert(not seen[v],'Cyclic payload') seen[v]=true
  local out={}
  for k,item in pairs(v) do
   count=count+1 assert(count<=32768,'Payload item budget exceeded')
   assert(type(k)=='string' or type(k)=='number' and finite(k),'Unsupported payload key')
   if type(k)=='string' then bytes=bytes+#k assert(bytes<=M.maxPayloadBytes,'Payload key budget exceeded') end
   out[k]=copy(item,depth+1)
  end
  seen[v]=nil return out
 end
 local ok,result=pcall(copy,value,0)
 if ok then return result end
 return nil,tostring(result)
end
function M.fresh(record,now)
 if now==nil then now=os.clock() end
 return type(record)=='table' and record.clock=='local_uptime' and record.clockId==clockId
   and finite(now) and finite(record.observedAt) and finite(record.validUntil)
   and record.observedAt>=0 and record.observedAt<=now and record.validUntil>=record.observedAt and now<=record.validUntil
end
function M.validateObservation(o,now,archive)
 if type(o)~='table' or getmetatable(o)~=nil or o.schema~=1 or o.valid~=true or o.synthetic==true then return false,'Unsupported/non-real observation' end
 if not label(o.source) or not label(o.entityId) or not label(o.field) or not label(o.clockId) or o.clock~='local_uptime'
   or not finite(o.observedAt) or o.observedAt<0 or not finite(o.validUntil) or o.validUntil<o.observedAt then return false,'Observation provenance/clock missing' end
 if o.origin~='observed' and o.origin~='derived' then return false,'Observation origin must be explicit' end
 if o.origin=='derived' and (type(o.parents)~='table' or #o.parents<1) then return false,'Derived observation needs parent provenance' end
 if not archive and not M.fresh(o,now) then return false,'Observation stale, future or different boot clock' end
 if o.kind=='position' then
  if (o.frame~='world' and o.frame~='body_plot') or o.unit~='block' or type(o.value)~='table'
    or getmetatable(o.value)~=nil or not finite(o.value.x) or not finite(o.value.y) or not finite(o.value.z) then return false,'Known position/frame/unit required' end
 elseif o.kind=='scalar' then
  if not finite(o.value) or not label(o.unit,32) then return false,'Scalar value/unit required' end
 elseif o.kind=='status' then
  if type(o.value)~='boolean' and not label(o.value) then return false,'Status value missing' end
 else return false,'Unsupported observation kind' end
 if o.frame=='body_plot' and not label(o.vehicleId,128) then return false,'Body plot needs vessel identity' end
 return true
end
function M.compatible(a,b,now)
 local ok,err=M.validateObservation(a,now) if not ok then return false,err end
 ok,err=M.validateObservation(b,now) if not ok then return false,err end
 if not label(a.namespace) or a.namespace~=b.namespace then return false,'World/dimension namespace unknown or different' end
 if not a.frame or a.frame=='unknown' or a.frame~=b.frame or a.unit~=b.unit or a.entityId~=b.entityId or a.field~=b.field or a.kind~=b.kind then return false,'Incompatible frame/unit/entity/field' end
 if a.frame=='body_plot' and a.vehicleId~=b.vehicleId then return false,'Different body plot identities' end
 return true
end
function M.validateMap(map)
 if type(map)~='table' or getmetatable(map)~=nil or map.schema~=1 or map.type~='atlas-map' or not label(map.namespace) or map.frame~='world' or map.unit~='block'
   or type(map.entries)~='table' or getmetatable(map.entries)~=nil or #map.entries>1024 then return false,'Invalid persistent map schema/frame/namespace' end
 local count=0
 for k,o in pairs(map.entries) do
  count=count+1
  if type(k)~='number' or k%1~=0 or k<1 or k>#map.entries then return false,'Invalid map entry sequence' end
  local ok,err=M.validateObservation(o,nil,true) if not ok then return false,err end
  if o.kind~='position' or o.frame~='world' or o.unit~='block' or o.namespace~=map.namespace then return false,'Map entry namespace/frame mismatch' end
 end
 if count~=#map.entries then return false,'Incomplete map sequence' end
 return true
end
function M.encodeMap(map)
 local ok,err=M.validateMap(map) if not ok then return nil,err end
 local copy,problem=M.clone(map) if not copy then return nil,problem end
 local success,text=pcall(textutils.serialize,copy)
 if not success or type(text)~='string' or #text>M.maxMapBytes then return nil,'Map serialization/size refused' end
 return text
end
function M.decodeMap(text)
 if type(text)~='string' or #text>M.maxMapBytes then return nil,'Map input size refused' end
 local ok,map=pcall(textutils.unserialize,text)
 if not ok then return nil,'Map decoding failed' end
 local valid,err=M.validateMap(map) if not valid then return nil,err end
 return M.clone(map)
end
function M.validateMission(mission)
 local copy,problem=M.clone(mission) if not copy then return false,problem end
 mission=copy
 if type(mission)~='table' or mission.schema~=1 or mission.type~='waypoint-mission' or mission.frame~='world' or mission.unit~='block'
   or not label(mission.namespace) or not label(mission.vehicleId,128) or type(mission.route)~='table'
   or mission.route.verifiedVehicleId~=mission.vehicleId then return false,'Mission namespace/frame/vessel binding required' end
 -- Validation only: the existing flight service owns all authorization/arming.
 return require('system.navigation.autopilot').validate(mission.route)
end
function M.statusFor(envelope,now)
 if now==nil then now=os.clock() end
 if type(envelope)~='table' or envelope.schema~=1 then return {state='unavailable',reason='Unsupported source envelope'} end
 local live=envelope.available==true and M.fresh(envelope,now)
 local result={source=envelope.source,state=live and 'ready' or 'unavailable',reason=live and (envelope.status or 'Fresh source cache') or envelope.reason or 'Source stale or clock unknown',frame=envelope.frame,namespace=envelope.namespace}
 if envelope.clockId==clockId and finite(envelope.observedAt) and finite(now) and now>=envelope.observedAt then result.age=now-envelope.observedAt end
 return result
end
return M

 end
 factories["system.navigation.geometry"]=function(require)
local addon = require("system.libraries.addon")
local M = {}

function M.wrap(angle) return (angle + 180) % 360 - 180 end
function M.atan2(y, x)
  if x > 0 then return math.atan(y / x) end
  if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
  return y > 0 and math.pi / 2 or y < 0 and -math.pi / 2 or 0
end

-- Same convention as Avionics NavTable: rotate body +Z, atan2(world X,Z).
local function quaternion(q)
  if type(q)~="table" then return end
  if q.a~=nil or q.v~=nil then
    if type(q.v)~="table" then return end
    return q.v.x,q.v.y,q.v.z,q.a
  end
  return q.x or q[1],q.y or q[2],q.z or q[3],q.w or q[4]
end
-- Rotation utilities share the exact supported Sable quaternion encodings.
function M.orientation(value)
 local x,y,z,w=quaternion(value)
 if not (addon.finite(x) and addon.finite(y) and addon.finite(z) and addon.finite(w)) then return nil end
 local n=math.sqrt(x*x+y*y+z*z+w*w)
 if not addon.finite(n) or n<1e-9 then return nil end
 return {x=x/n,y=y/n,z=z/n,w=w/n}
end
function M.angularVelocity(previous,current,dt)
 if not addon.finite(dt) or dt<=0 then return nil end
 local a,b=M.orientation(previous),M.orientation(current) if not a or not b then return nil end
 -- current * conjugate(previous): axis-angle in WORLD axes, radians/second.
 local x=-b.w*a.x+b.x*a.w-b.y*a.z+b.z*a.y
 local y=-b.w*a.y+b.x*a.z+b.y*a.w-b.z*a.x
 local z=-b.w*a.z-b.x*a.y+b.y*a.x+b.z*a.w
 local w=b.w*a.w+b.x*a.x+b.y*a.y+b.z*a.z
 if w<0 then x,y,z,w=-x,-y,-z,-w end
 if w<1e-3 then return nil,'Rotation interval near 180 degrees is ambiguous' end
 local n=math.sqrt(x*x+y*y+z*z)
 local factor=n<1e-9 and 2/dt or 2*M.atan2(n,w)/(n*dt)
 return {x=x*factor,y=y*factor,z=z*factor}
end
function M.bodyVector(value,orientation)
 local q=M.orientation(orientation) if not q then return nil end
 return M.transform(value,{position={x=0,y=0,z=0},rotationPoint={x=0,y=0,z=0},scale={x=1,y=1,z=1},orientation={x=-q.x,y=-q.y,z=-q.z,w=q.w}})
end
function M.heading(orientation)
  if type(orientation)~="table" then return nil end
  local x,y,z,w=quaternion(orientation)
  if not (addon.finite(x) and addon.finite(y) and addon.finite(z) and addon.finite(w)) then return nil end
  local norm=x*x+y*y+z*z+w*w
  if not addon.finite(norm) or norm<1e-12 then return nil end
  local forwardX,forwardZ=2*(x*z+w*y)/norm,1-2*(x*x+y*y)/norm
  if forwardX*forwardX+forwardZ*forwardZ<1e-8 then return nil end
  return math.deg(M.atan2(forwardX,forwardZ))%360
end

function M.relative(position, origin, heading)
  position, origin = addon.vec(position), addon.vec(origin)
  if not position or not origin then return nil, "world origin/position unavailable" end
  local dx, dy, dz = position.x - origin.x, position.y - origin.y, position.z - origin.z
  local a = math.rad(heading or 0)
  return { x = dx * math.cos(a) - dz * math.sin(a), y = dy, z = dx * math.sin(a) + dz * math.cos(a),
    distance = math.sqrt(dx * dx + dz * dz), bearing = math.deg(M.atan2(dx, dz)) }
end

function M.transform(point, pose)
  point = addon.vec(point)
  if not point or type(pose) ~= "table" then return nil, "unknown pose" end
  local origin = addon.vec(pose.position)
  local q = pose.orientation
  if not origin or type(q) ~= "table" then return nil, "unknown pose convention" end
  local x, y, z, w = quaternion(q)
  if not (addon.finite(x) and addon.finite(y) and addon.finite(z) and addon.finite(w)) then return nil end
  local norm = math.sqrt(x*x + y*y + z*z + w*w)
  if not addon.finite(norm) or norm < 1e-9 then return nil end
  x, y, z, w = x/norm, y/norm, z/norm, w/norm
  local pivot = addon.vec(pose.rotationPoint)
  local scale = addon.vec(pose.scale)
  if not pivot or not scale then return nil,"pose pivot/scale unavailable" end
  local px, py, pz = (point.x-pivot.x)*scale.x, (point.y-pivot.y)*scale.y, (point.z-pivot.z)*scale.z
  local tx, ty, tz = 2*(y*pz-z*py), 2*(z*px-x*pz), 2*(x*py-y*px)
  return { x = origin.x + px + w*tx + y*tz-z*ty,
    y = origin.y + py + w*ty + z*tx-x*tz, z = origin.z + pz + w*tz + x*ty-y*tx }
end

return M

 end
 factories["system.navigation.state_estimator"]=function(require)
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

 end
 factories["system.navigation.authority"]=function(require)
-- Measured control-space diagnostics and bounded horizontal supervision.
-- This module never probes hardware, invents an axis or writes an actuator.
local A=require('system.libraries.addon')
local M={}
local limits={forward=.01,right=.01,vertical=.01,pitch=.1,yaw=.1,roll=.1}
local function sequence(value,maximum)
 if type(value)~='table' or getmetatable(value) or #value<1 or #value>maximum then return false end
 local count=0 for key in pairs(value) do
  if type(key)~='number' or key%1~=0 or key<1 or key>#value then return false end count=count+1
 end
 return count==#value
end
function M.identify(axes,columns)
 if not sequence(axes,6) or not sequence(columns,32) then return nil,'Response matrix bounds invalid' end
 local seen,scale={},{}
 for i,axis in ipairs(axes) do
  if not limits[axis] or seen[axis] then return nil,'Unknown/duplicate response axis' end seen[axis]=true scale[i]=0
  for _,column in ipairs(columns) do
   if type(column)~='table' or getmetatable(column) or type(column.id)~='string' or #column.id<1 or #column.id>192 or type(column.values)~='table' or getmetatable(column.values) or not A.finite(column.values[axis]) then return nil,'Complete measured columns required' end
   scale[i]=math.max(scale[i],math.abs(column.values[axis]))
  end
 end
 local ids,Q,vectors={}, {},{} local smallest,largest=math.huge,0
 for _,column in ipairs(columns) do
  if ids[column.id] then return nil,'Duplicate actuator column' end ids[column.id]=true
  local v={}
  for i,axis in ipairs(axes) do v[i]=scale[i]>=limits[axis] and column.values[axis]/scale[i] or 0 end
  vectors[#vectors+1]=v
 end
 -- Column-pivoted, reorthogonalized Gram-Schmidt. Redundant weak columns
 -- cannot spoil a well-conditioned independently observed subset.
 local used={}
 for step=1,math.min(#axes,#vectors) do
  local best,bestVector,bestNorm=nil,nil,0
  for j,original in ipairs(vectors) do if not used[j] then
   local v={} for i,value in ipairs(original) do v[i]=value end
   for pass=1,2 do for _,q in ipairs(Q) do
    local dot=0 for i=1,#axes do dot=dot+v[i]*q[i] end
    for i=1,#axes do v[i]=v[i]-dot*q[i] end
   end end
   local norm=0 for _,value in ipairs(v) do norm=norm+value*value end norm=math.sqrt(norm)
   if norm>bestNorm then best,bestVector,bestNorm=j,v,norm end
  end end
  if bestNorm<=1e-3 then break end
  used[best]=true smallest,largest=math.min(smallest,bestNorm),math.max(largest,bestNorm)
  for i=1,#axes do bestVector[i]=bestVector[i]/bestNorm end Q[#Q+1]=bestVector
 end
 local out={schema=1,rank=#Q,axes={},columns=#columns,condition=#Q>0 and largest/smallest or nil,scope='response-subspace-only'}
 for i,axis in ipairs(axes) do
  local projection=0 for _,q in ipairs(Q) do projection=projection+q[i]^2 end
  local observed=scale[i]>=limits[axis]
  local independent=observed and 1-projection<1e-5 and out.condition<=1000
  out.axes[axis]={observed=observed,independent=independent,peak=scale[i],
   reason=independent and 'Independent response measured in supplied subspace' or observed and 'Coupled/ill-conditioned response; axis not independently certified' or 'Response below identification threshold'}
 end
 return out
end
function M.braking(rows)
 local a,reaction,speed,count=math.huge,0,0,0
 for _,r in ipairs(rows or {}) do
  if A.finite(r.brakeSpeed) and r.brakeSpeed>=.15 and A.finite(r.brakingDistance) and r.brakingDistance>1e-5 and
   A.finite(r.reactionTime) and r.reactionTime>=0 and r.reactionTime<=10 then
   a=math.min(a,r.brakeSpeed^2/(2*r.brakingDistance)) reaction=math.max(reaction,r.reactionTime)
   speed=math.max(speed,r.brakeSpeed) count=count+1
  end
 end
 if count<2 or not A.finite(a) or a<=0 then return nil,'Observed neutral braking envelope unavailable' end
 return {schema=1,deceleration=a,reactionTime=reaction,maxObservedSpeed=speed,samples=count,source='acknowledged-neutral-stops'}
end
function M.speed(envelope,distance)
 if not envelope or not A.finite(envelope.deceleration) or envelope.deceleration<=0 or not A.finite(envelope.reactionTime) or envelope.reactionTime<0 or
  not A.finite(envelope.maxObservedSpeed) or envelope.maxObservedSpeed<=0 or not A.finite(distance) then return nil end
 distance=math.max(0,distance)
 local a,t=envelope.deceleration,envelope.reactionTime
 local denominator=math.sqrt((a*t)^2+2*a*distance)+a*t
 return denominator>0 and math.min(envelope.maxObservedSpeed,2*a*distance/denominator) or 0
end
function M.monitor()
 local self={samples=0}
 function self:observe(s,expected,ack)
  if not ack or not expected or not s or not s.velocity or not A.finite(s.at) or not A.finite(s.yawRate) then self.samples=0 return end
  if self.last and s.at<=self.last then return end
  if self.last and s.at-self.last<.5 then return end
  if self.last and s.at-self.last>1.5 then self.samples=0 end self.last=s.at
  if not A.finite(expected.forward) or not A.finite(expected.yaw) or not A.finite(s.velocity.x) or not A.finite(s.velocity.z) then self.samples=0 return end
  local strong=math.abs(expected.forward)>=.02 or math.abs(expected.yaw)>=.5
  local stationary=s.velocity.x^2+s.velocity.z^2<.05^2 and math.abs(s.yawRate)<.1
  self.samples=strong and stationary and self.samples+1 or 0
  if self.samples>=8 then return 'Confirmed motor commands without measurable horizontal response' end
 end
 return self
end
return M

 end
 factories["system.navigation.response_model"]=function(require)
-- Six-axis identification and bounded allocation for explicitly assigned outputs.
-- Pure mathematics: no peripheral access, output writes or client certificates.
local A=require('system.libraries.addon')
local Authority=require('system.navigation.authority')
local G=require('system.navigation.geometry')
local M={}
M.axes={'forward','right','vertical','pitch','yaw','roll'}
local floors={.01,.01,.01,.1,.1,.1}
local function vector(v)
 if type(v)~='table' or #v~=6 then return end
 local out={} for i=1,6 do if not A.finite(v[i]) then return end out[i]=v[i] end return out
end
local function sequence(t,limit)
 if type(t)~='table' or getmetatable(t) or #t<1 or #t>limit then return false end
 local n=0 for k in pairs(t) do if type(k)~='number' or k%1~=0 or k<1 or k>#t then return false end n=n+1 end
 return n==#t
end
local function id(s) return type(s)=='string' and #s>0 and #s<=192 and not s:find('%c') end
-- Coordinate descent solves the normalized box-constrained least-squares
-- problem. The iteration budget is fixed; a residual is always returned.
function M.allocate(model,wanted)
 wanted=vector(wanted)
 if not wanted or type(model)~='table' or not sequence(model.columns,32) or not vector(model.scale) then return nil,'Invalid allocation input' end
 local normalized,residual,outputs,columns,seen={},{},{},{},{}
 for i=1,6 do
  if model.scale[i]<=0 then return nil,'Invalid response scale' end
  normalized[i]=wanted[i]/model.scale[i] residual[i]=normalized[i]
  if not A.finite(normalized[i]) then return nil,'Allocation magnitude outside numeric domain' end
 end
 for j,c in ipairs(model.columns) do
  if type(c)~='table' then return nil,'Malformed actuator column' end
  local values=vector(c.response)
  if not values or not id(c.id) or seen[c.id] or not A.finite(c.low) or not A.finite(c.high) or c.low>0 or c.high<0 or c.high-c.low>15 then return nil,'Invalid actuator bounds' end
  seen[c.id]=true
  local v={} local norm=0
  for i=1,6 do v[i]=values[i]/model.scale[i] norm=norm+v[i]^2 end
  if not A.finite(norm) then return nil,'Response magnitude outside numeric domain' end
  columns[j]={v=v,norm=norm,low=c.low,high=c.high} outputs[j]=0
 end
 for _=1,96 do
  local largest=0
  for j,c in ipairs(columns) do
   local dot=0 for i=1,6 do dot=dot+c.v[i]*residual[i] end
   local old=outputs[j]
   local value=c.norm>1e-12 and math.max(c.low,math.min(c.high,old+dot/c.norm)) or 0
   local delta=value-old outputs[j]=value largest=math.max(largest,math.abs(delta))
   for i=1,6 do residual[i]=residual[i]-c.v[i]*delta end
  end
  if largest<1e-8 then break end
 end
 local actual,signals={},{} local error=0 local saturated=false
 for i=1,6 do
  actual[i]=0 for j,c in ipairs(model.columns) do actual[i]=actual[i]+c.response[i]*outputs[j] end
  if not A.finite(actual[i]) then return nil,'Allocated response outside numeric domain' end
  error=math.max(error,math.abs(residual[i]))
 end
 for j,c in ipairs(model.columns) do
  signals[c.id]=outputs[j]
  if math.abs(outputs[j]-c.low)<1e-6 or math.abs(outputs[j]-c.high)<1e-6 then saturated=true end
 end
 return {delta=signals,actual=actual,normalizedResidual=error,saturated=saturated}
end
-- Coupled error diffusion for 16-level hardware. Select integer outputs jointly
-- in response space, rather than rounding each coupled motor independently.
function M.quantize(model,values,state)
 if type(values)~='table' or type(state)~='table' or not model or not sequence(model.columns,32) or not vector(model.scale) then return nil,'Invalid quantizer input' end
 local error=state.error and vector(state.error) or {0,0,0,0,0,0}
 if not error then return nil,'Invalid quantizer history' end
 local columns,selected={},{}
 if state.scale then
  local old=vector(state.scale) if not old then return nil,'Invalid quantizer scale history' end
  for i=1,6 do error[i]=error[i]*old[i]/model.scale[i] end
 end
 for j,col in ipairs(model.columns) do
  if type(col)~='table' or not vector(col.response) or not A.finite(col.neutral) or col.neutral%1~=0 or not A.finite(col.low) or not A.finite(col.high) or col.low%1~=0 or col.high%1~=0 or col.low>0 or col.high<0 or col.low< -15 or col.high>15 then return nil,'Invalid integer output domain' end
  local wanted=values[col.id]
  if not A.finite(wanted) or wanted<col.neutral+col.low-1e-8 or wanted>col.neutral+col.high+1e-8 then return nil,'Quantizer demand outside measured output bounds' end
  local c={low=col.low,high=col.high,values={},norm=0}
  for i=1,6 do
   if not A.finite(model.scale[i]) or model.scale[i]<=0 then return nil,'Invalid quantizer response scale' end
   c.values[i]=col.response[i]/model.scale[i] c.norm=c.norm+c.values[i]^2
   error[i]=error[i]+c.values[i]*(wanted-col.neutral)
   if not A.finite(error[i]) or not A.finite(c.norm) then return nil,'Quantizer numeric domain exceeded' end
  end
  columns[j]=c selected[j]=0
 end
 local clipped=false
 for i=1,6 do if math.abs(error[i])>64 then error[i]=math.max(-64,math.min(64,error[i])) clipped=true end end
 for _=1,16 do
  local changed=false
  for j,c in ipairs(columns) do
   local dot=0 for i=1,6 do dot=dot+c.values[i]*error[i] end
   local nextValue=c.norm>1e-12 and math.max(c.low,math.min(c.high,math.floor(selected[j]+dot/c.norm+.5))) or 0
   local delta=nextValue-selected[j]
   if delta~=0 then changed=true selected[j]=nextValue for i=1,6 do error[i]=error[i]-c.values[i]*delta end end
  end
  if not changed then break end
 end
 local result={}
 for j,col in ipairs(model.columns) do result[col.id]=col.neutral+selected[j] end
 state.error=error state.scale=A.copy(model.scale) state.clipped=clipped
 return result
end
-- Rotate the measured body columns into a single WORLD allocation frame.
-- No forward/up assumption is made about the vehicle's initial orientation.
function M.orient(model,orientation)
 local q=G.orientation(orientation)
 if not q or not model or not sequence(model.columns,32) then return nil,'Known body orientation and measured columns required' end
 local out={columns={},scale={.01,.01,.01,.1,.1,.1},frame='world_acceleration_and_world_rotation_vectors'}
 for _,col in ipairs(model.columns) do
  local values=vector(col.response) if not values then return nil,'Malformed measured response' end
  local function rotate(x,y,z)
   return G.transform({x=x,y=y,z=z},{position={x=0,y=0,z=0},rotationPoint={x=0,y=0,z=0},scale={x=1,y=1,z=1},orientation=q})
  end
  local l,r=rotate(values[2],values[3],values[1]),rotate(values[4],values[5],values[6])
  if not l or not r then return nil,'Response rotation invalid' end
  local c=A.copy(col) c.response={l.z,l.x,l.y,r.x,r.y,r.z}
  out.columns[#out.columns+1]=c
  for i=1,6 do out.scale[i]=math.max(out.scale[i],math.abs(c.response[i])) end
 end
 return out
end
function M.fit(channels,observations,provenance)
 if not sequence(channels,32) or not sequence(observations,64) or type(provenance)~='table' or not id(provenance.vehicleId) or
  provenance.frame~='body_orientation_at_neutral_reference' or provenance.translationUnit~='block/s2' or provenance.rotationUnit~='deg/s2' then return nil,'Explicit vehicle, frame and response units required' end
 local channelIds,groups={},{}
 for _,c in ipairs(channels) do
  if not id(c.id) or channelIds[c.id] then return nil,'Duplicate/invalid assigned output' end
  for _,k in ipairs({'min','max','neutral','rescue'}) do if not A.finite(c[k]) or c[k]%1~=0 or c[k]<0 or c[k]>15 then return nil,'Invalid output domain' end end
  if c.min>c.max or c.neutral<c.min or c.neutral>c.max or c.rescue<c.min or c.rescue>c.max then return nil,'Output outside domain' end
  channelIds[c.id]=c groups[c.id]={}
 end
 for _,o in ipairs(observations) do
  if type(o)~='table' then return nil,'Malformed response observation' end
  local c=channelIds[o.id] local mean,noise=vector(o.response),vector(o.noise)
  if not c or not mean or not noise or not A.finite(o.signal) or o.signal%1~=0 or o.signal==c.neutral or o.signal<c.min or o.signal>c.max or
   not A.finite(o.samples) or o.samples<4 or o.samples>4096 or not A.finite(o.baselineSamples) or o.baselineSamples<4 or o.baselineSamples>4096 or
   not A.finite(o.after) or not A.finite(o.first) or not A.finite(o.last) or o.after<0 or o.first<=o.after or o.last<=o.first or
   o.vehicleId~=provenance.vehicleId or o.singleCommand~=true or o.otherOutputsChanged~=false then return nil,'Complete post-ACK isolated response observations required' end
  if provenance.clockId and (o.clockId~=provenance.clockId or o.clock~=provenance.clock or o.frame~=provenance.frame or o.translationUnit~=provenance.translationUnit or o.rotationUnit~=provenance.rotationUnit) then return nil,'Response provenance differs across derivative intervals' end
  for i=1,6 do if noise[i]<0 then return nil,'Negative measurement spread' end end
  local sign=o.signal>c.neutral and 'positive' or 'negative'
  if groups[o.id][sign] then return nil,'Duplicate response side' end groups[o.id][sign]=o
 end
 local model={schema=1,kind='measured-output-response',vehicleId=provenance.vehicleId,frame=provenance.frame,
  translationUnit=provenance.translationUnit,rotationUnit=provenance.rotationUnit,columns={},scale={0,0,0,0,0,0},
  rejected={},provenance=A.copy(provenance),scope='local-observed-output-domain; closed-loop qualification required'}
 for _,c in ipairs(channels) do
  local g=groups[c.id] local positive,negative=g.positive,g.negative
  local usable=(c.neutral==c.max or positive~=nil) and (c.neutral==c.min or negative~=nil)
  local response,noise={},{}
  for i=1,6 do
   local slopes,spreads={},{}
   for _,o in ipairs({positive or false,negative or false}) do if o then
    local delta=o.signal-c.neutral slopes[#slopes+1]=o.response[i]/delta spreads[#spreads+1]=o.noise[i]/math.abs(delta)
   end end
   local value,spread=slopes[1] or 0,spreads[1] or 0
   if #slopes==2 then
    if math.abs(slopes[1]-slopes[2])>math.max(floors[i],3*(spreads[1]+spreads[2]),.35*math.max(math.abs(slopes[1]),math.abs(slopes[2]))) then usable=false end
    value=(slopes[1]+slopes[2])/2 spread=math.max(spreads[1],spreads[2])
   end
   response[i]=value noise[i]=spread
   if not A.finite(value) or not A.finite(spread) then usable=false end
  end
  if usable then
   -- Never extrapolate to signals not exercised during this characterization.
   local low=negative and negative.signal-c.neutral or 0 local high=positive and positive.signal-c.neutral or 0
   local col={id=c.id,neutral=c.neutral,rescue=c.rescue,low=low,high=high,response=response,noise=noise}
   model.columns[#model.columns+1]=col
   for i=1,6 do model.scale[i]=math.max(model.scale[i],math.abs(response[i])) end
  else model.rejected[#model.rejected+1]={id=c.id,reason='Missing signed observation or contradictory local response'} end
 end
 if #model.columns==0 then return nil,'No consistent measured output column' end
 local matrix={}
 for _,c in ipairs(model.columns) do local values={} for i,axis in ipairs(M.axes) do values[axis]=c.response[i] end matrix[#matrix+1]={id=c.id,values=values} end
 local authority,why=Authority.identify(M.axes,matrix) if not authority then return nil,why end
 model.authority=authority model.axes={}
 local domain={excursion={0,0,0,0,0,0},maxRate={0,0,0,0,0,0},worldExcursion={0,0,0,0,0,0},worldMaxRate={0,0,0,0,0,0},delay=0,sampleInterval=0} local completeDomain=true
 for _,o in ipairs(observations) do
  local extent,rates=vector(o.excursion),vector(o.maxRate)
  local worldExtent,worldRates=vector(o.worldExcursion),vector(o.worldMaxRate)
  if not extent or not rates or not worldExtent or not worldRates then completeDomain=false else
   for i=1,6 do
    if extent[i]<0 or rates[i]<0 or worldExtent[i]<0 or worldRates[i]<0 then completeDomain=false end
    domain.excursion[i]=math.max(domain.excursion[i],extent[i]) domain.maxRate[i]=math.max(domain.maxRate[i],rates[i])
    domain.worldExcursion[i]=math.max(domain.worldExcursion[i],worldExtent[i]) domain.worldMaxRate[i]=math.max(domain.worldMaxRate[i],worldRates[i])
   end
   domain.delay=math.max(domain.delay,o.first-(A.finite(o.appliedAt) and o.appliedAt or o.after))
   domain.sampleInterval=math.max(domain.sampleInterval,(o.last-o.first)/(o.samples-1))
  end
 end
 if completeDomain then model.motionDomain=domain end
 for i=1,6 do model.scale[i]=math.max(floors[i],model.scale[i]) end
 for i,axis in ipairs(M.axes) do
  local observable=authority.axes[axis].independent
  local amplitude=math.max(floors[i],model.scale[i]*.1)
  local worst=0
  for _,sign in ipairs({-1,1}) do
   local demand={0,0,0,0,0,0} demand[i]=sign*amplitude
   local allocation=M.allocate(model,demand)
   worst=math.max(worst,allocation.normalizedResidual)
  end
  local noise=0 for _,c in ipairs(model.columns) do noise=math.max(noise,c.noise[i]) end
  local clear=authority.axes[axis].peak>=math.max(floors[i],3*noise)
  model.axes[axis]={observable=observable and clear,allocatable=observable and clear and worst<=.005,
   testAmplitude=amplitude,residual=worst,noise=noise,
   reason=not observable and 'No independent measured response' or not clear and 'Response below observed noise' or worst>.005 and 'Opposite signed corrections infeasible in observed output bounds' or 'Local bidirectional allocation; closed-loop test still required'}
 end
 return model
end
return M

 end
 factories["system.navigation.measured_controller"]=function(require)
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

 end
 factories["system.navigation.closed_loop_qualification"]=function(require)
-- Real measured-target transitions, never success from an elapsed timer.
local A=require('system.libraries.addon')
local G=require('system.navigation.geometry')
local R=require('system.navigation.response_model')
local Progress=require('system.navigation.motion_progress')
local M={}
local function multiply(a,b)
 return {w=a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z,x=a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,
  y=a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,z=a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w}
end
local function offset(controller,index,value)
 local p,q=A.copy(controller.origin),A.copy(controller.reference)
 if index<=3 then
  local v={x=index==2 and value or 0,y=index==3 and value or 0,z=index==1 and value or 0}
  for _,axis in ipairs({'x','y','z'}) do p[axis]=p[axis]+v[axis] end
 else
  local half=math.rad(value)/2 local r={x=0,y=0,z=0,w=math.cos(half)}
  r[index==4 and 'x' or index==5 and 'y' or 'z']=math.sin(half) q=multiply(r,q)
 end
 return p,q
end
function M.new(controller,only)
 local self={state='running',index=1,steps={},checks={},reason='Checking actual closed-loop response on candidate axes'}
 for i,axis in ipairs(R.axes) do if controller.axes[axis] and (not only or only[axis]) then
  local amplitude=math.min(controller.model.motionDomain.worldExcursion[i]*.2,i<=3 and .5 or 2)
  for _,sign in ipairs({1,-1,0}) do self.steps[#self.steps+1]={axis=axis,index=i,offset=amplitude*sign,amplitude=amplitude} end
 end end
 if #self.steps==0 then return nil,'No candidate axis for closed-loop qualification' end
 function self:abort(why) self.state,self.reason='aborted',why end
 function self:step(current,at,ack)
  if self.state~='running' then return end
  if not A.finite(at) or self.last and at<self.last then self:abort('Qualification clock regressed') return end
  local step=self.steps[self.index]
  if not self.issued then
   local p,q=offset(controller,step.index,step.offset)
   local ok,why=controller:target(p,q) if not ok then self:abort(why) return end
   self.progress=Progress.new()
   self.issued=true self.commandAt=at self.last=nil self.samples=0 self.motion=0 self.from=nil self.low,self.high=math.huge,-math.huge
   self.reason='Measuring '..step.axis..' target '..string.format('%.3f',step.offset)..'; wait for actual motion and stability'
   return
  end
  if not ack or at<=self.commandAt or self.last and at-self.last<.1-1e-8 then return end
  if self.last and at-self.last>.5 then self.samples=0 self.motion=0 self.from=nil end self.last=at
  local error,rates=current.error,current.rates
  if type(error)~='table' or type(rates)~='table' then self:abort('Closed-loop measurements unavailable') return end
  for i=1,6 do if not A.finite(error[i]) or not A.finite(rates[i]) then self:abort('Nonfinite closed-loop measurement') return end end
  self.progress:observe(error,rates,at)
  self.from=self.from or error[step.index]
  local sign=self.from>=0 and 1 or -1
  if sign*rates[step.index]>(step.index<=3 and .01 or .1) and sign*(self.from-error[step.index])>step.amplitude*.25 then self.motion=self.motion+1 end
  local stable=true
  for i,axis in ipairs(R.axes) do if controller.axes[axis] then
   local tolerance=math.max(i<=3 and .02 or .1,math.min(i<=3 and .1 or .5,controller.model.motionDomain.worldExcursion[i]*.04))
   if math.abs(error[i])>tolerance or math.abs(rates[i])>controller.rateTolerance[i] then stable=false end
  end end
  if not stable then self.samples=0 self.low,self.high=math.huge,-math.huge return end
  self.samples=self.samples+1 self.low=math.min(self.low,error[step.index]) self.high=math.max(self.high,error[step.index])
  if self.samples<8 or self.motion<3 or self.high-self.low>step.amplitude*.4 then return end
  self.checks[#self.checks+1]={axis=step.axis,offset=step.offset,amplitude=step.amplitude,motionSamples=self.motion,settledSamples=self.samples,error=error[step.index],rate=rates[step.index],observedAt=at,startedAt=self.commandAt,settleDuration=at-self.commandAt,spread=self.high-self.low}
  self.index=self.index+1 self.issued=false
  if self.index>#self.steps then self.state='complete' self.reason='All candidate axes passed real motion, return and settling tests' end
 end
 function self:status() return {state=self.state,index=self.index,count=#self.steps,reason=self.reason,stableSamples=self.samples or 0,motionSamples=self.motion or 0,checks=A.copy(self.checks),progress=self.progress and self.progress:status() or nil} end
 return self
end
return M

 end
 factories["system.navigation.output_characterization"]=function(require)
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
 function self:reuseCandidate(candidate)
  if self.appliedAt or self.index~=1 or self.phase~='baseline' or type(candidate)~='table' or not candidate.model or candidate.model.vehicleId~=self.vehicleId then return false end
  self.model=A.copy(candidate.model) self.rows=A.copy(candidate.observations) self.reusedFrom={clockId=candidate.sourceClockId,archivedAt=candidate.archivedAt}
  self.steps={} self.reason='Historical candidate: waiting for freshly confirmed stationary neutral' return true
 end
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
     if not self.reusedFrom then self.model,self.modelError=Response.fit(self.channels,self.rows,{vehicleId=self.vehicleId,source='Sable logicalPose derivatives',clock='local_uptime',clockId=C.clockId(),frame='body_orientation_at_neutral_reference',translationUnit='block/s2',rotationUnit='deg/s2'}) end
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
   reusedFrom=A.copy(self.reusedFrom),axes=self.model and A.copy(self.model.axes) or nil}
 end
 return self
end
return M

 end
 factories["system.navigation.tilt_response"]=function(require)
-- Passive identification during existing attitude trials, with no extra pulse.
-- Empirical lateral dynamics: a_h - a_y*u_h/u_y = B*u_h/u_y + D*v_h + wind.
local A=require('system.libraries.addon')
local G=require('system.navigation.geometry')
local C=require('system.ascendancy.contracts')
local M={}
local function rotate(v,q)
 return G.transform(v,{position={x=0,y=0,z=0},rotationPoint={x=0,y=0,z=0},scale={x=1,y=1,z=1},orientation=q})
end
function M.new(vehicleId,reference)
 local q=G.orientation(reference) if not q then return nil,'Tilt reference orientation unavailable' end
 local self={vehicleId=vehicleId,upBody=G.bodyVector({x=0,y=1,z=0},q),n=0,x={0,0,0,0},y={0,0},xx={},xy={},yy={0,0},
  extent={0,0},rates={0,0},ratio={0,0},reason='Need independent tilt and velocity observations'}
 for i=1,4 do self.xx[i]={0,0,0,0} self.xy[i]={0,0} end
 function self:observe(k,pose,ack,now)
  if ack~=true or self.n>=4096 or not C.fresh(k,now) or k.available~=true or k.vehicleId~=self.vehicleId or k.frame~='world' or
   not k.units or k.units.acceleration~='block/s2' or k.units.velocity~='block/s' or not pose or pose.vehicleId~=self.vehicleId or pose.inSublevel~=true or pose.frame~='world' or
   not A.finite(pose.timestamp) or pose.timestamp>now or now-pose.timestamp>.5 then return end
  if self.last and k.observedAt<=self.last then return end self.last=k.observedAt
  local orientation=G.orientation(pose.logicalPose and pose.logicalPose.orientation)
  local p,v,a=A.vec(k.position),A.vec(k.velocity),A.vec(k.acceleration)
  local up=orientation and rotate(self.upBody,orientation)
  if not p or not v or not a or not up or up.y<.95 then return end
  self.origin=self.origin or p
  local x={up.x/up.y,up.z/up.y,v.x,v.z}
  local y={a.x-a.y*x[1],a.z-a.y*x[2]}
  for _,value in ipairs(x) do if not A.finite(value) then return end end
  for _,value in ipairs(y) do if not A.finite(value) then return end end
  local n=self.n+1 local dx,dy={},{}
  for i=1,4 do dx[i]=x[i]-self.x[i] self.x[i]=self.x[i]+dx[i]/n end
  for j=1,2 do dy[j]=y[j]-self.y[j] self.y[j]=self.y[j]+dy[j]/n self.yy[j]=self.yy[j]+dy[j]*(y[j]-self.y[j]) end
  for i=1,4 do
   for j=1,4 do self.xx[i][j]=self.xx[i][j]+dx[i]*(x[j]-self.x[j]) end
   for j=1,2 do self.xy[i][j]=self.xy[i][j]+dx[i]*(y[j]-self.y[j]) end
  end
  self.n=n
  self.ratio[1]=math.max(self.ratio[1],math.abs(x[1])) self.ratio[2]=math.max(self.ratio[2],math.abs(x[2]))
  self.extent[1]=math.max(self.extent[1],math.abs(p.x-self.origin.x)) self.extent[2]=math.max(self.extent[2],math.abs(p.z-self.origin.z))
  self.rates[1]=math.max(self.rates[1],math.abs(v.x)) self.rates[2]=math.max(self.rates[2],math.abs(v.z))
 end
 function self:fit()
  if self.n<128 then return nil,'Fewer than 128 passive tilt/velocity observations' end
  local scale,matrix={},{}
  for i=1,4 do
   scale[i]=math.sqrt(math.max(0,self.xx[i][i]))
   if scale[i]<1e-6 then return nil,'Tilt/velocity feature did not vary independently' end
  end
  for i=1,4 do
   matrix[i]={}
   for j=1,4 do matrix[i][j]=self.xx[i][j]/(scale[i]*scale[j]) end
   for j=1,2 do matrix[i][4+j]=self.xy[i][j]/scale[i] end
  end
  local smallest,largest=math.huge,0
  for pivot=1,4 do
   local best=pivot for i=pivot+1,4 do if math.abs(matrix[i][pivot])>math.abs(matrix[best][pivot]) then best=i end end
   local divisor=matrix[best][pivot]
   if math.abs(divisor)<1e-4 then return nil,'Passive tilt fit is rank-deficient or ill-conditioned' end
   smallest,largest=math.min(smallest,math.abs(divisor)),math.max(largest,math.abs(divisor))
   matrix[pivot],matrix[best]=matrix[best],matrix[pivot]
   for j=pivot,6 do matrix[pivot][j]=matrix[pivot][j]/divisor end
   for i=1,4 do if i~=pivot then local factor=matrix[i][pivot] for j=pivot,6 do matrix[i][j]=matrix[i][j]-factor*matrix[pivot][j] end end end
  end
  if largest/smallest>1000 then return nil,'Passive tilt fit condition exceeds measured-model limit' end
  local coefficients,noise={},{}
  for j=1,2 do
   local row={} local intercept=self.y[j] local explained=0
   for i=1,4 do row[i]=matrix[i][4+j]/scale[i] intercept=intercept-row[i]*self.x[i] explained=explained+row[i]*self.xy[i][j] end
   row[5]=intercept coefficients[j]=row
   noise[j]=math.sqrt(math.max(0,(self.yy[j]-explained)/(self.n-5)))
   if not A.finite(noise[j]) then return nil,'Nonfinite passive tilt statistics' end
   for _,value in ipairs(row) do if not A.finite(value) then return nil,'Nonfinite passive tilt coefficient' end end
  end
  local a,b=coefficients[1],coefficients[2] local determinant=a[1]*b[2]-a[2]*b[1]
  if math.abs(determinant)<1e-5 then return nil,'Tilt response has no independent lateral allocation' end
  for j=1,2 do
   local effect=math.abs(coefficients[j][1])*self.ratio[1]+math.abs(coefficients[j][2])*self.ratio[2]
   if effect<.01 or noise[j]*3>effect*.5 or self.ratio[j]<.002 or self.rates[j]<.02 or self.extent[j]<.5 then return nil,'Passive lateral motion domain or response/noise ratio insufficient' end
  end
  return {schema=1,kind='passive-measured-tilt-response',vehicleId=self.vehicleId,frame='world',clockId=C.clockId(),clock='local_uptime',
   samples=self.n,coefficients=coefficients,noise=noise,ratio=A.copy(self.ratio),extent=A.copy(self.extent),maxRate=A.copy(self.rates),upBody=A.copy(self.upBody),
   units={acceleration='block/s2',velocity='block/s',tilt='up-horizontal/up-vertical'},scope='observed-local-tilt-domain; separate closed-loop qualification required'}
 end
 return self
end
return M

 end
 factories["system.navigation.known_flight"]=function(require)
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

 end
 factories["system.navigation.motion_progress"]=function(require)
-- Fixed-memory physical progress evidence; never a stabilization timeout.
local A=require('system.libraries.addon')
local M={}
function M.new()
 local self={samples={},last=nil,diagnostic='Collecting physical progress evidence',axes={}}
 function self:observe(error,rates,at)
  if not A.finite(at) or self.last and at<=self.last then return false end
  for i=1,6 do if not A.finite(error and error[i]) or not A.finite(rates and rates[i]) then return false end end
  if self.last and at-self.last<.5-1e-8 then return false end
  if self.last and at-self.last>1 then self.samples={} end self.last=at
  self.samples[#self.samples+1]={error=A.copy(error),rates=A.copy(rates)}
  if #self.samples>32 then table.remove(self.samples,1) end
  self.axes={}
  if #self.samples<32 then self.diagnostic='Collecting physical progress evidence' return true end
  for axis=1,6 do
   local first,last,turns,sign=0,0,0,0
   for j,sample in ipairs(self.samples) do
    local e=sample.error[axis] local r=sample.rates[axis]
    if j<=16 then first=first+e*e else last=last+e*e end
    local threshold=axis<=3 and .05 or .5
    local current=r>threshold and 1 or r< -threshold and -1 or 0
    if current~=0 then if sign~=0 and current~=sign then turns=turns+1 end sign=current end
   end
   local rms=math.sqrt(last/16) local threshold=axis<=3 and .25 or 3
   if rms>threshold and last>=first*.9 then
    self.axes[axis]=turns>=6 and 'nondecaying-oscillation' or 'no-measured-convergence'
   end
  end
  self.diagnostic=next(self.axes) and 'Physical errors are not converging; no qualification granted by waiting' or 'Observed errors converge or remain within the diagnostic band'
  return true
 end
 function self:status() return {samples=#self.samples,capacity=32,axes=A.copy(self.axes),reason=self.diagnostic} end
 return self
end
return M

 end
 factories["system.navigation.altitude_model"]=function(require)
-- Actual settled height table + independently checked restoring/damping model.
-- Never infer horizontal control, manual takeover, or physical rescue behaviour.
local addon=require('system.libraries.addon')
local M={}
function M.heatAt(model,height)
 local points=type(model)=='table' and model.points
 if type(points)~='table' or #points<3 or #points>15 or not addon.finite(height) then return nil,'Measured altitude table unavailable' end
 for i,p in ipairs(points) do
  if not addon.finite(p.altitude) or not addon.finite(p.heat) or p.heat<1 or p.heat>15 or p.heat%1~=0 or
    i>1 and (p.altitude<=points[i-1].altitude or p.heat<=points[i-1].heat) then return nil,'Invalid measured altitude table' end
 end
 if height<points[1].altitude or height>points[#points].altitude then return nil,'Target outside measured altitude range' end
 for i=2,#points do
  local a,b=points[i-1],points[i]
  if height<=b.altitude then return a.heat+(b.heat-a.heat)*(height-a.altitude)/(b.altitude-a.altitude) end
 end
end
local function fit(rows)
 if #rows<20 then return nil end
 local mean={0,0,0,0}
 for _,r in ipairs(rows) do for i=1,4 do mean[i]=mean[i]+r[i]/#rows end end
 local matrix={{0,0,0,0},{0,0,0,0},{0,0,0,0}}
 local scale={0,0,0}
 for _,r in ipairs(rows) do for i=1,3 do scale[i]=scale[i]+(r[i]-mean[i])^2 end end
 for i=1,3 do scale[i]=math.sqrt(scale[i]) if scale[i]<1e-8 then return nil end end
 for _,r in ipairs(rows) do for i=1,3 do
  local x=(r[i]-mean[i])/scale[i]
  for j=1,3 do matrix[i][j]=matrix[i][j]+x*(r[j]-mean[j])/scale[j] end
  matrix[i][4]=matrix[i][4]+x*(r[4]-mean[4])
 end end
 for i=1,3 do
  local pivot=i for j=i+1,3 do if math.abs(matrix[j][i])>math.abs(matrix[pivot][i]) then pivot=j end end
  matrix[i],matrix[pivot]=matrix[pivot],matrix[i]
  local d=matrix[i][i] if math.abs(d)<1e-5 then return nil end
  for j=i,4 do matrix[i][j]=matrix[i][j]/d end
  for k=1,3 do if k~=i then local f=matrix[k][i] for j=i,4 do matrix[k][j]=matrix[k][j]-f*matrix[i][j] end end end
 end
 local out={matrix[1][4]/scale[1],matrix[2][4]/scale[2],matrix[3][4]/scale[3],mean[4]}
 for i=1,3 do out[4]=out[4]-out[i]*mean[i] end
 for _,v in ipairs(out) do if not addon.finite(v) then return nil end end
 return out
end
function M.analyze(samples,levels,options)
 local points={}
 for heat=options.first,options.last do
  local level=levels[heat]
  if not level or not level.settled or not addon.finite(level.altitude) then return nil,'Every heat level needs a measured stable height' end
  if #points>0 and level.altitude-points[#points].altitude<0.5 then return nil,'Stable heights not distinctly increasing; ground contact, inertia or non-monotonic response: retain measurements' end
  points[#points+1]={heat=heat,altitude=level.altitude,spread=level.altitudeSpread}
 end
 local rows={}
 for i=2,#samples do
  local a,b=samples[i-1],samples[i] local dt=b.time-a.time
  if a.signal==b.signal and dt>=0.2 and dt<=1 then
   rows[#rows+1]={(a.altitude+b.altitude)/2,(a.rate+b.rate)/2,b.signal,(b.rate-a.rate)/dt}
  end
 end
 local model=fit(rows)
 if not model then return nil,'Height/speed/heat dynamics not identifiable; stable heights retained' end
 local mean=0 for _,r in ipairs(rows) do mean=mean+r[4]/#rows end
 local residual,total=0,0
 for _,r in ipairs(rows) do
  residual=residual+(r[4]-model[1]*r[1]-model[2]*r[2]-model[3]*r[3]-model[4])^2
  total=total+(r[4]-mean)^2
 end
 local r2=total>1e-8 and 1-residual/total or 0
 if r2<0.9 then return nil,'Height response too noisy/nonlinear for automatic hold; stable heights retained' end
 local train,hold={},{}
 for i,r in ipairs(rows) do if i<=math.floor(#rows*0.7) then train[#train+1]=r else hold[#hold+1]=r end end
 local cross=fit(train) if not cross then return nil,'Independent dynamics validation unavailable' end
 local mse=0 for _,r in ipairs(hold) do mse=mse+(r[4]-cross[1]*r[1]-cross[2]*r[2]-cross[3]*r[3]-cross[4])^2 end
 if math.sqrt(mse/math.max(1,#hold))>0.01+0.2*math.sqrt(total/#rows) then return nil,'Height response changed during sweep' end
 local stiffness,damping,force=-model[1],-model[2],model[3]
 if stiffness<=1e-5 or damping<=0 or force<=0 then return nil,'No restoring altitude/damped heat response identified' end
 local kp=0.25*stiffness/force
 local kd=math.max(0,(2*math.sqrt(1.25*stiffness)-damping)/force)
 if not addon.finite(kp) or not addon.finite(kd) or kp>2 or kd>100 then return nil,'Measured response outside supported hold sensitivity' end
 -- Settled heights and dynamic equilibrium must agree; a transient at zero
 -- velocity is not sufficient evidence for an automatic equilibrium controller.
 for _,p in ipairs(points) do
  local predicted=(force*p.heat+model[4])/stiffness
  if math.abs(predicted-p.altitude)>math.max(0.5,0.05*(points[#points].altitude-points[1].altitude)) then
   return nil,'Stable-height table disagrees with dynamic equilibrium; repeat measurements'
  end
 end
 local neutral=math.floor((options.first+options.last)/2)
 return {kind='altitude-table',points=points,hover=neutral,neutral=neutral,tau=1/damping,r2=r2,
  dynamics={stiffness=stiffness,damping=damping,heatAcceleration=force},
  measuredRange={first=options.first,last=options.last,minAltitude=points[1].altitude,maxAltitude=points[#points].altitude},
  gains={kp=kp,ki=0,kd=kd,limit=2,slew=0.25,integralLimit=0,deadband=0.1},
  note='Measured altitude interpolation + restoring/damping feedback. No horizontal route or metre-accuracy guarantee.'}
end
return M

 end
 factories["system.navigation.altitude_sweep"]=function(require)
-- Measurement-driven identification. No peripheral writes or physical-validation flags.
local addon=require("system.libraries.addon")
local Progress=require("system.navigation.sweep_progress")
local M={}
function M.defaults() return {first=7,last=15,maxSpeed=0,maxTravel=0,autoPrepare=true,autoHold=true,certify=true} end
function M.validate(value)
  if type(value)~="table" then return nil,"Sweep options missing" end
  local p={}
  for key,range in pairs({first={1,15},last={1,15}}) do
    local v=value[key]
    if not addon.finite(v) or v<range[1] or v>range[2] then return nil,"Sweep "..key.." outside "..range[1]..".."..range[2] end
    p[key]=v
  end
  for key,maximum in pairs({maxSpeed=1000,maxTravel=10000000}) do
    local v=value[key]
    if v==nil then v=0 end
    if not addon.finite(v) or v<0 or v>maximum then return nil,"Invalid optional sweep "..key end
    p[key]=v
  end
  if p.first%1~=0 or p.last%1~=0 or p.last-p.first<2 then return nil,"At least three integer heat levels required" end
  for _,key in ipairs({"autoPrepare","autoHold","certify"}) do
    if value[key]~=nil and type(value[key])~="boolean" then return nil,"Invalid sweep "..key end
    p[key]=value[key]==true
  end
  if p.certify and not p.autoHold then return nil,"Closed-loop calibration requires automatic altitude hold" end
  if p.autoHold and not p.autoPrepare then return nil,"Automatic hold requires automatic receiver tests" end
  return p
end
function M.analyze(samples,options,levels)
  if type(levels)~="table" then return nil,"Measured stable heights required" end
  return require("system.navigation.altitude_model").analyze(samples,levels,options)
end
M.heatAt=require("system.navigation.altitude_model").heatAt
function M.new(options,start,now)
  local p,err=M.validate(options) if not p then return nil,err end
  if not addon.finite(start) or not addon.finite(now) then return nil,"Fresh starting altitude required" end
  local self={options=p,startAltitude=start,startedAt=now,stageAt=now,signal=p.first,state="running",samples={},levels={},reason="Measure stable altitude",lastObserved=nil,phase=p.autoPrepare and "initialize" or "measure",rescueHeat=0}
  local progress=Progress.new()
  function self:abort(reason) self.state="aborted" self.reason=reason return nil,reason end
  function self:step(t,clock,ack)
    if self.state~="running" then return nil,self.reason end
    if not addon.finite(clock) or clock<(self.lastClock or self.startedAt) then return self:abort("Sweep clock regressed") end
    self.lastClock=clock
    if not t.inSublevel or not addon.finite(t.timestamp) or clock<t.timestamp or clock-t.timestamp>0.5 or
      not addon.finite(t.altitude) or not addon.finite(t.altitudeRate) then return self:abort("Fresh altitude/rate/sublevel telemetry lost") end
    if self.options.maxSpeed>0 and math.abs(t.altitudeRate)>self.options.maxSpeed then return self:abort("Operator vertical-speed limit reached") end
    if self.options.maxTravel>0 and math.abs(t.altitude-self.startAltitude)>self.options.maxTravel then return self:abort("Operator altitude travel limit reached") end
    if self.phase~="measure" then
      if ack then
        if self.phase=="initialize" then self.initialized=true self.phase="rescue" self.signal=self.rescueHeat
        else self.prepared=true self.phase="measure" self.signal=self.options.first end
        self.stageAt=clock self.lastObserved=nil
      end
      self.reason=self.phase=="initialize" and "Automatic burner test / initialization: waiting for every receiver" or
        self.phase=="rescue" and "Automatic rescue test: waiting for every receiver" or "Tests acknowledged; waiting for stable altitude"
      return self.signal
    end
    if ack and t.timestamp>=self.stageAt and (not self.lastObserved or t.timestamp-self.lastObserved>=0.5) then
      local sample={time=t.timestamp-self.startedAt,signal=self.signal,altitude=t.altitude,rate=t.altitudeRate}
      self.samples[#self.samples+1]=sample self.lastObserved=t.timestamp
      -- Retain 24 initial dynamic samples and a rolling 16 per heat level.
      -- Waiting indefinitely never grows RAM or creates a hidden sample timeout.
      local count=0
      for i,r in ipairs(self.samples) do
        if r.signal==self.signal then count=count+1 if count==25 then self.replaceAt=i end end
      end
      if count>40 then table.remove(self.samples,self.replaceAt) end
      local level=self.levels[self.signal] or {signal=self.signal,count=0,minAltitude=t.altitude,maxAltitude=t.altitude,sumRate=0}
      level.count=level.count+1 level.minAltitude=math.min(level.minAltitude,t.altitude) level.maxAltitude=math.max(level.maxAltitude,t.altitude)
      level.sumRate=level.sumRate+t.altitudeRate
      level.tail=level.tail or {} level.tail[#level.tail+1]=sample
      while #level.tail>8 do table.remove(level.tail,1) end
      local minY,maxY,minV,maxV=math.huge,-math.huge,math.huge,-math.huge
      for _,r in ipairs(level.tail) do minY=math.min(minY,r.altitude) maxY=math.max(maxY,r.altitude) minV=math.min(minV,r.rate) maxV=math.max(maxV,r.rate) end
      local span=sample.time-level.tail[1].time
      local contiguous=true
      local mt,mv=0,0
      for i,r in ipairs(level.tail) do
        mt=mt+r.time mv=mv+r.rate
        if i>1 and r.time-level.tail[i-1].time>1.25 then contiguous=false end
      end
      mt,mv=mt/#level.tail,mv/#level.tail
      local covariance,variance=0,0
      for _,r in ipairs(level.tail) do covariance=covariance+(r.time-mt)*(r.rate-mv) variance=variance+(r.time-mt)^2 end
      level.speedSlope=variance>0 and covariance/variance or math.huge
      level.windowSpan,level.speedSpread,level.altitudeSpread=span,maxV-minV,maxY-minY
      local windowReady=#level.tail>=8 and span>=3 and contiguous
      level.stableAltitude=windowReady and maxY-minY<=0.5 and math.max(math.abs(minV),math.abs(maxV))<=0.1
      level.steadySpeed=windowReady and maxV-minV<=0.04 and math.abs(level.speedSlope)<=0.01
      self.levels[self.signal]=level
      progress:observe(level) self.diagnostic=progress:status()
      level.progress=addon.copy(self.diagnostic)
    end
    local level=self.levels[self.signal]
    if ack and level and self.lastObserved==t.timestamp and level.stableAltitude then
      level.settled=true level.finishedAt=clock-self.startedAt
      local height=0 for _,r in ipairs(level.tail) do height=height+r.altitude end
      level.altitude=height/#level.tail
      local rate=0 for _,r in ipairs(level.tail) do rate=rate+r.rate end level.meanRate=rate/#level.tail

      if self.signal==self.options.last then
        self.state="complete" self.reason="Measurements complete; returning to rescue"
        self.proposal,self.fitError=M.analyze(self.samples,self.options,self.levels)
        return nil,self.reason
      end
      self.signal=self.signal+1 self.stageAt=clock self.lastObserved=nil self.diagnostic=nil progress=Progress.new()
      self.reason="Waiting for |vertical speed| <= 0.1 m/s at heat "..self.signal
    elseif not ack then self.reason="Waiting for every burner receiver to confirm heat "..self.signal
    else self.reason="Heat "..self.signal..": "..(self.diagnostic and self.diagnostic.reason or "waiting for fresh stability observations") end
    return self.signal
  end
  function self:status(full)
    local out={state=self.state,phase=self.phase,prepared=self.prepared==true,initialized=self.initialized==true,reason=self.reason,startAltitude=self.startAltitude,startedAt=self.startedAt,signal=self.signal,count=#self.samples,options=addon.copy(self.options),
      proposal=addon.copy(self.proposal),fitError=self.fitError,diagnostic=addon.copy(self.diagnostic),levels=addon.copy(self.levels)}
    for _,level in pairs(out.levels) do level.tail=nil end
    if full then out.samples=addon.copy(self.samples) end
    return out
  end
  return self
end
return M

 end
 factories["system.navigation.sweep_progress"]=function(require)
-- Read-only evidence of progress. Never advances a heat level or sets a deadline.
local A=require('system.libraries.addon')
local M={}
function M.new()
 local self={windows={},total=0}
 function self:observe(level)
  local tail=level.tail or {} local last=tail[#tail]
  if not last then return end
  local out={schema=1,scope='sweep-progress-diagnostic',clock='sweep_elapsed',signal=level.signal,observedAt=last.time,samples=#tail,
   stable=level.stableAltitude==true,completedWindows=self.total,noProgress=false}
  self.current=out
  local contiguous=true local turns=0 local previousSign
  local sum,peak=0,0
  for i,r in ipairs(tail) do
   if i>1 and r.time-tail[i-1].time>1.25 then contiguous=false end
   sum=sum+r.rate peak=math.max(peak,math.abs(r.rate))
   local sign=r.rate>.1 and 1 or r.rate<-.1 and -1 or nil
   if sign and previousSign and sign~=previousSign then turns=turns+1 end
   if sign then previousSign=sign end
  end
  out.peakSpeed=peak out.meanSpeed=A.finite(sum) and sum/#tail or nil out.heightSpread=A.finite(level.altitudeSpread) and level.altitudeSpread or nil
  out.speedSlope=A.finite(level.speedSlope) and level.speedSlope or nil out.signChanges=turns
  if not contiguous then self.windows={} self.lastEnd=nil end
  if #tail<8 or (level.windowSpan or 0)<3 or not contiguous then
   out.state='gathering' out.reason=contiguous and 'Need eight contiguous measured samples for stability' or 'Measurement gap; collecting contiguous stability evidence'
   return
  end
  local score=math.max(peak/.1,(level.altitudeSpread or 0)/.5)
  if not A.finite(score) or not A.finite(sum) then
   out.state='unavailable' out.reason='Progress arithmetic unavailable; stability still required' return
  end
  if not self.lastEnd or tail[1].time>self.lastEnd then
   self.total=self.total+1 self.windows[#self.windows+1]={score=score,at=last.time}
   if #self.windows>8 then table.remove(self.windows,1) end self.lastEnd=last.time
  end
  out.completedWindows=self.total out.comparedWindows=#self.windows
  if #self.windows==8 then
   local first=self.windows[1].score local best=math.huge
   for i=2,8 do best=math.min(best,self.windows[i].score) end
   out.firstScore=first out.bestLaterScore=best
   out.noProgress=score>1 and best>=first-math.max(.05,first*.1)
  end
  if out.stable then out.state='stable' out.reason='Measured height and vertical speed satisfy stability criteria'
  elseif turns>=2 then out.state='oscillating' out.reason='Repeated vertical direction changes above 0.1 m/s; not stable'
  elseif level.steadySpeed and math.abs(out.meanSpeed)>.1 then
   out.state='steady-motion' out.reason=out.meanSpeed>0 and 'Steady ascent is not a stable altitude' or 'Steady descent is not a stable altitude'
  elseif out.noProgress then out.state='no-progress' out.reason='No clear stability improvement across eight separate windows'
  else out.state='settling' out.reason='Vertical speed or height spread still exceeds stability criteria' end
  if out.noProgress and out.state~='no-progress' then out.reason=out.reason..'; no clear improvement across eight separate windows' end
  out.atMaximumHeat=level.signal==15
  if out.atMaximumHeat and not out.stable then out.reason=out.reason..'; maximum heat requested, lift authority not established' end
 end
 function self:status() return A.copy(self.current) end
 return self
end
return M

 end
 factories["system.navigation.autopilot"]=function(require)
-- Position guidance for physically verified, hover-capable aircraft. This layer
-- produces attitude/altitude setpoints only; flightd owns every actuator write.
local addon=require("system.libraries.addon")
local geometry=require("system.navigation.geometry")
local Authority=require("system.navigation.authority")
local M={}
local function bounded(v,lo,hi) return addon.finite(v) and v>=lo and v<=hi end
local function clamp(v,limit) return math.max(-limit,math.min(limit,v)) end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
function M.defaults()
  return {points={},maxSpeed=3,maxTilt=5,positionGain=0.3,velocityGain=1,
    pitchSign=1,rollSign=1,radius=3,altitudeTolerance=2,settleSeconds=2,
    maxDistance=512,timeout=600,driveMode="thrusters",translationVerified=false,clearRouteConfirmed=false}
end
function M.validate(plan)
  if type(plan)~="table" or type(plan.points)~="table" or #plan.points<1 or #plan.points>32 then return false,"Route needs 1 to 32 waypoints" end
  local n=0
  for k in pairs(plan.points) do if type(k)~="number" or k%1~=0 or k<1 or k>#plan.points then return false,"Invalid waypoint sequence" end n=n+1 end
  if n~=#plan.points then return false,"Incomplete waypoint sequence" end
  for _,p in ipairs(plan.points) do
    if type(p)~="table" or not bounded(p.x,-30000000,30000000) or not bounded(p.z,-30000000,30000000) or not bounded(p.y,-2048,2048) then return false,"Invalid world waypoint" end
  end
  for key,range in pairs({maxSpeed={0.2,10},maxTilt={1,15},positionGain={0.05,1},velocityGain={0.1,5},
    radius={1,32},altitudeTolerance={0.5,10},settleSeconds={1,30},maxDistance={16,2048},timeout={10,3600}}) do
    if not bounded(plan[key],range[1],range[2]) then return false,"Invalid route setting: "..key end
  end
  if (plan.pitchSign~=1 and plan.pitchSign~=-1) or (plan.rollSign~=1 and plan.rollSign~=-1) then return false,"Translation signs must be +1 or -1" end
  if plan.translationVerified~=true then return false,"Physically verify hover, translation direction and braking first" end
  if type(plan.verifiedVehicleId)~="string" or #plan.verifiedVehicleId<1 or #plan.verifiedVehicleId>128 then return false,"Verify translation on this sublevel identity" end
  if plan.driveMode~="tilt" and plan.driveMode~="thrusters" and plan.driveMode~="differential" then return false,"Choose tilt, directional thrusters or measured differential motors" end
  if plan.clearRouteConfirmed~=true then return false,"Confirm a clear route; no obstacle avoidance or automatic landing" end
  return true
end
function M.new()
  local self={state="idle",reason="No autonomous mission",index=0}
  function self:observe(pose,now)
    if type(pose)~="table" or pose.inSublevel~=true or pose.frame~="world"
      or type(pose.vehicleId)~="string" or pose.vehicleId=="" or #pose.vehicleId>128
      or not addon.finite(pose.identityAt) or now<pose.identityAt or now-pose.identityAt>0.5
      or not addon.finite(pose.timestamp) or now<pose.timestamp or now-pose.timestamp>0.5 then self.sample=nil return end
    local p=addon.vec(pose.logicalPose and (pose.logicalPose.position or pose.logicalPose.pos))
    if not p then self.sample=nil return end
    local previous=self.sample
    if previous and previous.vehicleId==pose.vehicleId and pose.timestamp==previous.at then return end
    local sample={position=p,vehicleId=pose.vehicleId,at=pose.timestamp}
    if previous and previous.vehicleId==pose.vehicleId then
      local dt=pose.timestamp-previous.at
      if dt>0 and dt<=0.5 then sample.velocity={x=(p.x-previous.position.x)/dt,y=(p.y-previous.position.y)/dt,z=(p.z-previous.position.z)/dt} end
    end
    self.sample=sample
  end
  function self:running() return self.state=="climb" or self.state=="cruise" or self.state=="holding" end
  function self:cancel(reason,failed)
    if self:running() then self.state=failed and "failed" or "cancelled" self.reason=reason or "Pilot takeover" end
  end
  function self:start(plan,t,now)
    if self:running() then return false,"Stop the current mission first" end
    local ok,err=M.validate(plan) if not ok then return false,err end
    local s=self.sample
    if not s or not s.velocity or now<s.at or now-s.at>0.5 then return false,"Need two fresh world-position samples and a vehicle identity" end
    if plan.verifiedVehicleId~=s.vehicleId then return false,"Translation verification belongs to another sublevel" end
    if not addon.finite(t.heading) or not addon.finite(t.altitude) then return false,"Altitude and heading unavailable" end
    for _,point in ipairs(plan.points) do if distance(point,s.position)>plan.maxDistance then return false,"Waypoint outside launch geofence" end end
    self.plan=addon.copy(plan) self.vehicleId=s.vehicleId self.home=addon.copy(s.position)
    self.heading=t.heading self.startedAt=now self.index=1 self.settledAt=nil self.phaseAt=now
    self.driveSpeed,self.driveAt=0,now
    self.state,self.reason="climb","Climb before horizontal travel"
    return true
  end
  function self:step(t,now)
    if not self:running() then return nil end
    local s,p=self.sample,self.plan
    local function fail(why) self:cancel(why,true) return nil,why end
    if s and s.vehicleId~=self.vehicleId then return fail("Autopilot sublevel identity changed") end
    if not s or not s.velocity or now<s.at or now-s.at>0.5 then return fail("Autopilot position/velocity stale") end
    if not addon.finite(t.heading) or not addon.finite(t.altitude) then return fail("Autopilot flight measurements unavailable") end
    if self.state~="holding" and now-self.startedAt>p.timeout then return fail("Autopilot route timeout") end
    if distance(s.position,self.home)>p.maxDistance then return fail("Autopilot left launch geofence") end
    local v=s.velocity local speed=math.sqrt(v.x*v.x+v.z*v.z)
    if speed>p.maxSpeed*3+5 or math.abs(v.y)>30 then return fail("Autopilot excessive velocity/position discontinuity") end
    local point=p.points[self.index]
    local dx,dz=point.x-s.position.x,point.z-s.position.z
    local d=math.sqrt(dx*dx+dz*dz) local altitudeError=point.y-s.position.y
    self.distance,self.position,self.speed=d,addon.copy(s.position),speed
    local targets={pitch=0,roll=0,altitude=t.altitude+altitudeError,heading=self.heading}
    if self.state=="climb" then
      if math.abs(altitudeError)<=p.altitudeTolerance and math.abs(v.y)<=1 then
        self.settledAt=self.settledAt or now
        if now-self.settledAt>=p.settleSeconds then self.state,self.reason,self.settledAt="cruise","Following world waypoint",nil end
      else self.settledAt=nil end
      -- Even during the climb, brake existing horizontal drift.
      dx,dz=0,0
    end
    local safeSpeed=Authority.speed(p.braking,math.max(0,d-p.radius*.5))
    self.brakingSpeed=safeSpeed
    local speedLimit=math.min(p.maxSpeed,safeSpeed or p.maxSpeed)
    local desiredX,desiredZ=dx*p.positionGain,dz*p.positionGain
    local magnitude=math.sqrt(desiredX^2+desiredZ^2)
    if magnitude>speedLimit then desiredX,desiredZ=desiredX*speedLimit/magnitude,desiredZ*speedLimit/magnitude end
    local a=math.rad(t.heading) local ex,ez=desiredX-v.x,desiredZ-v.z
    local right=ex*math.cos(a)-ez*math.sin(a)
    local forward=ex*math.sin(a)+ez*math.cos(a)
    if p.driveMode=="differential" then
      local heading=t.heading
      if self.state~="climb" and d>p.radius then heading=math.deg(geometry.atan2(dx,dz))%360 self.course=heading
      elseif self.state~="climb" then heading=self.course or heading end
      local forward=dx*math.sin(math.rad(t.heading))+dz*math.cos(math.rad(t.heading))
      local wanted=clamp(forward*p.positionGain,speedLimit)
      if math.abs(geometry.wrap(heading-t.heading))>35 then wanted=0 end
      if self.state=="climb" then wanted=0 end
      if p.braking and addon.finite(p.braking.acceleration) and p.braking.acceleration>0 and math.abs(wanted)>math.abs(self.driveSpeed or 0) then
        local increase=p.braking.acceleration*math.max(0,math.min(.5,s.at-(self.driveAt or s.at)))
        wanted=clamp(wanted,math.abs(self.driveSpeed or 0)+increase)
      end
      self.driveSpeed,self.driveAt=wanted,s.at
      targets.drive={speed=wanted,heading=heading}
    elseif p.driveMode=="tilt" then
      targets.pitch=clamp(forward*p.velocityGain*p.pitchSign,p.maxTilt)
      targets.roll=clamp(right*p.velocityGain*p.rollSign,p.maxTilt)
    else
      targets.translation={forward=clamp(forward*p.velocityGain,1),right=clamp(right*p.velocityGain,1)}
    end
    if self.state=="cruise" and d<=p.radius and math.abs(altitudeError)<=p.altitudeTolerance and speed<=0.5 and math.abs(v.y)<=0.5 then
      self.settledAt=self.settledAt or now
      if now-self.settledAt>=p.settleSeconds then
        self.settledAt=nil
        if self.index<#p.points then self.index=self.index+1 self.state,self.reason="climb","Climb for next waypoint"
        else self.state,self.reason="holding","Final waypoint position hold; no automatic landing" end
      end
    elseif self.state=="cruise" then self.settledAt=nil end
    return targets
  end
  function self:status()
    return {state=self.state,reason=self.reason,index=self.index,count=self.plan and #self.plan.points or 0,
      distance=self.distance,speed=self.speed,brakingSpeed=self.brakingSpeed,position=addon.copy(self.position),vehicleId=self.vehicleId}
  end
  return self
end
return M

 end
 local function require(name)
  assert(type(name)=='string' and factories[name],'Module not included in Sputnik edition')
  if cache[name]~=nil then return cache[name] end
  local value=factories[name](require) cache[name]=value return value
 end
 return require
end
-- Sputnik node body. Each evaluation is bounded; no files, HTTP or CC APIs.
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function read(name,...)
 local fn=_G[name] if type(fn)~='function' then return end
 local ok,a,b,c=pcall(fn,...) if ok then return a,b,c end
end
local function number(v) return finite(v) and string.format('%.2f',v) or '?' end
if not _G.MintCraftSputnik then
 local require=makePortableModules()
 local state={version='0.1.0',require=require,actuation=false,flightQualified=false,clockAvailable=false}
 -- No vehicle UUID, RX association or ownership API is present in the audited host.
 state.capabilities={telemetry=true,numericNavigation=true,wirelessLinks=true,numericRadio=true,
  filesystem=false,http=false,authentication=false,completeGeometry=false,qualifiedAutopilot=false}
 _G.MintCraftSputnik=state
 if type(ui)=='table' and type(addElement)=='function' then
  state.title=ui.label('MintCraft Sputnik 0.1.0 | lecture seule')
  state.position=ui.label('Position ?') state.motion=ui.label('Vitesse ?')
  state.attitude=ui.label('Attitude ?') state.physical=ui.label('Masse ?')
  state.notice=ui.label('Pilotage qualifie indisponible: identite/RX non exposes')
  state.peripherals=ui.label('Peripheriques: Scan pour relever les IDs, jamais auto-selectionnes')
  state.scan=ui.button('Scan lecture seule',180)
 end
end
local s=_G.MintCraftSputnik
local x,y,z=read('getPosition') local vx,vy,vz=read('getVelocity')
local pitch,yaw,roll=read('getOrientation') local mass=read('getShipMass')
local dimension=read('getDimension') local ticks=read('getUniverseTime')
local previous=s.lastTicks
s.clockAvailable=finite(ticks) and ticks>0
s.clockFault=s.clockAvailable and previous~=nil and ticks<previous or false
if s.clockAvailable then s.lastTicks=ticks end
s.time=s.clockAvailable and ticks/20 or nil
s.telemetry={position={x=x,y=y,z=z},velocity={x=vx,y=vy,z=vz},pitch=pitch,yaw=yaw,roll=roll,
 mass=finite(mass) and mass>0 and mass or nil,namespace=dimension,source='Sputnik native Lua API',
 sourceClock='cosmonautics_universe_ticks',sourceTick=s.clockAvailable and ticks or nil,
 velocityConvention='Sable root finite difference times 20; not velocity at the rotating Sputnik block',
 identityAvailable=false,fullInertiaAvailable=false}
if s.title then
 s.position.setText('XYZ '..number(x)..' / '..number(y)..' / '..number(z)..' | '..tostring(dimension or '?'))
 s.motion.setText('V xyz '..number(vx)..' / '..number(vy)..' / '..number(vz)..' m/s')
 s.attitude.setText('Pitch / yaw / roll '..number(pitch)..' / '..number(yaw)..' / '..number(roll)..' deg')
 s.physical.setText('Masse '..number(s.telemetry.mass)..' kg | horloge '..(s.clockFault and 'regression' or s.clockAvailable and 'serveur disponible' or 'indisponible cote client'))
 if s.scan.wasClicked() then
  local ids=read('getPeripheralIds') local names={}
  if type(ids)=='table' then
   for i=1,math.min(#ids,32) do names[#names+1]=tostring(ids[i]):sub(1,24)..':'..tostring(read('getPeripheralType',ids[i]) or '?'):sub(1,32) end
   s.peripherals.setText(#ids..' ID(s): '..table.concat(names,', ')..(#ids>32 and ' (32 affiches)' or ''))
  else s.peripherals.setText('Inventaire indisponible dans ce contexte') end
 end
 for _,element in ipairs({s.title,s.position,s.motion,s.attitude,s.physical,s.notice,s.scan,s.peripherals}) do addElement(element) end
end
-- Literal names/types are intentional: Sputnik discovers graph pins from source.
output('Altitude',finite(y) and y or 0)
output('Vertical speed',finite(vy) and vy or 0)
output('Mass',s.telemetry.mass or 0)
output('Telemetry valid',s.clockAvailable and not s.clockFault and s.telemetry.mass~=nil and finite(x) and finite(y) and finite(z) and dimension~='unknown' and 1 or 0)
output('Flight qualified',0)
