package.path="./?.lua;"..package.path
require("system.libraries.addon").bounded=function(fn) return pcall(fn) end
local now=1
os.clock=function() return now end
parallel={waitForAll=function(...) for _,f in ipairs({...}) do f() end end}
local calls,scans=0,0
local devices={altitude={getHeight=function() calls=calls+1 return 198 end,getAirPressure=function() return 0.69 end,getVerticalSpeed=function() return 2 end},
  gimbal={getAngles=function() return {3,4} end,getAngularRates=function() return {1,2,3} end,getGravity=function() return {0,-11,0} end},
  nav={getHeading=function() return 359 end},motor={getSignal=function() calls=calls+1 return 7 end}}
local types={altitude="altitude_sensor",gimbal="gimbal_sensor",nav="navigation_table",motor="analog_transmission"}
peripheral={getNames=function() scans=scans+1 return {"altitude","gimbal","nav","motor"} end,getType=function(n) return types[n] end,
  getMethods=function(n) local methods={} for key in pairs(devices[n]) do methods[#methods+1]=key end return methods end,wrap=function(n) return devices[n] end}
local av=require("system.services.avionicsd")
av.acquire(true)
assert(av.snapshot().measurements.pitch.value==3 and av.snapshot().measurements.yawRate.value==2)
assert(av.snapshot().measurements.gravity.value.y==-11)
local before=calls
for i=1,50 do av.snapshot() av.status() end
assert(calls==before and scans==1,"cached reads acquired peripherals")
now=1.1 av.acquire(false)
assert(calls==before+1,"slow diagnostics read at 10Hz")
assert(scans==1,"fast sample rescanned peripherals")
now=2.2 av.acquire(false)
assert(calls==before+3)
local snap=av.snapshot() snap.devices[1].name="tampered"
assert(av.snapshot().devices[1].name~="tampered")
local geom=require("system.navigation.geometry")
local q=math.sqrt(0.5)
local pose={position={10,20,30},orientation={0,q,0,q},scale={1,1,1},rotationPoint={0,0,0}}
local p=assert(geom.transform({0,0,1},pose))
assert(math.abs(p.x-11)<1e-8 and math.abs(p.z-30)<1e-8)
assert(not geom.transform({0,0,1},{position={0,0,0},orientation={0,0,0,1}}),"missing pivot/scale guessed")
assert(not geom.relative({0,0,1},nil),"invented world origin")
assert(geom.wrap(1-359)==2)
package.loaded["system.libraries.log"]={warn=function() end,error=function() end}
sublevel={isInPlotGrid=function() return true end,getLogicalPose=function() return pose end,getMass=function() return 126093 end,getLinearVelocity=function() return {x=1,y=2,z=3} end}
local sable=require("system.services.sabled")
sable.acquire(true)
assert(sable.status().inSublevel and sable.snapshot().sublevel.mass==126093)
sublevel.isInPlotGrid=function() return false end
sable.acquire(false)
assert(not sable.status().inSublevel)
print("addon cache, cadence, explicit sublevel and coordinate transform tests passed")
