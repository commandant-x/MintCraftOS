package.path="./?.lua;"..package.path
package.loaded["system.libraries.log"]={info=function() end,warn=function() end,error=function() end}
package.loaded["system.libraries.profile"]={serviceEnabled=function() return true end}
local allowed={}
package.loaded["system.security.permissions"]={require=function(actor,permission)
  assert(permission=="services.control") return allowed[actor.pid]==true,"Permission denied"
end}
os.epoch=function() return 0 end
os.pullEvent=function(filter) return coroutine.yield(filter) end
local events={}
os.queueEvent=function(name,...) events[#events+1]={name=name,args=table.pack(...)} end
local scheduler=require("system.kernel.scheduler").new()
local manager=require("system.services.service_manager").new({scheduler=scheduler})
local function owner()
  local pid=scheduler:spawn("Services",function() while true do coroutine.yield() end end,{appId="services",permissions={"services.control"}})
  scheduler:start(pid) allowed[pid]=true return pid
end
local function wake(name,...) scheduler:dispatch({name=name,args=table.pack(...),raw=table.pack(name,...)}) end
local first,second=owner(),owner()
local starts,stops=0,0 local suspendStart,suspendStop,refuseStop,throwStop=false,false,false,false
package.loaded["tests.fixture-service"]={start=function()
  starts=starts+1 if suspendStart then os.pullEvent("task_complete") end return true
end,stop=function()
  stops=stops+1 if suspendStop then os.pullEvent("task_complete") end
  if throwStop then error("fixture stop failure") end
  if refuseStop then return false,"Rescue pending" end return true
end,status=function() return {ok=true} end}
manager:register("safe","tests.fixture-service",true)
manager:register("other","tests.fixture-service",false)
manager:register("securityd","tests.fixture-service",true)
assert(manager:start("safe")) assert(starts==1)
assert(not manager:start(nil) and not manager:stop("absent"))
assert(not manager:requestAction({pid=first},"stop","securityd"))
assert(not manager:requestAction({pid=first},"erase","safe"))
local transient=owner()
assert(manager:requestAction({pid=transient},"stop","safe"))
assert(scheduler:kill(transient)) wake("mintcraft_service_action")
assert(stops==0 and not manager:controlStatus().ok,"closed queued owner still mutated service")
local closing=owner() local window={closed=false}
scheduler:attachWindow(closing,window)
assert(manager:requestAction({pid=closing},"stop","safe")) window.closed=true wake("mintcraft_service_action")
assert(stops==0 and not manager:controlStatus().ok,"closed window executed queued action before process retired")
assert(manager:requestAction({pid=first},"stop","safe"))
allowed[first]=false wake("mintcraft_service_action")
assert(stops==0 and manager:controlStatus().ok==false,"queued permission revoked but action executed")
allowed[first]=true suspendStop=true
assert(manager:requestAction({pid=first},"restart","safe")) wake("mintcraft_service_action")
assert(manager:controlStatus().busy and stops==1)
assert(not manager:requestAction({pid=second},"restart","safe"),"second UI interleaved a transition")
assert(not manager:requestAction({pid=second},"start","other"),"different-service request bypassed global serialization")
assert(not manager:start("safe"),"internal launch bypassed transition lock")
local worker=manager:controlStatus().pid
assert(scheduler:kill(first)) wake("task_complete",10,true)
assert(starts==1 and not manager.services.safe.started,"closed owner restarted service after yielded stop")
assert(scheduler.processes[worker].state=="ready" and not manager:controlStatus().busy,"owner cleanup abandoned transition worker")
suspendStop=false suspendStart=true
assert(manager:requestAction({pid=second},"start","safe")) wake("mintcraft_service_action")
assert(starts==2 and manager:controlStatus().busy)
assert(not manager:stop("safe"),"internal stop overlapped yielded start")
assert(scheduler:kill(second)) wake("task_complete",11,true)
assert(manager.services.safe.started and manager:controlStatus().ok,"in-flight start abandoned when owner closed")
local third=owner() suspendStart=false refuseStop=true
assert(manager:requestAction({pid=third},"restart","safe")) wake("mintcraft_service_action")
assert(starts==2 and stops==2 and manager.services.safe.started and not manager:controlStatus().ok,"refused rescue stop proceeded to start")
refuseStop=false suspendStop=true
assert(manager:requestAction({pid=third},"restart","safe")) wake("mintcraft_service_action")
allowed[third]=false wake("task_complete",12,true)
assert(starts==2 and not manager.services.safe.started,"permission revoked during stop but restart proceeded")
allowed[third]=true suspendStop=false
assert(manager:start("safe"))
throwStop=true
assert(manager:requestAction({pid=third},"stop","safe")) wake("mintcraft_service_action")
assert(not manager:controlStatus().ok and not manager:controlStatus().busy and not manager.transitions.safe,"failed transition kept stale lock or retried")
assert(not manager:start("safe"),"uncertain failed stop was treated as an idempotent successful start")
throwStop=false suspendStop=true
assert(manager:requestAction({pid=third},"stop","safe")) wake("mintcraft_service_action")
assert(scheduler:kill(worker,true))
assert(manager:controlStatus().phase=="uncertain" and not manager:requestAction({pid=third},"start","safe"),"uncertain worker loss automatically retried")
assert(#events>0)
local failedStarts,cleanups=0,0
package.loaded["tests.failed-start"]={start=function() failedStarts=failedStarts+1 error("partial start") end,stop=function() cleanups=cleanups+1 return false,"cleanup pending" end}
manager:register("broken","tests.failed-start",false)
assert(not manager:start("broken") and manager.services.broken.uncertain)
assert(not manager:start("broken") and failedStarts==1 and cleanups==1,"failed startup retried while cleanup uncertain")
package.loaded["tests.failed-start"].stop=function() return true end
assert(manager:stop("broken") and not manager.services.broken.uncertain)
print("service control: permissions, global serialization, protected services, yielding transitions, owner loss, rescue refusal and uncertain state passed")
