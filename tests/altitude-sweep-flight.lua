package.path="./?.lua;"..package.path
local addon=require("system.libraries.addon")
addon.bounded=function(fn) return pcall(fn) end addon.configure({readsPerTick=100000})
addon.periodic=function() return {stop=function() end} end
parallel={waitForAll=function(...) for _,f in ipairs({...}) do f() end end}
local worldX,tilt,poseLost,foreignPose=0,0,false,false
local now,z,v,command,pressed,allowed,badReceiver,stale,failWrite=10,100,0,0,false,true,false,false,false
os.clock=function() return now end os.epoch=function() return now*1000 end
local stored,serialized,files={},nil,{}
local onTransmit
textutils={serialize=function(t) serialized=addon.copy(t) return "cfg" end}
package.loaded["system.libraries.config"]={load=function() return addon.copy(stored) end}
package.loaded["system.libraries.safe_write"]={write=function(path)
 if failWrite then return false,"disk full" end
 if path=="/system/config/navigation.cfg" then stored=addon.copy(serialized) end
 files[path]=addon.copy(serialized) return true
end}
local space=1000000
fs={getFreeSpace=function() return space end,exists=function(p) return files[p]~=nil end}
package.loaded["system.libraries.log"]={warn=function() end,error=function() end}
package.loaded["system.security.permissions"]={require=function() return allowed,"denied" end}
redstone={getInput=function() return pressed end}
addon.inventory=function() return {{name="tx",types={"redstone_link_bridge"},set={sendLinkSignal=true},device={sendLinkSignal=function(_,_,value) command=value if onTransmit then local callback=onTransmit onTransmit=nil callback() end return true end}}} end
package.loaded["system.services.sabled"]={snapshot=function() return {timestamp=now} end,status=function() return {inSublevel=true} end,pose=function() if poseLost then return nil end return {vehicleId=foreignPose and "other" or "ship",inSublevel=true,frame="world",timestamp=now,identityAt=now,logicalPose={position={x=worldX,y=z,z=0},orientation={x=math.sin(math.rad(tilt)/2),y=0,z=0,w=math.cos(math.rad(tilt)/2)}}} end}
package.loaded["system.services.avionicsd"]={flightTelemetry=function()
 local stamp=stale and now-1 or now
 return {timestamp=stamp,measurements={altitude={value=z,valid=true,observedAt=stamp,validUntil=stamp+0.5},
 altitudeRate={value=v,valid=true,observedAt=stamp,validUntil=stamp+0.5}}}
end}
local raw={schema=1,ok=true,complete=true,readOnly=true,frame="body_plot",vehicleId="ship",units={position="block"},revision=0,ageTicks=0,
 centerOfMass={x=0,y=0,z=0},features={burners=true},actuators={},links={},burners={}}
for i=1,2 do raw.burners[i]={id="heater"..i,position={x=i,y=0,z=0},signal=0,gasOutput=0,hasBalloon=false,associationSource="heater_membership",associationState="no_balloon_reference"} end
mintcraft_vehicle={snapshot=function() return addon.copy(raw) end}
local bridge=require("system.services.vehiclebridged")
local function sample()
 raw.revision=raw.revision+1
 for i,b in ipairs(raw.burners) do b.signal=(i==1 and badReceiver) and 0 or command b.gasOutput=b.signal*10 b.hasBalloon=b.signal>0 b.associationState=b.hasBalloon and "associated" or "no_balloon_reference" end
 bridge.acquire()
end
local process={pid=7,state="ready",meta={appId="navigation"},permissions={}}
local ctx={scheduler={processes={[7]=process}}}
local flight=require("system.services.flightd")
local actor={pid=7}
flight.start(ctx) flight.step(true) sample()
local function prepare()
 pressed,allowed,badReceiver,stale,failWrite=false,true,false,false,false process.state="ready"
 worldX,tilt,poseLost,foreignPose=0,0,false,false
 if flight.status().state=="failsafe" then assert(flight.disarm(actor)) end
 local cfg=flight.configuration()
 cfg.mode="altitude" cfg.channels={{id="burners",backend="frequency",name="tx",min=0,max=15,neutral=5,rescue=0,
 link={first="minecraft:white_wool",second="minecraft:white_wool"},mix={altitude=1},actuator={role="buoyancy"}}}
 cfg.balloonSetup={vehicleId="ship",burnerIds={"heater1","heater2"}}
 cfg.manualInputs={{axis="altitude",side="front",value=1}} cfg.gains.altitude.kp=0
 assert(flight.configure(actor,cfg))
 assert(flight.testOutput(actor,"burners",5,true,2)) flight.step()
 now=now+1 sample() flight.step()
 now=now+1.1 flight.step() flight.step() sample()
 assert(flight.calibrate(actor,"channel","burners",true))
 assert(flight.calibrate(actor,"manual",nil,true))
 assert(flight.calibrate(actor,"rescue",nil,true)) flight.step()
 assert(flight.calibrate(actor,"rescueConfirm",nil,true))
 z,v=100,0 sample()
