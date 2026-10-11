-- Normal GUI, isolated storage, mocked main-thread peripherals; no Minecraft writes.
local ok,err=pcall(function()
  shell.setDir("/") assert(shell.run("/source/install.lua"))
  http,_G.http=nil,nil
  local count,scans,task,scanTick=0,0,0,0
  local function native(value)
    count=count+1 task=task+1 local id=task
    os.queueEvent("task_complete",id,true,value)
    while true do local _,got,success,result=os.pullEvent("task_complete") if got==id then assert(success) return result end end
  end
  local pose={position={x=0,y=198,z=0},orientation={x=0,y=0,z=0,w=1},scale={x=1,y=1,z=1},rotationPoint={x=0,y=0,z=0}}
  _G.sublevel={isInPlotGrid=function() return native(true) end,getUniqueId=function() return native("mock-ship") end,getName=function() return native("Quad mock") end,
    getLogicalPose=function() return native(pose) end,getLastPose=function() return native(pose) end,getLinearVelocity=function() return native({x=3,y=0,z=1}) end,
    getVelocity=function() return native({x=3,y=0,z=1}) end,getAngularVelocity=function() return native({x=0,y=0,z=0}) end,getMass=function() return native(126093) end,
    getCenterOfMass=function() return native({x=0,y=0,z=0}) end,getInverseMass=function() return native(1/126093) end,
    getInertiaTensor=function() return native({}) end,getInverseInertiaTensor=function() return native({}) end}
  local devices={altitude={getHeight=function() return native(198) end,getVerticalSpeed=function() return native(0) end,getAirPressure=function() return native(0.6906) end},
    gimbal={getAngles=function() return native({7,-12}) end,getAngularRates=function() return native({0,0,0}) end,getGravity=function() return native({0,-11,0}) end},
    nav={getHeading=function() return native(30) end,getOrientation=function() return native(pose.orientation) end},
    radar={getRange=function() return native(1000) end,getPosition=function() return native({x=0,y=198,z=0}) end,getRotation=function() return native((os.clock()*15)%360) end,
      getTracks=function() scanTick=scanTick+1 local rows={}
        for i=1,6 do rows[i]={id="mock-target-"..i,scannedTime=scanTick,position={x=math.sin(i)*200,y=180+i*30,z=math.cos(i)*250},category="entity",entityType="minecraft:player"} end return native(rows)
      end},mount={getInfo=function() return native({x=0,y=198,z=0,yaw=0,pitch=0,assembled=true}) end,setTargetAngles=function() return native(true) end,
      setComputerControl=function() return native(true) end,fire=function() error("GUI test must never fire") end}}
  local types={altitude="altitude_sensor",gimbal="gimbal_sensor",nav="navigation_table",radar="create_radar:radar",mount="cannon_mount"}
  peripheral.getNames=function() scans=scans+1 return {"altitude","gimbal","nav","radar","mount"} end
  peripheral.getType=function(name) return types[name] end
  peripheral.getMethods=function(name) local rows={} for key in pairs(devices[name] or {}) do rows[#rows+1]=key end return rows end
  peripheral.wrap=function(name) return devices[name] end
  local config=require("system.libraries.config")
  config.save("/system/config/combat.cfg",{radar={maxTargets=128},radars={radar={frame="world",headingFrame="world",headingValidated=true,headingSign=1,headingOffset=0,fov=60}},profiles={mount={frame="world",headingFrame="world",validated=true,gravity=11,muzzleVelocity=120,minYaw=0,maxYaw=360,minPitch=-10,maxPitch=80,yawSign=1,pitchSign=1,yawOffset=0,pitchOffset=0}},aliases={}})
  local nav=config.load("/system/config/navigation.cfg",{})
  nav.control={sensors={gimbal="gimbal",altitude="altitude",nav="nav"},channels={},gains={}}
  config.save("/system/config/navigation.cfg",nav)
  local apps=require("system.libraries.apps")
  parallel.waitForAny(function() require("system.boot.bootloader").start() end,function()
    for i=1,50 do if apps.ctx and apps.get("navigation") then break end sleep(0.1) end
    assert(apps.ctx,"kernel missing") sleep(3.5)
    assert(require("system.services.sabled").status().inSublevel,"yielding Sable API not acquired")
    assert(require("system.services.avionicsd").snapshot().measurements.pitch.value==7,"yielding Avionics not acquired")
    assert(#require("system.services.combatd").snapshot().targets==6,"yielding tracks not acquired")
    local parent=term.current()
    for _,id in ipairs({"navigation","combat"}) do
      local launched,pid=apps.launch(id) assert(launched,tostring(pid)) sleep(0.3)
      local process=apps.ctx.scheduler.processes[pid] local win=assert(process.window)
      for _,size in ipairs({{24,12},{49,15},{80,26},{118,36}}) do
        local target=window.create(parent,1,1,size[1],size[2],false)
        local old=term.redirect(target)
        local before,inventoryBefore=count,scans
        for _,page in ipairs(id=="navigation" and {"flight","control","mapping","gains","sensors","manual","calibration","environment","estimates","frequencies"} or {"radar","three","targets","cannons","fire","probe","config"}) do
          win.app.page=page win.app:draw(size[1],size[2])
        end
        assert(count==before and scans==inventoryBefore,"draw acquired peripheral")
        term.redirect(old)
      end
      win.app.page=id=="combat" and "radar" or "flight"
      win:toggleMaximize() os.queueEvent("redraw") sleep(0.3)
      assert(process.state=="ready" and not win.closed,tostring(process.error))
      if term.screenshot then term.screenshot() sleep(1.1) end
      if id=="combat" then
        win.app.page="three" os.queueEvent("redraw") sleep(0.3)
        if term.screenshot then term.screenshot() sleep(1.1) end
      end
      local graphAt=win.app.graphAt
      win.minimized=true sleep(0.5)
      assert(win.app.graphAt==graphAt,"minimized graph still rendered")
      apps.ctx.scheduler:kill(pid)
    end
    for _,process in pairs(apps.ctx.scheduler.processes) do assert(process.state~="crashed",process.name..": "..tostring(process.error)) end
    local radarDevice=devices.radar
    devices.radar=nil types.radar=nil os.queueEvent("peripheral_detach","radar") sleep(0.5)
    assert(require("system.services.combatd").status().counts.radars==0,"detached radar still in inventory")
    devices.radar=radarDevice types.radar="create_radar:radar" os.queueEvent("peripheral","radar") sleep(0.5)
    assert(require("system.services.combatd").status().counts.radars==1,"radar hotplug not acquired")
    _G.sublevel.isInPlotGrid=function() return native(false) end sleep(0.3)
    assert(not require("system.services.sabled").status().inSublevel,"sublevel loss not detected")
    -- Timeout leaves the old acquisition unstacked and without retries inside the call.
    local success,message=require("system.libraries.addon").bounded(function() while true do os.pullEvent("missing_task") end end,0.1)
    assert(not success and message:find("uncertain",1,true))
  end)
end)
local output=assert(fs.open("/addons-result.txt","w")) output.write(ok and "PASS: yielding workers, four render sizes, no acquisition in draw, minimized pause, timeout, hotplug, sublevel loss" or "FAIL: "..tostring(err)) output.close()
os.shutdown()
