package.path='./?.lua;'..package.path
local A=require('system.libraries.addon') local G=require('system.navigation.equipment_groups') local L=require('system.navigation.link_output') local D=require('system.navigation.drivetrain') local Auto=require('system.navigation.automatic_setup')
parallel={waitForAll=function(...) for _,f in ipairs({...}) do f() end end}
local s={ok=true,available=true,inventoryComplete=true,burnerDiscoveryAvailable=true,vehicleId='ship',burners={},links={},actuators={},mechanics={},observedAt=20}
for i=1,2 do
 local p={x=i*6,y=10,z=0}
 s.burners[i]={id='b'..i,position=p}
 s.links[#s.links+1]={id='brx'..i,receiver=true,position={x=p.x+1,y=10,z=0},first={item='minecraft:white_wool',dyedColor=i},second={item='minecraft:iron_ingot'},signal=0}
end
local function motor(i,x)
 local prefix='m'..i local ids={prefix..'p',prefix..'c',prefix..'g',prefix..'r'}
 s.actuators[#s.actuators+1]={id=ids[1],position={x=x,y=0,z=0},geometryValid=true,direction={x=0,y=0,z=1}}
 for k,role in ipairs({'other','clutch','gear','reverse'}) do
  s.mechanics[#s.mechanics+1]={id=ids[k],position={x=x,y=0,z=k*4},role=role,sourceId=ids[k+1]}
  if k>1 then s.links[#s.links+1]={id=prefix..'rx'..k,receiver=true,position={x=x+1,y=0,z=k*4},first={item='minecraft:'..prefix..role},second={item='minecraft:iron_ingot'},signal=0} end
 end
end
for i,x in ipairs({-20,-10,10,20}) do motor(i,x) end
local groups=G.discover(s)
assert(#groups.burners==2 and #groups.burnerIds==2 and #groups.motors==4 and #groups.unmappedMotors==0)
local c,_,discovered=assert(Auto.plan(s,{channels={},sensors={},gains={},manualInputs={}},{{name='tx',backend='frequency'}}))
assert(#c.channels==1 and #c.balloonSetup.burnerIds==2 and #L.keys(c.channels[1])==2,'burner groups not multiplexed into collective command')
assert(c.drivetrain.enabled and #c.drivetrain.left.clutch.members==1 and #c.drivetrain.right.gear.members==1)
assert(#discovered.banks==2 and #discovered.banks[1].actuatorIds==2 and discovered.banks[1].commandGroups==2)
local calls={}
local row={device={sendLinkSignal=function(first,second,value,color) calls[#calls+1]={first=first,second=second,value=value,color=color} return true end}}
assert(L.write(row,c.channels[1],7)) assert(#calls==2 and calls[1].color~=calls[2].color and calls[1].value==7 and calls[2].value==7,'group lost frequency colors or output members')
row.device.sendLinkSignal=function(...) calls[#calls+1]={...} return #calls%2~=0 end
assert(not L.write(row,c.channels[1],0) and #calls==4,'partial refusal hid another group member')
row.device.sendLinkSignal=function(...) calls[#calls+1]={...} if #calls%2==0 then error('wire failed') end return true end
assert(not pcall(L.write,row,c.channels[1],0) and #calls==6,'uncertain write lost group rescue/error semantics')
local vals=D.commands(c.drivetrain,{left={gear=3,reverse=15},right={gear=7,reverse=0}})
for _,channel in ipairs(D.channels(c.drivetrain)) do
 for _,r in ipairs(s.links) do for _,k in ipairs(L.keys(channel)) do if L.receiverKey(r)==k then r.signal=vals[channel.id] end end end
end
assert(D.feedback(c.drivetrain,s,vals,19) and D.observed(c.drivetrain,s))
s.links[#s.links].signal=4 assert(not D.feedback(c.drivetrain,s,vals,19),'missing/wrong bank member hidden by primary RX')
local overlap=A.copy(c.drivetrain) overlap.left.clutch.members[1]={first='minecraft:white_wool',second='minecraft:iron_ingot',firstColor=1}
assert(not D.validate(overlap,c.channels),'burner overlap in a secondary motor frequency accepted')
-- Two propellers on the same source chain are one physical command group.
local shared=A.copy(s) shared.actuators={shared.actuators[1],A.copy(shared.actuators[1])} shared.actuators[2].id='shared-prop'
shared.mechanics[#shared.mechanics+1]={id='shared-prop',position={x=-18,y=0,z=0},role='other',sourceId='m1c'}
local same=G.discover(shared) assert(#same.motors==1 and #same.motors[1].actuatorIds==2)
local vertical=assert(Auto.plan(shared,{channels={},sensors={},gains={},manualInputs={}},{{name='tx',backend='frequency'}}))
assert(not vertical.drivetrain,'one shared source chain invented independent yaw')
local missing=A.copy(s) table.remove(missing.links,2)
assert(not Auto.plan(missing,{mode='altitude',channels={A.copy(c.channels[1])},balloonSetup={vehicleId='ship',burnerIds={'b1'}}},{{name='tx',backend='frequency'}}),'unmapped added burner silently omitted')
local many={} for i=1,17 do many[i]={first='minecraft:f'..i,second='minecraft:stone'} end
assert(not L.combine(many),'unbounded multicast accepted')
local dup=A.copy(c.channels[1]) dup.link.members[1]=A.copy(dup.link) dup.link.members[1].members=nil assert(not L.key(dup),'duplicate grouped frequency accepted')
print('equipment groups: multiple burner frequencies/colors, shared motor chains, four motors in two software banks, all-member acknowledgements, partial errors and overlap rejection passed')
