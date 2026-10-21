package.path="./?.lua;"..package.path
local Route=require("system.navigation.autopilot")
local addon=require("system.libraries.addon")
local plan=Route.defaults()
assert(not Route.validate(plan))
plan.points={{x=0,y=100,z=12},{x=10,y=105,z=12}}
assert(not Route.validate(plan),"unverified vehicle accepted")
plan.translationVerified=true plan.clearRouteConfirmed=true plan.verifiedVehicleId="ship-a"
assert(Route.validate(plan))
for _,field in ipairs({"maxSpeed","maxTilt","positionGain","velocityGain","radius","altitudeTolerance","settleSeconds","maxDistance","timeout"}) do
  local bad=addon.copy(plan) bad[field]=0/0 assert(not Route.validate(bad),"NaN accepted: "..field)
end
local bad=addon.copy(plan) bad.points[3]=bad.points[1] bad.points[1]=nil assert(not Route.validate(bad))
local now=10 local position={x=0,y=100,z=0} local heading=90 local id="ship-a"
local function pose(at) return {frame="world",inSublevel=true,vehicleId=id,identityAt=at or now,timestamp=at or now,logicalPose={position=addon.copy(position)}} end
local function telemetry() return {altitude=position.y+5,heading=heading} end
local route=Route.new()
route:observe(pose(),now) assert(not route:start(plan,telemetry(),now),"one position sample invented velocity")
now=now+0.1 route:observe(pose(),now)
assert(route:start(plan,telemetry(),now))
local original=plan.points[1].z plan.points[1].z=99999
assert(route.plan.points[1].z==original,"caller mutated active mission") plan.points[1].z=original
local vx,vz=0,0
for _=1,1800 do
  now=now+0.1 route:observe(pose(),now)
  local target,err=route:step(telemetry(),now) assert(target,err)
  assert(target.pitch==0 and target.roll==0 and target.heading==heading)
  assert(math.abs(target.translation.forward)<=1 and math.abs(target.translation.right)<=1)
  local a=math.rad(heading) local f,r=target.translation.forward,target.translation.right
  vx=vx+((f*math.sin(a)+r*math.cos(a))*2-vx*0.5)*0.1
  vz=vz+((f*math.cos(a)-r*math.sin(a))*2-vz*0.5)*0.1
  position.x=position.x+vx*0.1 position.z=position.z+vz*0.1
  position.y=position.y+math.max(-0.1,math.min(0.1,target.altitude-telemetry().altitude))
  if route.state=="holding" then break end
end
assert(route.state=="holding" and route.index==2,"two-waypoint closed-loop fixture did not settle")
assert(math.abs(position.x-10)<plan.radius and math.abs(position.z-12)<plan.radius)
now=now+0.6 local _,err=route:step(telemetry(),now)
assert(route.state=="failed" and err:find("stale"),"stale position kept autonomous outputs")
local function fresh(p)
  local r=Route.new() position={x=0,y=100,z=0} id="ship-a"
  r:observe(pose(),now) now=now+0.1 r:observe(pose(),now)
  assert(r:start(p or plan,telemetry(),now)) return r
end
route=fresh() id="ship-b" now=now+0.1 route:observe(pose(),now)
assert(select(2,route:step(telemetry(),now)):find("identity changed"))
route=fresh() now=now+plan.timeout+1 route:observe(pose(now-0.1),now) route:observe(pose(),now)
assert(select(2,route:step(telemetry(),now)):find("timeout"))
route=fresh() position.x=plan.maxDistance+1 now=now+0.1 route:observe(pose(),now)
assert(select(2,route:step(telemetry(),now)):find("geofence"))
route=fresh() local future=pose(now+1) route:observe(future,now) assert(not route.sample)
local tilt=addon.copy(plan) tilt.driveMode="tilt" tilt.pitchSign=-1
route=fresh(tilt) route.state="cruise" heading=0
local target=assert(route:step(telemetry(),now))
assert(target.pitch<0 and math.abs(target.pitch)<=tilt.maxTilt and not target.translation,"tilt polarity or bound ignored")
route:cancel("manual") assert(not route:running() and not route:step(telemetry(),now))
print("autopilot: explicit validation, body/world guidance, frozen route, two-waypoint settling/hold, tilt bounds, stale/identity/geofence/timeout and takeover passed")
