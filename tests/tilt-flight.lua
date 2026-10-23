-- Synthetic calibrated rotor plant. Tests actual estimator, qualification and
-- passive tilt discovery; this does not inject a model into the flight service.
package.path='./?.lua;'..package.path
local A=require('system.libraries.addon')
local G=require('system.navigation.geometry')
local R=require('system.navigation.response_model')
local C=require('system.navigation.measured_controller')
local Q=require('system.navigation.closed_loop_qualification')
local T=require('system.navigation.tilt_response')
local K=require('system.navigation.known_flight')
local E=require('system.navigation.state_estimator')
local function mul(a,b) return {w=a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z,x=a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,y=a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,z=a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w} end
local function rotation(w,dt)
 local n=math.sqrt(w.x^2+w.y^2+w.z^2)
 if n<1e-12 then return {x=0,y=0,z=0,w=1} end
 local f=math.sin(n*dt/2)/n return {x=w.x*f,y=w.y*f,z=w.z*f,w=math.cos(n*dt/2)}
end
local function world(v,q) return assert(G.transform(v,{position={x=0,y=0,z=0},rotationPoint={x=0,y=0,z=0},scale={x=1,y=1,z=1},orientation=q})) end
local matrix={{0,0,.3,-4,4,-4},{0,0,.3,-4,-4,4},{0,0,.3,4,-4,-4},{0,0,.3,4,4,4}}
local channels,rows={},{}
for j,col in ipairs(matrix) do
 channels[j]={id='rotor-'..j,min=0,max=15,neutral=7,rescue=0}
 for _,sign in ipairs({-1,1}) do
  local response,extent,rate={},{},{}
  for i=1,6 do response[i]=col[i]*sign extent[i]=math.abs(col[i])*2 rate[i]=math.abs(col[i])*2 end
  rows[#rows+1]={id='rotor-'..j,signal=7+sign,response=response,noise={0,0,0,0,0,0},samples=8,baselineSamples=8,after=10,first=10.2,last=11,vehicleId='ship',singleCommand=true,otherOutputsChanged=false,excursion=extent,maxRate=rate,worldExcursion=extent,worldMaxRate=rate}
 end
end
local model=assert(R.fit(channels,rows,{vehicleId='ship',frame='body_orientation_at_neutral_reference',translationUnit='block/s2',rotationUnit='deg/s2'}))
local now,p,v,q,w=20,{x=0,y=80,z=0},{x=0,y=0,z=0},{x=0,y=0,z=0,w=1},{x=0,y=0,z=0}
local function pose() return {vehicleId='ship',frame='world',inSublevel=true,timestamp=now,identityAt=now,logicalPose={position=A.copy(p),orientation=A.copy(q)}} end
local estimator=E.new()
for _=1,5 do now=now+.1 estimator:observe(pose(),now) end
local job=assert(K.new(channels,'ship',2,true))
job.model=model job.controller=assert(C.new(model,pose(),estimator:status(now)))
job.qualification=assert(Q.new(job.controller)) job.tiltObserver=assert(T.new('ship',q))
job.phase='qualifying' job.quantizer={} job.worldBounds={minY=79,maxY=81}
local function tick()
 job:applied(job.generation,now-.1)
 job:step(estimator:status(now),pose(),true,now,now)
 assert(job.state~='aborted',job.reason)
 local acceleration={0,0,0,0,0,0}
 for j,col in ipairs(matrix) do
  local signal=job.values['rotor-'..j]
  assert(signal%1==0 and signal>=6 and signal<=8,'unmeasured rotor value')
  for i=1,6 do acceleration[i]=acceleration[i]+col[i]*(signal-7) end
 end
 local linear=world({x=acceleration[2],y=9.8+acceleration[3],z=acceleration[1]},q) linear.y=linear.y-9.8
 local angular=world({x=math.rad(acceleration[4]),y=math.rad(acceleration[5]),z=math.rad(acceleration[6])},q)
 for _,axis in ipairs({'x','y','z'}) do
  v[axis]=v[axis]+(linear[axis]-.2*v[axis])*.1 p[axis]=p[axis]+v[axis]*.1
  w[axis]=w[axis]+(angular[axis]-.2*w[axis])*.1
 end
 q=assert(G.orientation(mul(rotation(w,.1),q)))
 now=now+.1 estimator:observe(pose(),now)
end
for i=1,12000 do
 tick()
 if job.active then break end
 assert(i<12000,'tilt qualification did not finish: '..job.reason..' / '..tostring(job.tiltError)..' / '..job.qualification.index)
end
assert(job.attitudeQualification and #job.attitudeQualification.checks==12,'attitude qualification was skipped')
assert(job.tiltModel and job.controller.strategy=='measured-tilt' and #job.qualification.checks==6,'lateral flight was not separately qualified')
local x,z=p.x,p.z
local target=A.copy(job.controller.position) target.x=target.x+.4 target.z=target.z+.4
assert(job.controller:target(target,job.controller.reference))
for _=1,2500 do tick() end
assert(math.abs(p.x-target.x)<.15 and math.abs(p.z-target.z)<.15,'measured tilt did not settle on requested X/Z')
assert(math.abs(p.y-target.y)<.15 and math.sqrt(v.x^2+v.z^2)<.15,'lateral flight lost altitude or braking')
assert(job.controller.tiltObserver==nil,'controller performed its own peripheral observations')
print('Measured multirotor physics: real gravity/thrust-direction drift, production quaternion derivatives, existing attitude trials, passive lateral fit, separate X/Z motion/return checks, 16-level control and local target braking passed; simulation only')
