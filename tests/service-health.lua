package.path="./?.lua;"..package.path
package.loaded["system.libraries.log"]={info=function() end,error=function() end}
package.loaded["system.libraries.profile"]={serviceEnabled=function() return true end}
peripheral=setmetatable({},{__index=function() error("health must not acquire peripherals") end})
local snap={state="running",pid=7,lastSuccess=12}
local queryError=false
package.preload["test.health"]=function() return {
  start=function() end,
  health=function() if queryError then error("snapshot error") end return snap end,
  status=function() error("health must take precedence over status") end,
  stop=function() return false,"rescue pending" end,
} end
package.preload["test.scalar"]=function() return {status="ready"} end
local ctx={scheduler={processes={[7]={state="ready"}}}}
local manager=require("system.services.service_manager").new(ctx)
manager:register("worker","test.health",true)
manager:register("scalar","test.scalar",true)
manager:startAutostart()
local function row() return manager:list()[2] end
assert(row().state=="running" and row().lastSuccess==12)
snap.error="timeout" assert(row().state=="degraded" and row().error=="timeout")
snap.error=nil snap.lastSuccess=13 assert(row().state=="running" and row().lastSuccess==13)
snap.ok=false snap.lastFault="acquisition failed"
assert(row().state=="degraded" and row().error=="acquisition failed")
snap.ok=true snap.lastFault=nil
ctx.scheduler.processes[7]={state="crashed",error="worker crash"}
assert(row().state=="crashed" and row().error=="worker crash")
assert(manager:start("worker"),"must not duplicate still-owned worker")
ctx.scheduler.processes[7]=nil assert(row().state=="crashed")
ctx.scheduler.processes[7]={state="ready"}
queryError=true assert(row().state=="degraded") queryError=false
assert(not manager:stop("worker")) assert(manager.services.worker.started)
assert(manager:list()[1].state=="running","scalar status must not be called")
manager.services.worker.module.stop=function() return true end
assert(manager:stop("worker"))
assert(row().state=="stopped" and row().lastSuccess==13,"stop lost last success")
manager.services.worker.module.health=nil
manager.services.worker.module.status=function() return {ok=false,lastFault="cached status fault"} end
assert(manager:start("worker"))
assert(row().state=="degraded" and row().error=="cached status fault")
manager.services.scalar.module.start=function()
  ctx.scheduler.processes[8]={name="scalar",meta={appId="scalar"},state="ready"}
end
assert(manager:stop("scalar")) assert(manager:start("scalar"))
assert(manager:list()[1].pid==8)
ctx.scheduler.processes[8]=nil
assert(manager:list()[1].state=="crashed","pruned worker falsely running")
print("service health: cached queries, degraded recovery, worker crash, last success and scalar status passed")
