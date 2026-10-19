local permissions=require("system.security.permissions")
local log=require("system.libraries.log")
local M={}
function M.new(manager)
  local scheduler=assert(manager.ctx.scheduler,"Service control requires scheduler")
  local self={serial=0,busy=false}
  local pending,pid
  local function authorize(owner)
    local process=scheduler.processes[owner]
    if not process or process.state~="ready" then return false,"Owner not running" end
    local attached,open=false,false
    for _,win in ipairs(process.windows or {}) do attached=true if not win.closed then open=true break end end
    if attached and not open then return false,"Owner windows closed" end
    if type(permissions.require)~="function" then return false,"Permission service unavailable" end
    return permissions.require({pid=owner,appId=process.meta and process.meta.appId,permissions=process.permissions or {}},"services.control")
  end
  local function perform(request)
    local ok,err=authorize(request.owner)
    if not ok then return false,err end
    if manager:isProtected(request.name) and request.action~="start" then return false,"Protected service" end
    if request.action=="start" then return manager:start(request.name) end
    local stopped,reason=manager:stop(request.name)
    if not stopped then return false,reason or "Stop refused" end
    if request.action=="stop" then return true,"Stopped" end
    local authorized,denied=authorize(request.owner)
    if not authorized then return false,"Restart stopped before start: "..tostring(denied).."; service remains stopped" end
    return manager:start(request.name)
  end
  local function ensureWorker()
    if pid and scheduler.processes[pid] and scheduler.processes[pid].state=="ready" then return end
    pid=scheduler:spawn("Service operations",function()
      while true do
        if pending then
          local request=pending pending=nil
          self.phase="running"
          local ran,ok,message=pcall(function()
            return manager:withTransition(request.name,function() return perform(request) end)
          end)
          if not ran then message="Transition failed; inspect service before retry: "..tostring(ok) ok=false end
          self.busy=false self.phase="finished" self.ok=ok==true
          self.message=tostring(message or (ok and "Completed" or "Refused"))
          pcall(ok and log.info or log.warn,"service-control",request.action.." "..request.name..": "..self.message)
          os.queueEvent("mintcraft_service_result",request.owner,request.id,self.ok,self.message)
        end
        os.pullEvent("mintcraft_service_action")
      end
    end,{eventMode="raw",appId="service-control",permissions={},protected=true})
    assert(scheduler:start(pid))
  end
  function self:request(actor,action,name)
    if action~="start" and action~="stop" and action~="restart" then return false,"Invalid service action" end
    if type(name)~="string" or not manager.services[name] then return false,"No such service" end
    if self.busy then return false,"Service transition already running" end
    local ok,err=authorize(actor and actor.pid)
    if not ok then return false,err end
    if manager:isProtected(name) and action~="start" then return false,"Protected service" end
    ensureWorker()
    self.serial=self.serial+1
    pending={id=self.serial,owner=actor.pid,action=action,name=name}
    self.busy=true self.phase="queued" self.name=name self.action=action self.owner=actor.pid self.message="Queued" self.ok=nil
    os.queueEvent("mintcraft_service_action",pid)
    return true,self.serial
  end
  function self:status()
    local worker=pid and scheduler.processes[pid]
    if self.busy and (not worker or worker.state~="ready") then
      return {busy=true,phase="uncertain",name=self.name,action=self.action,owner=self.owner,id=self.serial,
        message="Service worker stopped; transition may be partial. Inspect before recovery.",ok=false,pid=pid}
    end
    return {busy=self.busy,phase=self.phase,name=self.name,action=self.action,owner=self.owner,id=self.serial,message=self.message,ok=self.ok,pid=pid}
  end
  return self
end
return M
