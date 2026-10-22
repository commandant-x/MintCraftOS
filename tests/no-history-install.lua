package.path='./?.lua;'..package.path
local files
assert(loadfile('install.lua','t',{assert=assert,print=function() end,load=function() return function() return {install=function(bundle) files=bundle end} end end}))()
local nativeLoadfile=loadfile
local previousFiles=files
if arg[1] then
 assert(nativeLoadfile(arg[1],'t',{assert=assert,print=function() end,load=function() return function() return {install=function(bundle) previousFiles=bundle end} end end}))()
end
local function setup(historyBytes)
 local state=assert(nativeLoadfile('tests/storage-fixture.lua'))()()
 loadfile=function(path) return load(state.nodes[path],path) end
 local used=function()
  local n=0 for path,data in pairs(state.nodes) do if path~='/' then n=n+(data==true and 512 or math.max(512,#data)) end end return n
 end
 fs.getFreeSpace=function() return 1000000-used() end
 local peak=0
 state.hook=function() peak=math.max(peak,used()) assert(used()<=1000000,'quota exceeded') end
 local installer=assert(load(files['system/libraries/installer.lua'],'installer','t',_ENV))()
 assert(installer.install(previousFiles))
 state.put('/home/user/documents/witness',string.rep('x',100000))
 state.put('/var/backups/update/100/old',string.rep('y',historyBytes or 160000))
 state.put('/VERSION','0.18.62\n') state.put('/boot.lua','return "old"')
 return state,installer,function() return peak end
end
local state,installer,peak=setup()
local old=state.nodes['/var/backups/update/100/old']
local ok=pcall(installer.install,files,{purgeHistory=true,beforeHistoryCleanup=function() error('denied') end})
assert(not ok and state.nodes['/var/backups/update/100/old']==old,'denial deleted history')
assert(installer.install(files,{purgeHistory=true,beforeInstall=function(plan)
 assert(plan.retainRollback==false)
 -- Compatibility with an older installed Update that still creates a checkpoint.
 state.put('/var/backups/update/101/boot.lua','return "old"')
end}))
assert(not fs.exists('/var/backups/update') and not fs.exists('/var/tmp/mintcraft-install'))
assert(state.nodes['/home/user/documents/witness']==string.rep('x',100000))
assert(textutils.unserialize(state.nodes['/system/config/update-storage.cfg']).retainRollback==false)
print('no-history install: obsolete versions removed, personal data retained, no checkpoint after legacy callback; peak '..peak())
state,installer=setup()
local quotaHook=state.hook local interrupted=false
state.hook=function(action,path)
 quotaHook(action,path)
 if not interrupted and action=='write' and path=='/VERSION' then interrupted=true coroutine.yield('power loss') end
end
local worker=coroutine.create(function() installer.install(files,{purgeHistory=true}) end)
local ok,err=coroutine.resume(worker) assert(ok,err) assert(interrupted)
state.hook=quotaHook
assert(installer.recover())
assert(state.nodes['/VERSION']=='0.18.62\n' and state.nodes['/boot.lua']=='return "old"')
assert(not fs.exists('/var/backups/update') and not fs.exists('/var/tmp/mintcraft-install'))
assert(state.nodes['/home/user/documents/witness']==string.rep('x',100000))
assert(installer.install(files))
print('no-history install: interrupted writes recover using temporary transaction only, retry removes transaction')

state,installer=setup(10000)
local preserved=state.nodes['/var/backups/update/100/old']
assert(installer.install(files))
assert(state.nodes['/var/backups/update/100/old']==preserved,'default installation implicitly removed an existing backup')
assert(not fs.exists('/var/tmp/mintcraft-install'))
print('default no-history upgrade preserves every existing checkpoint without explicit purge')