end
local options=require("system.navigation.altitude_sweep").defaults()
prepare()
local verified=flight.configuration()
local unverified=addon.copy(verified) unverified.manualValidated=false
assert(flight.configure(actor,unverified))
local refused,detail=flight.startSweep(actor,options,true)
assert(not refused and detail:find("Manual OK",1,true) and detail:find("Test rescue, then Rescue OK",1,true) and detail:find("Verify direction",1,true) and detail:find("Initialize (2s)",1,true),"missing sweep prerequisites not identified")
prepare()
assert(not flight.startSweep(actor,options,false)) assert(command==0)
local frozen=flight.configuration() frozen.channels[1].neutral=1
assert(not flight.startSweep(actor,options,true,frozen))
assert(flight.startSweep(actor,options,true,flight.configuration()))
assert(stored.control.sessionActive and command==0,"extended operation not persisted before actuation")
local ticks=0
while flight.status().sweep.state=="running" do
 ticks=ticks+1 assert(ticks<1800)
 now=now+0.1
 v=v+(0.05*(command-11)-v)/2*0.1 z=z+v*0.1
 if ticks%10==0 then sample() end
 flight.step()
end
local result=assert(flight.sweepReport(actor))
assert(result.state=="complete",result.reason)
assert(result.proposal,result.fitError)
assert(command==0 and not stored.control.sessionActive)
assert(flight.configuration().channels[1].neutral==5,"sweep silently applied model")
assert(not flight.applySweep(actor,false))
local saved,path=flight.exportSweep(actor) assert(saved and files[path].samples[1])
space=0 assert(not flight.exportSweep(actor)) space=1000000
assert(flight.applySweep(actor,true))
assert(flight.configuration().channels[1].neutral==11 and flight.configuration().gains.altitude.ki>0)
assert(not flight.configuration().manualValidated and not flight.configuration().hoverValidated and not flight.configuration().rescueValidated)
assert(not flight.arm(actor),"model fit forged physical validation")
-- Repeated independent failures must rescue without applying candidate gains.
for _,fault in ipairs({"travel","world","tilt","pose","identity","speed","sensor","receiver","owner","permission","manual","stop"}) do
 prepare()
 assert(flight.startSweep(actor,options,true)) flight.step()
 if fault=="travel" then z=109 elseif fault=="world" then worldX=9 elseif fault=="tilt" then tilt=11 elseif fault=="pose" then poseLost=true elseif fault=="identity" then foreignPose=true elseif fault=="speed" then v=2
 elseif fault=="sensor" then stale=true elseif fault=="receiver" then badReceiver=true now=now+2.1
 elseif fault=="owner" then process.state="killed" elseif fault=="permission" then allowed=false
 elseif fault=="manual" then pressed=true elseif fault=="stop" then assert(flight.stopSweep(actor)) end
 now=now+0.1 sample() flight.step()
 assert(command==0 and flight.status().sweep.state=="aborted",fault.." did not abort/rescue")
 assert(flight.configuration().gains.altitude.kp==0,fault.." changed gains")
 process.state="ready" allowed=true pressed=false stale=false badReceiver=false v=0
 assert(flight.disarm(actor))
end
prepare()
assert(flight.startSweep(actor,options,true))
onTransmit=function() assert(flight.stopSweep(actor)) end
flight.step()
assert(command==0 and flight.status().sweep.state=="aborted","stop during suspended write was overwritten")
assert(flight.disarm(actor))
prepare() failWrite=true
assert(not flight.startSweep(actor,options,true) and command==0,"failed durable preparation actuated")
failWrite=false
assert(flight.startSweep(actor,options,true)) flight.step()
assert(stored.control.sessionActive)
flight.start(ctx)
assert(flight.status().state=="failsafe" and flight.status().rescuePending and not flight.status().sweep)
flight.step(true) assert(command==0,"boot did not apply interrupted sweep rescue")
print("altitude sweep service: simulated plant/model, explicit start/apply, durable preparation/report, config invalidation, guard failures, owner/manual/permission stop and interrupted boot rescue passed")
