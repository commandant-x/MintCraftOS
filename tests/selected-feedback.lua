package.path='./?.lua;'..package.path
local A=require('system.libraries.addon')
A.configure({readsPerTick=100000})
A.bounded=function(fn) return pcall(fn) end
parallel={waitForAll=function(...) for _,f in ipairs({...}) do f() end end}
local now=10 os.clock=function() return now end
local calls=0
local raw={schema=1,ok=true,readOnly=true,frame='body_plot',vehicleId='ship',units={position='block'},revision=100,ageTicks=0,
 complete=true,centerOfMass={x=2,y=3,z=4},features={},actuators={},links={{id='rx',receiver=true,position={x=1,y=0,z=0},first={item='minecraft:iron_ingot'},second={item='minecraft:gold_ingot'},signal=7}}}
local fast={schema=1,ok=true,readOnly=true,scope='selected-known-nodes-not-inventory',vehicleId='ship',frame='body_plot',units={position='block'},
 revision=101,observedAtGameTick=101,ageTicks=0,requested=1,selectionComplete=true,missing={},links=A.copy(raw.links),burners={},mechanics={},actuators={}}
mintcraft_vehicle={snapshot=function() return A.copy(raw) end,feedback=function(id,selection)
 calls=calls+1 assert(id=='ship' and #selection==1 and selection[1]=='rx') return A.copy(fast)
end}
local B=require('system.services.vehiclebridged')
local lease={}
B.acquire() assert(B.snapshot().ok)
local inventoryAt=B.snapshot().observedAt
assert(not B.requestFeedback('foreign',{'rx'},lease))
assert(not B.requestFeedback('ship',{'unknown'},lease))
assert(not B.requestFeedback('ship',{'rx','rx'},lease))
assert(B.requestFeedback('ship',{'rx'},lease))
assert(not B.requestFeedback('ship',{'rx'},{}),'another job replaced the active lease')
assert(not B.releaseFeedback({}),'another job cancelled the active lease')
now=10.1 B.acquireFeedback()
local selected=B.selectedSnapshot()
assert(selected.ok and selected.observedAt==10.1 and selected.validUntil==10.6 and not selected.inventoryComplete and not selected.complete and selected.centerOfMass==nil)
assert(B.snapshot().observedAt==inventoryAt and B.snapshot().centerOfMass.x==2,'selected read refreshed or replaced geometry provenance')
selected.links[1].signal=99 assert(B.selectedSnapshot().links[1].signal==7,'consumer mutated selected cache')
now=10.3 B.acquireFeedback() assert(B.selectedSnapshot().observedAt==10.1,'repeated game tick refreshed freshness')
now=10.7 B.acquireFeedback() assert(not B.selectedSnapshot().ok,'stale selected sample remained valid')
fast.revision=102 fast.observedAtGameTick=102 B.acquireFeedback() assert(B.selectedSnapshot().ok)
-- Failure cannot erase the previous successful clock and allow a later replay.
fast.revision=99 fast.observedAtGameTick=99 now=10.8 B.acquireFeedback() assert(not B.selectedSnapshot().ok)
fast.revision=100 fast.observedAtGameTick=100 now=10.9 B.acquireFeedback() assert(not B.selectedSnapshot().ok)
fast.revision=103 fast.observedAtGameTick=103 now=11 B.acquireFeedback() assert(B.selectedSnapshot().ok)
fast.links[1].id='unrequested' now=11.1 B.acquireFeedback() assert(not B.selectedSnapshot().ok)
fast.links={} fast.missing={'rx'} fast.selectionComplete=false fast.revision=104 fast.observedAtGameTick=104
now=11.2 B.acquireFeedback() assert(not B.selectedSnapshot().ok and B.selectedSnapshot().missing[1]=='rx')
fast.links=A.copy(raw.links) fast.missing={} fast.selectionComplete=true fast.revision=105 fast.observedAtGameTick=105
now=11.3 B.acquireFeedback() assert(B.selectedSnapshot().ok)
fast={ok=false,code='BUSY'} now=11.4 B.acquireFeedback() assert(B.selectedSnapshot().ok,'busy discarded still-fresh physical evidence')
now=12.1 B.acquireFeedback() assert(not B.selectedSnapshot().ok,'expired read lease remained valid')
local before=calls B.acquireFeedback() assert(calls==before,'unsubscribed worker kept reading the bridge')
mintcraft_vehicle.feedback=nil assert(not B.requestFeedback('ship',{'rx'},lease),'legacy bridge invented selected-feedback support')
assert(B.snapshot().observedAt==inventoryAt)
print('Selected feedback: explicit known-node scope, immutable separate cache, no invented COM or inventory freshness, clock/replay and missing-node guards, BUSY expiry, lease STOP and legacy compatibility passed')
