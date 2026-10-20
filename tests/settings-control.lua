package.path='./?.lua;'..package.path
local revision=0 local allowed={}
package.loaded['system.libraries.log']={info=function() end,warn=function() end,error=function() end}
package.loaded['system.services.securityd']={sessionRevision=function() return revision end,lock=function() revision=revision+1 return true end,logout=function() revision=revision+1 return true end}
package.loaded['system.security.permissions']={require=function(actor,permission) return allowed[actor.pid]==true,'denied '..permission end}
local cfg={safeMode=false,graphicsMode='auto',keep='preserve'} local failSave=false
package.loaded['system.libraries.config']={load=function() local copy={} for k,v in pairs(cfg) do copy[k]=v end return copy end,
  save=function(_,value) if failSave then return false,'disk full' end cfg=value return true end}
local calls={} local suspend=false
package.loaded['system.services.deviced']={setTarget=function(target)
  calls[#calls+1]=target if suspend then os.pullEvent('display_done') end return true end,
  refreshDisplay=function() return false end,setScale=function(scale) calls[#calls+1]=scale return true end}
package.loaded['system.gui.theme']={set=function(theme) calls[#calls+1]=theme return true end}
local modes={}
package.loaded['system.libraries.profile']={isCore=function(id) return id=='editor' end,configuration=function() return {mode='auto',apps={}} end,
  configure=function(value) modes[#modes+1]=value return true end}
package.loaded['system.services.updated']={cleanup=function(_,options) assert(options.confirm==true) calls[#calls+1]='prune' return true end}
package.loaded['system.services.audiod']={setEnabled=function(value) calls[#calls+1]=value return true end,setVolume=function(value) calls[#calls+1]=value return true end,test=function() return true end,use=function() return true end}
os.epoch=function() return 0 end os.queueEvent=function() end os.pullEvent=function(filter) return coroutine.yield(filter) end
local scheduler=require('system.kernel.scheduler').new()
local function owner()
  local id=scheduler:spawn('Settings',function() while true do coroutine.yield() end end,{appId='settings'}) scheduler:start(id) allowed[id]=true return {pid=id}
end
local first,second=owner(),owner()
local service=require('system.services.settingsd')
local graphics={}
assert(service.start({scheduler=scheduler,apps={get=function(id) return id=='editor' or id=='browser' end},setGraphicsMode=function(mode) graphics[#graphics+1]=mode end}))
local function wake(name) scheduler:dispatch({name=name,args={},raw={name}}) end
assert(not service.request(first,'eval','print(1)'))
assert(not service.request(first,'label',{}))
assert(service.request(first,'display:terminal_0')) allowed[first.pid]=false wake('mintcraft_settings_action')
assert(#calls==0 and not service.status().result,'queued permission revocation ignored')
allowed[first.pid]=true assert(service.request(first,'theme:dark')) revision=revision+1 wake('mintcraft_settings_action')
assert(#calls==0,'session replacement inherited request')
assert(service.request(first,'theme:dark')) assert(scheduler:kill(first.pid)) wake('mintcraft_settings_action') assert(#calls==0,'closed queued caller mutated config')
first=owner() suspend=true assert(service.request(first,'display:terminal_0')) wake('mintcraft_settings_action')
assert(service.status().busy and calls[1]=='terminal_0')
assert(not service.request(second,'theme:mint') and not service.stop(),'overlapping command or service stop abandoned display operation')
assert(scheduler:kill(first.pid)) revision=revision+1 wake('display_done')
assert(not service.status().busy and service.status().result,'caller closure abandoned in-flight output change')
first=owner() suspend=false
assert(service.request(first,'graphics:pixel16')) wake('mintcraft_settings_action')
assert(cfg.graphicsMode=='pixel16' and not cfg.safeMode and cfg.keep=='preserve' and graphics[1]=='pixel16')
failSave=true assert(service.request(first,'graphics:text')) wake('mintcraft_settings_action')
assert(not service.status().result and #graphics==1 and not cfg.safeMode,'failed save changed active graphics') failSave=false
assert(service.request(first,'graphics:text')) wake('mintcraft_settings_action') assert(cfg.safeMode and graphics[2]=='text')
assert(service.request(first,'app:editor',false)) wake('mintcraft_settings_action') assert(not service.status().result and #modes==0,'essential app disabled')
assert(service.request(first,'app:browser',false)) wake('mintcraft_settings_action') assert(modes[1].apps.browser==false)
assert(service.request(first,'scale:17')) wake('mintcraft_settings_action') assert(not service.status().result)
local before=#calls assert(service.request(first,'cleanupConfirm',false)) wake('mintcraft_settings_action') assert(#calls==before,'cleanup without confirmation executed')
assert(service.request(first,'cleanupConfirm',true)) wake('mintcraft_settings_action') assert(calls[#calls]=='prune')
suspend=true assert(service.request(first,'display:terminal_1')) wake('mintcraft_settings_action')
assert(scheduler:kill(service.status().pid,true))
assert(service.status().phase=='uncertain' and not service.request(first,'theme:dark') and not service.stop(),'uncertain worker automatically retried')
print('Settings control: allowlist, live permission/session/owner checks, serial yielding writes, retained ownership, safe stop refusal, disk failure and protected apps passed')
