local P=assert(loadfile('platforms/sputnik/src/aero_physics.lua'))()
local Q=assert(loadfile('platforms/sputnik/src/quad_control.lua'))() Q.Physics=P
-- Oracle rows produced by real Sable BezierResourceFunction.evaluateFunction.
for line in io.lines('platforms/sputnik/tests/fixtures/sable-pressure.csv') do
 local y,v=line:match('([^,]+),([^,]+)') assert(math.abs(P.pressure(tonumber(y))-tonumber(v))<1e-12,'Sable pressure mismatch at '..y)
end
assert(P.rpm(256,0)==256 and P.rpm(256,15)==0 and P.rpm(256,7)==128)
local levels={256,224,208,192,176,160,144,128,112,96,80,64,48,32,16,0}
for signal=0,15 do assert(P.rpm(256,signal)==levels[signal+1],'wrong transmission state '..signal) end
for rpm=0,256 do
 local signal=assert(P.signal(256,rpm))
 assert(math.abs(P.rpm(256,signal)-rpm)<1e-9,'bypass inverse mismatch')
end
assert(P.rpm(256,.5)==240 and P.rpm(256,1)==224,'fractional mix does not match adjacent integer RPM')
assert(P.force(240,1,0,1,.1)==240)
assert(P.force(240,1,12,1,.1)==120 and P.force(240,1,-12,1,.1)==240)
assert(P.force(240,1,30,1,.1)==0 and P.force(0,1,0,1,.1)==0)
local spec={source=256,thrust=1,airflow=.1,armX=3,armZ=3,height=0,gravity=11}
local pose={tick=100,mass=65,ix=250,iz=250,x=0,y=80,z=0,pitch=0,roll=0,yaw=0,dimension='minecraft:overworld'}
local rows,diag=assert(P.rows(spec,pose))
assert(rows[1][4]<0 and rows[1][5]>0 and rows[1][6]>0,'front-left moments/transmission sign')
assert(not P.rows(spec,{dimension='custom:moon'}),'unknown dimension accepted')
local bad={} for k,v in pairs(pose) do bad[k]=v end bad.mass=1000
assert(not P.rows(spec,bad),'impossible lift accepted')
local lower=rows[1][1];bad.mass=pose.mass;bad.y=100
assert(P.rows(spec,bad)[1][1]<lower,'thin air did not increase RPM')
local config={physics=spec,speed=1,climb=.5,tilt=6}
-- Preserve passive rotational damping; don't invert it through lagged rotors.
local originalRows=P.rows;local sampledVelocity
P.rows=function(s,p,v) if v then sampledVelocity=v end return originalRows(s,p,v) end
local dampingPose={} for key,value in pairs(pose) do dampingPose[key]=value end
local dampingCore=assert(Q.new(nil,dampingPose,config))
dampingPose.tick=dampingPose.tick+1;dampingPose.pitch=1;dampingPose.roll=-1
assert(dampingCore:step(dampingPose,{forward=0,left=0,vertical=0}))
assert(dampingCore.rates.pitch~=0 and sampledVelocity.pitch==0 and sampledVelocity.roll==0,'rotational airflow damping was cancelled')
P.rows=originalRows
local core=assert(Q.new(nil,pose,config))
local rates={x=0,y=0,z=0,pitch=0,roll=0}
local rpm={} for i,r in ipairs(rows) do rpm[i]=P.rpm(spec.source,r[1]) end
local function step(command)
 pose.tick=pose.tick+1
 local signals,info=core:step(pose,command) assert(signals,info)
 local up={-math.sin(math.rad(pose.roll)),math.cos(math.rad(pose.pitch))*math.cos(math.rad(pose.roll)),math.sin(math.rad(pose.pitch))*math.cos(math.rad(pose.roll))}
 local sum,mx,mz=0,0,0
 local locations={{-3,3},{3,3},{-3,-3},{3,-3}}
 for i,loc in ipairs(locations) do
  -- Independent plant: steady transmission, actual 0.15 spool interpolation,
  -- local air inflow, density at each rotor, moment arms and actual mass/inertia.
  local target=signals[i]==0 and 256 or 256*(1-(signals[i]+1)/16)
  rpm[i]=rpm[i]+.15*(target-rpm[i])
  local vy=rates.x*up[1]+rates.y*up[2]+rates.z*up[3]+math.rad(rates.roll)*loc[1]-math.rad(rates.pitch)*loc[2]
  local pressure=P.pressure(pose.y+loc[1]*math.sin(math.rad(pose.roll))*math.cos(math.rad(pose.pitch))-loc[2]*math.sin(math.rad(pose.pitch)))
  local factor=rpm[i]>.03334 and math.max(0,math.min(1,(.1*rpm[i]-vy)/(.1*rpm[i]))) or 0
  local force=rpm[i]*pressure*factor
  sum=sum+force mx=mx-loc[2]*force mz=mz+loc[1]*force
 end
 local a={x=up[1]*sum/pose.mass-.3*rates.x,y=up[2]*sum/pose.mass-11-.2*rates.y,z=up[3]*sum/pose.mass-.3*rates.z,pitch=math.deg(mx/pose.ix)-.2*rates.pitch,roll=math.deg(mz/pose.iz)-.2*rates.roll}
 for _,key in ipairs({'x','y','z','pitch','roll'}) do rates[key]=rates[key]+a[key]*.05 pose[key]=pose[key]+rates[key]*.05 end
 return info
