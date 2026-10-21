package.path="./?.lua;"..package.path
local addon=require("system.libraries.addon")
addon.bounded=function(fn) return pcall(fn) end
addon.periodic=function() return {stop=function() end} end
parallel={waitForAll=function(...) for _,fn in ipairs({...}) do fn() end end}
local now,pos,id=10,{x=0,y=100,z=0},"ship-a"
os.clock=function() return now end
local stale,physical,permitted=false,false,true
package.loaded["system.libraries.log"]={warn=function() end,error=function() end}
package.loaded["system.security.permissions"]={require=function(actor) return permitted and actor.pid==7 end}
local function telemetry()
  return {pitch=0,roll=0,altitude=100,heading=0,pitchRate=0,rollRate=0,altitudeRate=0,headingRate=0,timestamp=now}
end
package.loaded["system.services.avionicsd"]={flightTelemetry=telemetry}
package.loaded["system.services.sabled"]={status=function() return {inSublevel=true,timestamp=now} end,
 pose=function() return {frame="world",inSublevel=true,vehicleId=id,identityAt=now,timestamp=stale and now-1 or now,logicalPose={position=addon.copy(pos)}} end}
local cfg={control={mode="full",sensors={},channels={},gains={},hoverValidated=true,rescueValidated=true,manualValidated=true,
 manualInputs={{axis="altitude",side="back",value=1}}}}
for i,axis in ipairs({"pitch","roll","altitude","heading"}) do
  cfg.control.channels[i]={id=axis,backend="redstone",side=({"top","bottom","left","right"})[i],min=0,max=15,neutral=7,rescue=15,mix={[axis]=1},validated=true}
  cfg.control.gains[axis]={kp=1,ki=0,kd=0.1,limit=2,slew=10,integralLimit=1,deadband=0}
end
local outputs,rows={},{}
for _,key in ipairs({"routeForward","routeReverse","routeRight","routeLeft"}) do
  local name=key
  cfg.control.channels[#cfg.control.channels+1]={id=name,backend="relay",name=name,side="front",min=0,max=15,neutral=15,rescue=15,mix={[name]=-10},validated=true}
  rows[#rows+1]={name=name,types={"redstone_relay"},set={setAnalogOutput=true},device={setAnalogOutput=function(_,value) outputs[name]=value end}}
end
addon.inventory=function() return rows end
redstone={getInput=function() return physical end,setAnalogOutput=function(side,value) outputs[side]=value end}
package.loaded["system.libraries.config"]={load=function() return addon.copy(cfg) end}
package.loaded["system.libraries.safe_write"]={write=function() return true end}
textutils={serialize=function() return "config" end}
local process={pid=7,state="ready",meta={appId="navigation"},permissions={}}
local flight=require("system.services.flightd")
flight.start({scheduler={processes={[7]=process}}}) flight.step()
now=now+0.1 flight.step() assert(flight.arm({pid=7}))
local plan=require("system.navigation.autopilot").defaults()
plan.points={{x=0,y=100,z=100}} plan.translationVerified=true plan.clearRouteConfirmed=true plan.settleSeconds=1 plan.verifiedVehicleId="ship-a"
assert(not flight.startMission({pid=7},plan,false),"confirmation bypass")
assert(not flight.startMission({pid=8},plan,true),"owner bypass")
permitted=false assert(not flight.startMission({pid=7},plan,true)) permitted=true
assert(flight.startMission({pid=7},plan,true))
for _=1,14 do now=now+0.1 flight.step() end
assert(flight.status().autopilot.state=="cruise" and outputs.routeForward<15 and outputs.routeReverse==15,"forward demand not routed through calibrated relay")
pos.z=0.5 now=now+0.1 flight.step()
assert(outputs.routeForward==15 and outputs.routeReverse==15,"direction reversal lacked neutral tick")
pos.z=1 now=now+0.1 flight.step()
assert(outputs.routeForward==15 and outputs.routeReverse<15,"braking failed after neutral tick")
assert(flight.manual({pid=7},"heading",1)) now=now+0.1 flight.step()
assert(flight.status().autopilot.state=="cancelled" and outputs.routeForward==15,"manual takeover left autonomous thrust")
now=now+0.4 flight.step() assert(flight.startMission({pid=7},plan,true))
physical=true now=now+0.1 flight.step()
assert(flight.status().autopilot.state=="cancelled" and outputs.routeForward==15,"physical pilot failed to cancel mission")
physical=false now=now+0.4 flight.step() assert(flight.startMission({pid=7},plan,true))
stale=true now=now+0.1 flight.step()
assert(flight.status().state=="failsafe" and outputs.routeForward==15 and outputs.top==15,"stale world pose bypassed rescue")
stale=false assert(not flight.startMission({pid=7},plan,true),"failsafe automatically rearmed")
assert(flight.disarm({pid=7})) assert(flight.arm({pid=7}))
now=now+0.1 flight.step() now=now+0.1 flight.step() assert(flight.startMission({pid=7},plan,true))
id="ship-b" now=now+0.1 flight.step() flight.step()
assert(flight.status().state=="failsafe" and flight.status().autopilot.reason:find("identity"))
plan.verifiedVehicleId="ship-b"
assert(flight.disarm({pid=7})) assert(flight.arm({pid=7}))
now=now+0.1 flight.step() now=now+0.1 flight.step() assert(flight.startMission({pid=7},plan,true))
flight.release(7,"Navigation closed") flight.step()
assert(flight.status().state=="failsafe" and outputs.routeForward==15,"owner loss failed rescue")
assert(flight.disarm({pid=7}))
cfg.control.channels[5].mix.routeForward=nil
flight.start({scheduler={processes={[7]=process}}}) flight.step() now=now+0.1 flight.step()
assert(flight.arm({pid=7}))
assert(not flight.startMission({pid=7},plan,true),"missing forward/braking map accepted")
flight.disarm({pid=7}) flight.step() assert(flight.disarm({pid=7}))
cfg.control.channels[5].mix.routeForward=-10 cfg.control.channels[1].mix.routeForward=-1
flight.start({scheduler={processes={[7]=process}}}) flight.step() now=now+0.1 flight.step()
assert(flight.arm({pid=7}))
assert(not flight.startMission({pid=7},plan,true),"translation consumed stabilization channels")
print("flight integration: ownership/permissions, explicit start, calibrated thrust, GUI/physical takeover, stale/identity rescue and owner loss passed")
