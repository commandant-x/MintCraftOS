package.path='./?.lua;'..package.path
-- Capture the exact distributable, then execute its actual installer/loader.
local files
assert(loadfile('install.lua','t',{assert=assert,print=function() end,load=function()
 return function() return {install=function(bundle) files=bundle end} end
end}))()
local state=assert(loadfile('tests/storage-fixture.lua'))()()
for path,data in pairs(files) do state.put('/'..path,data) end
state.put('/VERSION','0.18.44\n') state.put('/boot.lua','return "stable"')
state.put('/home/user/documents/witness','user data')
state.config('/system/config/system.cfg',{safeMode=false,vehicle='witness',customField=42})
local nativeLoadfile=loadfile
loadfile=function(path) return load(state.nodes[path],path) end
-- A stale/broken installed checkpoint service must never be used by wget.
package.loaded['system.services.updated']={createRollback=function() error('stale installed service') end}
local installer=assert(load(files['system/libraries/installer.lua'],'installer','t',_ENV))()
assert(installer.install(files))
assert(state.nodes['/VERSION']==files.VERSION and state.nodes['/boot.lua']==files['boot.lua'])
local info=textutils.unserialize(state.nodes['/var/backups/update/latest.cfg'])
assert(info.checksums and info.checksums['/boot.lua'],'manual installer did not use bundled verified checkpoint service')
local raw=assert(nativeLoadfile('system/boot/recovery.lua'))
assert(raw('--raw-rollback'))
assert(state.nodes['/VERSION']=='0.18.44\n' and state.nodes['/boot.lua']=='return "stable"')
assert(state.nodes['/home/user/documents/witness']=='user data')
local cfg=textutils.unserialize(state.nodes['/system/config/system.cfg'])
assert(cfg.vehicle=='witness' and cfg.customField==42 and cfg.safeMode and cfg.graphicsOptimizations==false)
local empty=assert(nativeLoadfile('tests/storage-fixture.lua'))()()
state=empty
fs.getFreeSpace=function() return 1000000 end
local ok,err=pcall(installer.install,files)
assert(ok,tostring(err))
assert(fs.exists('/VERSION') and not fs.exists('/var/tmp/mintcraft-install'))
loadfile=nativeLoadfile
print('distributable upgrade: isolated bundled checkpoint loader, actual installer, verified rollback and configuration preservation passed')
