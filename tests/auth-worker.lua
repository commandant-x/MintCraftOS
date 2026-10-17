package.path="./?.lua;"..package.path
package.loaded["system.libraries.log"]={warn=function() end,error=function() end}
package.loaded["system.security.permissions"]={}
os.epoch=function() return 0 end
os.queueEvent=function() end
local scheduler=require("system.kernel.scheduler").new()
local owner=scheduler:spawn("Terminal",function() while true do coroutine.yield() end end,{appId="terminal"})
scheduler:start(owner)
local ctx=scheduler:makeContext(owner)
ctx.system={scheduler=scheduler} ctx.appId="terminal" ctx.permissions={}
local committed,finished,released=false,false,false
local worker=require("system.libraries.auth_worker").new(ctx,function(_,options)
  local ok=pcall(function()
    coroutine.yield("timer")
    if options.cancelled() then error("cancelled") end
    committed=true
  end)
  released=true
  return ok
end,function() finished=true end)
assert(worker:submit("secret"))
assert(not released and not committed,"authentication did not yield")
assert(scheduler:kill(owner))
scheduler:dispatch({name="timer",args={1}})
assert(released and not committed and not finished,"closed app killed auth cleanup or committed stale auth")
print("native auth worker yields and releases mutex before retiring after owner close")
