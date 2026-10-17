package.path="./?.lua;"..package.path
local vehicle=require("system.navigation.vehicle")
for _,kind in ipairs({"monocopter","bicopter","tricopter","quadcopter","hexacopter"}) do
  assert(vehicle.profile({type=kind}).type==kind)
end
local profile={type="quadcopter",massKg=126093,comVerified=true,com={x=0,y=0,z=0}}
local channels={{id="front-right",frequency="existing",actuator={role="lift",geometryVerified=true,
  position={x=2,y=0,z=3},direction={x=0,y=2,z=0}}},
  {id="rear",actuator={role="propulsion",geometryVerified=true,position={x=0,y=2,z=-3},direction={x=0,y=0,z=1}}}}
local result=vehicle.analyze(profile,channels)
assert(result.rows[1].torque.pitch==-3 and result.rows[1].torque.roll==2)
assert(result.rows[2].torque.pitch==2,"off-center propulsion tilt not exposed")
assert(result.rows[1].frequency=="existing" and channels[1].actuator.direction.y==2)
profile.comVerified=false
assert(not vehicle.analyze(profile,channels).rows[1].torque,"unknown COM frame used")
profile.comVerified=true channels[1].actuator.geometryVerified=false
assert(not vehicle.analyze(profile,channels).rows[1].torque,"unverified geometry used")
channels[2].actuator.direction={x=0,y=0,z=0}
assert(not vehicle.analyze(profile,channels).rows[2].torque,"zero vector used")
assert(vehicle.profile({rotorCount=math.huge}).rotorCount==0)
assert(vehicle.profile({com="bad"}).com.x==0)
channels[1].actuator.geometryVerified=true channels[1].actuator.direction={x=1e308,y=0,z=0}
assert(not vehicle.analyze(profile,channels).rows[1].torque,"unbounded direction overflow accepted")
print("vehicle types, actuator roles, verified body COM, force/torque coupling and safe unknowns passed")
