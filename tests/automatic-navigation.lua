package.path='./?.lua;'..package.path
local A=require('system.libraries.addon') local Setup=require('system.navigation.automatic_setup') local Cache=require('system.navigation.automatic_setup')
local control={mode='altitude',channels={{backend='frequency',name='tx',link={first='minecraft:white_wool',second='minecraft:white_wool'}}},balloonSetup={vehicleId='ship',burnerIds={'b'}}}
local snap={vehicleId='ship',ok=true,inventoryComplete=true,mass=10,units={mass='kg'},actuators={},mechanics={},links={}}
assert(Setup.plan(snap,control,{{backend='frequency',name='tx'}}))
for i,side in ipairs({'left','right'}) do
 local ids={side..'p',side..'c',side..'g',side..'r'} local x=i*8
 snap.actuators[#snap.actuators+1]={id=ids[1],geometryValid=true,position={x=x,y=0,z=0},direction={x=0,y=0,z=1}}
 for k,role in ipairs({'other','clutch','gear','reverse'}) do
  local p={x=x,y=0,z=k*3}
  snap.mechanics[#snap.mechanics+1]={id=ids[k],role=role,position=p,sourceId=ids[k+1]}
  if k>1 then snap.links[#snap.links+1]={receiver=true,position={x=x+1,y=0,z=p.z},first={item='minecraft:'..side..role},second={item='minecraft:iron_ingot'}} end
 end
end
local c=assert(Setup.plan(snap,control,{{backend='frequency',name='tx'}}))
assert(c.drivetrain.enabled and c.drivetrain.left.clutch.first=='minecraft:leftclutch' and c.drivetrain.right.reverse.first=='minecraft:rightreverse')
assert(not control.drivetrain,'passive proposal mutated configuration')
local bad=A.copy(snap);bad.mechanics[2].sourceId=nil assert(not Setup.plan(bad,control,{{backend='frequency',name='tx'}}),'missing actual source path replaced with proximity guess')
bad=A.copy(snap);bad.mechanics[4].sourceId='leftp' assert(not Setup.plan(bad,control,{{backend='frequency',name='tx'}}),'source cycle accepted')
bad=A.copy(snap);bad.links[#bad.links+1]=A.copy(bad.links[1]) assert(not Setup.plan(bad,control,{{backend='frequency',name='tx'}}),'ambiguous RX accepted')
local model={kind='altitude-table',r2=.99,points={{heat=7,altitude=50},{heat=8,altitude=55},{heat=9,altitude=60}},hover=8,neutral=8,tau=2,
 dynamics={stiffness=.1,damping=.5,heatAcceleration=.5},gains={kp=.05,ki=0,kd=0,limit=2,slew=.25,integralLimit=0,deadband=.1},measuredRange={first=7,last=9,minAltitude=50,maxAltitude=60}}
local report={schema=2,state='complete',structureFingerprint=string.rep('a',64),vehicleId='ship',mass=10,massUnit='kg',model=model}
assert(Cache.candidate(report,report.structureFingerprint,snap))
for _,change in ipairs({function(r)r.mass=1 end,function(r)r.massUnit='unknown'end,function(r)r.model.gains.kp=1/0 end,function(r)r.model.points[2]=true end,function(r)r.model.measuredRange.last=15 end,function(r)r.vehicleId='other'end,function(r)r.model.r2=.2 end}) do
 local r=A.copy(report) change(r) assert(not Cache.candidate(r,report.structureFingerprint,snap))
end
assert(not Cache.candidate(report,string.rep('b',64),snap)) assert(not Cache.candidate(report,nil,snap))
print('automatic navigation: actual source-chain mapping, ambiguity/cycle refusal, immutable proposals and bounded structure/mass/model reuse checks passed')
