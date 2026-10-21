package.path="./?.lua;"..package.path
colors={} for i,n in ipairs({"white","orange","magenta","lightBlue","yellow","lime","pink","gray","lightGray","cyan","purple","blue","brown","green","red","black"}) do colors[n]=2^(i-1) end
keys={f10=68}
local width,height=26,17
local writes={}
package.loaded["system.gui.renderer"]={crop=function(s,w) return tostring(s):sub(1,math.max(0,w)) end,
 writeAt=function(x,y,s) assert(x>=1 and y>=1 and x+#s-1<=width and y<=height,"text outside viewport") writes[#writes+1]=s end,
 blitAt=function(x,y,s) assert(x>=1 and y>=1 and x+#s-1<=width and y<=height) end,
 color=function(c) for i=0,15 do if c==2^i then return string.format("%x",i) end end end,fill=function() end}
package.loaded["system.gui.components"]={input=function() end,toolbar=function() return {} end,toolbarHit=function() return "confirm" end}
package.loaded["system.gui.action_menu"]={new=function() return {} end,bar=function() return {} end,overlay=function() end}
package.loaded["system.gui.form"]={new=function() return {draw=function() end} end,field=function(object,key) return {set=function(v) object[key]=v end} end}
package.loaded["system.libraries.config"]={load=function() return {} end}
package.loaded["apps.navigation.pixel"]={sample=function() return {} end,attach=function(app)
 app.pixelPages={} app.drawPixels=function() end app.handlePixels=function() end app.handleNativeKey=function() return false end
end}
package.loaded["apps.navigation.route"]={new=function() return {refresh=function() end} end}
local snapshot={ok=true,available=true,complete=false,inventoryComplete=true,frame="body_plot",vehicleId="ship-a",status="Partial vehicle inventory",
 burnerDiscoveryAvailable=true,actuators={},links={},burners={{id="heater",position={x=1,y=2,z=3},signal=3,gasOutput=4,hasBalloon=true,gasActive=false}}}
local rescans,saved,started,stopped=0,0,0,0
local preflightConfig
local progress={initializationConfirmed=true,tested={}}
local initializeCalls,calibrationCalls=0,{}
local rejectSweep=false
local sweepState
package.loaded["system.services.vehiclebridged"]={snapshot=function() return snapshot end,rescan=function() rescans=rescans+1 end}
package.loaded["system.services.sabled"]={snapshot=function() return {} end,pose=function() return {} end,rescan=function() end}
package.loaded["system.services.avionicsd"]={snapshot=function() return {} end,rescan=function() end}
package.loaded["system.services.flightd"]={configuration=function() if preflightConfig then return preflightConfig end return {channels={},vehicle={},manualInputs={},balloonSetup={vehicleId="ship-a",burnerIds={"heater"}}} end,
 status=function() return {calibration=progress,sweep=sweepState} end,telemetry=function() return {} end,endpoints=function() return {{backend="frequency",name="bridge"}} end,
 configure=function() saved=saved+1 return true end,
 testOutput=function() initializeCalls=initializeCalls+1 progress.initializationConfirmed=true return true end,
 calibrate=function(_,kind)
  calibrationCalls[#calibrationCalls+1]=kind
  if kind=="channel" then preflightConfig.channels[1].validated=true
  elseif kind=="manual" then preflightConfig.manualValidated=true
  elseif kind=="rescue" then progress.rescueTested=true
  elseif kind=="rescueConfirm" then preflightConfig.rescueValidated=true end
  return true
 end,
 startSweep=function(_,p,confirmed,control)
  if rejectSweep then return false,"Sweep blocked: Rescue OK (Test rescue completed; confirmation still missing)" end
  assert(confirmed and p.first==7 and p.last==15 and control.balloonSetup.vehicleId=="ship-a")
  started=started+1 sweepState={state="running",reason="test",signal=7,count=0,options=p,levels={}} return true
 end,
 stopSweep=function() stopped=stopped+1 sweepState=nil return true end,
 disarm=function() stopped=stopped+1 sweepState=nil return true end,
}
term={getSize=function() return width,height end}
local app,win
local function command(id) assert(app:handle({name="action",args={},navigationCommand=id})) end
require("apps.navigation.main").run({pid=7,onCleanup=function() end,startTimer=function() return 1 end,
 windowManager={create=function(_,opts) app=opts.app win={closed=false} return win end},
 pullEvent=function()
  command("sweepOptions") command("sweepStart")
  command("sweepConfirm") assert(started==0,"sweep ran before read-through")
  app.sweepOptions.last=14 -- frozen confirmation must still use 15
  width,height=12,9
  for _=1,100 do app:draw(width,height) if app.sweepRead then break end command("sweepRead") end
  assert(app.sweepRead,"small-window sweep warning could not be read")
  command("sweepConfirm") assert(started==1 and saved==0)
  app:handle({name="key",args={keys.f10}}) assert(stopped==1,"F10 did not stop sweep")
  rejectSweep=true
  command("sweepOptions") command("sweepStart")
  for _=1,100 do app:draw(width,height) if app.sweepRead then break end command("sweepRead") end
  command("sweepConfirm")
  assert(app.sweepStartError and app.sweepStartError:find("Rescue OK",1,true))
  width,height=80,28 writes={} app:draw(width,height)
  assert(table.concat(writes,"\n"):find("START REFUSED:",1,true),"refusal hidden in footer")
  command("sweepOptions") app:draw(width,height)
  app.page="calibration" width,height=80,28 app:draw(width,height)
  assert(table.concat(writes,"\n"):find("Initialization this run: confirmed (retained while off)",1,true),"retained initialization not shown")
  width,height=12,9 app.scroll=100 app:draw(width,height)
  width,height=26,17
  preflightConfig={vehicle={},channels={{id="burners",backend="frequency",neutral=5,rescue=0,mix={altitude=1},actuator={role="buoyancy"}}},manualInputs={},balloonSetup={vehicleId="ship-a",burnerIds={"heater"}}}
  progress.initializationConfirmed=false progress.rescueTested=false
  command("sweepResults")
  for _,kind in ipairs({"initialize","channel","manual","rescue","rescueConfirm"}) do
    command("sweepNext") assert(app.confirm,"next preflight action needs explicit physical confirmation")
    app:handle({name="mouse_click",args={1,1,1}})
    assert(app.page=="sweep","preflight left consolidated tab")
  end
  assert(initializeCalls==1 and table.concat(calibrationCalls,",")=="channel,manual,rescue,rescueConfirm","preflight repeated initialization or skipped rescue confirmation")
  command("sweepNext") assert(not app.confirm and initializeCalls==1,"ready preflight restarted initialization")
  assert(app.page=="sweepConfirm" and app.sweepPending,"completed preflight did not open sweep review")
  preflightConfig=nil
  command("guide") assert(app.setup and app.setup.burnerCount==1,"intact burner guide blocked by missing COM")
  for i=1,60 do app.scroll=i app:draw(width,height) end
  assert(table.concat(writes,"\n"):find("signal 3/15",1,true),"live burner feedback missing from guide")
  command("diagram") command("iso") command("zoomIn") command("componentNext")
  assert(app.diagramView=="iso" and app.diagramZoom==2)
  for _,size in ipairs({{12,9},{26,17},{80,28}}) do width,height=table.unpack(size) app:draw(width,height) end
  command("inspect") app:draw(width,height) assert(app.page=="component")
  command("rescan") assert(rescans==1 and saved==0,"passive inspection wrote configuration")
  command("guide") app.setupStep=4 app.setupOptions.wiringConfirmed=true
  command("guideApply") assert(app.confirm and saved==0)
  snapshot.inventoryComplete=false
  app:handle({name="mouse_click",args={1,1,1}})
  assert(saved==0,"guide saved after inventory became incomplete")
  snapshot.inventoryComplete=true
  snapshot.burners[2]={id="inactive",position={x=1,y=2,z=4},signal=0,gasOutput=0,hasBalloon=false}
  command("guide") assert(app.setup.burnerCount==2)
  command("chooseGroup") assert(app.page=="burnerGroup") app:draw(width,height)
  app.setupSelection.inactive=false
  command("applyGroup") assert(app.confirm and saved==0)
  app:handle({name="mouse_click",args={1,1,1}})
  assert(app.setup.burnerCount==1 and app.setup.burnerIds[1]=="heater")
  assert(app.setup.ignoredBurnerIds[1]=="inactive" and saved==0,"group selection wrote control outputs")
  command("chooseGroup") app.setupSelection.heater=false command("applyGroup")
  assert(not app.confirm and app.message:find("au moins",1,true),"empty burner selection accepted")
  snapshot={available=false,ok=false,status="Vehicle bridge not installed",error="mintcraft_vehicle API missing"}
  command("guide") assert(not app.setup and app.message:find("0.2.1",1,true))
  app:draw(width,height)
  win.closed=true return {name="test",args={}}
 end})
print("Navigation equipment UI: passive diagram/inspection, live guide, missing bridge, bounded viewports and apply-time inventory rejection passed")
