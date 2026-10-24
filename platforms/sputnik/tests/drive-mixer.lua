-- Pure demands and synthetic measured-RPM tables; no physical actuation.
local M=assert(loadfile('platforms/sputnik/src/drive_mixer.lua'))()
local function check(drive,turn,left,right,mode)
 local out=assert(M.differential(drive,turn,mode))
 assert(math.abs(out.left-left)<1e-10 and math.abs(out.right-right)<1e-10,'wrong bank mixing')
end
check(1,0,1,1) check(-1,0,-1,-1) check(0,1,-1,1) check(0,-1,1,-1)
check(1,1,0,1) check(1,-1,1,0) check(-1,1,-1,0) check(-1,-1,0,-1)
check(.4,1,0,1) check(1,.5,.5,1)
check(.5,.25,.25,.75,'blend') check(1,1,0,1,'blend')
assert(not M.differential(0/0,0) and not M.differential(0,2) and not M.differential(0,0,'unknown'))
local curve={{signal=15,rpm=0},{signal=11,rpm=64},{signal=3,rpm=200}}
assert(M.transmission(0,curve).signal==15,'transmission 15 invented as maximum thrust')
assert(M.transmission(64,curve).signal==11)
assert(M.transmission(32,curve).signal==15,'tie should select lower measured RPM')
assert(not M.transmission(201,curve) and not M.transmission(-1,curve),'unmeasured RPM extrapolated')
assert(not M.transmission(12,{{signal=1,rpm=0},{signal=1,rpm=10}}))
for i=0,10 do for j=-10,10 do for k=-10,10 do
 local c=i/10 local lift=assert(M.quadLift(c,j/10,k/10)) local sum=0
 for _,name in ipairs({'frontLeft','frontRight','rearLeft','rearRight'}) do
  assert(lift[name]>=-1e-10 and lift[name]<=1+1e-10,'unbounded lift demand') sum=sum+lift[name]
 end
 assert(math.abs(sum/4-c)<1e-10,'attitude saturation changed collective demand')
end end end
assert(not M.quadLift(0/0,0,0) and not M.quadLift(1.1,0,0))
-- Native node exposes demands only, never actuator writes.
local v={Drive=1,['Left turn']=1,['Lift collective']=.6,['Front bias']=.1,['Right bias']=-.1}
local outputValues={}
input=function(name) return v[name] or 0 end
output=function(name,value) outputValues[name]=value end
ui={label=function() return {setText=function() end} end} addElement=function() end
transmitWirelessRedstone=function() error('mixer must not actuate') end writePeripheral=transmitWirelessRedstone
local node=assert(loadfile('platforms/sputnik/dist/mintcraft-drive-mixer.lua'))
node() assert(outputValues['Left signed demand']==0 and outputValues['Right signed demand']==1)
local previous={} for name,value in pairs(outputValues) do previous[name]=value end
v['Drive STOP']=1 node()
assert(outputValues['Left signed demand']==0 and outputValues['Right signed demand']==0)
for _,name in ipairs({'Front left lift demand','Front right lift demand','Rear left lift demand','Rear right lift demand'}) do
 assert(outputValues[name]==previous[name],'horizontal STOP changed vertical demand')
end
assert(outputValues['Flight qualified']==0)
print('Venator demands: forward/reverse/pivot/neutral steering, shared ratio limits, four independent bounded lifts, collective priority, measured-only nonextrapolating RPM selection and horizontal STOP preserving lift passed; no actuation')
-- New profiles do not alter the old differential console or write actuators.
assert(M.balloon(-.7,.4,.6).reverseRequested)
for i=-10,10 do
 local b=assert(M.balloon(.2,i/10,.6))
 assert(b.steerLeft*b.steerRight==0,'both spring directions requested')
end
assert(not M.balloon(2,0,.5))
assert(not M.quadIntent(1,0,10,false),'unmeasured tilt enabled')
assert(not M.quadIntent(1,0,31,true),'unmeasured/unbounded tilt envelope')
local q=assert(M.quadIntent(1,1,10,true))
assert(math.abs(math.sqrt(q.forwardTilt^2+q.leftTilt^2)-10)<1e-10)
assert(q.yawAvailable==false,'rotor yaw invented')
v={Profile=1,['Forward demand']=-.7,['Left demand']=.4,['Collective demand']=.6}
outputValues={}
local vehicle=assert(loadfile('platforms/sputnik/dist/mintcraft-vehicle-mixer.lua'))
vehicle()
assert(outputValues['Single drive demand']==-.7 and outputValues['Reverse requested']==1)
assert(outputValues['Spring left demand']==.4 and outputValues['Spring right demand']==0)
v['Horizontal STOP']=1 vehicle()
assert(outputValues['Single drive demand']==0 and outputValues['Single lift demand']==.6)
v={Profile=2,['Forward demand']=1,['Collective demand']=.6,['Front correction']=.1,['Measured tilt limit deg']=10}
vehicle()
assert(outputValues['Profile valid']==0 and outputValues['Tilt target valid']==0)
assert(outputValues['Lift valid']==1 and outputValues['Front left demand']>.6,'unavailable horizontal response cut lift')
v['Tilt response qualified']=1 vehicle()
assert(outputValues['Forward tilt target deg']==10 and outputValues['Profile valid']==1)
v['Horizontal STOP']=1 vehicle()
assert(outputValues['Forward tilt target deg']==0 and outputValues['Front left demand']==.6 and outputValues['Rear right demand']==.6)
assert(outputValues['Yaw available']==0 and outputValues['Flight qualified']==0)
v.Profile=99 vehicle() assert(outputValues['Profile valid']==0 and outputValues['Lift valid']==0)
print('Balloon five-channel demands and quad body-tilt intents: exclusive spring, independent lift validity, no invented yaw, no actuator writes passed')
