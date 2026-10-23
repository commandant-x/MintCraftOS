package.path='./?.lua;'..package.path
local nativeLoadfile=loadfile
local fixture=assert(nativeLoadfile('tests/storage-fixture.lua'))()
local C=require('system.libraries.packed_source')
local case=require('tests.fixtures.packed-v3')[6]
local function read(path) local h=assert(io.open(path,'rb')) local data=h:read('*a') h:close() return data end
local core=assert(nativeLoadfile('system/libraries/installer_v2.lua'))()
local oldLoader='-- older compatible source loader\n'..read('system/libraries/packed_source.lua')
local files={VERSION='next',
 ['system/libraries/packed_source.lua']=read('system/libraries/packed_source.lua'),
 ['system/libraries/packed_source_v2.lua']=read('system/libraries/packed_source_v2.lua'),
 ['system/libraries/packed_source_v3.lua']=read('system/libraries/packed_source_v3.lua'),
 ['system/sample.lua']='-- MintCraft packed source 3\nreturn assert(load(require("system.libraries.packed_source_v3").decode([['..case.encoded..']],'..#case.source..',"'..case.digest..'"),"fixture","t",_ENV))(...)\n',
 ['system/changed.lua']="return 'new'"}
local function setup()
 local s=fixture() s.put('/VERSION','old') s.put('/system/sample.lua',C.pack('system/sample.lua',case.source))
 s.put('/system/changed.lua',"return 'old'") s.put('/system/libraries/packed_source.lua',oldLoader)
 s.put('/system/libraries/packed_source_v2.lua',files['system/libraries/packed_source_v2.lua'])
 s.config('/system/config/update-storage.cfg',{retainRollback=false}) s.put('/home/user/witness','personal')
 loadfile=function(path) return load(s.nodes[path],path,'t',_ENV) end
 return s
end
for _,phase in ipairs({'decoder','loader','representation','live'}) do
 local s=setup() local stopped=false
 s.hook=function(action,path)
  local selected=phase=='decoder' and path=='/system/libraries/packed_source_v3.lua' or
   phase=='loader' and path=='/system/libraries/packed_source.lua' or phase=='representation' and path=='/system/sample.lua' or
   phase=='live' and path=='/system/changed.lua'
  if not stopped and action=='write' and selected then stopped=true coroutine.yield('power loss') end
 end
 local worker=coroutine.create(function() core.install(files,{beforePreparation=function() end}) end)
 local ok,why=coroutine.resume(worker) assert(ok,why) assert(stopped and coroutine.status(worker)=='suspended') s.hook=nil
 assert(core.recover())
 assert(s.nodes['/VERSION']=='old' and s.nodes['/system/changed.lua']=="return 'old'")
 assert(C.unpack(s.nodes['/system/sample.lua'])==case.source and s.nodes['/home/user/witness']=='personal')
 if phase=='decoder' or phase=='loader' then
  assert(not s.nodes['/system/libraries/packed_source_v3.lua'] and s.nodes['/system/libraries/packed_source.lua']==oldLoader,'partial codec bootstrap survived recovery')
 end
 assert(core.install(files,{beforePreparation=function() end}))
 assert(s.nodes['/VERSION']=='next' and C.unpack(s.nodes['/system/sample.lua'])==case.source)
 assert(not fs.exists('/var/tmp/mintcraft-install'))
end
loadfile=nativeLoadfile
print('Format-3 migration: decoder/loader bootstrap, equivalent representation and live-write interruptions recover atomically, preserve user data and retry successfully')
