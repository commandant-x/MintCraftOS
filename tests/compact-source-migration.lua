package.path='./?.lua;'..package.path
local nativeLoadfile=loadfile
local fixture=assert(nativeLoadfile('tests/storage-fixture.lua'))()
local cases=require('tests.fixtures.packed-v2') local r=cases[3]
local C=require('system.libraries.packed_source')
local V=require('system.libraries.packed_source_v2')
local function read(path) local h=assert(io.open(path,'rb')) local x=h:read('*a') h:close() return x end
local core=assert(nativeLoadfile('system/libraries/installer_v2.lua'))()
local old=C.pack('system/sample.lua',r.source)
local files={VERSION='new', ['system/libraries/packed_source.lua']=read('system/libraries/packed_source.lua'),
 ['system/libraries/packed_source_v2.lua']=read('system/libraries/packed_source_v2.lua'),
 ['system/sample.lua']=r.wrapper,['system/changed.lua']="return 'new'"}
local function setup()
 local state=fixture()
 state.put('/VERSION','old') state.put('/system/sample.lua',old)
 state.put('/system/changed.lua',"return 'old'")
 state.put('/system/libraries/packed_source.lua',files['system/libraries/packed_source.lua'])
 state.put('/home/user/witness','personal') state.config('/system/config/update-storage.cfg',{retainRollback=false})
 return state
