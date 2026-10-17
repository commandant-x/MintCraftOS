package.path='./?.lua;'..package.path
local fixture=dofile('tests/storage-fixture.lua')
local state=fixture()
os.getComputerID=function() return 1 end
os.epoch=function() return 1700000000000 end
local wire=require('system.nexus.protocol')
local bootstrap=require('system.nexus.bootstrap')
local store=require('system.nexus.storage')
local function disk()
  state=fixture()
  local manifest={schema=1,release='test_1',master=0,nodes={['1']={key=string.rep('k',64),group='factory'}},hashes={}}
  for _,path in ipairs(bootstrap.files) do
    local data='return {} -- '..path
    state.put('/disk/nexus/payload/'..path,data) manifest.hashes[path]=wire.hash(data)
  end
  state.config('/disk/nexus/manifest.cfg',manifest)
end
disk()
local stages=0
state.hook=function(action) if action=='move' or action=='write' then stages=stages+1 end end
assert(bootstrap.install('/disk')) state.hook=nil
for failure=1,stages do
  disk() local at=0
  state.hook=function(action)
    if action=='move' or action=='write' then at=at+1 if at==failure then error('power loss') end end
  end
  pcall(bootstrap.install,'/disk') state.hook=nil
  assert(bootstrap.install('/disk'),'Installation did not resume at stage '..failure)
  local cfg=assert(store.load('/nexus/config.cfg'))
  assert(cfg.active=='test_1' and fs.exists('/startup.lua') and fs.exists('/nexus/uninstall.lua'))
  assert(store.read('/startup.lua')==bootstrap.launcher)
end
disk() state.put('/disk/nexus/payload/'..bootstrap.files[1],'tampered')
assert(not pcall(bootstrap.install,'/disk')) assert(not fs.exists('/startup.lua'),'Corrupt payload activated')
disk() assert(bootstrap.install('/disk'))
local manifest=store.load('/disk/nexus/manifest.cfg') manifest.release='test_2' state.config('/disk/nexus/manifest.cfg',manifest)
assert(bootstrap.install('/disk'))
local cfg=store.load('/nexus/config.cfg')
assert(cfg.active=='test_2' and cfg.previous=='test_1','Previous version not retained')
assert(fs.exists('/nexus/versions/test_1/system/nexus/agent.lua'),'Rollback slot destroyed')
print('NEXUS bootstrap: '..stages..' interrupted write/move stages resume, corrupted payload refused, previous slot retained')
