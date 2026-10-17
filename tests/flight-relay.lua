package.path="./?.lua;"..package.path
local now=10
os.clock=function() return now end
local addon=require("system.libraries.addon")
addon.bounded=function(fn) return pcall(fn) end
addon.periodic=function() return {stop=function() end} end
parallel={waitForAll=function(...) for _,fn in ipairs({...}) do fn() end end}
local readings={pitch=0,roll=0,altitude=198,heading=359,pitchRate=0,rollRate=0,altitudeRate=0,headingRate=0}
local fastReads=0
package.loaded["system.services.avionicsd"]={flightTelemetry=function(sensors)
  fastReads=fastReads+1
  assert(sensors.gimbal=="g")
  local out=addon.copy(readings) out.timestamp=now return out
end,snapshot=function() error("full flight snapshot copied") end}
package.loaded["system.services.sabled"]={flightStatus=function() return {inSublevel=true,timestamp=now} end,
  snapshot=function() error("full Sable snapshot copied") end}
package.loaded["system.security.permissions"]={require=function(actor) return actor.pid==7 end}
package.loaded["system.libraries.log"]={info=function() end,warn=function() end,error=function() end}
local axes={"pitch","roll","altitude","heading"}
local sides={"top","bottom","left","right"}
local stored={control={sensors={gimbal="g"},channels={},gains={},manualInputs={},
  hoverValidated=true,rescueValidated=true,manualValidated=true}}
for i,axis in ipairs(axes) do
  stored.control.channels[i]={id=axis,backend="relay",name="relay_0",side=sides[i],min=0,max=15,neutral=7,rescue=15,
    mix={[axis]=1},validated=true,frequency="existing frequency"}
  stored.control.gains[axis]={kp=1,ki=0,kd=0.1,limit=2,slew=10,integralLimit=1,deadband=0}
end
package.loaded["system.libraries.config"]={load=function() return addon.copy(stored) end}
textutils={serialize=function(value) stored=addon.copy(value) return "saved" end}
package.loaded["system.libraries.safe_write"]={write=function() return true end}
local values,writes={},0
local row={name="relay_0",types={"redstone_relay"},set={setAnalogOutput=true},device={setAnalogOutput=function(side,value)
  assert(value%1==0 and value>=0 and value<=15)
  values[side]=value writes=writes+1
end}}
local present=true
addon.inventory=function() return present and {row} or {} end
local flight=require("system.services.flightd")
local process={pid=7,state="ready",meta={appId="navigation"},permissions={}}
flight.start({scheduler={processes={[7]=process}}})
flight.step(true)
assert(#flight.endpoints()==1 and flight.endpoints()[1].backend=="relay")
assert(flight.validate())
assert(flight.arm({pid=7}))
flight.step()
assert(writes==4 and values.top==7 and values.right==7,"relay channels not independent")
flight.step()
assert(writes==4,"unchanged relay outputs repeated")
flight.release(7,"test close") flight.step()
assert(values.top==15 and values.bottom==15 and flight.status().state=="failsafe","relay rescue omitted")
assert(flight.disarm({pid=7}))
local cfg=flight.configuration()
cfg.channels[2].side=cfg.channels[1].side
assert(flight.configure({pid=7},cfg))
local ok,errors=flight.validate()
assert(not ok and table.concat(errors,";"):find("duplicate output",1,true),"duplicate relay side accepted")
cfg=flight.configuration() cfg.channels[1].neutral=7.5
assert(not flight.configure({pid=7},cfg),"fractional signal accepted")
cfg=flight.configuration() cfg.channels[1].backend="avionics" cfg.channels[1].name=true
assert(not flight.configure({pid=7},cfg),"malformed endpoint crashes/accepted")
present=false flight.step(true)
assert(#flight.endpoints()==0 and not flight.validate(),"detached relay still ready")
assert(fastReads>0)
print("relay mapping, independent sides, rescue, duplicate/range checks and slim telemetry passed")
