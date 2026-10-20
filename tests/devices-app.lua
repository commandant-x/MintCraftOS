package.path='./?.lua;'..package.path
package.loaded['system.libraries.log']={info=function() end,warn=function() end,error=function() end}
package.loaded['system.gui.renderer']={}
package.loaded['system.gui.theme']={get=function() return 1 end}
local allowed=true local reads,scans,released=0,0,0 local source={{name='right',type='monitor',types={'monitor'}},{name='left',type='modem',types={'modem'}}}
local slow=false
package.loaded['system.services.deviced']={list=function()
  local rows={} for _,row in ipairs(source) do rows[#rows+1]={name=row.name,type=row.type,types=row.types} end return rows end,
  scan=function() scans=scans+1 end,getDisplay=function() reads=reads+1 return {target='computer',width=160,height=60} end}
local probe,serial
package.loaded['system.services.combatd']={rescan=function() end,release=function() released=released+1 end,
  requestProbe=function() serial=(serial or 0)+1 return true,serial end,snapshot=function() return {probe=probe} end}
package.loaded['system.services.avionicsd']={rescan=function() end,status=function() return {available=false} end}
package.loaded['system.services.sabled']={rescan=function() end,status=function() return {available=false,inSublevel=false} end}
local now=0 os.clock=function() return now end os.epoch=function() return 0 end
local nextTimer=0 os.startTimer=function() nextTimer=nextTimer+1 return nextTimer end os.cancelTimer=function() end
os.pullEvent=function(filter) return coroutine.yield(filter) end os.queueEvent=function() end
term={getSize=function() return 160,60 end}
peripheral={getMethods=function(name) reads=reads+1 if slow then os.pullEvent('metadata_done') end return {'method_'..name} end}
local scheduler=require('system.kernel.scheduler').new()
local app,window,pid
pid=scheduler:spawn('Devices',function()
  local ctx=scheduler:makeContext(pid)
  ctx.system={scheduler=scheduler,renderStats=function() return {backend='PIXEL256',pixelWidth=960,pixelHeight=540} end}
  ctx.security={require=function() return allowed,'permission denied' end}
  ctx.permissions={'devices.list','peripheral.probe'} ctx.appId='devices'
  ctx.apps={launch=function(id,args) assert(id=='settings' and args.page=='display') return false,'Settings denied' end}
  ctx.windowManager={create=function(_,opts) app=opts.app window={app=app,closed=false} scheduler:attachWindow(pid,window) return window end}
  require('apps.devices.main').run(ctx)
end,{appId='devices',permissions={'devices.list'}})
assert(scheduler:start(pid)) assert(app.busy and reads==0,'metadata acquired synchronously at launch')
local function wake(name,...) scheduler:dispatch({name=name,args=table.pack(...),raw=table.pack(name,...)}) end
wake('mintcraft_app_work') assert(not app.busy and #app.rows==2)
local before=reads local Surface=require('system.graphics.surface')
local palette={panel=7,desktop=15,text=0,button=8,muted=8,accent=9,ink=15,border=8}
app:drawPixels(Surface.new(600,360,15),600,360,palette) assert(reads==before,'draw acquired telemetry')
slow=true app:select(1) wake('mintcraft_app_work') assert(app.busy)
app:select(2) wake('metadata_done') assert(app.selected=='left' and not app.methods.right,'old metadata changed current selection or retained stale cache')
slow=false app:requestRead(false) wake('mintcraft_app_work') assert(app.methods.left[1]=='method_left')
app:activate('probe') local pending=app.probePending assert(pending)
probe={name='right',operationId=pending.id,ownerPid=pid,values={bad='wrong endpoint'}}
wake('mintcraft_combat_result',pid,pending.id,true,'completed') assert(not app.probes.left,'wrong endpoint Probe imported')
app:activate('probe') pending=app.probePending
app:requestRead(true) wake('mintcraft_app_work') assert(scans==1)
probe={name='left',operationId=pending.id,ownerPid=pid,values={}}
wake('mintcraft_combat_result',pid,pending.id,true,'completed') assert(not app.probes.left and app.message:find('Inventory changed',1,true),'pre-hotplug result imported')
app:activate('probe') pending=app.probePending
probe={name='left',operationId=pending.id,ownerPid=pid,values={}}
wake('mintcraft_combat_result',pid,pending.id,true,'exported') assert(app.probes.left==probe)
app:requestRead(false) wake('mintcraft_app_work') assert(app.message=='exported','periodic read erased Probe message')
app:activate('display') assert(app.message=='Settings denied')
allowed=false app:requestRead(true) wake('mintcraft_app_work') assert(app.message:find('permission denied',1,true))
allowed=true source={} app:requestRead(true) wake('mintcraft_app_work') assert(not app.selected and #app.rows==0 and not next(app.probes),'detached selection retained')
source={{name='right',type='monitor',types={'monitor'}}} app:requestRead(true) wake('mintcraft_app_work')
app:select(1) wake('mintcraft_app_work') app:activate('probe') pending=app.probePending
now=9 wake('timer',nextTimer)
assert(not app.probePending and app.message:find('timed out',1,true),'lost Probe left controls disabled forever')
probe={name='right',operationId=pending.id,ownerPid=pid,values={late=true}}
wake('mintcraft_combat_result',pid,pending.id,true,'late result') assert(not app.probes.right,'expired Probe result imported')
wake('mintcraft_app_work') assert(app.message:find('timed out',1,true),'metadata refresh erased timeout')
slow=true app:select(1) wake('mintcraft_app_work')
assert(scheduler:kill(pid)) wake('metadata_done')
assert(released==1,'close did not release queued probe ownership')
for _,process in pairs(scheduler.processes) do assert(process.state~='ready','metadata worker leaked after owner close') end
print('Devices app: asynchronous reads, no draw acquisition, selection/result binding, hotplug generation, errors, permissions and suspended owner cleanup passed')
