-- Contract fixtures above cover commands; this suite isolates acquisition clocks.
dofile("tests/combat-audit.lua")
local combat=require("system.services.combatd")
local addon=require("system.libraries.addon")
package.loaded["system.libraries.config"].load=function() return {radars={},profiles={}} end
package.loaded["system.services.sabled"].status=function() return {inSublevel=false} end
local now,tick=100,100
os.clock=function() return now end
local counts,devices={},{}
local lastRevision,lastPublishAt,partials=nil,nil,0
local retainCheck=false
local prior
local function step(name,method)
  now=now+0.03
  counts[method]=(counts[method] or 0)+1
  local snap=combat.snapshot()
  if snap.acquisition and snap.acquisition.pending>0 and snap.revision~=lastRevision then
    if lastPublishAt then assert(snap.timestamp-lastPublishAt>=0.2-1e-8,"partial publication exceeded 5 Hz") end
    lastRevision,lastPublishAt=snap.revision,snap.timestamp partials=partials+1
    assert(not combat.solution("none","none"),"incomplete cycle allowed command")
    if prior then
      for _,row in ipairs(snap.radars) do if row.id=="d" and row.pending then
        assert(row.timestamp==prior.timestamp and row.stale,"pending radar timestamp refreshed")
        retainCheck=true
      end end
      local found=false
      for _,row in ipairs(snap.targets) do if row.id=="d" then found=true end end
      assert(found,"pending target disappeared from partial snapshot")
    end
  end
end
for _,name in ipairs({"a","b","c","d"}) do
  local id=name
  devices[id]={getTracks=function() step(id,"getTracks") return {{id=id,scannedTime=tick,position={x=0,y=0,z=100}}} end,
    getPosition=function() step(id,"getPosition") return {x=0,y=0,z=0} end,
    getRange=function() step(id,"getRange") return 1000 end,
    getRotation=function() step(id,"getRotation") return tick end,
    getRotationSpeed=function() step(id,"getRotationSpeed") return 1 end,
    getDishCount=function() step(id,"getDishCount") return 2 end}
end
peripheral={getNames=function() return {"a","b","c","d"} end,getType=function() return "create_radar:radar_bearing" end,
  getMethods=function(id) local result={} for key in pairs(devices[id]) do result[#result+1]=key end return result end,
  wrap=function(id) return devices[id] end}
local scheduler={processes={},spawn=function() return 2 end,start=function() end,kill=function() end}
combat.start({scheduler=scheduler}) combat.acquire(true)
local first=combat.snapshot()
assert(first.acquisition.overrun and first.acquisition.pending==0 and first.acquisition.completed==4)
assert(first.acquisition.elapsed>0.7 and not first.acquisition.effectiveHz,"first cycle claimed achieved cadence")
assert(first.radars[4].timestamp>first.radars[1].timestamp,"all device observations stamped at cycle start")
for _,row in ipairs(first.radars) do
  assert(row.measurements.position.timestamp==row.fieldTimes.observedAt.getPosition)
  assert(row.measurements.range.timestamp==row.fieldTimes.observedAt.getRange)
end
assert(counts.getRange==4 and counts.getDishCount==4 and counts.getRotationSpeed==4)
prior=first.radars[4]
tick=tick+1 combat.acquire(false)
local second=combat.snapshot()
assert(retainCheck and partials>=2,"pending rows not retained/published during overrun")
assert(counts.getTracks==8 and counts.getRotation==8 and counts.getPosition==8,"fast radar fields cached")
assert(counts.getRange==4 and counts.getDishCount==4 and counts.getRotationSpeed==4,"slow radar metadata polled above 1 Hz")
assert(second.radars[4].measurements.range.timestamp==prior.measurements.range.timestamp,"cached range date refreshed")
assert(second.acquisition.effectiveHz and second.acquisition.effectiveHz<5,"overrun cadence misreported as 5 Hz")
assert(combat.stop())

-- Renamed/removed radar sources retire to two safety booleans, not unbounded maps.
local source="source1"
peripheral.getNames=function() return {source} end
peripheral.getMethods=function() return {"getTracks","getPosition","getRange"} end
peripheral.wrap=function() return {
  getTracks=function() return {{id="shared",scannedTime=tick,position={x=0,y=0,z=100},friendly=source=="source1"}} end,
  getPosition=function() return {x=0,y=0,z=0} end,getRange=function() return 1000 end} end
combat.start({scheduler=scheduler}) combat.acquire(true)
for i=2,140 do
  source="source"..i tick=tick+1 now=now+0.01 combat.acquire(true)
  local target=combat.snapshot().targets[1]
  local count=0 for _ in pairs(target.observations) do count=count+1 end
  assert(count==1 and target.retiredFriendly and target.friendly,"gone source leaked or safety tombstone cleared")
end
source="empty"
peripheral.wrap=function() return {getTracks=function() return {} end} end
now=now+11 combat.acquire(true)
assert(#combat.snapshot().targets==0,"retired safety evidence survived contact eviction")
assert(combat.stop())
peripheral.getNames=function() local ids={} for i=1,130 do ids[i]="source"..i end return ids end
peripheral.wrap=function() return {getTracks=function() return {{id="overflow",scannedTime=tick,position={x=0,y=0,z=100},friendly=false}} end} end
combat.start({scheduler=scheduler}) combat.acquire(true)
local overflow=combat.snapshot().targets[1]
local count=0 for _ in pairs(overflow.observations) do count=count+1 end
assert(count==128 and overflow.classificationUncertain,"source overflow not bounded/fail-closed")
assert(combat.stop())
print("combat acquisition: per-getter clocks, metadata cache, throttled retained partials, cadence and bounded retired classifications passed")
