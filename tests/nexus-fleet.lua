package.path='./?.lua;'..package.path
local fleet=require('system.nexus.fleet')
local observe=require('system.nexus.observe')
local policy={enabled=true,ids={1,2,3},group='a'}
local members={['1']={group='a'},['2']={group='a'},['3']={group='b'}}
local rows={}
for id=1,3 do rows[id]={seenAt=99,capabilities={'observe'},peripherals={{name='chest_0',kind='inventory'},{name='battery_0',kind='energy_storage'}}} end
local jobs={{node=1,state='sent'}}
local task=fleet.plan(rows,members,jobs,policy,{},100,1000)
assert(task.node==2,'Shared endpoint not assigned to least loaded authorized agent')
local assets={[task.asset]={attemptAt=1000}}
local second=fleet.plan(rows,members,jobs,policy,assets,100,1000)
assert(second.asset~=task.asset,'Duplicate polling of same shared endpoint')
jobs[#jobs+1]={node=2,state='sent',asset=second.asset}
assert(not fleet.plan(rows,members,jobs,policy,assets,100,1000),'Pending or recent endpoint scheduled twice')
rows[2].seenAt=1 rows[1].seenAt=1
assert(not fleet.plan(rows,members,{},policy,{},100,1000),'Stale owner selected')
rows[1].seenAt=99 rows[2].seenAt=99
rows[1].peripherals={{name='left',kind='inventory'}} rows[2].peripherals={{name='left',kind='inventory'}}
local first=fleet.plan(rows,members,{},policy,{},100,1000)
assert(first.asset=='1:left')
assert(fleet.plan(rows,members,{},policy,{['1:left']={attemptAt=1000}},100,1000).asset=='2:left','Local sides were incorrectly deduplicated')
os.epoch=function() return 1000000 end
local calls={}
peripheral={hasType=function(name,kind) return (name=='chest' and kind=='inventory') or (name=='battery' and kind=='energy_storage') or (name=='tank' and kind=='fluid_storage') end,
 call=function(name,method)
 calls[#calls+1]=method
 if name=='chest' then if method=='size' then return 27 elseif method=='list' then return {[2]={count=64},[19]={count=12}} end end
 if name=='battery' then return method=='getEnergy' and 500 or 1000 end
 if name=='tank' then return {{amount=2000},{amount=1000}} end
 error('No command should be invoked')
 end}
local inventory=observe.read('chest') assert(inventory.ok and inventory.items==76 and inventory.used==2)
assert(observe.read('battery').energy==500 and observe.read('tank').amount==3000)
assert(not observe.read('unknown').ok)
for _,name in ipairs(calls) do assert(name~='pushItems' and name~='setOutput' and name~='pullFluid','Observer performed a write') end
local clean=observe.normalize({ok=true,energy=0/0,error=string.rep('x',900),secret='hidden'})
assert(not clean.energy and #clean.error==120 and not clean.secret)
print('NEXUS fleet: shared endpoint deduplication, balanced owners, stale failover, local sides, read-only sensors and bounded reports passed')
