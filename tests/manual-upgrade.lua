package.path='./?.lua;'..package.path
local state=assert(loadfile('tests/storage-fixture.lua'))()()
local nativeLoadfile=loadfile
loadfile=function(path) return load(state.nodes[path],path) end
state.put('/VERSION','0.18.44') state.put('/boot.lua','return "stable"')
state.put('/home/user/documents/witness','user data')
local installer=require('system.libraries.installer')
local free=fs.getFreeSpace
fs.getFreeSpace=function() return 1 end
assert(not pcall(installer.install,{VERSION='0.18.45',['boot.lua']='return "new"'}))
assert(state.nodes['/boot.lua']=='return "stable"')
fs.getFreeSpace=free
assert(installer.install({VERSION='0.18.45',['boot.lua']='return "new"'}))
local updated=require('system.services.updated')
local info=assert(updated.rollbackInfo())
assert(state.nodes[info.path..'/boot.lua']=='return "stable"')
assert(updated.rollback())
assert(state.nodes['/VERSION']=='0.18.44' and state.nodes['/boot.lua']=='return "stable"')
assert(state.nodes['/home/user/documents/witness']=='user data')
loadfile=nativeLoadfile
print('manual upgrade: space refusal, durable differential checkpoint and rollback preserve user data')
