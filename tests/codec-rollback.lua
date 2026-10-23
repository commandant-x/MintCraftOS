package.path='./?.lua;'..package.path
local nativeLoadfile=loadfile
local fixture=assert(nativeLoadfile('tests/storage-fixture.lua'))()
local C=require('system.libraries.packed_source')
local r=require('tests.fixtures.packed-v2')[3]
local h=assert(io.open('system/libraries/packed_source_v2.lua','rb')) local decoder=h:read('*a') h:close()
local function setup(tree)
 local state=fixture()
 state.config('/system/config/system.cfg',{custom='retain'})
 state.config('/var/backups/update/latest.cfg',{id='1'})
 state.put('/VERSION','new') state.put('/system/libraries/packed_source_v2.lua',decoder)
 state.put('/apps/custom/main.lua',r.wrapper)
 state.put('/var/backups/update/1/VERSION','old')
 if tree then
  state.config('/var/backups/update/1/manifest.cfg',{id='1',paths={'/VERSION','/system'}})
  state.put('/var/backups/update/1/system/libraries/demo.lua',"return 'old'")
 else
  state.config('/var/backups/update/1/manifest.cfg',{id='1',kind='files',paths={'/VERSION','/system/libraries/packed_source_v2.lua'},
   existed={['/VERSION']=true,['/system/libraries/packed_source_v2.lua']=false}})
 end
 return state
end
for _,tree in ipairs({true,false}) do for _,raw in ipairs({true,false}) do
 local state=setup(tree)
 if raw then assert(assert(nativeLoadfile('system/boot/recovery.lua'))('--raw-rollback'))
 else
  for _,name in ipairs({'system.services.updated','system.libraries.config','system.libraries.safe_write'}) do package.loaded[name]=nil end
  assert(require('system.services.updated').rollback())
 end
 assert(state.nodes['/VERSION']=='old')
 assert(state.nodes['/system/libraries/packed_source_v2.lua']==decoder,'rollback removed the decoder needed by preserved code')
 assert(C.unpack(state.nodes['/apps/custom/main.lua'])==r.source,'rollback broke preserved custom application')
 assert(textutils.unserialize(state.nodes['/system/config/system.cfg']).custom=='retain')
 assert(not fs.exists('/var/tmp/mintcraft-restore') and not fs.exists('/var/tmp/mintcraft-rollback.cfg'))
end end
print('Codec rollback compatibility: legacy system trees and file checkpoints preserve the format decoder for retained applications, in service and raw recovery paths')
