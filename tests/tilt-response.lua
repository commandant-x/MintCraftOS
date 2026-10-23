package.path='./?.lua;'..package.path
local A=require('system.libraries.addon')
local C=require('system.ascendancy.contracts')
local T=require('system.navigation.tilt_response')
local q0={x=0,y=0,z=0,w=1}
local function q(upX,upZ)
 local n=math.sqrt(1+upX^2+upZ^2) local x,y,z=upX/n,1/n,upZ/n
 local length=math.sqrt(z*z+x*x+(1+y)^2)
 return {x=z/length,y=0,z=-x/length,w=(1+y)/length}
end
local function train(fault)
 local t=assert(T.new('ship',q0))
 for i=1,2000 do
  local now=20+i*.1 local ux=.025*math.sin(i*.031) local uz=.02*math.cos(i*.021)
  local vx=.5*math.sin(i*.017) local vz=.4*math.cos(i*.013) local ay=.1*math.sin(i*.019)
  local k={available=true,vehicleId='ship',frame='world',observedAt=now-.1,validUntil=now+.2,clock='local_uptime',clockId=C.clockId(),
   units={acceleration='block/s2',velocity='block/s'},position={x=5*math.sin(i*.007),y=80,z=4*math.cos(i*.011)},velocity={x=vx,y=0,z=vz},
   acceleration={x=9.8*ux-.2*vx+.01+ay*ux,y=ay,z=9.8*uz-.15*vz-.01+ay*uz}}
  if fault=='rank' then uz=0 vz=0 k.velocity.z=0 k.acceleration.z=0 end
  if fault=='noise' then k.acceleration.x=k.acceleration.x+2*math.sin(i*1.7) k.acceleration.z=k.acceleration.z+2*math.cos(i*1.3) end
  local pose={inSublevel=true,vehicleId=fault=='identity' and 'foreign' or 'ship',frame='world',timestamp=now,logicalPose={orientation=q(ux,uz)}}
  t:observe(k,pose,fault~='ack',now)
 end
 return t
end
local model=assert(train():fit())
assert(model.samples==2000 and math.abs(model.coefficients[1][1]-9.8)<.01 and math.abs(model.coefficients[2][2]-9.8)<.01)
assert(math.abs(model.coefficients[1][3]+.2)<.01 and math.abs(model.coefficients[2][4]+.15)<.01)
for _,fault in ipairs({'rank','noise','identity','ack'}) do assert(not train(fault):fit(),'unqualified passive tilt data accepted: '..fault) end
fs=setmetatable({},{__index=function() error('filesystem in passive tilt observer') end})
peripheral=setmetatable({},{__index=function() error('peripheral in passive tilt observer') end})
assert(train():fit())
print('Passive tilt identification: observed up/acceleration/velocity coupling, neutral acceleration correction, drag/wind separation, bounded sufficient statistics and rank/noise/identity/ACK refusals passed')
