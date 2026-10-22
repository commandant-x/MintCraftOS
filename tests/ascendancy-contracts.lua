package.path='./?.lua;'..package.path
-- Test fixtures only; production readers use the existing real service caches.
local allowed,reads=true,0
os.clock=function() return 10 end
os.epoch=function() return 10000 end
package.loaded['system.security.permissions']={require=function() return allowed,'denied' end}
local pose={inSublevel=true,vehicleId='ship-a',frame='world',timestamp=9.8,identityAt=9.8,logicalPose={position={x=1,y=70,z=3},orientation={a=1,v={x=0,y=0,z=0}}}}
package.loaded['system.services.sabled']={pose=function() reads=reads+1 return pose end}
local Contract=require('system.ascendancy.contracts')
local Sources=require('system.ascendancy.sources')
allowed=false local denied=Sources.read({pid=7},'sable.pose',10) assert(not denied.available and reads==0 and not denied.payload)
allowed=true local result=Sources.read({pid=7},'sable.pose',10)
assert(result.available and result.observedAt==9.8 and result.payload.logicalPose.position.x==1)
result.payload.logicalPose.position.x=999 result.units.position='wrong'
assert(pose.logicalPose.position.x==1 and Sources.read(nil,'sable.pose',10).units.position=='block','consumer mutated source/units')
assert(not Sources.read(nil,'sable.pose',11).available,'cache read renewed stale observation')
pose.timestamp=11 assert(not Sources.read(nil,'sable.pose',10).available,'future pose accepted') pose.timestamp=9.8
local unknown=Sources.read(nil,'astral.cosmonautics',10) assert(not unknown.available and not unknown.payload and not unknown.frame,'unregistered future adapter invented data')
local bad={} bad.self=bad assert(not Contract.clone(bad)) assert(not Contract.clone({x=0/0})) assert(Contract.clone(false)==false)
local function observation(frame,id)
 return {schema=1,valid=true,source='sable.pose',origin='observed',entityId='ship-a',field='position',kind='position',frame=frame or 'world',unit='block',namespace='minecraft:overworld',vehicleId=id or 'ship-a',clock='local_uptime',clockId=Contract.clockId(),observedAt=9.8,validUntil=10.3,value={x=1,y=70,z=3}}
end
local a,b=observation(),observation()
assert(Contract.compatible(a,b,10)) b.namespace='other-world' assert(not Contract.compatible(a,b,10))
a,b=observation('body_plot','a'),observation('body_plot','b') assert(not Contract.compatible(a,b,10),'different vessel plots fused')
a,b=observation(),observation() b.unit='m' assert(not Contract.compatible(a,b,10),'units silently converted')
b=observation() b.clockId='different-boot' assert(not Contract.compatible(a,b,10),'different clocks treated as fresh')
b=observation() b.valid=false assert(not Contract.validateObservation(b,10),'invalid source measurement treated as valid')
b=observation() b.synthetic=true assert(not Contract.validateObservation(b,10),'synthetic position accepted')
b=observation() b.namespace=nil assert(not Contract.compatible(a,b,10),'missing namespace inferred')
local state=assert(loadfile('tests/storage-fixture.lua'))()()
local map={schema=1,type='atlas-map',frame='world',unit='block',namespace='minecraft:overworld',entries={observation()}}
local text=assert(Contract.encodeMap(map)) local decoded=assert(Contract.decodeMap(text))
assert(decoded.entries[1].value.y==70 and decoded.entries[1].observedAt==9.8)
map.entries[1].clockId='old-boot' assert(Contract.encodeMap(map),'historical map incorrectly required current boot')
map.entries[1].frame='body_plot' assert(not Contract.encodeMap(map),'untransformed plot saved as world map')
assert(not Contract.decodeMap('not a map'))
local route=require('system.navigation.autopilot').defaults() route.points={{x=1,y=70,z=3}}
local mission={schema=1,type='waypoint-mission',frame='world',unit='block',namespace='minecraft:overworld',vehicleId='ship-a',route=route}
assert(not Contract.validateMission(mission),'mission validation fabricated physical verification')
route.translationVerified=true route.clearRouteConfirmed=true route.verifiedVehicleId='ship-a' assert(Contract.validateMission(mission))
mission.vehicleId='other' assert(not Contract.validateMission(mission))
assert(Contract.statusFor(result,10).state=='ready' and Contract.statusFor(result,11).state=='unavailable')
assert(not Sources.collect(nil,{[2]='sable.pose'},10))

assert(Contract.statusFor(result,10).reason=='Fresh source cache')
assert(not Sources.read(nil,'sable.pose',false).available)
local zero=observation() zero.value={x=0,y=0,z=0} assert(Contract.validateObservation(zero,10),'real zero coordinates rejected')
zero.value.z=nil assert(not Contract.validateObservation(zero,10),'missing coordinate became zero')
assert(not Contract.clone({oversized=string.rep('x',Contract.maxPayloadBytes+1)}))
assert(not Contract.clone({callback=function() end}))

pose.identityAt=1 assert(not Sources.read(nil,'sable.pose',10).available,'stale vessel identity paired with fresh position')
pose.identityAt=9.8 local original=pose.logicalPose pose.logicalPose=nil
assert(not Sources.read(nil,'sable.pose',10).available,'missing position marked as ready pose') pose.logicalPose=original


pose.synthetic=true assert(not Sources.read(nil,'sable.pose',10).available,'explicit synthetic source accepted') pose.synthetic=nil
print('ASCENDANCY contracts: authorized real-cache reads, freshness/provenance, immutable payloads, unavailable adapters, frame/unit/vessel/clock isolation, persistent map roundtrip and non-actuating mission validation passed')
