package.path='./?.lua;'..package.path
local S=require('system.navigation.altitude_sweep')
local P=require('system.navigation.sweep_progress')
local options=S.defaults() options.autoPrepare=false options.autoHold=false options.certify=false
local function sweep() return assert(S.new(options,100,0)) end
local function step(s,i,y,v,ack)
 local t=i*.5 return s:step({timestamp=t,altitude=y,altitudeRate=v,inSublevel=true},t,ack~=false)
end
-- A steady climb is identified from measurements, but never certified or timed out.
local climb=sweep()
for i=0,10000 do assert(step(climb,i,100+i*.5,1)==7) end
local d=climb:status().diagnostic
assert(climb.state=='running' and not climb.proposal and not climb.levels[7].settled)
assert(d.state=='steady-motion' and d.noProgress and d.comparedWindows==8)
assert(d.clock=='sweep_elapsed' and d.signal==7 and d.meanSpeed==1)
assert(#climb.samples==40 and #climb.levels[7].tail==8)
assert(climb.reason:find('Steady ascent',1,true) and climb.reason:find('eight separate windows',1,true))
-- Refused/stale receiver proof cannot create progress or hide the waiting reason.
local n=climb.levels[7].count
assert(step(climb,10001,6000,1,false)==7 and climb.levels[7].count==n)
assert(climb.reason:find('every burner receiver',1,true))
-- Reaching a stable measured altitude later remains possible with no restart.
for i=10002,10016 do step(climb,i,6000,0) end
assert(climb.signal==8 and climb.levels[7].settled and climb.levels[7].altitude==6000)
assert(not climb:status().diagnostic or climb:status().diagnostic.signal==8,'old heat diagnostic attributed to new heat')
-- Non-overlapping measured windows, not UI redraws or elapsed wall time.
local progress=P.new()
local function level(t,rates,spread)
 local tail={} for i=1,8 do tail[i]={time=t+(i-1)*.5,rate=rates and rates[i] or 1,altitude=100} end
 return {signal=7,tail=tail,windowSpan=3.5,altitudeSpread=spread or 1,speedSlope=0,steadySpeed=not rates,stableAltitude=false}
end
local l=level(0)
for i=1,1000 do progress:observe(l) end
assert(progress.total==1 and #progress.windows==1 and not progress:status().noProgress)
-- Repeated direction reversals identify oscillation without claiming success.
local oscillating=sweep()
for i=0,100 do step(oscillating,i,100+(i%2)*2,i%2==0 and 1 or -1) end
assert(oscillating.signal==7 and oscillating:status().diagnostic.state=='oscillating')
-- Improving responses are not labelled stalled; only measured reductions count.
local improving=P.new()
for i=0,7 do improving:observe(level(i*4,{1-i*.1,1-i*.1,1-i*.1,1-i*.1,1-i*.1,1-i*.1,1-i*.1,1-i*.1})) end
assert(improving:status().comparedWindows==8 and not improving:status().noProgress)
-- No contradictory inference from highest possible heat: authority remains unproved.
local maximum=P.new() l=level(0) l.signal=15 maximum:observe(l)
assert(maximum:status().atMaximumHeat and maximum:status().reason:find('authority not established',1,true))
-- Data gaps clear comparative evidence rather than counting stale windows.
l=level(40) l.tail[4].time=l.tail[4].time+1.3 progress:observe(l)
assert(#progress.windows==0 and not progress:status().noProgress and progress:status().state=='gathering')
local copy=oscillating:status() copy.diagnostic.state='fake'
assert(oscillating:status().diagnostic.state=='oscillating')
assert(climb:abort('operator stop')==nil and climb.state=='aborted')
print('Sweep progress: bounded independent windows, measured climb/oscillation/improvement, no deadline or false qualification, receiver wait, gap reset and actual later stability passed')
