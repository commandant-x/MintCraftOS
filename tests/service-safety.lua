package.path="./?.lua;"..package.path
local now,serial,timers,events=10,0,{},{}
os.clock=function() return now end
os.epoch=function() return now*1000 end
os.startTimer=function(delay) serial=serial+1 timers[serial]=now+delay return serial end
os.cancelTimer=function(id) timers[id]=nil end
os.pullEvent=function(filter) return coroutine.yield(filter) end
os.queueEvent=function(...) events[#events+1]=table.pack(...) end

-- Model CC's native filtered event fan-out, including nested parallel calls.
local function wait(any,...)
  local threads,filters={},{}
  for i,fn in ipairs({...}) do threads[i]=coroutine.create(fn) end
  local event=table.pack()
  while true do
    local alive=0
    for i,thread in ipairs(threads) do
      if coroutine.status(thread)~="dead" then
        if not filters[i] or filters[i]==event[1] or event[1]=="terminate" then
          local ok,filter=coroutine.resume(thread,table.unpack(event,1,event.n))
          assert(ok,filter) filters[i]=filter
        end
        if coroutine.status(thread)=="dead" then if any then return i end
        else alive=alive+1 end
      end
    end
    if alive==0 then return end
    event=table.pack(os.pullEvent())
  end
end
parallel={waitForAll=function(...) return wait(false,...) end,waitForAny=function(...) return wait(true,...) end}
local function run(fn)
  local thread=coroutine.create(fn)
  local event=table.pack()
  for _=1,500 do
    local ok,err=coroutine.resume(thread,table.unpack(event,1,event.n))
    assert(ok,err)
    if coroutine.status(thread)=="dead" then return end
    event=table.remove(events,1)
    if not event then
      local id,at
      for key,time in pairs(timers) do if not at or time<at then id,at=key,time end end
      assert(id,"worker stalled without deadline")
      now=at timers[id]=nil event=table.pack("timer",id)
    end
  end
  error("event budget exhausted")
end
local function hang() os.pullEvent("never") end
local addon=require("system.libraries.addon")
local realInventory=addon.inventory
local realPeriodic=addon.periodic
local runners={}
addon.periodic=function(_,name,_,refresh)
  local runner={stop=function() end,rescan=function() end,refresh=refresh}
  runners[name]=runner return runner
end
local errorsLogged=0
package.loaded["system.libraries.log"]={warn=function() end,error=function() errorsLogged=errorsLogged+1 end}
package.loaded["system.security.permissions"]={require=function() return true end}
package.loaded["system.libraries.safe_write"]={write=function() return true end}
textutils={serialize=function() return "saved" end}
local stored={}
package.loaded["system.libraries.config"]={load=function() return addon.copy(stored) end}

local before=now
run(function()
  local values,errors=addon.read({fast=function() return 42 end,slow=hang},{"fast","slow"})
  assert(values.fast==42 and errors.slow:find("uncertain",1,true))
end)
assert(now-before<0.2,"method deadline exceeded")
run(function()
  os.queueEvent("task_complete",42,true,nil,"trailing")
  local ok,name,id,success,value,last=addon.bounded(function() return os.pullEvent("task_complete") end,0.2)
  assert(ok and name=="task_complete" and id==42 and success and value==nil and last=="trailing")
end)

local devices={bad={getHeight=hang},good={getHeight=function() return 200 end}}
local function row(name,kind,device)
  local methods,set={},{}
  for method in pairs(device) do methods[#methods+1]=method set[method]=true end
  return {name=name,types={kind},methods=methods,set=set,device=device}
end
addon.inventory=function() return {row("bad","altitude_sensor",devices.bad),row("good","altitude_sensor",devices.good)} end
local av=require("system.services.avionicsd")
av.start({})
run(function() av.acquire(true) end)
assert(not av.health().ok and av.snapshot().altitude[2].ok)
assert(av.snapshot().measurements.altitude.value==200,"healthy duplicate sensor lost")
local revision=av.health().revision
runners.avionicsd.onError("outer timeout")
assert(av.health().revision==revision+1 and av.health().lastFault=="outer timeout")
devices.bad.getHeight=function() return 199 end
run(function() av.acquire(false) end)
assert(av.health().ok and av.health().lastFault==nil)

sublevel={isInPlotGrid=hang,getLogicalPose=function() return {position={1,2,3}} end,getMass=function() return 100 end,getVelocity=hang}
aero={getGravity=function() return {x=0,y=-10,z=0} end}
local sable=require("system.services.sabled")
sable.start({})
run(function() sable.acquire(true) end)
run(function() sable.acquireDiagnostics() sable.acquire(false) end)
assert(not sable.health().ok and sable.snapshot().aero.gravity.y==-10,"hung sublevel discarded aero")
sublevel.isInPlotGrid=function() return true end
run(function() sable.acquire(false) end)
run(function() sable.acquireDiagnostics() sable.acquire(false) end)
assert(not sable.health().ok and sable.snapshot().sublevel.mass==100,"hung method discarded healthy Sable fields")
sublevel.getVelocity=function() return {1,2,3} end
run(function() sable.acquire(false) end)
assert(sable.health().ok and sable.health().lastFault==nil)

package.loaded["system.services.radarnetd"]={snapshot=function() return {radars={},targets={}} end,configuration=function() return {} end,checkPerimeter=function() end}
stored={radars={}}
devices={bad={getTracks=hang},good={getTracks=function() return {{id="healthy",position={0,0,100},scannedTime=1}} end,getPosition=function() return {0,0,0} end}}
for _,device in pairs(devices) do
  device.getRange=function() return 1000 end
  device.getPosition=function() return {0,0,0} end
end
addon.inventory=function() return {row("bad","create_radar:radar",devices.bad),row("good","create_radar:radar",devices.good)} end
local scheduler={processes={},spawn=function() return 123 end,start=function() end,kill=function() end}
local combat=require("system.services.combatd")
combat.start({scheduler=scheduler})
run(function() combat.acquire(true) end)
assert(not combat.health().ok and #combat.snapshot().targets==1,"hung radar discarded healthy tracks")
revision=combat.health().revision
runners.combatd.onError("outer timeout")
assert(combat.health().revision==revision+1 and combat.health().lastFault=="outer timeout")
local logged=errorsLogged
devices.bad.getTracks=function() return {} end
run(function() combat.acquire(false) end)
assert(combat.health().ok and combat.health().lastFault==nil,"combat fault did not recover")
runners.combatd.onError("outer timeout")
assert(errorsLogged==logged+1,"recovered identical fault suppressed")

-- Rescue continues past an absent endpoint and a suspended output, without retry.
stored={control={sessionActive=true,channels={
  {id="absent",backend="avionics",name="absent",min=0,max=15,neutral=0,rescue=10},
  {id="invalid",backend="redstone",side="bottom",min=0,max=15,neutral=0},
  {id="refused",backend="avionics",name="refused",min=0,max=15,neutral=0,rescue=10},
  {id="hung",backend="avionics",name="hung",min=0,max=15,neutral=0,rescue=11},
  {id="healthy",backend="redstone",side="top",min=0,max=15,neutral=0,rescue=12}},gains={},sensors={}}}
local writes,hungCalls={},0
redstone={setAnalogOutput=function(side,value) writes[side]=value end}
addon.inventory=function() return {
  row("hung","analog_transmission",{setSignal=function() hungCalls=hungCalls+1 hang() end}),
  row("refused","analog_transmission",{setSignal=function() return false end})} end
local flight=require("system.services.flightd")
flight.start({scheduler=scheduler})
run(function() flight.step(true) end)
local status=flight.status()
assert(status.rescueResults.absent.state=="unavailable")
assert(status.rescueResults.invalid.state=="unavailable" and status.rescueResults.refused.state=="refused")
assert(status.rescueResults.hung.state=="uncertain")
assert(status.rescueResults.healthy.state=="confirmed" and writes.top==12,"healthy rescue skipped")
assert(not status.rescuePending and status.reason:find("incomplete",1,true))
run(function() flight.step(false) end)
assert(hungCalls==1,"uncertain output repeated automatically")
assert(not flight.health().ok)

-- Keep the periodic worker raw and independent of application event envelopes.
addon.periodic=realPeriodic
local nativeScheduler=require("system.kernel.scheduler").new()
local bus={on=function() return 1 end,off=function() end}
local received
local worker=addon.periodic({scheduler=nativeScheduler,eventBus=bus},"native safety test",0.1,function()
  received=table.pack(os.pullEvent("task_complete"))
end)
nativeScheduler:dispatch({name="task_complete",args=table.pack(77,true,nil,"last"),raw=table.pack("task_complete",77,true,nil,"last")})
assert(received[1]=="task_complete" and received[2]==77 and received[3] and received[4]==nil and received[5]=="last")
assert(nativeScheduler.processes[worker.pid].meta.eventMode=="raw")
assert(worker.lastSuccess==now and worker.error==nil)
worker:stop()
local failed=true
local recovering=addon.periodic({scheduler=nativeScheduler,eventBus=bus},"recovering safety test",0.1,function()
  if failed then error("sample failure") end
end)
assert(recovering.error and not recovering.lastSuccess)
failed=false
nativeScheduler:dispatch({name="timer",args=table.pack(recovering.timer),raw=table.pack("timer",recovering.timer)})
assert(recovering.error==nil and recovering.lastSuccess==now,"runner fault did not recover")
recovering:stop()
-- A large healthy batch is not implicitly cancelled at half a second.
local callbacks, scans = {}, 0
addon.inventory=realInventory
peripheral={getNames=function() scans=scans+1 return {} end}
addon.invalidateInventory()
addon.inventory()
local cycleCount=0
local hotBus={on=function(_,event,callback) callbacks[event]=callback return event end,off=function() end}
local large=addon.periodic({scheduler=nativeScheduler,eventBus=hotBus},"large batch",0.2,function(dirty)
  cycleCount=cycleCount+1
  if dirty then addon.inventory() end
  os.pullEvent("task_complete")
end)
assert(scans==1)
callbacks.peripheral_detach()
addon.inventory()
assert(scans==2,"hotplug did not invalidate shared inventory")
large:rescan()
addon.inventory()
assert(scans==3,"explicit rescan did not invalidate shared inventory")
now=now+0.6
nativeScheduler:dispatch({name="task_complete",args=table.pack(99,true),raw=table.pack("task_complete",99,true)})
assert(large.lastSuccess==now and large.dirty and cycleCount==1,"rescan lost or refresh stacked")
assert(large:metrics().overruns==1 and large:metrics().seconds>0.59)
large:stop()
local partial=0
local budgetCtx={scheduler=nativeScheduler,eventBus=bus}
local budgeted=addon.periodic(budgetCtx,"budgeted",0.1,function() hang() end,
  {budget=0.3,onPartial=function(err) assert(err:find("uncertain",1,true)) partial=partial+1 end})
local deadline=serial
assert(budgetCtx.workerTimers[deadline],"bounded deadline not marked internal")
now=now+0.3
nativeScheduler:dispatch({name="timer",args=table.pack(deadline),raw=table.pack("timer",deadline)})
assert(partial==1 and budgeted.error and budgeted:metrics().overruns==1)
assert(not budgetCtx.workerTimers[deadline],"expired deadline retained internal flag")
budgeted:stop()
assert(next(budgetCtx.workerTimers)==nil)
-- Direct scheduler kill must close inherited scopes without runner:stop().
addon.configure({concurrency=1,readsPerTick=1000})
local flightBefore=addon.metrics().readsByPriority.flight or 0
local killCtx={scheduler=nativeScheduler,eventBus=bus}
local killed=addon.periodic(killCtx,"killed acquisition",0.1,function()
  addon.read({a=hang,b=hang},{"a","b"},10)
end,{priority="flight"})
assert(addon.metrics().inFlight==1 and addon.metrics().queue==1)
assert(addon.metrics().readsByPriority.flight==flightBefore+1,"runner priority not inherited")
assert(next(killCtx.workerTimers),"read deadline not marked internal")
nativeScheduler:kill(killed.pid,true)
assert(killed.stopped and addon.metrics().inFlight==0 and addon.metrics().queue==0,"scheduler kill leaked leases")
assert(next(killCtx.workerTimers)==nil,"scheduler kill leaked timer flags")
run(function()
  local values=addon.read({fast=function() return 7 end},{"fast"})
  assert(values.fast==7,"dead process retained admission permit")
end)
addon.configure({concurrency=1,readsPerTick=1})
now=now+0.1
local pacedCtx={scheduler=nativeScheduler,eventBus=bus}
local paced=addon.periodic(pacedCtx,"paced acquisition",0.2,function()
  addon.read({fast=function() return 1 end},{"fast"})
  addon.read({fast=function() return 2 end},{"fast"})
end)
local pacingTimer=serial
assert(pacedCtx.workerTimers[pacingTimer],"pacing timer not marked internal")
now=now+0.06
nativeScheduler:dispatch({name="timer",args=table.pack(pacingTimer),raw=table.pack("timer",pacingTimer)})
assert(not pacedCtx.workerTimers[pacingTimer] and paced.lastSuccess==now,"pacing flag retained after expiry")
assert(addon.metrics().runners["paced acquisition"].reads==2)
nativeScheduler:kill(paced.pid,true)
assert(next(pacedCtx.workerTimers)==nil and not addon.metrics().runners["paced acquisition"])
-- An ordinary refresh exception cancels siblings without killing the runner.
addon.configure({concurrency=1,readsPerTick=1000})
local recoveryCtx={scheduler=nativeScheduler,eventBus=bus}
local attempts,healthy=0,0
local branchRecovery=addon.periodic(recoveryCtx,"branch recovery",0.1,function()
  attempts=attempts+1
  if attempts==1 then
    addon.parallel({function() addon.read({hang=hang},{"hang","hang"},10) end,
      function() error("bad sensor shape") end},2)
  else
    local values=addon.read({good=function() return 7 end},{"good"})
    assert(values.good==7)
    healthy=healthy+1
  end
end)
assert(branchRecovery.error and branchRecovery.error:find("bad sensor shape",1,true))
assert(addon.metrics().inFlight==0 and addon.metrics().queue==0,"failed cycle leaked reads")
for _=1,100 do
  local id,at
  for key,time in pairs(timers) do if not at or time<at then id,at=key,time end end
  assert(id,"recovery worker lost its timer")
  now=at timers[id]=nil
  nativeScheduler:dispatch({name="timer",args=table.pack(id),raw=table.pack("timer",id)})
end
assert(healthy==100 and attempts==101 and branchRecovery.lastSuccess==now and not branchRecovery.error,
  "branch failure prevented subsequent acquisition cycles")
assert(addon.metrics().inFlight==0 and addon.metrics().queue==0)
for id in pairs(recoveryCtx.workerTimers) do assert(id==branchRecovery.timer,"abandoned cycle timer survived") end
branchRecovery:stop()
assert(next(recoveryCtx.workerTimers)==nil)
-- Closing a failed cycle must not cancel another periodic worker's deadline.
addon.configure({concurrency=2,readsPerTick=1000})
local sharedCtx={scheduler=nativeScheduler,eventBus=bus}
local receivedValue
local unaffected=addon.periodic(sharedCtx,"unaffected acquisition",0.1,function()
  local values=addon.read({wait=function()
    local _,_,_,value=os.pullEvent("task_complete")
    return value
  end},{"wait"},10)
  receivedValue=values.wait
end)
local isolated=addon.periodic(sharedCtx,"isolated failure",0.1,function()
  addon.parallel({function() addon.read({hang=hang},{"hang","hang"},10) end,
    function() error("isolated branch failure") end},2)
end)
assert(isolated.error and addon.metrics().inFlight==1 and addon.metrics().queue==0)
isolated:stop()
assert(next(sharedCtx.workerTimers),"failed worker cancelled unrelated deadline")
nativeScheduler:dispatch({name="task_complete",args=table.pack(88,true,42),raw=table.pack("task_complete",88,true,42)})
assert(receivedValue==42 and unaffected.lastSuccess==now and not unaffected.error)
assert(addon.metrics().inFlight==0 and addon.metrics().queue==0)
unaffected:stop()
assert(next(sharedCtx.workerTimers)==nil)
-- Hung diagnostics must not occupy the next fast acquisition cycle.
addon.configure({concurrency=4,readsPerTick=1000})
local slowRows={}
for i=1,20 do
  slowRows[#slowRows+1]=row(string.format("00analog%02d",i),"analog_transmission",
    {getSignal=hang,getOutputSpeed=hang,isExternallyControlled=hang})
end
slowRows[#slowRows+1]=row("gimbal","gimbal_sensor",{getAngles=function() return {3,4} end,
  getAngularRates=function() return {1,2,3} end,getGravity=function() return {0,-9,0} end})
slowRows[#slowRows+1]=row("altitude","altitude_sensor",{getHeight=function() return 200 end,getVerticalSpeed=function() return 0 end})
slowRows[#slowRows+1]=row("nav","navigation_table",{getHeading=function() return 90 end})
addon.inventory=function() return slowRows end
sublevel={isInPlotGrid=function() return true end,getLogicalPose=function() return {position={1,2,3}} end,
  getMass=hang,getInverseMass=hang,getCenterOfMass=hang,getInertiaTensor=hang,getInverseInertiaTensor=hang}
aero={getGravity=hang,getMagneticNorth=hang,getAirPressure=hang}
local isolatedCtx={scheduler=nativeScheduler,eventBus=bus}
av.start(isolatedCtx) sable.start(isolatedCtx)
local initialRevision=av.snapshot().revision
local started=now
local samples=0
for _=1,5000 do
  local event=table.remove(events,1)
  if not event then
    local id,at
    for key,time in pairs(timers) do if not at or time<at then id,at=key,time end end
    assert(id,"independent workers lost timers")
    now=at timers[id]=nil event=table.pack("timer",id)
  end
  local args={n=event.n-1}
  for i=2,event.n do args[i-1]=event[i] end
  nativeScheduler:dispatch({name=event[1],args=args,raw=event})
  if now-started>=0.3 then
    local sample=av.flightTelemetry({gimbal="gimbal",altitude="altitude",nav="nav"})
    assert(sample.pitch==3 and now-sample.timestamp<=0.5,"hung diagnostics starved flight sensors")
    assert(sable.flightStatus().inSublevel and now-sable.pose().timestamp<=0.5,"hung Sable diagnostics starved pose")
    samples=samples+1
  end
  if now-started>=2 then break end
end
assert(now-started>=2 and samples>5 and av.snapshot().revision>initialRevision+5)
assert(addon.metrics().runners["avionicsd-diagnostics"] and addon.metrics().runners["sabled-diagnostics"])
av.stop() sable.stop()
assert(next(isolatedCtx.workerTimers)==nil,"diagnostic worker timers leaked at stop")
assert(addon.metrics().inFlight==0 and addon.metrics().queue==0,"diagnostic read leases leaked at stop")
assert(not addon.metrics().runners.avionicsd and not addon.metrics().runners["avionicsd-diagnostics"])
assert(not addon.metrics().runners.sabled and not addon.metrics().runners["sabled-diagnostics"])
print("bounded sensor isolation, health revisions/recovery, partial rescue and raw-worker regressions passed")
