package.path='./?.lua;'..package.path
local fixture=assert(loadfile('tests/storage-fixture.lua'))()
for _,mode in ipairs({'service','raw'}) do
 local state=fixture()
 state.config('/var/backups/update/latest.cfg',{id='1'})
 state.config('/var/backups/update/1/manifest.cfg',{id='1',paths={'/VERSION','/system'}})
 state.put('/var/backups/update/1/VERSION','old')
 state.put('/var/backups/update/1/system/security/users.db','old credentials and roles')
 state.put('/var/backups/update/1/system/libraries/code.lua','old code')
 state.put('/VERSION','new')
 state.put('/system/security/users.db','current credentials, roles and session')
 state.config('/system/config/system.cfg',{personal='preserve'})
 local ok,err
 if mode=='raw' then ok,err=assert(loadfile('system/boot/recovery.lua'))('--raw-rollback')
 else ok,err=require('system.services.updated').rollback() end
 assert(ok,err)
 assert(state.nodes['/system/security/users.db']=='current credentials, roles and session',mode..' reverted live credentials')
 assert(state.nodes['/var/backups/update/1/system/security/users.db']=='old credentials and roles','checkpoint was mutated')
 assert(state.nodes['/system/libraries/code.lua']=='old code' and state.nodes['/VERSION']=='old')
end
print('legacy tree rollback: service and raw Recovery retain current credentials/roles/session without changing checkpoint')
