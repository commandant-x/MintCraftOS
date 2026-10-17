package.path='./?.lua;'..package.path
local fixture=dofile('tests/storage-fixture.lua')
fixture()
os.getComputerID=function() return 1 end
os.getComputerLabel=function() return 'test' end
local now=10
os.clock=function() return now end
os.epoch=function() return 1700000000000+now*1000 end
local wire=require('system.nexus.protocol')
local module=require('system.nexus.agent')
local sent,calls={},0
peripheral={getNames=function() return {'back','chest'} end,getType=function(name) return name=='back' and 'modem' or 'inventory' end,
 hasType=function(name,kind) return (name=='back' and kind=='modem') or (name=='chest' and kind=='inventory') end,
 call=function(_,method)
 calls=calls+1
 if method=='size' then coroutine.yield('task_complete') return 27 end
 assert(method=='list') return {[1]={count=12}}
 end}
rednet={isOpen=function() return true end,send=function(_,packet) sent[#sent+1]=packet return true end}
local cfg={role='agent',id=1,master=0,key=string.rep('k',64),active='release'}
local agent=module.new(cfg,{defer=true})
local function packet(label) return wire.sign(cfg.key,0,1,'mission',label,{id='observe-job',type='observe',endpoint='chest',expiresAt=os.epoch('utc')+120000}) end
assert(agent:receive(0,packet('first'),wire.name) and calls==0)
local worker=coroutine.create(function() agent:workStep() end)
assert(coroutine.resume(worker)) assert(coroutine.status(worker)=='suspended')
now=now+1 agent:tick()
assert(#sent==1 and wire.verify(cfg.key,1,0,sent[1]).kind=='heartbeat','Suspended read blocked heartbeat')
assert(agent:receive(0,packet('retry'),wire.name) and #agent.work==0,'Pending observation executed twice')
assert(coroutine.resume(worker)) assert(coroutine.status(worker)=='dead' and calls==2)
assert(wire.verify(cfg.key,1,0,sent[#sent]).body.result.items==12)
assert(agent:receive(0,packet('receipt'),wire.name) and calls==2,'Completed observation executed twice')
print('NEXUS agent: suspended peripheral worker, live heartbeat, bounded queue and idempotent observation passed')
