-- Position guidance for physically verified, hover-capable aircraft. This layer
-- produces attitude/altitude setpoints only; flightd owns every actuator write.
local addon=require("system.libraries.addon")
local geometry=require("system.navigation.geometry")
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
    local desiredX,desiredZ=dx*p.positionGain,dz*p.positionGain
    local magnitude=math.sqrt(desiredX^2+desiredZ^2)
    if magnitude>p.maxSpeed then desiredX,desiredZ=desiredX*p.maxSpeed/magnitude,desiredZ*p.maxSpeed/magnitude end
    local a=math.rad(t.heading) local ex,ez=desiredX-v.x,desiredZ-v.z
    local right=ex*math.cos(a)-ez*math.sin(a)
    local forward=ex*math.sin(a)+ez*math.cos(a)
    if p.driveMode=="differential" then
      local heading=t.heading
      if self.state~="climb" and d>p.radius then heading=math.deg(geometry.atan2(dx,dz))%360 self.course=heading
      elseif self.state~="climb" then heading=self.course or heading end
      local forward=dx*math.sin(math.rad(t.heading))+dz*math.cos(math.rad(t.heading))
      local wanted=clamp(forward*p.positionGain,p.maxSpeed)
      if math.abs(geometry.wrap(heading-t.heading))>35 then wanted=0 end
      if self.state=="climb" then wanted=0 end
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
      distance=self.distance,speed=self.speed,position=addon.copy(self.position),vehicleId=self.vehicleId}
  end
  return self
end
return M
