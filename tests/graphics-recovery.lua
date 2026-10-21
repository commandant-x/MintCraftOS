package.path='./?.lua;'..package.path
local fixture=assert(loadfile('tests/storage-fixture.lua'))()
local state=fixture()
local updated=require('system.services.updated')
state.put('/VERSION','0.18.44') state.put('/system/code.lua','return "stable"')
state.put('/home/user/documents/witness','personal')
state.put('/system/config/vehicle.cfg','vehicle and keys')
assert(updated.createRollback('test',{'VERSION','system/code.lua','system/added.lua'}))
local info=updated.rollbackInfo()
state.put('/VERSION','0.18.45') state.put('/system/code.lua','return "new"') state.put('/system/added.lua','return true')
local raw=assert(loadfile('system/boot/recovery.lua'))
local backup=info.path..'/system/code.lua'
local original=state.nodes[backup]
state.nodes[backup]='corrupt'
assert(not updated.rollback()) assert(state.nodes['/VERSION']=='0.18.45')
assert(not raw('--raw-rollback')) assert(state.nodes['/VERSION']=='0.18.45')
state.nodes[backup]=nil assert(not raw('--raw-rollback')) assert(state.nodes['/VERSION']=='0.18.45')
state.nodes[backup]=original
-- Failure between files retains the resume journal and the checkpoint.
state.hook=function(action,path) if action=='move' and path=='/system/code.lua' then error('power loss') end end
assert(not raw('--raw-rollback'))
assert(fs.exists('/var/tmp/mintcraft-rollback.cfg') and fs.exists(backup))
state.hook=nil
assert(raw('--resume-rollback'))
assert(state.nodes['/VERSION']=='0.18.44' and state.nodes['/system/code.lua']=='return "stable"')
assert(not fs.exists('/system/added.lua'))
assert(state.nodes['/home/user/documents/witness']=='personal')
assert(state.nodes['/system/config/vehicle.cfg']=='vehicle and keys')
assert(updated.createRollback('next update',{'VERSION'}))
local Guard=require('system.boot.graphics_guard')
local clock=os.clock local now=0 os.clock=function() return now end
local guard=Guard.begin({}) assert(guard.state=='pending')
assert(Guard.begin({}).state=='safe','incomplete boot retried graphics')
assert(Guard.retry()) guard=Guard.begin({})
Guard.observe(guard,{backend='PIXEL256'}) now=1
Guard.observe(guard,{backend='PIXEL256'}) assert(guard.state=='pending')
Guard.observe(guard,{backend='PIXEL256'}) assert(guard.state=='healthy')
Guard.fail(guard,'palette failed') assert(Guard.begin({}).state=='safe')
assert(Guard.begin({safeMode=true}).state=='safe')
os.clock=clock
print('graphics recovery: corrupt/missing checkpoint refusal, interrupted raw rollback/resume, user preservation, subsequent checkpoint and boot guard passed')
