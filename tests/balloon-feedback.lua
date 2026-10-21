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
package.loaded["system.services.avionicsd"]={snapshot=function() return {timestamp=now} end}
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
assert(flight.configure(actor,cfg))
assert(not flight.testOutput(actor,"balloon-burners",5,true),"short heater pulse accepted as feedback calibration")
assert(flight.testOutput(actor,"balloon-burners",5,true,2)) flight.step()
assert(sent[#sent]==5)
now=11 sample() flight.step()
local test=flight.status().calibration.test
assert(not test.burnerFeedback and test.feedbackError:find("received 0/15, expected 5",1,true))
now=12.1 flight.step() flight.step()
assert(sent[#sent]==0 and flight.status().state=="disarmed")
assert(not flight.status().calibration.tested["balloon-burners"])
assert(flight.status().reason:find("NOT confirmed",1,true))
assert(not flight.calibrate(actor,"channel","balloon-burners",true))
-- Fresh post-command feedback from both heaters allows only the direction step,
-- not arming, PID configuration or hover/rescue confirmations.
now=13 assert(flight.testOutput(actor,"balloon-burners",5,true,2)) flight.step()
assert(not bridge.burnerFeedback(cfg.balloonSetup,5,13),"pre-command snapshot accepted")
now=14 for _,b in ipairs(raw.burners) do b.signal=5 b.hasBalloon=true end sample() flight.step()
assert(flight.status().calibration.test.burnerFeedback)
now=15.1 flight.step() flight.step()
assert(flight.status().calibration.tested["balloon-burners"] and sent[#sent]==0)
assert(flight.status().calibration.initializationConfirmed)
for _,b in ipairs(raw.burners) do
 b.signal=0 b.gasOutput=0 b.hasBalloon=false b.associationSource="heater_membership" b.associationState="no_balloon_reference"
end
now=15.2 sample()
local errors=table.concat(flight.status().errors,";")
assert(not errors:find("association",1,true),"successful initialization lost after rescue to zero")
assert(flight.calibrate(actor,"channel","balloon-burners",true))
assert(not flight.arm(actor),"heater feedback bypassed flight calibration")
now=16 assert(flight.testOutput(actor,"balloon-burners",5,true,2)) flight.step()
now=18.1 flight.step() flight.step()
assert(not flight.status().calibration.tested["balloon-burners"],"stale repeated test reused old confirmation")
assert(not flight.status().calibration.initializationConfirmed,"failed repeat retained idle proof")
assert(not bridge.burnerFeedback({vehicleId="different",burnerIds=cfg.balloonSetup.burnerIds},5,0))
print("balloon feedback: mixed screenshot signals, fresh per-heater acknowledgment, stale/wrong vehicle rejection, rescue, no false calibration and re-test invalidation passed")
