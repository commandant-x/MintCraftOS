-- Normal GUI only, disposable data directory, /source mounted read-only.
local ok,err=pcall(function()
  shell.setDir("/") assert(shell.run("/source/install.lua")) http=nil pocket=nil
  local serial=0
  local function native(value)
    serial=serial+1 local id=serial
    os.queueEvent("task_complete",id,true,value)
    while true do
      local _,got,success,result=os.pullEvent("task_complete")
      if got==id then assert(success) return result end
    end
  end
  sublevel={isInPlotGrid=function() return native(true) end,
    getLogicalPose=function() return native({position={x=0,y=70,z=0},orientation={x=0,y=0,z=0,w=1},rotationPoint={x=0,y=0,z=0},scale={x=1,y=1,z=1}}) end,
    getMass=function() return native(126093) end,getCenterOfMass=function() return native({x=100000,y=70,z=100000}) end}
  local pressureCalls=0
  aero={getGravity=function() return native({x=0,y=-11,z=0}) end,getAirPressure=function(x,y,z)
    assert(type(x)=="number" and type(y)=="number" and type(z)=="number","pressure coordinates are not numeric")
    pressureCalls=pressureCalls+1 return native(0.69)
  end}
  _G.sublevel,_G.aero=sublevel,aero
  local scan=1
  local yaw,pitch=0,0
  local signals,shots={},{}
  local devices={
    altitude={getHeight=function() return native(198) end,getVerticalSpeed=function() return native(0) end,getAirPressure=function() return native(0.69) end},
    gimbal={getAngles=function() return native({0,0}) end,getAngularRates=function() return native({0,0,0}) end,getGravity=function() return native({0,-11,0}) end},
    nav={getHeading=function() return native(0) end},
    relay={setAnalogOutput=function(side,value) signals[side]=value return native(nil) end},
    radar={getPosition=function() return native({x=0,y=70,z=0}) end,getRange=function() return native(1000) end,
      getRotation=function() return native(0) end,getTracks=function() return native({{id="target",position={x=0,y=70,z=100},scannedTime=scan,category="PLAYER"}}) end},
    mount={getInfo=function() return native({assembled=true,x=0,y=70,z=0,yaw=yaw,pitch=pitch}) end,
      setComputerControl=function() return native(nil) end,setTargetAngles=function(y,p) yaw,pitch=y,p return native(nil) end,
      fire=function(value) shots[#shots+1]=value return native(value) end}}
  local kinds={altitude="altitude_sensor",gimbal="gimbal_sensor",nav="navigation_table",relay="redstone_relay",radar="create_radar:radar_bearing",mount="cannon_mount"}
  peripheral.getNames=function() return {"altitude","gimbal","nav","relay","radar","mount"} end
  peripheral.getType=function(name) return kinds[name] end
  peripheral.getMethods=function(name) local methods={} for method in pairs(devices[name]) do methods[#methods+1]=method end return methods end
  peripheral.wrap=function(name) return devices[name] end
  local apps=require("system.libraries.apps")
  local combat=require("system.services.combatd")
  local flight=require("system.services.flightd")
  parallel.waitForAny(function() require("system.boot.bootloader").start() end,function()
    for _=1,60 do if apps.ctx and apps.get("combat") and #combat.snapshot().targets>0 and pressureCalls>0 then break end sleep(0.1) end
    assert(apps.ctx,"kernel did not start")
    assert(pressureCalls>0,"Sable pressure never acquired")
    local m=require("system.services.sabled").snapshot().measurements.centerOfMass
    assert(m and m.frame=="unknown","COM frame invented")
    assert(not combat.solution("mount","target"),"unverified first scan authorized")
    local launched,navPid=apps.launch("navigation") assert(launched,tostring(navPid))
    local t=require("system.services.avionicsd").flightTelemetry({gimbal="gimbal",altitude="altitude",nav="nav"})
    assert(t.pitch==0 and t.roll==0 and t.altitude==198 and t.heading==0,"slim native flight telemetry missing")
    assert(#flight.endpoints()==1 and flight.endpoints()[1].backend=="relay")
    local cfg=flight.configuration()
    cfg.channels={{id="relay-test",backend="relay",name="relay",side="top",min=0,max=15,neutral=15,rescue=15,mix={}}}
    cfg.sensors={gimbal="gimbal",altitude="altitude",nav="nav"}
    assert(flight.configure({pid=navPid},cfg))
    assert(flight.testOutput({pid=navPid},"relay-test",7,true))
    for _=1,30 do if signals.top==15 then break end sleep(0.1) end
    assert(signals.top==15,"relay test did not return to configured rescue")
    apps.ctx.scheduler:kill(navPid)
    launched,navPid=apps.launch("combat") assert(launched,tostring(navPid))
    local actor={pid=navPid}
    assert(combat.configure(actor,"profiles","mount",{frame="world",headingFrame="world",validated=true,
      gravity=11,muzzleVelocity=120,minPitch=-10,maxPitch=90,minYaw=0,maxYaw=360,yawOffset=0,pitchOffset=0,yawSign=1,pitchSign=1}))
    for _=1,4 do scan=scan+1 sleep(0.25) end
    assert(combat.solution("mount","target"),"progressing native radar never became commandable")
    assert(combat.requestAim(actor,"mount","target"))
    sleep(0.4)
    assert(combat.requestFire(actor,"mount","target",assert(combat.prepareFire(actor,"mount","target"))))
    sleep(0.6)
    assert(shots[1]==true and shots[2]==false and #shots==2,"CBC native pulse/release mismatch")
    assert(not combat.status().uncertain.mount,"normal false CBC release marked uncertain")
    assert(apps.ctx.scheduler.processes[navPid].state=="ready","Combat app crashed")
    apps.ctx.scheduler:kill(navPid)
    assert(combat.stop(),"released CBC output blocked service stop")
  end)
end)
local h=assert(fs.open("/addon-audit-result.txt","w"))
h.write(ok and "PASS: native task_complete, numeric Sable pressure, unknown COM, slim flight, relay rescue, scan progression and CBC false release" or "FAIL: "..tostring(err))
h.close() os.shutdown()
