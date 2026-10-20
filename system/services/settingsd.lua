local permissions=require('system.security.permissions')
local security=require('system.services.securityd')
local config=require('system.libraries.config')
local profile=require('system.libraries.profile')
local log=require('system.libraries.log')
local M={}
local ctx,pid,pending
local state={busy=false,phase='idle',serial=0,message='Ready'}
local function classify(id)
  if id=='lock' or id=='guest' then return 'system.auth' end
  if id=='cleanupConfirm' then return 'system.storage.manage' end
  if id=='audio' or id=='test' or id:match('^volume:') or id:match('^speaker:') then return 'audio.control' end
  if id=='label' or id=='refresh' or id:match('^display:') or id:match('^scale:') or id:match('^theme:')
    or id:match('^profile:') or id:match('^app:') or id=='graphics:auto' or id=='graphics:pixel16' or id=='graphics:text' then return 'system.config' end
end
local function authorize(request)
  local process=ctx and ctx.scheduler.processes[request.owner]
  if not process or process.state~='ready' or process~=request.process then return false,'SET-OWNER: caller stopped/replaced' end
  if security.sessionRevision()~=request.session then return false,'SET-AUTH: session changed' end
  local attached,open=false,false
  for _,win in ipairs(process.windows or {}) do attached=true if not win.closed then open=true end end
  if attached and not open then return false,'SET-OWNER: caller windows closed' end
  return permissions.require({pid=process.pid,appId=process.meta and process.meta.appId,permissions=process.permissions},request.permission)
end
local function perform(request)
  local id,value=request.action,request.value
  if id=='cleanupConfirm' then
    if value~=true then return false,'SET-CONFIRM: cleanup confirmation required' end
    return require('system.services.updated').cleanup('updates',{confirm=true})
  elseif id=='lock' then return security.lock()
  elseif id=='guest' then return security.logout()
  elseif id=='label' then
    if type(value)~='string' or #value>1024 then return false,'Invalid label' end
    os.setComputerLabel(value) return true,'Computer label saved'
  elseif id=='refresh' then
    require('system.services.deviced').refreshDisplay() return true,'Display discovery refreshed; inspect active target'
  elseif id=='graphics:auto' or id=='graphics:pixel16' or id=='graphics:text' then
    local cfg=config.load('/system/config/system.cfg',{})
    cfg.safeMode=id=='graphics:text' cfg.graphicsMode=id:sub(10)
    local ok,err=config.save('/system/config/system.cfg',cfg) if not ok then return false,err end
    ctx.setGraphicsMode(cfg.graphicsMode)
    return true,cfg.safeMode and 'Text rescue requested' or 'Pixel retry requested; unsupported outputs retain text fallback'
  elseif id:sub(1,8)=='display:' then return require('system.services.deviced').setTarget(id:sub(9))
  elseif id:sub(1,6)=='scale:' then
    local scale=tonumber(id:sub(7))
    if not scale or scale<0.5 or scale>5 or scale*2%1~=0 then return false,'Invalid monitor text scale' end
    return require('system.services.deviced').setScale(scale)
  elseif id:sub(1,6)=='theme:' then
    local theme=id:sub(7) if theme~='mint' and theme~='dark' then return false,'Invalid theme' end
    return require('system.gui.theme').set(theme)
  elseif id:sub(1,8)=='profile:' then
    local mode=id:sub(9) if mode~='auto' and mode~='desktop' and mode~='pocket' then return false,'Invalid app profile' end
    local cfg=profile.configuration() cfg.mode=mode cfg.apps={}
    local ok,err=profile.configure(cfg) return ok,err or 'App profile saved; service changes require restart'
  elseif id:sub(1,4)=='app:' then
    local name=id:sub(5) local app=ctx.apps.get(name)
    if not app or type(value)~='boolean' then return false,'Invalid app choice' end
    if profile.isCore(name) then return false,'Essential app cannot be disabled' end
    local cfg=profile.configuration() cfg.apps[name]=value
    local ok,err=profile.configure(cfg) return ok,err or 'App choice saved; service changes require restart'
  end
  local audio=require('system.services.audiod')
  if id=='audio' then if type(value)~='boolean' then return false,'Invalid audio state' end return audio.setEnabled(value)
  elseif id=='test' then return audio.test()
  elseif id:sub(1,7)=='volume:' then
    local volume=tonumber(id:sub(8)) if not volume or volume<0.5 or volume>2 or volume*2%1~=0 then return false,'Invalid volume' end
    return audio.setVolume(volume)
  elseif id:sub(1,8)=='speaker:' then return audio.use(id:sub(9)) end
  return false,'Unsupported setting'