end
local neutral={forward=0,left=0,vertical=0}
for _=1,100 do step(neutral) end
for _=1,40 do step({forward=0,left=0,vertical=1}) end
for _=1,600 do step(neutral) end
assert(math.abs(pose.y-81)<.25,'physics altitude did not settle: '..pose.y)
local startZ=pose.z;local maxZ=startZ
for _=1,40 do step({forward=.5,left=0,vertical=0});maxZ=math.max(maxZ,pose.z) end
for _=1,600 do step(neutral);maxZ=math.max(maxZ,pose.z) end
-- The slower translation loop may capture a release position below 0.2m, then
-- return there after braking. Check actual movement AND return to that target,
-- rather than requiring a minimum final displacement away from the hold point.
assert(maxZ-startZ>.2 and math.abs(pose.z-core.target.z)<.2 and math.abs(rates.z)<.2 and math.abs(pose.y-81)<.3,'physics forward/brake lost stability')
pose.mass=60;pose.ix=230;pose.iz=230
for _=1,600 do step(neutral) end
assert(math.abs(pose.y-81)<.3 and math.abs(rates.y)<.15,'mass/inertia adaptation lost target')
assert(core.diagnostics.required==660 and core.target.y>80.99 and core.target.y<81.01)
print('Audited Aero physics: actual Sable pressure oracle, zero bypass and 1..15 transmission states, velocity-dependent thrust, mass/inertia/geometry auto model, spool-lag altitude/tilt/braking and in-flight mass update passed; simulated plant only')

-- Heavy aircraft hovers between physical states 0 (256) and 1 (224 RPM).
pose={tick=1000,mass=85,ix=350,iz=350,x=0,y=64,z=0,pitch=0,roll=0,yaw=0,dimension='minecraft:overworld'}
rates={x=0,y=0,z=0,pitch=0,roll=0};rpm={}
local heavyRows=assert(P.rows(spec,pose))
assert(heavyRows[1][1]>0 and heavyRows[1][1]<1,'zero-bypass blend domain not exercised')
for i,r in ipairs(heavyRows) do rpm[i]=P.rpm(spec.source,r[1]) end
core=assert(Q.new(nil,pose,config))
for _=1,100 do step(neutral) end
for _=1,20 do step({forward=0,left=0,vertical=1}) end
for _=1,800 do step(neutral) end
assert(math.abs(pose.y-64.5)<.3 and math.abs(rates.y)<.2,'zero-bypass interpolation destabilized heavy quad')
print('Zero bypass regression: heavy quad between actual 256/224-RPM states climbs and holds in the lagged simulation')
