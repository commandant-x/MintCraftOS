package.path='./?.lua;'..package.path
local C=require('system.navigation.command_catalogue')
local A=require('system.libraries.addon')
local control={channels={{id='burners',backend='frequency',name='tx',min=0,max=15,neutral=5,rescue=0,
 link={first='minecraft:red_wool',second='minecraft:iron_ingot'},mix={altitude=1},actuator={role='buoyancy'}}},balloonSetup={vehicleId='ship',burnerIds={'heater'}}}
local snap={ok=true,inventoryComplete=true,frame='body_plot',vehicleId='ship',observedAt=10,validUntil=12,links={
 {id='rx',receiver=true,first={item='minecraft:red_wool'},second={item='minecraft:iron_ingot'},signal=8}},burners={{id='heater',position={x=0,y=0,z=0}}},actuators={{id='unknown-prop',position={x=0,y=0,z=1}}},mechanics={}}
local endpoints={{backend='frequency',name='tx'}}
local out=C.build(control,snap,endpoints,10)
assert(out.available and #out.commands==1 and out.commands[1].feedback.signal==8)
assert(out.commands[1].neutral==5 and out.commands[1].rescue==0 and #out.commands[1].independentAxes==0,'mapping invented certified axes')
assert(#out.equipment==2 and out.equipment[2].commandBinding=='not-inferred-from-geometry','nearby propeller was bound to heater')
out.configuredBurners.ids[1]='other' assert(control.balloonSetup.burnerIds[1]=='heater')
control.drivetrain={enabled=true,name='tx',clutchOff=15,left={},right={}}
for _,side in ipairs({'left','right'}) do for _,role in ipairs({'clutch','gear','reverse'}) do
 local first='minecraft:'..side..'_'..role
 control.drivetrain[side][role]={first=first,second='minecraft:iron_ingot'}
 snap.links[#snap.links+1]={receiver=true,first={item=first},second={item='minecraft:iron_ingot'},signal=role=='clutch' and 15 or 0}
end end
out=C.build(control,snap,endpoints,10) assert(#out.commands==7)
for _,row in ipairs(out.commands) do
 if row.role=='clutch' then assert(row.values[1]==0 and row.values[2]==15 and row.rescue==15) end
 if row.role=='gear' or row.role=='reverse' then assert(row.rescue==nil and row.rescuePolicy:find('preserve',1,true)) end
end
local duplicate=A.copy(control.channels[1]) duplicate.id='shared' control.channels[2]=duplicate
out=C.build(control,snap,endpoints,10)
assert(out.commands[1].bindingAmbiguous and out.commands[2].bindingAmbiguous and not out.commands[1].feedback.available,'overlapping frequencies were silently accepted')
control.channels[2]=nil control.balloonSetup.vehicleId='foreign'
out=C.build(control,snap,endpoints,10) assert(not out.commands[1].feedback.available)
control.balloonSetup.vehicleId='ship'
assert(not C.build(control,snap,endpoints,13).available,'stale snapshot refreshed inventory')
snap.observedAt=14 assert(not C.build(control,snap,endpoints,10).available,'future inventory accepted') snap.observedAt=10
for i=1,200 do snap.mechanics[i]={id='node-'..i,sourceId=i>1 and 'node-'..(i-1) or nil,position={x=i,y=0,z=0},rpm=0,overstressed=true} end
out=C.build(control,snap,endpoints,10) assert(out.truncated and #out.equipment==64 and out.equipmentCount==202,'physical inventory memory not bounded')
fs=setmetatable({},{__index=function() error('filesystem acquisition in catalogue') end})
peripheral=setmetatable({},{__index=function() error('peripheral acquisition in catalogue') end})
assert(C.build(control,snap,endpoints,10))
print('Command catalogue: stable configured IDs, bounds/neutral/rescue, receiver cache, both motor chains, no inferred axes/proximity bindings, overlap diagnostics and bounded read-only inventory passed')
local big={channels={},balloonSetup={vehicleId='ship',burnerIds={}}}
for i=1,64 do big.balloonSetup.burnerIds[i]=string.rep('h',180)..i end
for i=1,32 do
 local row={id=string.rep('c',180)..i,backend='frequency',name='tx',min=0,max=15,neutral=0,rescue=0,link={members={}}}
 for j=1,16 do
  local f={first='minecraft:'..string.rep('a',110)..'_'..i..'_'..j,second='minecraft:'..string.rep('b',118)}
  if j==1 then row.link.first,row.link.second=f.first,f.second else row.link.members[#row.link.members+1]=f end
 end
 big.channels[i]=row
end
out=C.build(big,snap,endpoints,10)
assert(out.frequencyCount==512 and out.frequenciesPublished==256 and out.truncated and not out.complete,'frequency catalogue budget was not explicit')
assert(require('system.ascendancy.contracts').clone(out),'bounded catalogue exceeds interchange payload budget')
big.channels[1].actuator=true big.channels[1].mix=true
assert(C.build(big,snap,endpoints,10),'invalid optional metadata crashed catalogue')
print('Catalogue payload budget: 32 grouped commands, 512 configured/256 published keys, shared burner metadata and malformed optional metadata passed')
