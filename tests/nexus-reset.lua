package.path='./?.lua;'..package.path
local testRoot=fs and fs.exists('/source/tests/storage-fixture.lua') and '/source/' or ''
local fixture=dofile(testRoot..'tests/storage-fixture.lua')
local wire=require('system.nexus.protocol')
local bootstrap=require('system.nexus.bootstrap')
local store=require('system.nexus.storage')
os.getComputerID=function() return 1 end
os.epoch=function() return 1700000000000 end
local state,manifest
local function setup()
 state=fixture()
 fs.getDrive=function(path)
  if path=='/disk' or path:sub(1,6)=='/disk/' then return 'drive_0' end
  if path=='/rom' or path:sub(1,5)=='/rom/' then return 'rom' end
  if path=='/folder/mounted' or path:sub(1,16)=='/folder/mounted/' then return 'drive_1' end
  return 'hdd'
 end
 fs.isReadOnly=function(path) return fs.getDrive(path)=='rom' end
 manifest={schema=1,release='new_version',master=0,nodes={['1']={group='factory',key=string.rep('k',64),resetToken=string.rep('r',40)}},hashes={}}
 for _,path in ipairs(bootstrap.files) do
  local data='return {} -- '..path state.put('/disk/nexus/payload/'..path,data) manifest.hashes[path]=wire.hash(data)
 end
 state.config('/disk/nexus/manifest.cfg',manifest)
 state.put('/startup.lua','foreign startup') state.put('/system/old.lua','old OS')
 state.put('/personal.txt','erase') state.put('/folder/private.txt','erase')
 state.put('/folder/mounted/keep.txt','external') state.put('/rom/keep.lua','rom')
 state.put('/disk/keep.txt','disk')
end
setup()
assert(bootstrap.install('/disk'))
assert(not fs.exists('/personal.txt') and not fs.exists('/system') and not fs.exists('/folder/private.txt'))
assert(store.read('/disk/keep.txt')=='disk' and store.read('/rom/keep.lua')=='rom')
assert(store.read('/folder/mounted/keep.txt')=='external','Nested mounted disk deleted')
assert(store.load('/nexus/config.cfg').provisionToken==string.rep('r',40))
state.put('/after-install.txt','retain')
assert(bootstrap.install('/disk'))
assert(store.read('/after-install.txt')=='retain','Same reset campaign erased data again')
setup() manifest.master=1 state.config('/disk/nexus/manifest.cfg',manifest)
assert(not bootstrap.install('/disk') and fs.exists('/personal.txt'),'MASTER erased')
setup() manifest.nodes={} state.config('/disk/nexus/manifest.cfg',manifest)
assert(not bootstrap.install('/disk') and fs.exists('/personal.txt'),'Unselected computer erased')
setup() state.put('/disk/nexus/payload/'..bootstrap.files[1],'corrupt')
assert(not pcall(bootstrap.install,'/disk') and fs.exists('/personal.txt'),'Reset began before payload verification')
setup() fs.getDrive=function() return 'hdd' end
assert(not pcall(bootstrap.install,'/disk') and fs.exists('/personal.txt'),'Internal bootstrap accepted for reset')
setup() manifest.nodes['1'].resetToken=nil manifest.nodes['1'].forceToken=string.rep('f',40)
state.config('/disk/nexus/manifest.cfg',manifest)
assert(bootstrap.install('/disk'),'Locally confirmed failure did not force install')
assert(not fs.exists('/personal.txt') and store.load('/nexus/config.cfg').provisionToken==string.rep('f',40))
state.put('/after-force.txt','keep')
assert(bootstrap.install('/disk') and fs.exists('/after-force.txt'),'Local recovery repeated after success')
setup() manifest.nodes['1'].resetToken=nil manifest.nodes['1'].forceToken=string.rep('f',40)
state.config('/disk/nexus/manifest.cfg',manifest) state.put('/disk/nexus/payload/'..bootstrap.files[1],'corrupt')
assert(not pcall(bootstrap.install,'/disk') and fs.exists('/personal.txt'),'Force recovery erased before payload verification')
setup()
local cuts=0 state.hook=function(action) if action=='delete' or action=='move' or action=='write' then cuts=cuts+1 end end
assert(bootstrap.install('/disk')) state.hook=nil
for cut=1,cuts do
 setup() local at=0
 state.hook=function(action) if action=='delete' or action=='move' or action=='write' then at=at+1 if at==cut then error('power loss') end end end
 pcall(bootstrap.install,'/disk') state.hook=nil
 assert(bootstrap.install('/disk'),'Reset did not resume after interruption '..cut)
 assert(not fs.exists('/personal.txt') and fs.exists('/disk/keep.txt') and fs.exists('/startup.lua'))
end
print('NEXUS reset: selected internal disk only, ROM/mount protection, verified payload, one-shot receipt and '..cuts..' interruptions passed')