end
local state=setup() local plan,committed,authorized
assert(core.install(files,{beforePreparation=function() authorized=true end,beforeInstall=function(p) plan=p end,onCommitted=function() committed=(committed or 0)+1 end}))
assert(authorized and committed==1 and plan.compactedFiles==1 and plan.equivalentFiles==1)
assert(state.nodes['/system/sample.lua']==r.wrapper and files['system/sample.lua']==r.wrapper)
assert(C.unpack(state.nodes['/system/sample.lua'])==r.source and state.nodes['/home/user/witness']=='personal')
assert(not fs.exists('/var/backups/update') and not fs.exists('/var/tmp/mintcraft-install'))
-- Denied preparation must precede every write, including the storage policy.
state=setup() local before={} for p,x in pairs(state.nodes) do before[p]=x end
assert(not pcall(core.install,files,{beforePreparation=function() error('denied') end}))
for p,x in pairs(before) do assert(state.nodes[p]==x,'denied preparation changed '..p) end
for p in pairs(state.nodes) do assert(before[p]~=nil,'denied preparation added '..p) end
-- A callback-only legacy client cannot authorize prewrites. Keep equivalent
-- encoding in place, then apply actual code after its ordinary callback.
state=setup() plan=nil
assert(core.install(files,{beforeInstall=function(p) plan=p end}))
assert(plan.compactedFiles==0 and state.nodes['/system/sample.lua']==old and state.nodes['/system/changed.lua']==files['system/changed.lua'])
assert(files['system/sample.lua']==r.wrapper,'installer mutated caller payload')
-- All incoming source is checked before preparing even an equivalent module.
state=setup() local invalid={} for p,x in pairs(files) do invalid[p]=x end invalid['system/invalid.lua']='invalid ! lua'
assert(not pcall(core.install,invalid)) assert(state.nodes['/system/sample.lua']==old and not fs.exists('/system/libraries/packed_source_v2.lua'))
local stages=0
for crashAt=1,240 do
 state=setup() local operations=0
 state.hook=function() operations=operations+1 if operations==crashAt then coroutine.yield('power loss') end end
 local co=coroutine.create(function() assert(core.install(files)) end)
 local ok,why=coroutine.resume(co) assert(ok,why)
 local interrupted=coroutine.status(co)=='suspended' state.hook=nil
 local recovered=core.recover()
 -- Pre-journal ambiguity is retained for inspection, never guessed away.
 if not recovered then assert(fs.exists('/var/tmp/mintcraft-install') and state.nodes['/VERSION']=='old') end
 assert(C.unpack(state.nodes['/system/sample.lua'])==r.source,'equivalent-source crash changed executable bytes')
 if state.nodes['/system/sample.lua']:sub(1,#V.prefix)==V.prefix then assert(state.nodes['/system/libraries/packed_source_v2.lua']==files['system/libraries/packed_source_v2.lua'],'new encoding lost its standalone decoder') end
 assert(state.nodes['/home/user/witness']=='personal')
 if recovered then
  local previous=state.nodes['/VERSION']=='old' and state.nodes['/system/changed.lua']=="return 'old'"
  local nextVersion=state.nodes['/VERSION']=='new' and state.nodes['/system/changed.lua']==files['system/changed.lua']
  assert(previous or nextVersion,'recovery mixed functional versions')
  assert(core.install(files)) assert(C.unpack(state.nodes['/system/sample.lua'])==r.source)
 end
 if not interrupted then break end stages=stages+1
end
assert(stages>=50)
print('Equivalent-source preparation: atomic decoder bootstrap, exact byte proof, authorization-before-write, legacy callbacks, bounded transactions and '..stages..' power-loss points passed')
-- Persisting a previously implicit no-history policy must also be transactional.
local policyStages=0
for crashAt=1,140 do
 state=setup() state.config('/system/config/update-storage.cfg',{custom='retain'})
 local withPolicy={} for p,x in pairs(files) do withPolicy[p]=x end
 withPolicy['system/config/update-storage.cfg']=textutils.serialize({retainRollback=false})
 local operations=0 state.hook=function() operations=operations+1 if operations==crashAt then coroutine.yield('policy power loss') end end
 local co=coroutine.create(function() assert(core.install(withPolicy)) end)
 local ok,why=coroutine.resume(co) assert(ok,why)
 local interrupted=coroutine.status(co)=='suspended' state.hook=nil
 local recovered=core.recover()
 local p=textutils.unserialize(state.nodes['/system/config/update-storage.cfg'])
 assert(type(p)=='table' and p.custom=='retain','policy crash destroyed user fields')
 assert(p.retainRollback==nil or p.retainRollback==false)
 if not recovered then assert(fs.exists('/var/tmp/mintcraft-install')) end
 assert(state.nodes['/home/user/witness']=='personal')
 if not interrupted then break end policyStages=policyStages+1
end
assert(policyStages>=60)
print('Storage policy preparation: custom fields retained across '..policyStages..' transactional power-loss points')
-- Optional real release-to-release migration and compatible code rollback.
if arg[1] then
 local function bundle(path)
  local result
  assert(nativeLoadfile(path,'t',{assert=assert,print=function() end,load=function() return function() return {install=function(f) result=f end} end end}))()
  return assert(result)
 end
 local previous,nextFiles=bundle(arg[1]),bundle('install.lua')
 state=fixture() local peak=0
 local function used() local n=0 for p,x in pairs(state.nodes) do if p~='/' then n=n+(x==true and 512 or math.max(512,#x)) end end return n end
 fs.getFreeSpace=function() return 1000000-used() end
 state.hook=function() peak=math.max(peak,used()) assert(used()<=1000000,'quota exceeded') end
 loadfile=function(path) return load(state.nodes[path],path,'t',_ENV) end
 assert(core.install(previous)) state.put('/home/user/witness',string.rep('p',100000))
 local prepared
 assert(core.install(nextFiles,{beforeHistoryCleanup=function() end,beforeInstall=function(p) prepared=p.compactedFiles end}))
 assert(prepared~=nil,'real release migration did not report preparation')
 if previous.VERSION:match('^0%.18%.86%s*$') then
  assert(prepared>100,'format-1 release migration did not compact equivalent modules')
 else
  -- Already compact releases need only their real changed/new modules.
  assert(prepared==0,'format-2 release unexpectedly re-encoded unchanged source')
 end
 local after=used()
 local restored={} for path,data in pairs(previous) do restored[path]=data end
 if previous.VERSION:match('^0%.18%.86%s*$') then restored['system/services/flightd.lua']=read('tools/compat/flightd-0.18.86.packed') end
 assert(core.install(restored))
 assert(state.nodes['/VERSION']==previous.VERSION and state.nodes['/home/user/witness']==string.rep('p',100000))
 for path,data in pairs(restored) do
  if path:match('%.lua$') then assert(C.unpack(state.nodes['/'..path])==C.unpack(data),'rollback changed decoded old source: '..path) end
 end
 assert(core.install(nextFiles))
 assert(state.nodes['/VERSION']==nextFiles.VERSION and not fs.exists('/var/tmp/mintcraft-install'))
 print('Actual release migration: '..prepared..' sources compacted; '..after..' bytes with 100000 user bytes; migration/compatible rollback/re-upgrade peak '..peak)
 loadfile=nativeLoadfile
end
