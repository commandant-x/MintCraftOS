package.path="./?.lua;"..package.path
local addon=require("system.libraries.addon")
addon.bounded=function(fn) return pcall(fn) end
if addon.configure then addon.configure({readsPerTick=100000}) end
local now=10
os.clock=function() return now end
parallel={waitForAll=function(...) for _,fn in ipairs({...}) do fn() end end}
local devices={g={getAngles=function() return {3,4} end,getAngularRates=function() return {1,2,3} end,
  getGravity=function() return {0,-9,0} end},a={getHeight=function() return 100 end},n={getHeading=function() return 90 end},
  motor={getSignal=function() return 4 end}}
local types={g="gimbal_sensor",a="altitude_sensor",n="navigation_table",motor="throttle_lever"}
peripheral={getNames=function() return {"g","a","n","motor"} end,getType=function(n) return types[n] end,
  getMethods=function(n) local t={} for k in pairs(devices[n]) do t[#t+1]=k end return t end,wrap=function(n) return devices[n] end}
local av=require("system.services.avionicsd")
av.acquire(true)
av.acquireDiagnostics()
assert(av.status().ok,"absent optional methods degraded service")
local ids={gimbal="g",altitude="a",nav="n"}
local f=av.flightTelemetry(ids)
assert(av.flightTelemetry({}).heading==90 and av.flightTelemetry({}).pitch==3,"unique sensors not selected automatically")
assert(not av.flightTelemetry({nav="detached"}).heading,"explicit missing sensor silently replaced")
assert(f.pitch==3 and f.headingRate==2 and f.altitude==100 and f.timestamp==10)
assert(not f.measurements.pressure.valid and f.measurements.pitch.observedAt==10)
-- Inject an older optional sample to exercise mixed acquisition ages.
for i=1,20 do
  local name,value=debug.getupvalue(av.snapshot,i)
  if not name then break end
  if name=="cached" then
    value.gimbal[1].measurements.gravity.observedAt=1
    value.gimbal[1].measurements.gravity.validUntil=1.5
    value.altitude[1].measurements.airPressure.observedAt=2
  end
end
f=av.flightTelemetry(ids)
assert(f.timestamp==10 and f.pitch==3 and not f.gravity,"optional age blocked healthy flight")
devices.g.getGravity=function() return "bad" end
now=10.1 av.acquire(false)
f=av.flightTelemetry(ids)
assert(f.pitch==3 and not f.measurements.gravity.valid and not av.status().ok)
devices.g.getAngles=function() return {3,"bad"} end
av.acquire(false)
f=av.flightTelemetry(ids)
assert(f.pitch==3 and not f.roll,"malformed roll discarded valid pitch")
devices.g.getAngles=nil
now=10.2 av.acquire(false)
f=av.flightTelemetry(ids)
assert(not f.pitch and f.headingRate==2 and not av.snapshot().gimbal[1].ok)
assert(av.snapshot().throttle[1].measurements.signal.observedAt==10,"slow cache re-dated")
devices.a.getHeight=function() return false end
now=10.3 av.acquire(false)
assert(not av.flightTelemetry(ids).altitude)
assert(not av.flightTelemetry({gimbal="wrong"}).headingRate)
now=11
assert(not av.flightTelemetry(ids).heading,"expired value returned")
package.loaded["system.libraries.log"]={warn=function() end}
sublevel={isInPlotGrid=function() return true end,getLogicalPose=function() return {position={2,3,4}} end,
  getMass=function() return 5 end,getCenterOfMass=function() return {20,30,40} end}
aero={getAirPressure=function(x,y,z) assert(x==2 and y==3 and z==4) return 0.7 end,getGravity=function() return {0,-9,0} end}
local sable=require("system.services.sabled")
sable.acquire(true)
sable.acquireDiagnostics() sable.acquire(false)
local s=sable.snapshot()
assert(s.aero.airPressure==0.7 and s.measurements.centerOfMass.frame=="unknown")
assert(s.measurements.mass.observedAt==11)
now=11.2 sable.acquire(false)
s=sable.snapshot()
assert(s.timestamp==11.2 and s.measurements.mass.observedAt==11 and s.measurements.airPressure.observedAt==11)
assert(sable.flightStatus().timestamp==11.2 and sable.pose().timestamp==11.2)
local p=sable.pose() p.logicalPose.position[1]=999
assert(sable.pose().logicalPose.position[1]==2)
now=20
sublevel.getMass=function() local started=now now=now+1.25 return 5 end
sublevel.getLogicalPose=function() now=now+0.2 return {position={2,3,4}} end
sable.acquire(true)
sable.acquireDiagnostics() sable.acquire(false)
s=sable.snapshot()
local status=sable.flightStatus()
assert(status.timestamp==21.45 and s.timestamp>21,"publication freshened sublevel observation")
assert(s.measurements.mass.observedAt==20.2 and s.measurements.mass.receivedAt==21.45)
assert(s.measurements.mass.validUntil==21.2 and not s.measurements.mass.valid,"slow read latency masked expiration")
assert(s.measurements.airPressure.receivedAt>=s.measurements.airPressure.observedAt)
devices.p={getThrust=function() return 5 end,getAxis=function() return "north" end,getAirflow=function() return 2.5 end}
devices.b={getThrust=function() return 5 end,getAxis=function() return nil end,getAirflow=function() return 3 end}
types.p="propeller" types.b="propeller_bearing"
peripheral.getNames=function() return {"p","b"} end
av.acquire(true)
av.acquireDiagnostics() av.acquire(false)
assert(av.status().ok,"documented propeller types rejected")
local readiness=av.health().readiness
assert(readiness.p.airflow.valid and readiness.p.axis.valid)
assert(not readiness.b.axis.valid and not readiness.b.axis.available and not readiness.b.axis.required)
devices.p.getAirflow=function() return false end
now=now+1.1 av.acquire(false)
av.acquireDiagnostics() av.acquire(false)
assert(not av.health().readiness.p.airflow.valid and not av.status().ok,"boolean airflow accepted")
local realRead=addon.read
local priorities={}
addon.read=function(device,methods,timeout,options)
  assert(timeout==0.15,"mainThread read timeout too short")
  local name=methods[1]
  for _,method in ipairs(methods) do priorities[method]=options and options.priority end
  local values,errors=realRead(device,methods,timeout,options)
  local timings={}
  for _,method in ipairs(methods) do timings[method]={startedAt=now-0.03,receivedAt=now-0.01} end
  return values,errors,timings
end
devices.g.getAngles=function() return {3,4} end
devices.g.getGravity=function() return {0,-9,0} end
devices.a.getHeight=function() return 100 end
peripheral.getNames=function() return {"g","a","n","motor"} end
now=40 av.acquire(true)
av.acquireDiagnostics() av.acquire(false)
f=av.flightTelemetry(ids)
assert(f.timestamp==39.97 and f.measurements.pitch.receivedAt==39.99,"method timing ignored")
assert(priorities.getAngles=="flight" and priorities.getSignal=="diagnostics")
sublevel.getMass=function() return 5 end
sublevel.getLogicalPose=function() return {position={2,3,4}} end
sable.acquire(true)
sable.acquireDiagnostics() sable.acquire(false)
s=sable.snapshot()
assert(s.measurements.mass.observedAt==39.97 and s.measurements.mass.receivedAt==39.99)
assert(s.measurements.airPressure.observedAt==39.97 and sable.pose().timestamp==39.97)
assert(sable.flightStatus().timestamp==39.97)
assert(priorities.isInPlotGrid=="flight" and priorities.getLogicalPose=="flight")
assert(priorities.getMass=="diagnostics" and priorities.getAirPressure=="diagnostics")
-- Older mocks supply only values/errors: use conservative local acquisition time.
addon.read=function(...) local values,errors=realRead(...) return values,errors end
now=41 av.acquire(true) sable.acquire(true)
av.acquireDiagnostics() sable.acquireDiagnostics() av.acquire(false) sable.acquire(false)
assert(av.flightTelemetry(ids).timestamp==41)
assert(sable.snapshot().measurements.mass.observedAt==41 and sable.flightStatus().timestamp==41)
addon.read=realRead
local names={"g","a","n"}
for i=1,40 do
  local name=string.format("00prop%02d",i)
  names[#names+1]=name
  devices[name]={getThrust=function() return 5 end}
  types[name]="propeller"
end
peripheral.getNames=function() return names end
local diagnosticReads=0
now=50
addon.read=function(device,methods,timeout,options)
  if options.priority=="diagnostics" then
    diagnosticReads=diagnosticReads+1
    local fast=av.flightTelemetry(ids)
    assert(fast.timestamp==50,"inventory-order diagnostics preceded fast publication")
    if diagnosticReads==1 then assert(fast.pitch==3 and fast.heading==90) end
    now=now+0.02
  end
  return realRead(device,methods,timeout,options)
end
av.acquire(true)
assert(diagnosticReads==0,"fast acquisition awaited diagnostics")
av.acquireDiagnostics()
assert(diagnosticReads==40 and av.flightTelemetry(ids).timestamp==50)
assert(not av.flightTelemetry(ids).pitch,"diagnostic completion freshened expired flight")
assert(not av.snapshot().diagnosticsPending)
addon.read=realRead
-- The next fast cycle reuses diagnostics unchanged inside their one-second cache.
now=50.9 av.acquire(false)
local oldSlow=av.snapshot().propeller[1].measurements.thrust.observedAt
assert(av.flightTelemetry(ids).timestamp==50.9)
assert(av.snapshot().propeller[1].measurements.thrust.observedAt==oldSlow)
local stamp=av.snapshot().timestamp
local freshHealth=av.health()
assert(freshHealth.ok and freshHealth.lastSuccessAge==0 and not freshHealth.staleFast)
now=51.6
local stalled=av.health()
assert(not stalled.ok and stalled.degraded and stalled.staleFast and stalled.acquisitionStale)
assert(stalled.lastSuccessAge>0.5 and stalled.fastReadiness.g.pitch.stale)
assert(av.snapshot().timestamp==stamp and av.flightTelemetry(ids).timestamp==50.9,"health refreshed acquisition times")
devices.a.getVerticalSpeed=function() return 0 end
now=52 av.acquire(false)
devices["00prop01"].getThrust=function() error("diagnostic failure") end
now=53.1 av.acquire(false)
av.acquireDiagnostics() av.acquire(false)
assert(not av.health().ok and av.health().flightReady and not av.health().staleFast,"diagnostic fault blocked flight readiness")
peripheral.getNames=function() return {"a"} end
devices.a.getVerticalSpeed=nil
now=60 av.acquire(true)
local displayHealth=av.health()
assert(displayHealth.ok and not displayHealth.flightReady and not displayHealth.staleFast,"height-only display sensor degraded service")
-- An absent optional rate has no acquired value to become stale.
now=60.6
local agedDisplay=av.health()
assert(agedDisplay.fastReadiness.a.altitude.stale)
assert(not agedDisplay.fastReadiness.a.altitudeRate.stale,"missing optional rate reported stale")
peripheral.getNames=function() return {"g"} end
devices.g.getAngles=nil
now=61 av.acquire(true)
assert(not av.health().ok,"missing required angles reported healthy")
devices.n2={getHeading=function() return 180 end} types.n2="navigation_table"
peripheral.getNames=function() return {"n","n2"} end
av.acquire(true)
assert(not av.flightTelemetry({}).heading,"ambiguous automatic sensor chosen silently")
assert(av.flightTelemetry({nav="n2"}).heading==180,"explicit sensor selection ignored")
print("telemetry contract, automatic/ambiguous sensor selection, freshness and frame tests passed")
