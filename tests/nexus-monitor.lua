package.path='./?.lua;'..package.path
local monitor=require('system.nexus.monitor')
local rules=assert(monitor.rules(monitor.defaults))
local invalid={} for key,value in pairs(rules) do invalid[key]=value end invalid.energyLowPercent=0/0
assert(not monitor.rules(invalid),'NaN threshold accepted')
local rows={[1]={seenAt=100,diskFree=2,diskCapacity=100,peripherals={{name='battery',kind='energy_storage'}}},[2]={seenAt=100,peripherals={{name='battery',kind='energy_storage'}}}}
local members={['1']={},['2']={}}
local assets={battery={owner=1,endpoint='battery',receivedAt=1000,result={ok=true,energy=5,capacity=100,measuredAt=1000000}},
 chest={owner=1,endpoint='chest',receivedAt=1000,result={ok=true,used=95,slots=100}}}
local alarms=monitor.evaluate(assets,rows,members,rules,{},100,1000)
assert(alarms['asset:battery:energy'] and alarms['asset:chest:full'] and alarms['agent:1:disk'])
assets.chest.result.partial=true assets.battery.result.capacity=0
local unknown=monitor.evaluate(assets,rows,members,rules,alarms,100,1000)
assert(unknown['asset:battery:energy'] and unknown['asset:chest:full'],'Partial/unknown capacity falsely resolved conditions')
assets.chest.result.partial=false assets.battery.result.capacity=100
assets.battery.result.energy=11 assets.chest.result.used=89 rows[1].diskFree=6
local held=monitor.evaluate(assets,rows,members,rules,alarms,100,1001)
assert(held['asset:battery:energy'] and held['asset:chest:full'] and held['agent:1:disk'],'Hysteresis failed')
assets.battery.result.energy=12 assets.chest.result.used=88 rows[1].diskFree=7
assert(not next(monitor.evaluate(assets,rows,members,rules,held,100,1002)),'Recovered threshold stayed active')
assets.battery.owner=2 assets.battery.sampleOwner=1
rows[1].seenAt=1
assert(not monitor.fresh(assets.battery,rows,100,1002,rules),'Owner change made old sample fresh')
assert(monitor.orphaned({type='observe',node=1,endpoint='battery'},rows,100))
assert(not monitor.orphaned({type='observe',node=2,endpoint='battery'},rows,100))
assert(not monitor.orphaned({type='sum',node=1},rows,100),'Non-observation mission automatically reassigned')
local stale=monitor.evaluate(assets,rows,members,rules,alarms,100,1002)
assert(stale['agent:1:offline'] and stale['asset:battery:stale'] and stale['asset:battery:energy'],'Lost data falsely resolved a condition')
assets.battery.lastError='Timed out'
assert(monitor.evaluate(assets,rows,members,rules,stale,100,1002)['asset:battery:fault'])
assets.battery.sampleOwner=2 assets.battery.lastError=nil assets.battery.result.measuredAt=800000
assert(not monitor.fresh(assets.battery,rows,100,1002,rules),'Old measurement with new receipt counted as fresh')
rules.enabled=false assert(not next(monitor.evaluate(assets,rows,members,rules,stale,100,1002)))
print('NEXUS monitoring: validated thresholds, hysteresis, sample provenance, stale data, lease guards and disabled alerts passed')
