local M={}
-- Authentication must release its shared mutex before its coroutine is retired.
function M.new(ctx,perform,finished)
  local scheduler=assert(ctx.system and ctx.system.scheduler,"Authentication scheduler unavailable")
  local closed,busy,current=false,false,nil
  ctx.onCleanup(function() closed=true if current then current.cancelled=true end end)
  local worker={}
  function worker:submit(request)
    if closed or busy then return false,closed and "App closed" or "Authentication already running" end
    busy=true current={cancelled=false}
    local operation=current
    local options={cancelled=function() return closed or operation.cancelled end,
      progress=function() if not closed and ctx.invalidate then ctx.invalidate() end end}
    local pid=scheduler:spawn("Authentication",function()
      local result=table.pack(pcall(perform,request,options))
      request=nil busy=false current=nil
      if not closed then
        finished(table.unpack(result,1,result.n))
        if ctx.invalidate then ctx.invalidate() end
        os.queueEvent("mintcraft_app_result",ctx.pid)
      end
    end,{eventMode="raw",appId=ctx.appId,permissions=ctx.permissions,protected=true})
    local ok,err=scheduler:start(pid)
    if not ok then busy=false current=nil return false,err end
    return true
  end
  function worker:cancel() if current then current.cancelled=true end end
  return worker
end
return M
