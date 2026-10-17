package.path="./?.lua;"..package.path
local now=1
os.clock=function() return now end
os.epoch=function() return 0 end
local events,timers={},0
os.queueEvent=function(name,...) events[#events+1]={name=name,args=table.pack(...)} end
os.startTimer=function() timers=timers+1 return timers end
os.cancelTimer=function() end
os.pullEvent=function(filter) return coroutine.yield(filter) end
parallel={waitForAll=function(...) for _,fn in ipairs({...}) do fn() end end}
local addon=require("system.libraries.addon")
addon.bounded=function(fn) return pcall(fn) end
addon.periodic=function() return {stop=function() end,rescan=function() end} end
package.loaded["system.libraries.log"]={info=function() end,warn=function() end,error=function() end}
package.loaded["system.security.permissions"]={require=function(actor) return actor.pid==1 end}
package.loaded["system.services.sabled"]={status=function() return {inSublevel=false} end}
local settings={profiles={mount={frame="world",validated=true,gravity=11,muzzleVelocity=120,minPitch=-10,maxPitch=90,minYaw=0,maxYaw=360}},radars={radar={frame="world",headingValidated=true,headingOffset=90,headingSign=-1,fov=60}}}
package.loaded["system.libraries.config"]={load=function() return addon.copy(settings) end}
package.loaded["system.libraries.safe_write"]={write=function() return true end}
textutils={serialize=function() return "probe" end}
local scanTime,rotation=20,30
local currentYaw,currentPitch=0,0
local writes,reads,scans={},0,0
local devices={radar={getTracks=function() reads=reads+1 return {{id="player-uuid",position={x=0,y=0,z=100},scannedTime=scanTime,category="entity",entityType="minecraft:player"}} end,
  getPosition=function() return {x=0,y=0,z=0} end,getRange=function() return 1000 end,getRotation=function() return rotation end},
  mount={getInfo=function() reads=reads+1 return {x=0,y=0,z=0,assembled=true,yaw=currentYaw,pitch=currentPitch} end,
    setComputerControl=function(value) writes[#writes+1]={"control",value} end,
    setTargetAngles=function(yaw,pitch) currentYaw,currentPitch=yaw,pitch writes[#writes+1]={"aim",yaw,pitch} end,
    fire=function(value) writes[#writes+1]={"fire",value} end}}
peripheral={getNames=function() scans=scans+1 return {"radar","mount"} end,getType=function(name) return name=="mount" and "cannon_mount" or "create_radar:radar" end,
  getMethods=function(name) local methods={} for key in pairs(devices[name]) do methods[#methods+1]=key end return methods end,wrap=function(name) return devices[name] end}
local scheduler=require("system.kernel.scheduler").new()
scheduler.processes[1]={pid=1,state="ready",meta={appId="combat"},permissions={},co=coroutine.create(function() coroutine.yield("never") end),filter="never"}
scheduler.nextPid=2
local combat=require("system.services.combatd")
combat.start({scheduler=scheduler}) combat.acquire(true)
assert(combat.snapshot().radars[1].heading==60,"rotating heading not mapped")
assert(combat.snapshot().targets[1].label=="ID player-u","invented absent player name")
local before=reads
for i=1,100 do combat.snapshot() combat.status() end
assert(reads==before and scans==1)
local actor={pid=1}
local solution=assert(combat.solution("mount","player-uuid")) assert(solution.estimated and solution.pitch>0)
assert(not combat.solution("mount",nil),"missing target silently selected first contact")
local function flush()
  while #events>0 do scheduler:dispatch(table.remove(events,1)) end
end
assert(combat.requestAim(actor,"mount","player-uuid")) flush()
assert(writes[1][1]=="control" and writes[2][1]=="aim")
assert(not combat.requestFire(actor,"mount","player-uuid",nil),"fire without confirmation")
local token=assert(combat.prepareFire(actor,"mount","player-uuid"))
assert(combat.requestFire(actor,"mount","player-uuid",token)) flush()
assert(writes[#writes][1]=="fire" and writes[#writes][2]==true)
assert(combat.stop()==false,"stopped active fire worker")
scheduler:dispatch({name="timer",args={timers}}) flush()
assert(writes[#writes][2]==false,"fire output not released")
assert(not combat.requestFire(actor,"mount","player-uuid",token),"confirmation reused")
assert(combat.requestProbe(actor,"mount")) flush()
assert(writes[#writes][1]=="fire" and writes[#writes][2]==false,"Probe called actuator")
local originalFire=devices.mount.fire
local uncertainShots=0
devices.mount.fire=function(value)
  if value then uncertainShots=uncertainShots+1 error("reply lost after firing") end
  return originalFire(value)
end
local uncertainToken=assert(combat.prepareFire(actor,"mount","player-uuid"))
assert(combat.requestFire(actor,"mount","player-uuid",uncertainToken)) flush()
assert(combat.status().uncertain.mount,"lost fire reply did not lock mount")
local retryToken=assert(combat.prepareFire(actor,"mount","player-uuid"))
assert(not combat.requestFire(actor,"mount","player-uuid",retryToken)) flush()
assert(uncertainShots==1,"uncertain non-idempotent fire repeated")
assert(not combat.acknowledge(actor,"mount",false))
assert(combat.acknowledge(actor,"mount",true))
devices.mount.fire=originalFire
now=7 combat.acquire(false)
assert(combat.snapshot().targets[1].stale,"rereading same scannedTime kept lost target fresh")
assert(not combat.solution("mount","player-uuid"))
scanTime=21 combat.acquire(false) assert(not combat.snapshot().targets[1].stale)
assert(combat.configure(actor,"aliases","player-uuid","Local alias")) combat.acquire(false)
assert(combat.snapshot().targets[1].label=="Local alias" and combat.snapshot().targets[1].labelSource=="alias")
assert(combat.stop())
settings.radars={}
devices.right=devices.radar
devices.right.getDishCount=function() return 4 end
peripheral.getNames=function() return {"right"} end
peripheral.getType=function() return "create_radar:radar_bearing" end
combat.start({scheduler=scheduler}) combat.acquire(true)
local bearing=combat.snapshot().radars[1]
assert(bearing.position and bearing.frame=="world", "fresh fixed bearing hidden until manual config")
assert(bearing.rawTrackCount==1 and bearing.dishCount==4 and bearing.rawRotation==30)
settings.radars.right={frame="unknown"}
combat.start({scheduler=scheduler}) combat.acquire(true)
bearing=combat.snapshot().radars[1]
assert(not bearing.position and bearing.rawPosition and bearing.readStatus=="position frame required", "explicit unknown frame overridden")
settings.radars={}
package.loaded["system.services.sabled"].status=function() return {inSublevel=true} end
combat.start({scheduler=scheduler}) combat.acquire(true)
assert(not combat.snapshot().radars[1].position, "moving sublevel treated as fixed terrain")
devices.right.getPosition=nil
combat.acquire(true)
bearing=combat.snapshot().radars[1]
assert(bearing.rawTrackCount==1 and bearing.readErrors.getPosition=="method unavailable", "partial radar silently discarded")
local manual={positionMode="manual",positionX=10,positionY=70,positionZ=20,frame="world",headingFrame="world",headingSign=1,headingOffset=0}
manual.origin={x=1,y=2,z=3}
assert(not combat.configure(actor,"radars","right",manual),"fixed manual coordinates accepted on moving sublevel")
package.loaded["system.services.sabled"].status=function() return {inSublevel=false} end
local incomplete=addon.copy(manual) incomplete.positionX=nil
assert(not combat.configure(actor,"radars","right",incomplete),"missing manual coordinate fabricated")
assert(combat.configure(actor,"radars","right",manual))
combat.acquire(false)
bearing=combat.snapshot().radars[1]
assert(bearing.position.x==10 and bearing.position.y==70 and bearing.position.z==20)
assert(not bearing.readErrors.getPosition and combat.snapshot().ok,"manual origin did not resolve missing position method")
package.loaded["system.services.sabled"].status=function() return {inSublevel=true} end
package.loaded["system.services.sabled"].snapshot=function() return {timestamp=now,sublevel={logicalPose={position={100,200,300},orientation={0,0,0,1},scale={1,1,1},rotationPoint={0,0,0}}}} end
manual.frame="body"
assert(combat.configure(actor,"radars","right",manual)) combat.acquire(false)
bearing=combat.snapshot().radars[1]
assert(bearing.position.x==110 and bearing.position.y==270 and bearing.position.z==320,"manual body position not transformed")
devices.right.getTracks=function() error("radar read failed") end
combat.acquire(false)
assert(combat.snapshot().ok==false and combat.snapshot().radars[1].readErrors.getTracks)
assert(combat.stop())
devices.right.getTracks=function() return {{id="player-uuid",position={x=0,y=0,z=100},scannedTime=scanTime,friendly=true,synthetic=false}} end
peripheral.getNames=function() return {"right","mount"} end
peripheral.getType=function(name) return name=="mount" and "cannon_mount" or "create_radar:radar_bearing" end
package.loaded["system.services.sabled"].status=function() return {inSublevel=false} end
combat.start({scheduler=scheduler}) combat.acquire(true)
assert(combat.snapshot().targets[1].friendly==true and combat.snapshot().targets[1].synthetic==false)
local _,blocked=combat.solution("mount","player-uuid")
assert(blocked:find("friendly",1,true),"friendly API target can be commanded")
-- Classification is retained even when scan time did not change.
assert(combat.snapshot().radars[1].classificationSource=="API friendly/synthetic")
devices.right.getTracks=function() return {{id="player-uuid",position={x=0,y=0,z=100},scannedTime=scanTime,friendly=false,synthetic=true}} end
combat.acquire(false)
assert(combat.snapshot().targets[1].friendly==false and combat.snapshot().targets[1].synthetic==true)
local _,syntheticBlocked=combat.solution("mount","player-uuid")
assert(syntheticBlocked:find("synthetic",1,true),"synthetic API target can be commanded")
assert(combat.stop())
print("combat rotating heading, cache, freshness, confirmation and CBC pulse tests passed")
local net=require("system.services.radarnetd")
local original=net.snapshot
net.snapshot=function() return {radars={{id="net:2:radar",name="Remote",position={x=0,y=0,z=0},range=1000,remote=true}},targets={
  {id="remote-only",position={x=0,y=0,z=100},timestamp=now,freshnessKnown=true,remote=true,radarId="net:2:radar"},
  {id="player-uuid",position={x=0,y=0,z=110},timestamp=now,freshnessKnown=true,remote=true,radarId="net:2:radar"}}} end
combat.start({scheduler=scheduler}) combat.acquire(true)
assert(#combat.snapshot().targets==2,"same ID duplicated across stations")
local _,remoteBlocked=combat.solution("mount","remote-only")
assert(remoteBlocked:find("remote",1,true),"remote station enabled weapon commands")
now=now+6 combat.acquire(false)
local freshRemote
for _,target in ipairs(combat.snapshot().targets) do if target.id=="player-uuid" then freshRemote=target end end
assert(freshRemote.remote and freshRemote.position.z==110 and not freshRemote.stale,"stale local target hid fresh remote observation")
assert(not combat.solution("mount","player-uuid"),"remote replacement became commandable")
assert(combat.stop()) net.snapshot=original
-- Forty compact scanner APIs: one explicit bulk setup, no per-radar coordinates.
devices={} settings.radars={}
for i=1,40 do
  local n=i local id="radar_"..i
  settings.radars[id]={positionMode="manual",positionX=999,positionY=999,positionZ=999,frame="world",headingFrame="world",headingSign=1,headingOffset=0}
  devices[id]={getTracks=function() return {} end,getScanGeometry=function()
    return {version=1,positionFrame="world",headingFrame="world",position={x=n*10,y=70,z=20},range=1000,rotation=10,heading=n*5,fov=80,halfHeight=20,dishCount=2,running=true}
  end}
end
peripheral.getNames=function() local names={} for id in pairs(devices) do names[#names+1]=id end return names end
peripheral.getType=function() return "create_radar:radar_bearing" end
combat.start({scheduler=scheduler}) combat.acquire(true)
assert(#combat.snapshot().radars==40)
assert(combat.snapshot().radars[1].position.x==999,"manual calibration overwritten without request")
assert(combat.autoConfigureRadars(actor)) combat.acquire(false)
for _,radar in ipairs(combat.snapshot().radars) do
  assert(radar.position.x~=999 and radar.autoGeometry and radar.fov==80 and radar.fovSource=="scanner API")
  assert(radar.heading and radar.halfHeight==20 and radar.running and not radar.readErrors.getRange)
end
assert(combat.configuration().radars.radar_1.positionX==999,"manual backup lost")
assert(combat.stop())
devices.radar_1.getScanGeometry=function() return {version=1,positionFrame="world",headingFrame="body",position={x=10,y=70,z=20},range=1000,heading=90,fov=80,halfHeight=20,running=false} end
combat.start({scheduler=scheduler}) combat.acquire(true)
for _,radar in ipairs(combat.snapshot().radars) do if radar.id=="radar_1" then assert(radar.heading==nil and radar.running==false,"unconverted body angle treated as world") end end
assert(combat.stop())
print("forty radar automatic scanner setup and unknown body heading protection passed")