end
local function ensureWorker()
  if pid and ctx.scheduler.processes[pid] and ctx.scheduler.processes[pid].state=='ready' then return end
  pid=ctx.scheduler:spawn('settingsd',function()
    while true do
      if pending then
        local request=pending pending=nil
        local ran,ok,message=pcall(function()
          local allowed,err=authorize(request) if not allowed then return false,err end
          state.phase='running'
          return perform(request)
        end)
        if not ran then message='SET-FAILED: '..tostring(ok)..'; inspect current configuration before retry' ok=false end
        state.busy=false state.phase='finished' state.ok=ok~=false and ok~=nil
        state.message=tostring(message or (state.ok and 'Saved' or 'Refused')):sub(1,4096)
        pcall(state.ok and log.info or log.warn,'settings',request.action..' #'..request.id..': '..state.message)
        os.queueEvent('mintcraft_settings_result',request.owner,request.id,state.ok,state.message)
      end
      os.pullEvent('mintcraft_settings_action')
    end
  end,{eventMode='raw',appId='settingsd',permissions={},protected=true})
  assert(ctx.scheduler:start(pid))
end
function M.request(actor,id,value)
  if not ctx then return false,'SET-SERVICE: Settings service stopped' end
  if state.busy then return false,'SET-BUSY: configuration change already running' end
  if type(id)~='string' or #id>128 or id:find('[%c]') then return false,'Invalid setting ID' end
  local permission=classify(id) if not permission then return false,'Unsupported setting' end
  if value~=nil and type(value)~='boolean' and (type(value)~='string' or #value>1024) then return false,'Invalid setting value' end
  local process=actor and ctx.scheduler.processes[actor.pid]
  local request={owner=actor and actor.pid,process=process,session=security.sessionRevision(),action=id,value=value,permission=permission}
  local ok,err=authorize(request) if not ok then return false,err end
  ensureWorker() state.serial=state.serial+1 request.id=state.serial pending=request
  state.busy=true state.phase='queued' state.action=id state.owner=request.owner state.message='Queued' state.ok=nil
  os.queueEvent('mintcraft_settings_action',pid)
  return true,request.id
end
function M.status()
  local worker=ctx and pid and ctx.scheduler.processes[pid]
  local uncertain=state.busy and (not worker or worker.state~='ready')
  return {available=ctx~=nil,busy=state.busy,phase=uncertain and 'uncertain' or state.phase,ok=not uncertain,
    message=uncertain and 'Settings worker stopped; operation state uncertain; inspect before recovery' or state.message,
    id=state.serial,action=state.action,owner=state.owner,pid=pid,result=state.ok}
end
M.health=M.status
function M.stop()
  if state.busy then return false,'Settings change active/uncertain; cannot abandon worker' end
  if ctx and pid and ctx.scheduler.processes[pid] and ctx.scheduler.processes[pid].state=='ready' then ctx.scheduler:kill(pid,true) end
  pid=nil pending=nil ctx=nil return true
end
function M.start(context)
  local ok,err=M.stop() if not ok then return false,err end
  ctx=context state={busy=false,phase='idle',serial=state.serial,message='Ready'} return true
end
return M
