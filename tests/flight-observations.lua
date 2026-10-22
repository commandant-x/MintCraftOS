package.path='./?.lua;'..package.path
local G=require('system.navigation.geometry')
local E=require('system.navigation.state_estimator')
local C=require('system.ascendancy.contracts')
local function near(a,b) assert(math.abs(a-b)<1e-7,tostring(a)..' ~= '..tostring(b)) end
local function qy(a) return {a=math.cos(a/2),v={x=0,y=math.sin(a/2),z=0}} end
local function pose(at,p,q,id) return {timestamp=at,identityAt=at,vehicleId=id or 'ship',inSublevel=true,frame='world',logicalPose={position=p,orientation=q}} end
local s=E.new() local base=10
for _,dt in ipairs({0,.1,.3}) do s:observe(pose(base+dt,{x=dt^2,y=70,z=0},qy(math.pi/2)),base+dt) end
local r=s:status(10.3)
assert(r.available and r.method=='finite-differences-of-world-poses' and r.clockId==C.clockId())
near(r.acceleration.x,2) near(r.response.forward,2) near(r.response.right,0) near(r.response.vertical,0)
near(r.observedAt,10.125) near(r.body.orientationAt,10.3)
assert(r.responseUnits.rotation=='deg/s2' and r.units.angularAcceleration=='rad/s2')
local oldUntil=r.validUntil r.response.forward=900
assert(s:status(10.3).response.forward~=900,'consumer changed internal observations')
s:observe(pose(10.3,{x=900,y=900,z=900},qy(0)),10.4)
assert(s:status(10.4).validUntil==oldUntil,'duplicate timestamp refreshed derivatives')
assert(not s:status(10.7).available,'expired response was kept live')
-- Constant world angular acceleration about body X after a world yaw of 90°.
s=E.new()
for _,dt in ipairs({0,.1,.2}) do
 local yaw,pitch=math.pi/2,dt^2
 local a,b=math.cos(yaw/2),math.sin(yaw/2) local c,d=math.cos(pitch/2),math.sin(pitch/2)
 local q={w=a*c,x=a*d,y=b*c,z=-b*d}
 s:observe(pose(20+dt,{x=0,y=70,z=0},q),20+dt)
end
r=s:status(20.2)
assert(r.available) near(r.angularAcceleration.z,-2) near(r.response.pitch,math.deg(2)) near(r.response.roll,0) near(r.response.yaw,0)
local angular=assert(G.angularVelocity(qy(0),qy(.1),.1)) near(angular.y,1)
local flipped=assert(G.angularVelocity(qy(0),{x=0,y=-math.sin(.05),z=0,w=-math.cos(.05)},.1)) near(flipped.y,1)
assert(not G.angularVelocity(qy(0),qy(math.pi),.1),'180 degree alias was certified')
s:observe(pose(20.3,{x=999,y=0,z=0},qy(0),'other'),20.3)
assert(not s:status(20.3).available and not s:status(20.3).velocity,'vehicle switch reused derivative history')
local bad=pose(20.4,{x=0,y=0,z=0},qy(0),'other') bad.frame='body_plot'
s:observe(bad,20.4) assert(not s:status(20.4).available)
bad.frame='world' bad.identityAt=1 s:observe(bad,20.4) assert(not s:status(20.4).available)
bad.identityAt=20.4 bad.timestamp=21 s:observe(bad,20.4) assert(not s:status(20.4).available)
s=E.new()
for i=1,3 do s:observe(pose(30+i*.1,{x=i,y=70,z=0},false),30+i*.1) end
r=s:status(30.3) assert(not r.available and r.acceleration and not r.response,'missing quaternion invented body axes')
s=E.new()
for i=1,3 do s:observe(pose(35+i*.1,{x=i%2==0 and -1e308 or 1e308,y=0,z=0},qy(0)),35+i*.1) end
assert(not s:status(35.3).available and not s:status(35.3).response,'overflow fabricated finite body response')
s=E.new()
for i=1,1000 do local t=40+i*.1 s:observe(pose(t,{x=t,y=70,z=0},qy(0)),t) end
r=s:status(140) assert(r.available and not s.previous.previous,'pose history grew unbounded')
local reads=0
package.loaded['system.services.flightd']={kinematics=function() reads=reads+1 return r end}
package.loaded['system.security.permissions']={require=function(_,permission) return permission~='sable.read','no-sable-read' end}
local Sources=require('system.ascendancy.sources')
assert(not Sources.read({},'navigation.kinematics',140).available and reads==0,'read permission was checked after cache access')
package.loaded['system.security.permissions'].require=function() return true end
assert(Sources.read({},'navigation.kinematics',140).available and reads==1)
print('Six-axis observations: world/body transforms, actual quaternion derivatives, nonuniform sampling, clock/frame/identity isolation, missing rotations, bounded history and authorized source reads passed')
