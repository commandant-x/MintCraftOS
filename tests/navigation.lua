package.path="./?.lua;"..package.path
local now=10
os.clock=function() return now end
local addon=require("system.libraries.addon")
addon.bounded=function(fn) return pcall(fn) end
addon.inventory=function() return {} end
addon.periodic=function() return {stop=function() end} end
package.loaded["system.libraries.log"]={info=function() end,warn=function() end,error=function() end}
package.loaded["system.security.permissions"]={require=function(actor,p) return actor.pid==7 end}
local stored={aircraft={commands={{frequency="2x green concrete powder"}}}}
package.loaded["system.libraries.config"]={load=function() return addon.copy(stored) end}
textutils={serialize=function(value) stored=addon.copy(value) return "saved" end}
package.loaded["system.libraries.safe_write"]={write=function() return true end}
parallel={waitForAll=function(...) for _,f in ipairs({...}) do f() end end}
local angles,heading,height,rate={0,0},359,198,{0,0,0}
local timestamp=now
local onShip=true
package.loaded["system.services.avionicsd"]={snapshot=function()
  return {timestamp=timestamp,gimbal={{name="g",ok=true,data={angles=angles,angularRates=rate}}},
    altitude={{name="a",ok=true,data={height=height,verticalSpeed=0}}},nav={{name="n",ok=true,data={heading=heading}}}}
end}
package.loaded["system.services.sabled"]={status=function() return {inSublevel=onShip} end,snapshot=function() return {timestamp=timestamp} end}
local outputs,writes={},0
redstone={setAnalogOutput=function(side,value) outputs[side]=value writes=writes+1 end,getInput=function() return false end}
local process={pid=7,state="ready",meta={appId="navigation"},permissions={}}
local flight=require("system.services.flightd")
flight.start({scheduler={processes={[7]=process}}})
local actor={pid=7}
assert(not flight.arm(actor),"uncalibrated system armed")
local cfg=flight.configuration()
cfg.sensors={gimbal="g",altitude="a",nav="n"}
local axes={"pitch","roll","altitude","heading"}
local sides={"top","bottom","left","right"}
for i,axis in ipairs(axes) do
  cfg.channels[i]={id=axis,backend="redstone",side=sides[i],min=0,max=15,neutral=7,rescue=15,mix={[axis]=1}}
  cfg.gains[axis]={kp=1,ki=0.1,kd=0.1,limit=2,slew=10,integralLimit=1,deadband=0}
end
assert(flight.configure(actor,cfg))
assert(stored.aircraft.commands[1].frequency=="2x green concrete powder","migration erased frequency")
assert(not flight.arm(actor),"unvalidated mapping armed")
assert(not flight.calibrate(actor,"channel","pitch",true),"untested actuator accepted")
assert(not flight.testOutput(actor,"pitch",8,true,3),"unbounded calibration pulse accepted")
assert(not flight.testOutput(actor,"pitch",8,true,0/0),"invalid pulse duration accepted")
assert(not flight.testOutput(actor,"pitch",8,false,2),"extended pulse bypassed confirmation")
assert(flight.testOutput(actor,"pitch",8,true,2))
flight.step()
now=now+0.4 timestamp=now flight.step()
assert(flight.status().state=="calibration" and outputs.top==8,"extended test ended before burner discovery tick")
now=now+1.7 timestamp=now flight.step() flight.step()
assert(flight.status().state=="disarmed" and outputs.top==15,"extended test failed to return to rescue")
for _,axis in ipairs(axes) do
  assert(flight.testOutput(actor,axis,8,true))
  flight.step()
  now=now+0.31 timestamp=now flight.step() flight.step()
  assert(flight.status().state=="disarmed","successful output test requires failsafe acknowledgement")
  assert(flight.status().calibration.tested[axis])
  assert(flight.calibrate(actor,"channel",axis,true))
end
assert(flight.calibrate(actor,"hover",nil,true))
assert(flight.calibrate(actor,"manual",nil,true))
assert(not flight.calibrate(actor,"rescueConfirm",nil,true))
assert(flight.calibrate(actor,"rescue",nil,true)) flight.step()
assert(not flight.arm(actor),"rescue not physically confirmed")
assert(flight.calibrate(actor,"rescueConfirm",nil,true))
assert(flight.configure(actor,flight.configuration()),"unchanged Save failed")
assert(flight.configuration().rescueValidated and flight.configuration().channels[1].validated,"unchanged Save erased calibration")
local valid,errors=flight.validate() assert(valid,table.concat(errors,";"))
assert(flight.arm(actor))
assert(flight.status().targets.heading==359 and flight.status().targets.altitude==198)
heading=1 now=now+0.1 timestamp=now flight.step()
assert(outputs.right<=7,"359->1 heading wrapped in wrong direction")
assert(flight.manual(actor,"altitude",1))
height=200 now=now+0.1 timestamp=now flight.step()
assert(flight.status().targets.altitude==200)
height=201 now=now+0.3 timestamp=now flight.step()
assert(flight.status().targets.altitude==201,"manual release did not rebase target")
timestamp=now-0.51 flight.step()
assert(flight.status().state=="failsafe" and outputs.top==15)
assert(not flight.arm(actor),"automatic rearm after stale telemetry")
timestamp=now assert(flight.disarm(actor)) assert(flight.arm(actor))
process.state="killed" flight.release(7,"killed") flight.step()
assert(flight.status().state=="failsafe" and outputs.right==15)
assert(writes>0)
process.state="ready"
assert(flight.disarm(actor))
redstone.setAnalogOutput=function() error("test actuator disconnected") end
assert(flight.testOutput(actor,"pitch",9,true))
flight.step() flight.step()
assert(flight.status().state=="failsafe","actuator error no longer triggers failsafe")
assert(not flight.status().calibration.tested.pitch,"failed repeat test reused old success")
assert(not flight.configuration().channels[1].validated,"failed repeat test retained direction validation")
assert(not flight.calibrate(actor,"channel","pitch",true),"failed test accepted as physically verified")
local pid=require("system.navigation.pid")
local s={}
for i=1,100 do pid.step(s,{kp=100,ki=100,kd=0,limit=1,slew=10,integralLimit=10},20,0,0.1) end
assert((s.integral or 0)==0 and s.output<=1,"PID windup at saturation")
print("navigation calibration, wrap, manual priority, stale telemetry and failsafe tests passed")
