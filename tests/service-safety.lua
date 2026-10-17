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
assert(not sable.health().ok and sable.snapshot().aero.gravity.y==-10,"hung sublevel discarded aero")
sublevel.isInPlotGrid=function() return true end
run(function() sable.acquire(false) end)
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
print("bounded sensor isolation, health revisions/recovery, partial rescue and raw-worker regressions passed")
