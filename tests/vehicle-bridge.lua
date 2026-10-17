package.path="./?.lua;"..package.path
local addon=require("system.libraries.addon")
addon.bounded=function(fn) return pcall(fn) end
addon.configure({readsPerTick=100000})
parallel={waitForAll=function(...) for _,fn in ipairs({...}) do fn() end end}
local now=10 os.clock=function() return now end
local bridge=require("system.services.vehiclebridged")
bridge.acquire() assert(not bridge.snapshot().available)
local raw={schema=1,readOnly=true,ok=true,complete=true,frame="body_plot",vehicleId="ship-1",name="Heavy Quad",
  revision=200,ageTicks=0,units={position="block",mass="sable_mass",force="pixel_newton"},mass=126093,
  centerOfMass={x=0.5,y=0.5,z=0.5},actuators={},links={{id="link",position={x=0,y=0,z=0},receiver=true,
    first={item="minecraft:green_concrete_powder"},second={item="minecraft:green_concrete_powder"},signal=0}}}
for i=1,4 do raw.actuators[i]={id="rotor"..i,position={x=i,y=0,z=i},direction={x=0,y=1,z=0},
  suggestedRole="lift",thrust=0,active=false} end
local calls=0
mintcraft_vehicle={snapshot=function() calls=calls+1 return addon.copy(raw) end}
bridge.acquire()
local snapshot=bridge.snapshot()
assert(snapshot.ok and #snapshot.actuators==4 and #snapshot.links==1 and not snapshot.controlBindingsKnown)
bridge.snapshot() bridge.status() assert(calls==1,"cached getters performed acquisition")
now=11 bridge.acquire()
assert(bridge.snapshot().observedAt==10,"repeated bridge revision freshened measurements")
now=12.1 assert(not bridge.snapshot().ok,"expired model remained fresh")
raw.revision=220 bridge.acquire() assert(bridge.snapshot().ok)
local vehicle=require("system.navigation.vehicle")
local profile=assert(vehicle.import({massKg=99},bridge.snapshot()))
assert(profile.massKg==99 and profile.bridgeMass==126093,"game mass silently converted to kg")
assert(profile.type=="quadcopter" and profile.rotorCount==4 and profile.comVerified)
assert(profile.bridgeLinks[1].first.item=="minecraft:green_concrete_powder")
assert(#vehicle.analyze(profile,{}).rows==4 and vehicle.analyze(profile,{}).rows[1].torque)
assert(not profile.bridgeActuators[1].actuator.controlBindingKnown)
local manual=assert(vehicle.import({type="hybrid"},bridge.snapshot())) assert(manual.type=="hybrid")
raw.complete=false raw.revision=240 bridge.acquire()
assert(not vehicle.import({},bridge.snapshot()),"partial scan imported as complete")
raw.complete=true raw.frame="world" assert(not bridge.normalize(raw))
raw.frame="body_plot" raw.actuators[2].id=raw.actuators[1].id assert(not bridge.normalize(raw))
raw.actuators[2].id="rotor2" raw.actuators[1].position.x=math.huge assert(not bridge.normalize(raw))
raw.actuators[1].position.x=1 raw.units.position="unknown" assert(not bridge.normalize(raw))
raw.units.position="block" raw.readOnly=false assert(not bridge.normalize(raw))
raw.readOnly=true raw.inertia={{1,0,0},{0,2,0},{0,0,3}}
local parsed=assert(bridge.normalize(raw)) assert(parsed.inertia[3][3]==3)
raw.features={burners=true}
raw.burners={{id="burner:1:2:3",position={x=1,y=2,z=3},signal=0,gasOutput=0,hasBalloon=false}}
raw.revision=260 bridge.acquire()
local setup={vehicleId="ship-1",burnerIds={"burner:1:2:3"}}
local ready,why=bridge.balloonStatus(setup)
assert(not ready and why:find("off; balloon association not confirmed",1,true))
raw.burners[1].signal=3 raw.revision=280 bridge.acquire()
ready,why=bridge.balloonStatus(setup)
assert(not ready and why:find("Aeronautics balloon association unavailable",1,true))
raw.burners[1].hasBalloon=true raw.revision=300 bridge.acquire()
assert(bridge.balloonStatus(setup),"confirmed association still refused")
ready,why=bridge.balloonStatus({vehicleId="ship-1",burnerIds={"absent"}})
assert(not ready and why:find("Burner missing",1,true))
raw.actuators[1].direction={x=0,y=0,z=0}
assert(not bridge.normalize(raw).complete,"uninitialised direction silently omitted from complete model")
mintcraft_vehicle.snapshot=function() error("addon API failed") end
bridge.acquire() assert(not bridge.snapshot().ok and bridge.snapshot().available)
print("vehicle bridge: absence, cached acquisition, revisions/staleness, geometry/frequency import, unknown wiring/units and failures passed")
