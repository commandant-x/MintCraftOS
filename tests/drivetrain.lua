package.path='./?.lua;'..package.path
local D=require('system.navigation.drivetrain') local A=require('system.libraries.addon')
local d={enabled=true,name='tx',clutchOff=15,left={},right={}}
for _,side in ipairs({'left','right'}) do for _,role in ipairs({'clutch','gear','reverse'}) do d[side][role]={first='minecraft:'..side..'_'..role,second='minecraft:iron_ingot'} end end
assert(D.validate(d)) local dup=A.copy(d) dup.right.gear=dup.left.gear assert(not D.validate(dup))
assert(not D.validate(d,{{backend='frequency',name='tx',link=d.left.gear}}))
local wanted=D.commands(d,{left={gear=8,reverse=15}}) local initial=D.commands(d,{left={gear=3,reverse=0}})
local shift=D.transition(d,initial,wanted) assert(shift['drive-left-clutch']==15 and shift['drive-left-gear']==3 and shift['drive-left-reverse']==0)
shift=D.transition(d,shift,wanted) assert(shift['drive-left-clutch']==15 and shift['drive-left-gear']==8 and shift['drive-left-reverse']==15)
shift=D.transition(d,shift,wanted) assert(shift['drive-left-clutch']==0)
local off=D.stop(d,shift) assert(off['drive-left-clutch']==15 and off['drive-left-gear']==8 and off['drive-left-reverse']==15)
local unknown=D.stop(d) assert(unknown['drive-left-clutch']==15 and unknown['drive-left-gear']==nil,'unobserved gear manufactured during rescue')
local snap={ok=true,inventoryComplete=true,observedAt=12,links={}}
for _,c in ipairs(D.channels(d)) do snap.links[#snap.links+1]={receiver=true,first={item=c.link.first},second={item=c.link.second},signal=shift[c.id]} end
assert(D.feedback(d,snap,shift,11)) assert(not D.feedback(d,snap,shift,12))
snap.links[1].signal=15 assert(not D.feedback(d,snap,shift,11));snap.links[1].signal=shift['drive-left-clutch']
table.remove(snap.links) assert(not D.feedback(d,snap,shift,11))
assert(not D.model({}),'empty observations qualified')
local rows={}
for _,side in ipairs({'left','right'}) do for _,sign in ipairs({1,-1}) do rows[#rows+1]={side=side,gear=8,reverse=sign<0 and 15 or 0,observable=true,forward=.2*sign,yaw=(side=='left' and -2 or 2)*sign,peakSpeed=.3,brakingDistance=.4} end end
local m=assert(D.model(rows)) assert(m.maxSpeed==.3)
local selection=assert(D.control(m,{heading=0,yawRate=0,velocity={x=0,y=0,z=0}},{heading=0,speed=.3}))
assert(selection.left and selection.right)
rows[3].yaw=-2 rows[4].yaw=2 assert(not D.model(rows),'no independent yaw authority qualified')
rows[3].yaw=2 rows[4].yaw=-2 rows[2].observable=false assert(not D.model(rows),'missing reverse qualified')
local G=require('system.navigation.geometry') local q={a=math.sqrt(.5),v={x=0,y=math.sqrt(.5),z=0}}
assert(math.abs(G.heading(q)-90)<1e-6)
local p=assert(G.transform({x=0,y=0,z=1},{position={x=3,y=4,z=5},orientation=q,rotationPoint={x=0,y=0,z=0},scale={x=1,y=1,z=1}}))
assert(math.abs(p.x-4)<1e-6 and math.abs(p.z-5)<1e-6)
assert(not G.heading({a=math.huge,v={x=0,y=0,z=0}}))
print('drivetrain: unique hardware roles, disengage-shift-engage, actual fresh RX acknowledgements, neutral rescue, measured authority rejection and native Sable quaternion passed')
