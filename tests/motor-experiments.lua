package.path='./?.lua;'..package.path
local M=require('system.navigation.experiments')
local Clock=require('system.ascendancy.contracts')
local function observation(t,linear,angular)
 return {available=true,clockId=Clock.clockId(),vehicleId='ship',frame='world',observedAt=t-.1,
  velocityAt=t-.05,velocity={x=0,y=0,z=0},units={acceleration='block/s2',angularAcceleration='rad/s2',velocity='block/s',angularVelocity='rad/s'},
  interval={first=t-.2,last=t},acceleration=linear or {x=0,y=0,z=0},angularAcceleration=angular or {x=0,y=0,z=0},angularVelocity={x=0,y=0,z=0}}
end
local s={at=10,vehicleId='ship',orientation={w=1,x=0,y=0,z=0},velocity={x=0,y=0,z=0},yawRate=0}
local probe={phase='baseline',steps={{side='left',gear=5,reverse=0}},index=1,rows={}}
local e=M.new()
for i=1,10 do s.at=10+i*.1 e:observe(probe,s,observation(s.at),true,11,10,10) end
assert(e.baseline.n>=4)
probe.phase='pulse' probe.appliedAt=11.1 e:transition(probe,'baseline',s)
for i=1,10 do s.at=11.1+i*.1 e:observe(probe,s,observation(s.at,{x=.1,y=0,z=.2},{x=.01,y=-.1,z=0}),true,11,11.1,11.1) end
probe.rows={{forward=.2}} probe.phase='brake' e:transition(probe,'pulse',s)
local summary=e:summary('ship')
assert(#summary.groups==1 and summary.groups[1].usable and summary.groups[1].samples>=3)
local r=summary.groups[1]
assert(math.abs(r.response[1]-.2)<1e-7 and math.abs(r.response[2]-.1)<1e-7 and math.abs(r.response[5]-math.deg(-.1))<1e-7)
assert(#r.operatingVelocity==6 and #r.neutralVelocity==6 and r.velocityObservedAt>r.responseObservedAt and r.referenceAt)
assert(r.notControlCertificate and r.observedMask>0 and r.noiseStdDev[1]<1e-7)
-- Fast probes can end before a complete derivative interval follows RX proof.
probe.phase='pulse' e:transition(probe,'baseline',s)
s.at=13 e:observe(probe,s,observation(s.at),true,11,13,13)
probe.rows={{forward=.9}} probe.phase='brake' e:transition(probe,'pulse',s)
assert(e:summary('ship').groups[1].usable and e:summary('ship').groups[1].command.gear==5,'short unqualified probe replaced useful measurements')
-- Changed heater is a confounder; never attribute its vertical effect to motor.
probe.steps={{side='right',gear=10,reverse=15}} probe.phase='baseline'
for i=1,10 do s.at=20+i*.1 e:observe(probe,s,observation(s.at),true,11,20,20) end
probe.phase='pulse' probe.appliedAt=21 e:transition(probe,'baseline',s)
for i=1,10 do s.at=21+i*.1 e:observe(probe,s,observation(s.at,{x=0,y=1,z=-.2}),true,12,21,21) end
probe.rows={{forward=-.2}} probe.phase='brake' e:transition(probe,'pulse',s)
summary=e:summary('ship') assert(#summary.groups==2 and not summary.groups[2].usable and summary.groups[2].otherHeatChanged)
assert(summary.scope=='motor-experiments-not-control-certificate' and summary.method:find('no new pulses',1,true))
local saved=assert(M.saved(summary,'ship')) assert(saved.historical and not M.saved(summary,'other'))
summary.groups[1].samples=999 assert(e:summary('ship').groups[1].samples~=999)
local denied=M.new() probe.phase='baseline' s.at=30
local bad=observation(30) bad.vehicleId='foreign' denied:observe(probe,s,bad,true,11,30,30)
assert(denied.baseline.n==0)
assert(not M.saved({schema=1,vehicleId='ship',scope='motor-experiments-not-control-certificate',groups={1,2,3,4,5}},'ship'))
-- A changed neutral heat must establish a new full post-ACK interval.
probe.phase='baseline' s.at=40
local reset=M.new()
for i=1,10 do s.at=40+i*.1 reset:observe(probe,s,observation(s.at),true,11,40,40) end
assert(reset.baseline.n>=4)
s.at=41.1 reset:observe(probe,s,observation(s.at),true,12,41.1,41.1)
assert(reset.baseline.n==0,'mixed pre-ACK heat derivative into neutral baseline')
local malformed=observation(41.2) malformed.interval.first='bad' s.at=41.2
reset:observe(probe,s,malformed,true,12,41.1,41.1) assert(reset.baseline.n==0)
-- The collector cannot mix another vessel into this experiment.
s.at=41.5 s.vehicleId='other' local other=observation(s.at) other.vehicleId='other'
reset:observe(probe,s,other,true,12,41.1,41.1) assert(reset.baseline.n==0)
s.vehicleId='ship'
-- Missing RX proof must not hide a heat command that changes and returns.
probe.phase='pulse' reset:transition(probe,'baseline',s)
reset.pulse.heat=11
reset:observe(probe,s,nil,false,12,nil,nil)
reset:observe(probe,s,nil,false,11,nil,nil)
assert(reset.pulse.heatChanged,'unacknowledged heat change was hidden')
print('Motor experiments: fixed reference, neutral subtraction, observed spread, full post-ACK intervals, heater confounding, bounded retained groups and no control certificate passed')
