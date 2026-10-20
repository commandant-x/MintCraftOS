local permissions=require("system.security.permissions")
local security=require("system.services.securityd")
local log=require("system.libraries.log")
local M={}
local function copy(value)
  if type(value)~="table" then return value end
  local result={} for k,v in pairs(value) do result[k]=copy(v) end return result
end
function M.new(ctx,service)
  local scheduler=assert(ctx.scheduler,"Update requires scheduler")
  local self={serial=0,busy=false,phase="idle",message="Ready"}
  local pending,pid
  local tokens,tokenSerial={},0
  local function identity(owner)
    local process=scheduler.processes[owner]
    if not process or process.state~="ready" then return nil,"UPD-OWNER: caller stopped" end
    local attached,open=false,false
    for _,win in ipairs(process.windows or {}) do attached=true if not win.closed then open=true end end
    if attached and not open then return nil,"UPD-OWNER: window closed" end
    return process
  end
  local function authorize(request)
    if request.committed then return true end
    local process,err=identity(request.owner)
    if not process then return false,err end
    if request.process and request.process~=process then return false,"UPD-OWNER: caller replaced" end
    if request.session~=security.sessionRevision() then return false,"UPD-AUTH: session changed" end
    local user=security.currentUser()
    if not user or user.name~=request.user then return false,"UPD-AUTH: user changed" end
    return permissions.require({pid=process.pid,appId=process.meta and process.meta.appId,permissions=process.permissions},
      request.action=="check" and "network.http" or "system.update")
  end
  local function capture(actor,action)
    local process,err=identity(actor and actor.pid)
    if not process then return nil,err end
    local user=security.currentUser()
    local request={owner=process.pid,process=process,user=user and user.name,session=security.sessionRevision(),action=action}
    local ok,why=authorize(request)
    if not ok then return nil,why end
    return request
  end
  function self:prepare(actor,action)
    if action~="apply" and action~="rollback" then return false,"UPD-ACTION: invalid confirmation" end
    if self.busy then return false,"UPD-BUSY: operation running" end
    local request,err=capture(actor,action) if not request then return false,err end
    request.localVersion=service.localVersion()
    if action=="apply" then
      local status,cfg=service.status,service.loadConfig()
      if not status.ok or not status.updateAvailable or not status.source then return false,"UPD-SOURCE: run Check first" end
      if status.source.repo~=cfg.repo or status.source.ref~=cfg.branch then return false,"UPD-STALE: source changed; check again" end
      request.source=copy(status.source) request.version=status.remoteVersion
    else
      local backup=service.rollbackInfo()
      if not backup then return false,"UPD-BACKUP: no checkpoint" end
      request.backupId=backup.id request.version=backup.fromVersion
    end
    for id,token in pairs(tokens) do if token.expires<os.clock() or token.owner==request.owner then tokens[id]=nil end end
    local count=0 for _ in pairs(tokens) do count=count+1 end
    if count>=8 then return false,"UPD-BUSY: confirmation limit" end
    tokenSerial=tokenSerial+1 request.token=tokenSerial request.expires=os.clock()+30
    tokens[tokenSerial]=request
    return true,{token=tokenSerial,action=action,version=request.version,localVersion=request.localVersion,
      source=copy(request.source),backupId=request.backupId,expires=request.expires}
  end
  local function ensureWorker()
    if pid and scheduler.processes[pid] and scheduler.processes[pid].state=="ready" then return end
    pid=scheduler:spawn("Update transaction",function()
      while true do
        if pending then
          local request=pending pending=nil self.phase="running"
          local ran,ok,message=pcall(function()
            local allowed,err=authorize(request) if not allowed then return false,err end
            local options=copy({source=request.source,version=request.version,localVersion=request.localVersion,backupId=request.backupId})
            options.authorize=function() return authorize(request) end
            options.commit=function() request.committed=true self.committed=true end
            options.progress=function(phase,message,done,total)
              self.phase=phase self.message=tostring(message or ""):sub(1,8192) self.done=done self.total=total
            end
            if request.action=="check" then
              local result=service.check(options) return result.ok,result.message
            end
            return service[request.action](options)
          end)
          if not ran then message="UPD-FAILED: "..tostring(ok) ok=false end
          self.busy=false self.phase="finished" self.ok=ok==true
          self.message=tostring(message or (ok and "Completed" or "Refused")):sub(1,8192)
          pcall(ok and log.info or log.error,"update",request.action.." #"..request.id..": "..self.message)
          if ctx.notifications then pcall(ctx.notifications.push,ctx.notifications,ok and "success" or "error","Update",self.message,6) end
          os.queueEvent("mintcraft_update_result",request.owner,request.id,self.ok,self.message)
        end
        os.pullEvent("mintcraft_update_action")
      end
    end,{eventMode="raw",appId="update-control",permissions={},protected=true})
    assert(scheduler:start(pid))
  end
  function self:request(actor,action,tokenId)
    if action~="check" and action~="apply" and action~="rollback" then return false,"UPD-ACTION: invalid action" end
    if self.busy then return false,"UPD-BUSY: operation running" end
    local request,err
    if action=="check" then request,err=capture(actor,action)
    else
      request=tokenId and tokens[tokenId] if tokenId then tokens[tokenId]=nil end
      if not request or request.owner~=(actor and actor.pid) or request.action~=action or request.expires<os.clock() then
        return false,"UPD-STALE: confirmation missing or expired"
      end
      local ok,why=authorize(request) if not ok then return false,why end
      if service.localVersion()~=request.localVersion then return false,"UPD-STALE: installed version changed" end
      if action=="apply" then
        local cfg=service.loadConfig()
        if cfg.repo~=request.source.repo or cfg.branch~=request.source.ref then return false,"UPD-STALE: source changed" end
      else
        local info=service.rollbackInfo()
        if not info or info.id~=request.backupId then return false,"UPD-STALE: checkpoint changed" end
      end
    end
    if not request then return false,err end
    ensureWorker() self.serial=self.serial+1 request.id=self.serial pending=request
    self.busy=true self.phase="queued" self.action=action self.owner=request.owner self.message="Queued"
    self.ok=nil self.done=nil self.total=nil self.committed=false
    os.queueEvent("mintcraft_update_action",pid)
    return true,self.serial
  end
  function self:status()
    local worker=pid and scheduler.processes[pid]
    local lost=self.busy and (not worker or worker.state~="ready")
    return {id=self.serial,busy=self.busy,phase=lost and "uncertain" or self.phase,action=self.action,owner=self.owner,
      ok=lost and false or self.ok,message=lost and "UPD-RECOVERY: worker stopped; inspect recovery journals before reboot" or self.message,
      committed=self.committed,done=self.done,total=self.total,pid=pid}
  end
  function self:stop()
    if self.busy then return false,"Update transaction running" end
    tokens={} pending=nil
    if pid and scheduler.processes[pid] and scheduler.processes[pid].state=="ready" then scheduler:kill(pid,true) end
    pid=nil return true
  end
  return self
end
return M
