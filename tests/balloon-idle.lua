package.path="./?.lua;"..package.path
local now=10 os.clock=function() return now end
local addon=require("system.libraries.addon")
addon.bounded=function(fn) return pcall(fn) end addon.configure({readsPerTick=100000})
addon.periodic=function() return {stop=function() end} end
parallel={waitForAll=function(...) for _,fn in ipairs({...}) do fn() end end}
package.loaded["system.libraries.log"]={info=function() end,warn=function() end}
package.loaded["system.security.permissions"]={require=function() return true end}
package.loaded["system.libraries.config"]={load=function() return {} end}
package.loaded["system.libraries.safe_write"]={write=function() return true end}
textutils={serialize=function() return "cfg" end}
local sent={}
addon.inventory=function() return {{name="tx",types={"redstone_link_bridge"},set={sendLinkSignal=true},device={sendLinkSignal=function(_,_,v) sent[#sent+1]=v return true end}}} end
package.loaded["system.services.avionicsd"]={flightTelemetry=function()
 return {timestamp=now,altitude=100,altitudeRate=0,measurements={
  altitude={value=100,valid=true,observedAt=now,validUntil=now+0.5},
  altitudeRate={value=0,valid=true,observedAt=now,validUntil=now+0.5}}}
end}
package.loaded["system.services.sabled"]={snapshot=function() return {timestamp=now} end,status=function() return {inSublevel=true} end}
local bridge=require("system.services.vehiclebridged")
local raw={schema=1,readOnly=true,ok=true,complete=true,frame="body_plot",vehicleId="ship",revision=1,ageTicks=0,
 units={position="block"},centerOfMass={x=0,y=0,z=0},actuators={},links={},features={burners=true},
 burners={{id="ship:-1:-2:2",position={x=-1,y=-2,z=2},signal=0,gasOutput=0,hasBalloon=false},
 {id="ship:-1:-2:3",position={x=-1,y=-2,z=3},signal=15,gasOutput=500,hasBalloon=true}}}
mintcraft_vehicle={snapshot=function() return addon.copy(raw) end}
local function sample() raw.revision=raw.revision+1 bridge.acquire() end
sample()
local flight=require("system.services.flightd")
flight.start({scheduler={processes={[7]={pid=7,state="ready",meta={appId="navigation"},permissions={}}}}})
flight.step(true)
local actor={pid=7}
local wizard=require("system.navigation.balloon_setup")
local plan=assert(wizard.plan(bridge.snapshot(),{channels={}},flight.endpoints()))
local cfg=assert(wizard.create(flight.configuration(),plan,{transmitter="tx",neutral=5,rescue=0,wiringConfirmed=true}))
cfg.gains.altitude={kp=1,ki=0,kd=0,limit=1,slew=1,integralLimit=1,deadband=0}
assert(flight.configure(actor,cfg))
local function off()
 for _,b in ipairs(raw.burners) do b.signal=0 b.gasOutput=0 b.hasBalloon=false b.associationSource="heater_membership" b.associationState="no_balloon_reference" end
 sample()
end
local function initialize()
 assert(flight.testOutput(actor,"balloon-burners",5,true,2)) flight.step()
 now=now+1
 for _,b in ipairs(raw.burners) do b.signal=5 b.gasOutput=100 b.hasBalloon=true b.associationSource="heater_membership" b.associationState="associated" end
 sample() flight.step()
 now=now+1.1 flight.step() flight.step()
 assert(flight.status().calibration.initializationConfirmed)
 off()
 assert(flight.calibrate(actor,"channel","balloon-burners",true))
end
initialize()
assert(not flight.arm(actor),"idle proof bypassed hover/manual/PID/rescue checks")
assert(flight.calibrate(actor,"hover",nil,true))
assert(flight.calibrate(actor,"manual",nil,true))
assert(flight.calibrate(actor,"rescue",nil,true)) flight.step()
assert(flight.calibrate(actor,"rescueConfirm",nil,true))
assert(flight.arm(actor),"cold arm blocked despite real positive initialization and physical confirmations")
flight.step() assert(sent[#sent]==5)
now=now+1 sample() flight.step()
assert(flight.status().state=="armed","cold restart failed before bounded association window")
-- A signal can arrive before Aeronautics' lazy association is populated.
for _,b in ipairs(raw.burners) do b.signal=5 b.gasOutput=100 end
sample() flight.step() assert(flight.status().state=="armed")
now=now+1.1 sample() flight.step()
assert(flight.status().state=="failsafe" and sent[#sent]==0,"missing active association was ignored after restart window")
assert(not flight.status().calibration.initializationConfirmed)
assert(flight.disarm(actor))
initialize()
assert(flight.arm(actor)) flight.step()
now=now+1
for _,b in ipairs(raw.burners) do b.signal=5 b.gasOutput=100 b.hasBalloon=true b.associationState="associated" end
sample() flight.step()
now=now+1.1 sample() flight.step()
assert(flight.status().state=="armed","confirmed warm heaters failed outside restart window")
-- One stopped receiver must not be hidden by the retained initialization.
raw.burners[1].signal=0 raw.burners[1].gasOutput=0 raw.burners[1].hasBalloon=false raw.burners[1].associationState="no_balloon_reference"
now=now+0.1 sample() flight.step()
assert(flight.status().state=="failsafe" and sent[#sent]==0,"one failed receiver hidden as idle during requested heat")
assert(flight.disarm(actor))
initialize()
-- A service restart intentionally loses volatile initialization proof.
flight.start({scheduler={processes={[7]={pid=7,state="ready",meta={appId="navigation"},permissions={}}}}})
assert(not flight.status().calibration.initializationConfirmed)
-- Helper cannot accept a proof for another group/vehicle, or mask explicit
-- capacity/membership failure as the particular off/no-reference condition.
local proof={vehicleId="ship",burnerIds=addon.copy(cfg.balloonSetup.burnerIds)}
assert(bridge.balloonStatus(cfg.balloonSetup,proof))
assert(not bridge.balloonStatus(cfg.balloonSetup,{vehicleId="other",burnerIds=proof.burnerIds}))
assert(not bridge.balloonStatus(cfg.balloonSetup,{vehicleId="ship",burnerIds={proof.burnerIds[1]}}))
raw.burners[1].associationState="invalid_capacity_or_heater_membership" sample()
assert(not bridge.balloonStatus(cfg.balloonSetup,proof))
raw.burners[1].associationState="no_balloon_reference" sample()
local removed=table.remove(raw.burners)
sample() assert(not bridge.balloonStatus(cfg.balloonSetup,proof),"missing burner accepted with idle proof")
raw.burners[2]=removed sample()
now=now+2.1 assert(not bridge.balloonStatus(cfg.balloonSetup,proof),"stale inventory accepted with idle proof")
print("balloon idle: positive initialization survives off/no-reference, guarded cold start, bounded reacquisition, missing heat/association rescue, restart and exact-group proof passed")
