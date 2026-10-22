package.path='./?.lua;'..package.path
local S=require('system.navigation.altitude_sweep')
local Model=require('system.navigation.altitude_model')
local p=S.defaults() p.autoPrepare=false p.autoHold=false
assert(p.first==7 and p.last==15 and p.dwell==nil and p.timeout==nil)
local invalid=S.defaults() invalid.first=math.huge assert(not S.validate(invalid))
invalid=S.defaults() invalid.last=8 assert(not S.validate(invalid))
local function simulate(noise)
 local sweep=assert(S.new(p,65,0)) local z,v=65,0
 for i=0,20000 do
  local now=i*0.1
  local signal=sweep:step({timestamp=now,altitude=z,altitudeRate=v+(noise and noise(now) or 0),inSublevel=true},now,now-sweep.stageAt>=1)
  if not signal then return sweep end
  v=v+(0.1*(30+5*signal-z)-0.6*v)*0.1 z=z+v*0.1
 end
 error('restoring plant never completed')
end
local result=simulate()
assert(result.state=='complete',result.reason)
assert(result.proposal,result.fitError)
assert(result.proposal.kind=='altitude-table' and #result.proposal.points==9)
assert(result.proposal.r2>0.99 and result.proposal.gains.kp>0 and result.proposal.gains.kd>=0)
assert(#result.samples<=9*40)
for heat=7,15 do
 local level=result.levels[heat]
 assert(level.settled and level.stableAltitude and math.abs(level.altitude-(30+5*heat))<0.6)
end
assert(Model.heatAt(result.proposal,80)>9 and Model.heatAt(result.proposal,80)<11)
assert(not Model.heatAt(result.proposal,10000),'altitude interpolation extrapolated')
local report=result:status(true) report.options.first=0 assert(result.options.first==7)
local noisy=simulate(function(t) return 0.08*math.sin(t*13) end)
assert(not noisy.proposal,'noisy dynamics generated an automatic controller')
local stable=assert(S.new(p,100,0))
for i=0,6 do local t=i*0.5 assert(stable:step({timestamp=t,altitude=100+0.05*t,altitudeRate=0.05,inSublevel=true},t,true)==7) end
assert(stable:step({timestamp=3.5,altitude=100.175,altitudeRate=0.05,inSublevel=true},3.5,true)==8)
assert(math.abs(stable.levels[7].altitude-100.0875)<1e-6,'mean settled altitude was not recorded')
-- A constant climb is not a stable height; no total/per-level/sample timeout.
local waiting=assert(S.new(p,100,0))
for i=0,4000 do
 local t=i*0.5 assert(waiting:step({timestamp=t,altitude=100+t,altitudeRate=1,inSublevel=true},t,true)==7)
end
assert(waiting.state=='running' and #waiting.samples==40 and waiting.levels[7].count==4001)
local crossing=assert(S.new(p,100,0))
for i=0,100 do local t=i*0.5
 assert(crossing:step({timestamp=t,altitude=100,altitudeRate=i%8==0 and 0 or 0.10001,inSublevel=true},t,true)==7,'single threshold crossing advanced')
end
local duplicate=assert(S.new(p,100,0))
for i=1,20 do duplicate:step({timestamp=0,altitude=100,altitudeRate=0,inSublevel=true},0,true) end
assert(#duplicate.samples==1 and duplicate.signal==7)
local gap=assert(S.new(p,100,0))
for _,t in ipairs({0,0.5,1,1.5,3.5,4,4.5,5}) do
 assert(gap:step({timestamp=t,altitude=100,altitudeRate=0,inSublevel=true},t,true)==7,'gapped samples qualified')
end
local missing=assert(S.new(p,100,0))
assert(not missing:step({timestamp=0,altitude=100,altitudeRate=0,inSublevel=false},0,true))
local constrained=S.defaults() constrained.maxSpeed=2 constrained.maxTravel=10
local limited=assert(S.new(constrained,100,0))
assert(not limited:step({timestamp=0,altitude=100,altitudeRate=3,inSublevel=true},0,true))
limited=assert(S.new(constrained,100,0))
assert(not limited:step({timestamp=0,altitude=111,altitudeRate=0,inSublevel=true},0,true))
constrained.maxSpeed=false assert(not S.validate(constrained))
local regressed=assert(S.new(p,100,0))
regressed:step({timestamp=1,altitude=100,altitudeRate=0,inSublevel=true},1,false)
assert(not regressed:step({timestamp=0.9,altitude=100,altitudeRate=0,inSublevel=true},0.9,false))
print('altitude sweep: measured |V/S| <=0.1, stable height table, no time/sample deadline, bounded RAM, no single zero crossing, actual dynamic qualification and no extrapolation passed')
