package.path="./?.lua;"..package.path
local S=require("system.navigation.altitude_sweep")
local p=S.defaults()
assert(p.first==7 and p.last==15)
assert(not S.validate({first=7,last=15,dwell=6,maxTravel=math.huge,maxSpeed=1,timeout=120}))
local small=S.defaults() small.last=8 assert(not S.validate(small))
local function simulate(options,noise)
 local self=assert(S.new(options,100,0))
 local z,v,u=100,0,options.first
 for i=0,1800 do
  local now=i*0.1
  local signal=self:step({timestamp=now,altitude=z,altitudeRate=v+(noise and noise(now) or 0),inSublevel=true},now,now-self.stageAt>=1)
  if not signal then return self end
  u=signal
  v=v+(0.05*(u-11)-v)/2*0.1 z=z+v*0.1
 end
 error("sweep did not terminate")
end
local result=simulate(p)
assert(result.state=="complete",result.reason)
assert(result.proposal,result.fitError)
assert(math.abs(result.proposal.hover-11)<0.1 and math.abs(result.proposal.tau-2)<0.2)
assert(result.proposal.gains.kp>0 and result.proposal.gains.ki>0 and result.proposal.gains.kd==0)
assert(#result.samples<=360 and result.proposal.r2>0.99)
local report=result:status(true) assert(#report.samples>20 and report.levels[7] and report.levels[15])
assert(not report.levels[7].stableAltitude,"steady climb mislabeled as stable altitude")
local old=result.options.first report.options.first=0 assert(result.options.first==old)
local bad=simulate(p,function(t) return 0.1*math.sin(t*13) end)
assert(not bad.proposal,"noisy response generated automatic gains")
local outside=S.defaults() outside.first=12 outside.last=15
local noHover=simulate(outside)
assert(not noHover.proposal,"extrapolated hover outside measured range")
local duplicate=assert(S.new(p,100,0))
for i=1,10 do duplicate:step({timestamp=0,altitude=100,altitudeRate=0,inSublevel=true},0,true) end
assert(#duplicate.samples==1,"duplicate sensor data re-counted")
assert(not duplicate:step({timestamp=0,altitude=109,altitudeRate=0,inSublevel=true},0,true))
assert(duplicate.reason:find("travel",1,true))
local lost=assert(S.new(p,100,0))
assert(not lost:step({timestamp=0,altitude=100,altitudeRate=0,inSublevel=false},0,false))
local fast=assert(S.new(p,100,0))
assert(not fast:step({timestamp=0,altitude=100,altitudeRate=1.1,inSublevel=true},0,false))
local regressed=assert(S.new(p,100,0))
regressed:step({timestamp=1,altitude=100,altitudeRate=0,inSublevel=true},1,false)
assert(not regressed:step({timestamp=0.9,altitude=100,altitudeRate=0,inSublevel=true},0.9,false))
print("altitude sweep: 7..15 dynamic identification, PI/hover fit, no extrapolation/noisy guesses, duplicate data and bounded motion/time/clock guards passed")
