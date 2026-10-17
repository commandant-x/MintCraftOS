package.path="./?.lua;"..package.path
package.loaded["system.libraries.log"]={error=function() error("disk full") end,warn=function() error("disk full") end}
package.loaded["system.security.permissions"]={require=function(actor,permission)
  for _,value in ipairs(actor.permissions) do if value==permission then return true end end
  return false,"permission denied"
end}
local time,serial=0,0
os.epoch=function() return time end
os.startTimer=function() serial=serial+1 return serial end
os.cancelTimer=function() end
local scheduler=require("system.kernel.scheduler").new()
scheduler.ctx={notifications={push=function() error("notification failed") end}}
local cleaned=false
local pid=scheduler:spawn("crash",function() error("original failure") end)
local win={id=1}
scheduler:attachWindow(pid,win)
scheduler:makeContext(pid).onCleanup(function() cleaned=true end)
local ok,err=scheduler:start(pid)
assert(not ok and err:find("original failure",1,true) and cleaned and win.closed)
assert(not scheduler.processes[pid].co and not scheduler.processes[pid].cleanup)
for i=1,200 do local id=scheduler:spawn("finished",function() end) scheduler:start(id) end
local count=0 for _,process in pairs(scheduler.processes) do count=count+1 assert(not process.co and not process.window) end
assert(count<=64 and #scheduler.history<=64)
local owner=scheduler:spawn("owner",function() while true do coroutine.yield() end end,{permissions={}})
scheduler:start(owner)
local context=scheduler:makeContext(owner)
assert(not context.kill(owner) and #context.listProcesses()==0)
local view={id=2,dirty=false}
scheduler:attachWindow(owner,view)
local timer=context.startTimer(0.05)
scheduler:dispatch({name="timer",args={timer}})
assert(view.dirty and scheduler.timerOwners[timer]==nil)
assert(scheduler:kill(owner))
assert(scheduler.processes[owner].resumes>=2 and scheduler.processes[owner].runtimeMs==0)
print("disk-full crash cleanup, bounded process records, timer ownership and kill permissions passed")
