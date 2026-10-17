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
  local bridgeCalls=0
  mintcraft_vehicle={snapshot=function()
    bridgeCalls=bridgeCalls+1
    local motors={}
    for i=1,6 do motors[i]={id="measured-rotor-"..i,block="aeronautics:propeller",suggestedRole="lift",active=false,thrust=0,
      position={x=math.cos(i*math.pi/3)*4,y=0,z=math.sin(i*math.pi/3)*4},direction={x=0,y=1,z=0}} end
    return native({schema=1,readOnly=true,ok=true,complete=true,frame="body_plot",vehicleId="native-ship",name="Measured Hexa",
      revision=math.floor(os.clock()*20),ageTicks=0,units={position="block",mass="sable_mass"},mass=126093,
      centerOfMass={x=0,y=0,z=0},actuators=motors,links={}})
  end}
  _G.mintcraft_vehicle=mintcraft_vehicle
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
    local initialApp=apps.ctx.scheduler.processes[navPid].window.app
    assert(initialApp.page=="vehicle","new vehicle did not request a profile")
    initialApp:draw(80,28)
    for _,field in ipairs(initialApp.form.fields) do
      if field.label=="Vehicle type" then field.set("hexacopter") end
      if field.label=="Mass (kg)" then initialApp.form.edit=field initialApp.form.text="130000" end
    end
    initialApp:draw(80,28)
    initialApp:handle({name="key",args={keys.enter}})
    initialApp:draw(80,28)
    local saveButton
    for _,box in ipairs(initialApp.commands.boxes) do if box.id=="save" then saveButton=box end end
    assert(saveButton) initialApp:handle({name="mouse_click",args={1,saveButton.x,saveButton.y}})
    assert(flight.configuration().vehicle.type=="hexacopter","vehicle profile not persisted")
    assert(flight.configuration().vehicle.massKg==130000,"numeric edit lost during redraw")
    for _=1,30 do if require("system.services.vehiclebridged").snapshot().ok then break end sleep(0.1) end
    initialApp.page="vehicle" initialApp:draw(80,28)
    local discoverButton
    for _,box in ipairs(initialApp.commands.boxes) do if box.id=="discover" then discoverButton=box end end
    assert(discoverButton,"Discover hidden")
    initialApp:handle({name="mouse_click",args={1,discoverButton.x,discoverButton.y}})
    assert(initialApp.confirm,"geometry import lacks confirmation")
    initialApp.confirm.callback() initialApp.confirm=nil
    assert(initialApp.page=="context")
    local before=bridgeCalls
    initialApp:draw(80,28)
    initialApp.page="diagram" initialApp:draw(80,28)
    assert(bridgeCalls==before,"draw acquired bridge data")
    initialApp.page="vehicle" initialApp:draw(80,28)
    for _,box in ipairs(initialApp.commands.boxes) do if box.id=="save" then initialApp:handle({name="mouse_click",args={1,box.x,box.y}}) break end end
    local imported=flight.configuration()
    assert(#imported.vehicle.bridgeActuators==6 and imported.vehicle.comVerified,"measured geometry not imported")
    assert(#imported.channels==0,"Discover created live output mappings")
    assert(imported.vehicle.massKg==130000,"raw bridge mass overwrote kg calibration")
    initialApp.page="calibration" initialApp:draw(80,28)
    local testButton
    for _,box in ipairs(initialApp.commands.boxes) do if box.id=="test" then testButton=box end end
    assert(testButton,"Test button missing")
    initialApp:handle({name="mouse_click",args={1,testButton.x,testButton.y}})
    assert(initialApp.confirm,"Test with no outputs silently did nothing")
    initialApp.confirm.callback() initialApp.confirm=nil
    assert(initialApp.page=="mapping","missing-output dialog did not open setup")
    initialApp.page="calibration" initialApp.dirty=true initialApp:draw(80,28)
    initialApp:handle({name="mouse_click",args={1,testButton.x,testButton.y}})
    assert(initialApp.confirm,"unsaved configuration silently blocked Test")
    initialApp.confirm.callback() initialApp.confirm=nil initialApp.dirty=false
    assert(initialApp.page=="mapping")
    local t=require("system.services.avionicsd").flightTelemetry({gimbal="gimbal",altitude="altitude",nav="nav"})
    assert(t.pitch==0 and t.roll==0 and t.altitude==198 and t.heading==0,"slim native flight telemetry missing")
    assert(#flight.endpoints()==1 and flight.endpoints()[1].backend=="relay")
    local cfg=flight.configuration()
    cfg.channels={{id="relay-test",backend="relay",name="relay",side="top",min=0,max=15,neutral=15,rescue=15,mix={}}}
    cfg.vehicle=imported.vehicle
    cfg.channels[1].actuator={role="lift",position={x=2,y=0,z=3},direction={x=0,y=1,z=0},geometryVerified=true}
    cfg.sensors={gimbal="gimbal",altitude="altitude",nav="nav"}
    assert(flight.configure({pid=navPid},cfg))
    apps.ctx.scheduler:kill(navPid)
    launched,navPid=apps.launch("navigation") assert(launched,tostring(navPid))
    local app=apps.ctx.scheduler.processes[navPid].window.app
    app.page="mapping" app:draw(80,28)
    local binding
    for _,field in ipairs(app.form.fields) do if field.label=="Measured actuator #" then binding=field end end
    assert(binding,"measured actuator picker missing") binding.set(2)
    app:draw(80,28)
    for _,box in ipairs(app.commands.boxes) do if box.id=="save" then app:handle({name="mouse_click",args={1,box.x,box.y}}) break end end
    local linked=flight.configuration().channels[1]
    assert(linked.actuator.bridgeId==imported.vehicle.bridgeActuators[2].id,"measured geometry not associated")
    assert(linked.backend=="relay" and linked.name=="relay" and linked.side=="top","geometry picker altered output wiring")
    for _,page in ipairs({"vehicle","context","diagram"}) do
      app.page=page
      for _,size in ipairs({{20,10},{26,17},{80,28}}) do app:draw(size[1],size[2]) end
    end
    app.page="diagram" app:draw(80,28)
    if term.screenshot then term.screenshot() end
    app.page="calibration"
    local function draw() app:draw(80,28) end
    local function click(box) assert(box,"calibration control missing") app:handle({name="mouse_click",args={1,box.x,box.y}}) end
    local function command(id)
      draw()
      local selected
      for _,box in ipairs(app.commands.boxes) do if box.id==id then selected=box end end
      if not selected then
        click(app.commands.trigger) draw()
        for _,box in ipairs(app.commands.menuBoxes or {}) do if box.id==id then selected=box end end
      end
      click(selected) draw()
      assert(app.confirm,"calibration action did not require confirmation")
      for _,box in ipairs(app.confirmBar) do if box.id=="confirm" then click(box) return end end
      error("confirmation button missing")
    end
    command("test")
    assert(app.form.edit,"neutral/rescue test signal did not offer editing")
    app.form.text="7" app:handle({name="key",args={keys.enter}})
    command("test")
    for _=1,30 do if signals.top==15 then break end sleep(0.1) end
    assert(signals.top==15,"relay test did not return to configured rescue")
    assert(flight.status().state=="disarmed","normal calibration pulse entered failsafe")
    command("channel")
    assert(flight.configuration().channels[1].validated,"UI direction verification blocked after successful pulse")
    assert(flight.configure({pid=navPid},flight.configuration()))
    assert(flight.configuration().channels[1].validated,"Save erased physical verification")
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
h.write(ok and "PASS: native workers, Navigation calibration UI signal/test/confirm/direction/save, relay rescue, Sable contracts, radar progression and CBC release" or "FAIL: "..tostring(err))
h.close() os.shutdown()
