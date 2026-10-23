package.path='./?.lua;'..package.path
local A=require('system.libraries.addon')
local G=require('system.navigation.geometry')
local R=require('system.navigation.response_model')
local Controller=require('system.navigation.measured_controller')
local Estimator=require('system.navigation.state_estimator')
local function mul(a,b)
 return {w=a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z,x=a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,
 y=a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,z=a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w}
end
local function rotation(x,y,z)
 local n=math.sqrt(x*x+y*y+z*z)
 if n<1e-12 then return {x=0,y=0,z=0,w=1} end
 local f=math.sin(n/2)/n return {x=x*f,y=y*f,z=z*f,w=math.cos(n/2)}
end
local function world(v,q)
 return assert(G.transform(v,{position={x=0,y=0,z=0},rotationPoint={x=0,y=0,z=0},scale={x=1,y=1,z=1},orientation=q}))
end
local basis={}
for j=1,6 do basis[j]={0,0,0,0,0,0} basis[j][j]=j<=3 and .8 or 4 end
local cases={
 {name='balloon',matrix={{0,0,.8,0,0,0}}},
 {name='airship',matrix={{.4,0,0,0,-2,0},{.4,0,0,0,2,0},{0,0,.8,0,0,0}}},
 {name='thrusters',matrix=basis},
 {name='multirotor',gravity=9.8,matrix={{0,0,.3,-4,4,-4},{0,0,.3,-4,-4,4},{0,0,.3,4,-4,-4},{0,0,.3,4,4,4}}},
 {name='asymmetric',matrix={{.4,0,0,0,-2,0},{1.2,0,0,0,1,0},{0,0,.8,0,0,0}}},
 {name='offset-mass',matrix={{.8,0,0,.2,0,0},{0,.8,0,0,0,.2},{0,0,.8,.2,0,.2},{0,0,0,4,0,0},{0,0,0,0,4,0},{0,0,0,0,0,4}}},
 {name='failed-motor',matrix={{0,0,.3,-4,4,-4},{0,0,.3,-4,-4,4},{0,0,.3,4,-4,-4},{0,0,0,0,0,0}}},
 {name='changed-mass',matrix=basis,massFactor=.7},
 {name='sensor-loss',matrix=basis,lost=true}}
for _,case in ipairs(cases) do
 local columns=A.copy(case.matrix)
 if case.massFactor then for _,col in ipairs(columns) do for i=1,6 do col[i]=col[i]*case.massFactor end end end
 local channels,rows={},{}
 for j,col in ipairs(columns) do
  channels[j]={id='c'..j,min=0,max=15,neutral=7,rescue=0}
  for _,sign in ipairs({-1,1}) do
   local values,extent,rates={},{},{}
   for i=1,6 do values[i]=col[i]*sign extent[i]=2*math.abs(col[i]) rates[i]=2*math.abs(col[i]) end
   rows[#rows+1]={id='c'..j,signal=7+sign,response=values,noise={0,0,0,0,0,0},samples=8,baselineSamples=8,
    after=10,first=10.2,last=11,vehicleId='ship',singleCommand=true,otherOutputsChanged=false,excursion=extent,maxRate=rates,worldExcursion=extent,worldMaxRate=rates}
  end
 end
 local model=assert(R.fit(channels,rows,{vehicleId='ship',frame='body_orientation_at_neutral_reference',translationUnit='block/s2',rotationUnit='deg/s2'}))
 local estimator=Estimator.new()
 local now,p,v,q,w=20,{x=0,y=80,z=0},{x=0,y=0,z=0},{x=0,y=0,z=0,w=1},{x=0,y=0,z=0}
 local function pose() return {vehicleId='ship',frame='world',inSublevel=true,timestamp=now,identityAt=now,logicalPose={position=A.copy(p),orientation=A.copy(q)}} end
 for _=1,5 do now=now+.1 estimator:observe(pose(),now) end
 local k=estimator:status(now)
 local controller,why=Controller.new(model,pose(),k)
 if case.name=='failed-motor' then
  assert(not controller,'three coupled fixed-pitch rotors invented four independent controls')
 else
  controller=assert(controller,why)
  local target=A.copy(p) local x,y,z=0,0,0
  if controller.axes.forward then target.z=target.z+.25 end
  if controller.axes.right then target.x=target.x+.25 end
  if controller.axes.vertical then target.y=target.y+.25 end
  if controller.axes.pitch then x=math.rad(1) end
  if controller.axes.yaw then y=math.rad(1) end
  if controller.axes.roll then z=math.rad(1) end
  assert(controller:target(target,rotation(x,y,z)))
  local fraction={}
  for tick=1,1500 do
   k=estimator:status(now)
   if case.lost and tick==100 then k.validUntil=now-1 end
   local values,issue=controller:step(k,pose(),tick%10~=5,now)
   if case.lost and tick==100 then assert(not values and issue:find('stale',1,true)) break end
   assert(values,case.name..': '..tostring(issue))
   local acceleration={0,0,0,0,0,0}
   local signals=assert(R.quantize(controller.allocationModel,values,fraction))
   for j,col in ipairs(columns) do
    local signal=signals['c'..j]
    assert(signal>=6 and signal<=8,'controller left the actually measured local output domain')
    for i=1,6 do acceleration[i]=acceleration[i]+col[i]*(signal-7) end
   end
   local linear=world({x=acceleration[2],y=acceleration[3]+(case.gravity or 0),z=acceleration[1]},q)
   linear.y=linear.y-(case.gravity or 0)
   local angular=world({x=math.rad(acceleration[4]),y=math.rad(acceleration[5]),z=math.rad(acceleration[6])},q)
   for _,axis in ipairs({'x','y','z'}) do
    v[axis]=v[axis]+(linear[axis]-.2*v[axis])*.1 p[axis]=p[axis]+v[axis]*.1
    w[axis]=w[axis]+(angular[axis]-.2*w[axis])*.1
   end
   q=assert(G.orientation(mul(rotation(w.x*.1,w.y*.1,w.z*.1),q)))
   now=now+.1 estimator:observe(pose(),now)
  end
  if not case.lost then
   local s=controller:status()
   if case.gravity then assert(not controller.axes.forward and not controller.axes.right and math.abs(p.x)+math.abs(p.z)>1,'tilting rotor fixture hid its real unqualified lateral drift') end
   for i,axis in ipairs(R.axes) do if controller.axes[axis] then
    assert(math.abs(s.error[i])<(i<=3 and .08 or .3),case.name..' did not settle '..axis..': '..s.error[i])
    assert(math.abs(s.rates[i])<controller.rateTolerance[i],case.name..' did not brake '..axis..': '..s.rates[i])
   end end
  end
 end
end
print('Measured feedback physics: nine simplified architectures, coupled asymmetric/offset allocation, real pose/quaternion derivatives, 16-level outputs, unavailable axes, braking and stale-sensor refusal passed; simulation only')
