package.path="./?.lua;"..package.path
local setup=require("system.navigation.balloon_setup")
local mode=require("system.navigation.control_mode")
local link=require("system.navigation.link_output")
local snapshot={ok=true,complete=true,burnerDiscoveryAvailable=true,vehicleId="balloon",
  burners={{id="burner1",hasBalloon=true,signal=6,position={x=0,y=0,z=0}}},links={}}
local control={channels={},manualInputs={{axis="heading"},{axis="altitude"}},vehicle={}}
local endpoints={{backend="frequency",name="bridge0"}}
local plan=assert(setup.plan(snapshot,control,endpoints))
assert(plan.frequency.first=="minecraft:white_wool" and plan.burnerCount==1 and plan.connected==1)
assert(not setup.create(control,plan,{transmitter="bridge0",neutral=6,rescue=0}))
local options={transmitter="bridge0",neutral=6,rescue=0,wiringConfirmed=true}
local draft=assert(setup.create(control,plan,options))
assert(draft.mode=="altitude" and #mode.axes(draft)==1 and mode.axes(draft)[1]=="altitude")
assert(draft.channels[1].mix.altitude==1 and draft.gains.altitude.kp==0)
assert(not draft.enabled and not draft.hoverValidated and #draft.manualInputs==1)
assert(#control.channels==0 and control.vehicle.type==nil,"wizard mutated source configuration")
assert(not setup.create(draft,plan,options),"existing mapping replaced without consent")
options.replaceExisting=true options.inverted=true
assert(setup.create(draft,plan,options).channels[1].mix.altitude==-1)
snapshot.links={{receiver=true,position={x=9,y=0,z=0},first={item="minecraft:white_wool"},second={item="minecraft:white_wool"}}}
assert(setup.plan(snapshot,control,endpoints).frequency.first=="minecraft:orange_wool")
snapshot.links[1].position.x=1
assert(setup.plan(snapshot,control,endpoints).reused)
snapshot.burnerDiscoveryAvailable=false assert(not setup.plan(snapshot,control,endpoints))
snapshot.burnerDiscoveryAvailable=true snapshot.complete=false assert(not setup.plan(snapshot,control,endpoints))
local a={link={first="minecraft:white_wool",second="minecraft:white_wool"},name="a"}
local b={link={first="minecraft:white_wool",second="minecraft:white_wool"},name="b"}
assert(link.key(a)==link.key(b),"same frequency on different transmitters must collide")
b.link.firstColor=5 assert(link.key(a)~=link.key(b))
print("balloon wizard: passive discovery, frequency proposal/reuse, replacement consent, altitude-only defaults and uncalibrated gains passed")
