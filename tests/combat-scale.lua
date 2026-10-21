-- Reuse the command safety fixture's API mocks, then exercise 24 wired radars
-- reporting the same 15 players. Optional baseline module supports comparison.
local hostClock=os.clock
dofile("tests/combat-audit.lua")
local addon=require("system.libraries.addon")
local combat=assert(loadfile(arg and arg[1] or "system/services/combatd.lua"))()
package.loaded["system.libraries.config"].load=function() return {radars={},profiles={}} end
local now,scan=100,100
os.clock=function() return now end
local devices,ids={},{}
for i=1,24 do
  local id="radar"..i ids[i]=id
  devices[id]={getTracks=function()
    local rows={}
    for j=1,15 do rows[j]={id="player"..j,scannedTime=scan,category="entity",position={x=j,y=64,z=100},friendly=j==1,synthetic=false} end
    return rows
  end,getPosition=function() return {x=i,y=64,z=0} end,getRotation=function() return 0 end,
    getRange=function() return 1000 end,getRotationSpeed=function() return 1 end,getDishCount=function() return 2 end}
end
peripheral={getNames=function() return ids end,getType=function() return "create_radar:radar_bearing" end,
  getMethods=function(id) local out={} for key in pairs(devices[id]) do out[#out+1]=key end return out end,
  wrap=function(id) return devices[id] end}
combat.start({scheduler={processes={},spawn=function() return 1 end,start=function() end,kill=function() end}})
combat.acquire(true)
local copied=0 local copy=addon.copy
addon.copy=function(...) copied=copied+1 return copy(...) end
local begin=hostClock()
for _=1,40 do
  now=now+0.05 scan=scan+1 combat.acquire(false)
  if combat.displaySnapshot then combat.displaySnapshot() else combat.snapshot() end
end
local elapsed=hostClock()-begin
local snapshot=combat.snapshot()
assert(#snapshot.radars==24 and #snapshot.targets==15)
for _,t in ipairs(snapshot.targets) do
  local sources=0 for _ in pairs(t.observations) do sources=sources+1 end
  assert(sources==24 and t.freshnessKnown and not t.stale)
  assert(t.friendly==(t.id=="player1") and t.synthetic==false)
end
local fullCopies=copied
if combat.displaySnapshot then
  copied=0 local display=combat.displaySnapshot() local displayCopies=copied
  copied=0 combat.snapshot() local commandCopies=copied
  assert(displayCopies<commandCopies*0.8,"UI projection retained private per-radar evidence")
  assert(not display.targets[1].observations and #display.targets[1].history>0)
  display.targets[1].position.x=-999 assert(combat.snapshot().targets[1].position.x~=-999,"UI mutated command evidence")
  print("display copy nodes: "..displayCopies.." / full "..commandCopies)
end
assert(combat.stop()) addon.copy=copy
print(string.format("24 wired radars, 15 players, 40 cycles: CPU %.6fs, copy calls %d; safety classifications preserved",elapsed,fullCopies))
