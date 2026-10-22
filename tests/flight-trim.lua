package.path='./?.lua;'..package.path
local Trim=require('system.navigation.flight_trim')
local model={gains={kp=0.05}}
local s=Trim.new({mass=65,units={mass='kg'}})
assert(not Trim.observe(s,{mass=65.1,units={mass='kg'}}) and not s.active,'mass noise started adaptation')
assert(Trim.observe(s,{mass=52,units={mass='kg'}}) and s.active and s.bias==0,'mass event changed heat without measured error')
local function step(stamp,height,ack,requested,target)
 Trim.step(s,model,{timestamp=stamp,altitude=height,altitudeRate=0},target or 82,ack,requested,stamp)
end
step(10,84,10,10) step(10.25,84,10,10)
assert(s.bias<0 and s.bias>=-0.025,'lighter-vehicle trim sign/rate invalid')
local bias=s.bias
step(10.25,84,10,10) assert(s.bias==bias,'duplicate telemetry learned twice')
step(10.5,84,nil,10) assert(s.bias==bias,'missing receiver feedback learned trim')
step(10.5,84,99,10) assert(s.bias==bias,'future feedback learned trim')
step(10.5,84,1,10) assert(s.bias==bias,'stale feedback learned trim')
step(10.5,84,10.5,0) assert(s.bias==bias and s.saturated,'lower heat limit wound up integral')
Trim.step(s,model,{timestamp=10.75,altitude=84,altitudeRate=0},82,10.75,5,10.75,5,12)
assert(s.bias==bias and s.saturated,'configured heat limit ignored')
assert(Trim.observe(s,{mass=72,units={mass='kg'}}) and s.bias==bias,'second mass event discarded learned heat continuity')
step(11,80,11,10) assert(s.bias>bias,'heavier-vehicle correction has wrong sign')
for i=1,12 do step(11+i,82,11+i,10) end
assert(s.phase=='holding' and #s.window==8,'1 Hz receiver evidence never reached natural stability')
local offset=s.bias
Trim.step(s,model,{timestamp=1,altitude=80,altitudeRate=0},82,23,10,23)
assert(s.bias==offset,'stale height changed adaptive output')
assert(Trim.observe(s,{mass=0,units={mass='kg'}})==nil)
assert(Trim.observe(s,{mass=72,units={mass='g'}})==nil)
assert(s.referenceMass==65 and s.mass==72,'baseline provenance overwritten')
assert(Trim.status(s).bias==s.bias)
print('Airborne trim: no excitation, mass threshold, signed bumpless correction, fresh acknowledged measurements, anti-windup, 1 Hz stability evidence and unit/validity guards passed')
