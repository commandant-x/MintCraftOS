package.path='./?.lua;'..package.path
local files
assert(loadfile('install.lua','t',{assert=assert,print=function() end,load=function()
 return function() return {install=function(bundle) files=bundle end} end
end}))()
local fixture=assert(loadfile('tests/storage-fixture.lua'))()
local nativeLoadfile=loadfile
local quota=1000000
local function setup()
 local state=fixture() local peak=0
 -- Conservative allocation model: at least 512 bytes per file and directory.
 local function used()
  local total=0
  for path,data in pairs(state.nodes) do
   if path~='/' then total=total+(data==true and 512 or math.max(512,#data)) end
  end
  return total
 end
 fs.getFreeSpace=function() return quota-used() end
 state.hook=function() peak=math.max(peak,used()) assert(used()<=quota,'one-million-byte disk exceeded') end
 state.put('/home/user/documents/witness',string.rep('user data\n',10000))
 state.config('/system/config/system.cfg',{customField='retain',vehicle='witness'})
 loadfile=function(path) return load(state.nodes[path],path) end
 local installer=assert(load(files['system/libraries/installer.lua'],'installer','t',_ENV))()
 return state,installer,used,function() return peak end
end
local state,installer,used,peak=setup()
assert(installer.install(files))
local installed=used()
local codec=require('system.libraries.packed_source')
local checked=0
for path,content in pairs(files) do
 if path~='system/config/system.cfg' then
  assert(state.nodes['/'..path]==content,'installed bytes differ: '..path)
  if path:match('%.lua$') then assert(load(codec.unpack(content),'@/'..path,'t',_ENV)) checked=checked+1 end
 end
end
local nextFiles={} for path,data in pairs(files) do nextFiles[path]=data end
nextFiles.VERSION='0.18.48\n'
local source=codec.unpack(files['apps/terminal/main.lua'])..'\n-- next release witness\n'
nextFiles['apps/terminal/main.lua']=codec.pack('apps/terminal/main.lua',source)
assert(installer.install(nextFiles))
local updated=require('system.services.updated')
assert(updated.rollback())
assert(state.nodes['/VERSION']==files.VERSION)
assert(codec.unpack(state.nodes['/apps/terminal/main.lua'])==codec.unpack(files['apps/terminal/main.lua']))
assert(state.nodes['/home/user/documents/witness']==string.rep('user data\n',10000))
local cfg=textutils.unserialize(state.nodes['/system/config/system.cfg'])
assert(cfg.customField=='retain' and cfg.vehicle=='witness' and cfg.safeMode)
assert(fs.getFreeSpace('/')>0)
print(string.format('compact 1 MB disk: %d installed Lua files; %d bytes with 100000-byte user witness; peak %d bytes including update/checkpoint/rollback; %d free at end',checked,installed,peak(),fs.getFreeSpace('/')))
-- Interrupt staging, then live installation; retry the exact installer without
-- deleting any user data or the retained transaction by hand.
for _,phase in ipairs({'stage','live'}) do
 state,installer,used,peak=setup()
 local originalHook=state.hook local interrupted=false
 state.hook=function(action,path)
  originalHook(action,path)
  if not interrupted and action=='write' and (phase=='stage' and path:match('/stage/apps/') or phase=='live' and path:match('^/apps/')) then
   interrupted=true coroutine.yield('power loss')
  end
 end
 local worker=coroutine.create(function() installer.install(files) end)
 assert(coroutine.resume(worker)) assert(interrupted and coroutine.status(worker)=='suspended')
 state.hook=originalHook
 assert(installer.install(files))
 assert(state.nodes['/VERSION']==files.VERSION and state.nodes['/home/user/documents/witness']==string.rep('user data\n',10000))
end
state,installer,used,peak=setup()
local damaged={} for path,data in pairs(files) do damaged[path]=data end
local replacements
 damaged['apps/terminal/main.lua'],replacements=damaged['apps/terminal/main.lua']:gsub('(%]%],%d+,")[0-9a-f]+(")',function(a,b) return a..'00000000'..b end,1)
assert(replacements==1)
local before=used()
local ok,reason=pcall(installer.install,damaged)
assert(not ok and tostring(reason):find('integrity mismatch',1,true))
assert(used()==before and not fs.exists('/var/tmp/mintcraft-install'),'corrupt source touched disk before validation')
loadfile=nativeLoadfile
print('compact disk: interrupted staging and live installation recover on pinned-installer retry')
