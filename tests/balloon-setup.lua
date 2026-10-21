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
snapshot.inventoryComplete=true
assert(setup.plan(snapshot,control,endpoints),"burner guide coupled to COM/propeller geometry")
snapshot.inventoryComplete=false
assert(not setup.plan(snapshot,control,endpoints),"truncated inventory accepted")
local _,missing=setup.plan({available=false},control,endpoints)
assert(missing:find("0.2.1",1,true) and missing:find("redemarrer",1,true))
snapshot.status="partial" snapshot.burners[1].gasOutput=0 snapshot.burners[1].gasActive=false
local diagnostics=table.concat(setup.diagnostics(snapshot),"\n")
assert(diagnostics:find("signal 6/15",1,true) and diagnostics:find("gaz actif non",1,true))
assert(diagnostics:find("ballon associe",1,true),"empty balloon confused with absent association")
local a={link={first="minecraft:white_wool",second="minecraft:white_wool"},name="a"}
local b={link={first="minecraft:white_wool",second="minecraft:white_wool"},name="b"}
assert(link.key(a)==link.key(b),"same frequency on different transmitters must collide")
b.link.firstColor=5 assert(link.key(a)~=link.key(b))
print("balloon wizard: passive discovery, frequency proposal/reuse, replacement consent, altitude-only defaults and uncalibrated gains passed")
-- Screenshot regression: one active/associated heater and one inactive,
-- unrelated/uninitialized heater must be selectable without hiding either.
snapshot.ok=true snapshot.complete=true snapshot.inventoryComplete=true
snapshot.burners={{id="ship:-1:-2:2",hasBalloon=false,signal=0,position={x=-1,y=-2,z=2}},
 {id="ship:-1:-2:3",hasBalloon=true,signal=15,position={x=-1,y=-2,z=3}}}
snapshot.links={}
local all=assert(setup.plan(snapshot,control,endpoints))
assert(all.burnerCount==2 and all.connected==1 and all.baseline==nil)
local group=assert(setup.plan(snapshot,control,endpoints,{["ship:-1:-2:2"]=false,["ship:-1:-2:3"]=true}))
assert(group.burnerCount==1 and group.connected==1 and group.baseline==15)
assert(#group.detectedBurners==2 and group.ignoredBurnerIds[1]=="ship:-1:-2:2")
local selectedConfig=assert(setup.create(control,group,{transmitter="bridge0",neutral=5,rescue=0,wiringConfirmed=true}))
assert(#selectedConfig.balloonSetup.burnerIds==1 and selectedConfig.balloonSetup.burnerIds[1]=="ship:-1:-2:3")
assert(not selectedConfig.enabled and not selectedConfig.hoverValidated)
assert(not setup.plan(snapshot,control,endpoints,{}))
assert(not setup.plan(snapshot,control,endpoints,{unknown=true}))
assert(not setup.plan(snapshot,control,endpoints,{["ship:-1:-2:3"]="yes"}))
print("burner selection: mixed screenshot group, explicit exclusion, baseline/group recompute and empty/stale selections passed")
