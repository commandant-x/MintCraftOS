local addon=require("system.libraries.addon")
local M={}
function M.new(ctx,name,perform,finished,timeout)
  local scheduler=assert(ctx.system and ctx.system.scheduler,"App worker requires scheduler")
  local queue={} local stopped=false local running=false local pid
  local worker={}
  pid=scheduler:spawn(name,function()
    while not stopped do
      while #queue>0 and not stopped do
        local request=table.remove(queue,1) running=true
        local result
        if timeout then result=table.pack(addon.bounded(function() return perform(request) end,timeout))
        else result=table.pack(pcall(perform,request)) end
        running=false
        if not stopped then
          finished(request,table.unpack(result,1,result.n))
          if ctx.invalidate then ctx.invalidate() end
          os.queueEvent("mintcraft_app_result",ctx.pid)
        end
      end
      os.pullEvent("mintcraft_app_work")
    end
  end,{eventMode="raw",appId=ctx.appId,permissions=ctx.permissions,protected=true})
  function worker:submit(request)
    if stopped then return false,"App closed" end
    if #queue>=4 then return false,"Request queue full" end
    queue[#queue+1]=request os.queueEvent("mintcraft_app_work",pid) return true
  end
  function worker:busy() return running or #queue>0 end
  ctx.onCleanup(function() stopped=true queue={} scheduler:kill(pid,true) end)
  scheduler:start(pid)
  return worker
end
return M
