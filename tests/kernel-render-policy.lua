package.path=(arg[1] or '.')..'/?.lua;'..package.path
local expected=tonumber(arg[2]) or 1
local locked=arg[3]=="locked"
local loaded=package.loaded
local events,draws,dispatched,emitted,handled={},0,0,0,0
local tick,nextTimer=0,0
os.clock=function() return tick end os.startTimer=function() nextTimer=nextTimer+1 return nextTimer end
os.cancelTimer=function() end
local stop={}
os.pullEventRaw=function()
 local event=table.remove(events,1)
 if not event then error(stop) end
 tick=event.time or tick
 return table.unpack(event)
end
term={getSize=function() return 51,19 end}
colors=colors or {black=32768,white=1}
for _,name in ipairs({"setBackgroundColor","setTextColor","clear","setCursorPos","setCursorBlink","write"}) do term[name]=function() end end
keys={f1=1}
loaded['system.libraries.log']={info=function() end,error=function() end}
loaded['system.gui.theme']={load=function() end,currentId='mint'}
local wm={windows={},invalidate=function() end,draw=function() end,handle=function() handled=handled+1 end}
loaded['system.wm.window_manager']={new=function() return wm end}
loaded['system.kernel.event_bus']={new=function() return {emit=function() emitted=emitted+1 end} end}
loaded['system.kernel.scheduler']={new=function() return {dispatch=function() dispatched=dispatched+1 end} end}
loaded['system.libraries.apps']={registerBuiltin=function() end,setContext=function() end}
loaded['system.package.package_manager']={setContext=function() end,registerInstalledApps=function() end}
loaded['system.security.permissions']={}
loaded['system.security.users']={needsEnrollment=function() return false end}
loaded['system.services.securityd']={isLocked=function() return locked end}
loaded['system.services.notifd']={new=function() return {queue={},nextId=1,push=function() end,handle=function() end,draw=function() end} end}
loaded['system.services.service_manager']={new=function() return {register=function() end,startAutostart=function() end} end}
loaded['system.services.deviced']={getDisplay=function() return {} end}
loaded['system.kernel.input']={normalize=function(raw) return {name=raw[1],args={raw[2]}} end}
local desktop={displayedClock='12:00',clockText=function() return '12:00' end,setApps=function() end,setWindowManager=function() end,setNotifications=function() end,draw=function() end,drawOverlays=function() end,handle=function() end}
loaded['system.gui.desktop']=desktop
loaded['system.libraries.config']={load=function() return {} end}
loaded['system.boot.graphics_guard']={begin=function() return {state='pending'} end,observe=function() end,fail=function() end}
loaded['system.graphics.workspace']={new=function() return {revision=0,cacheBytes=0,scene={stats={}},deactivate=function() end,prepare=function() end,draw=function() end,handle=function() return false end} end}
loaded['system.gui.compositor']={new=function() return {invalidate=function() end,draw=function(_,fn) draws=draws+1 fn() end,stats=function() return {backend='PIXEL256'} end} end}
for i=1,1000 do events[#events+1]={'modem_message',i,time=i/10000} end
if locked then for _,name in ipairs({'char','paste','key','key_up','mouse_click','mouse_drag','mouse_up','mouse_scroll','file_transfer','terminate'}) do events[#events+1]={name,'private password'} end end
local ok,err=pcall(require('system.kernel.kernel').start)
assert(not ok and err==stop,tostring(err))
assert(dispatched==1000 and emitted==1000 and handled==1000,'event dispatch was throttled')
assert(draws==expected,'unexpected desktop render count: '..draws)
print('kernel integration: 1000 nonvisual modem events dispatched; desktop renders: '..draws)
