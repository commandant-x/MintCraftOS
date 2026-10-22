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
package.loaded["system.gui.form"]={new=function() return {draw=function(_,w,h,fields) for _,f in ipairs(fields or {}) do if f.readOnly then writes[#writes+1]=f.label..": "..tostring(f.get()) end end end} end,field=function(object,key,label,kind,options) assert(object,"missing field object: "..tostring(label)) return {get=function() return object[key] end,set=function(v) object[key]=v end,label=label,kind=kind,options=options} end}
package.loaded["system.libraries.config"]={load=function() return {} end}
package.loaded["apps.navigation.pixel"]={sample=function() return {} end,attach=function(app)
 app.pixelPages={} app.drawPixels=function() end app.handlePixels=function() end app.handleNativeKey=function() return false end
end}
package.loaded["apps.navigation.route"]={new=function() return {refresh=function() end} end}
local snapshot={ok=true,available=true,complete=false,inventoryComplete=true,frame="body_plot",vehicleId="ship-a",status="Partial vehicle inventory",
 burnerDiscoveryAvailable=true,actuators={},links={},burners={{id="heater",position={x=1,y=2,z=3},signal=3,gasOutput=4,hasBalloon=true,gasActive=false}}}
local rescans,saved,started,stopped=0,0,0,0
local savedConfig
local endpointRows={{backend="frequency",name="bridge"}}
local preflightConfig
local progress={initializationConfirmed=true,tested={}}
local initializeCalls,calibrationCalls=0,{}
local targetCalls=0
local automaticCalls=0
local rejectSweep=false
local sweepState
package.loaded["system.services.vehiclebridged"]={snapshot=function() return snapshot end,rescan=function() rescans=rescans+1 end}
package.loaded["system.services.sabled"]={snapshot=function() return {} end,pose=function() return {} end,rescan=function() end}
package.loaded["system.services.avionicsd"]={snapshot=function() return {} end,rescan=function() end}
package.loaded["system.services.flightd"]={configuration=function() if preflightConfig then return preflightConfig end return {mode="altitude",channels={},gains={altitude={kp=0,ki=0,kd=0,limit=1,slew=1,integralLimit=1,deadband=0}},sensors={},vehicle={},manualInputs={},balloonSetup={vehicleId="ship-a",burnerIds={"heater"}}} end,
 activateAutomatic=function(actor,confirmed,options) assert(actor.pid==7 and confirmed and options.first==8 and options.last==12) automaticCalls=automaticCalls+1 return true end,
 status=function() return {calibration=progress,sweep=sweepState} end,telemetry=function() return {altitude=67.5,altitudeRate=0} end,endpoints=function() return endpointRows end,
 configure=function(_,value) saved=saved+1 savedConfig=require("system.libraries.addon").copy(value) return true end,
 setSetpoint=function(actor,axis,value) assert(actor.pid==7 and axis=="altitude" and value==68) targetCalls=targetCalls+1 return true end,
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
  app.sweepOptions.autoPrepare=false app.sweepOptions.autoHold=false app.sweepOptions.certify=false
  local sections=require("system.navigation.sections")
  assert(#sections.tabs==8 and #sections.pages()==18 and sections.parent("gains")=="sweep" and sections.parent("manual")=="mapping")
  local Surface=require("system.graphics.surface")
  local palette={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
  snapshot.complete=true snapshot.frame="body_plot" snapshot.centerOfMass={x=1,y=2,z=3}
  snapshot.units={position="block",mass="kg"} snapshot.mass=65.8 snapshot.name="Detected airship"
  app.dirty=false command("activateAutomatic")
  assert(not app.confirm and automaticCalls==0,'measurement-only options silently replaced for automatic pilot')
  app.sweepOptions.autoPrepare=true app.sweepOptions.autoHold=true app.sweepOptions.certify=true
  app.sweepOptions.first=8 app.sweepOptions.last=12
  command("activateAutomatic")
  assert(app.confirm.title:find("8 to 12",1,true),'confirmation hides selected burner range')
  app.sweepOptions.first=7 app.sweepOptions.last=15 -- confirmation must retain frozen values

  assert(app.confirm and automaticCalls==0 and app.page=="sweep","one-button action skipped clear-area confirmation")
  app:handle({name="mouse_click",args={1,1,1}})
  assert(automaticCalls==1,"automatic activation required a second workflow")
  app.sweepOptions.autoPrepare=false app.sweepOptions.autoHold=false app.sweepOptions.certify=false
  command("disarm")
  assert(app.detectedVehicle and app.detectedVehicle.massKg==65.8 and app.detectedVehicle.type=="airship" and saved==0)
  app.page="vehicle" app:drawPixels(Surface.new(600,500),600,500,palette)
  local model=app.nativePanel.state.model
  assert(#model.fields==3 and model.fields[1].value=="Detected airship" and model.fields[2].value=="airship","live identity/type not populated")
  for _,f in ipairs(model.fields) do assert(not f.label:find("COM") and not f.label:find("Mass"),"detected geometry still editable") end
  assert(saved==0 and not app.dirty,"passive detection saved or dirtied controls")
  app.panelViews=true app:drawPixels(Surface.new(600,500),600,500,palette)
  assert(#app.nativePanel.state.model.actions==8,"global view selector not consolidated") app.panelViews=false
  snapshot.available=false snapshot.ok=false
  command("guide") assert(not app.setup)
  snapshot.available=true snapshot.ok=true
  command("disarm")
  assert(app.setup and app.setupStep==3 and app.setupOptions.transmitter=="bridge","late bridge connection did not populate setup automatically")
  assert(not app.setupOptions.wiringConfirmed and saved==0,"discovery faked physical validation or saved")
  snapshot.ok=false command("disarm") assert(not app.detectedVehicle,"stale geometry stayed live")
  snapshot.ok=true snapshot.complete=false command("disarm")
  app.page="flight" app.confirm=nil stopped=0
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
  preflightConfig={mode="altitude",gains={altitude={kp=0,ki=0,kd=0,limit=1,slew=1,integralLimit=1,deadband=0}},sensors={},vehicle={},channels={{id="burners",backend="frequency",neutral=5,rescue=0,mix={altitude=1},actuator={role="buoyancy"}}},manualInputs={},balloonSetup={vehicleId="ship-a",burnerIds={"heater"}}}
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
  command("sweepResults") command("altitudeEdit") assert(app.form.edit and app.altitudeEditing)
  app:draw(width,height)
  app.form.edit.set(68) app.form.edit=nil
  command("altitudeApply") assert(app.confirm and targetCalls==0)
  app:handle({name="mouse_click",args={1,1,1}})
  assert(targetCalls==1 and app.page=="sweep")
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
  local Surface=require("system.graphics.surface")
  local palette={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
  for _,page in ipairs({"vehicle","mapping","gains","sensors","manual","calibration","setup","context","diagram","component","environment","estimates","frequencies","sweep"}) do
    app.page=page app.sweepEditing=page=="sweep"
    assert(app.pixelPages[page],"secondary page still requires legacy client: "..page)
    app:drawPixels(Surface.new(600,330),600,330,palette)
  end
  app.nativePanel.buffers={[1]="invalid"}
  local priorStopped=stopped
  app:handlePixels({name="mouse_click",args={1,5,5}})
  assert(stopped==priorStopped+1,"native STOP blocked by invalid field")
  app.nativePanel.buffers={} app.sweepOptions.last=15
  rejectSweep=false command("sweepStart")
  app.nativePanel.state.lastVisible=10000
  app:drawPixels(Surface.new(100,60),100,60,palette)
  assert(not app.sweepRead,"small native window inherited a completed warning read-through")
  for _=1,150 do
    app:drawPixels(Surface.new(600,330),600,330,palette)
    if app.sweepRead then break end
    local hit
    for _,item in ipairs(app.nativePanel.state.hits or {}) do if item.id=="sweepRead" then hit=item end end
    assert(hit,"native read-next action missing")
    app:handlePixels({name="mouse_click",args={1,hit.rect.x+1,hit.rect.y+1+app.nativePanel.header}})
  end
  assert(app.sweepRead,"native read-through cannot reach final warning")
  command("sweepConfirm") assert(started==2,"native review did not start the confirmed frozen plan")
  command("sweepStop")
  -- A fresh, unambiguous endpoint/frequency is proposed without typing or writing.
  app.page="mapping" command("add")
  app.nativePanel.buffers={} app:drawPixels(Surface.new(600,500),600,500,palette)
  app.nativePanel.buffers={[2]="frequency"} assert(app.nativePanel.commit())
  snapshot.links={{receiver=true,first={item="minecraft:red_wool",dyedColor=123},second={item="minecraft:white_wool"},position={x=1,y=2,z=2}}}
  command("disarm") app:drawPixels(Surface.new(600,500),600,500,palette)
  local before=saved local foundName,foundPair=false,false
  for _,f in ipairs(app.nativePanel.state.model.fields) do
    if f.label=="Frequency transmitter" then assert(f.value=="bridge" and f.action) foundName=true end
    if f.label=="Detected receiver frequency" then assert(f.value:find("minecraft:red_wool",1,true) and f.action) foundPair=true end
    assert(f.label~="Frequency item 1","detected pair still requires item typing")
  end
  assert(foundName and foundPair and saved==before)
  command("save") assert(saved==before+1 and savedConfig.channels[1].name=="bridge" and savedConfig.channels[1].link.firstColor==123,"unique detected choice not committed on Save")
  -- Multiple candidates stay explicit; a previous choice is not silently replaced.
  app.page="mapping" command("add") app:drawPixels(Surface.new(600,500),600,500,palette)
  app.nativePanel.buffers={[2]="frequency"} assert(app.nativePanel.commit())
  endpointRows[2]={backend="frequency",name="bridge-2"}
  snapshot.links[2]={receiver=true,first={item="minecraft:blue_wool"},second={item="minecraft:blue_wool"},position={x=3,y=2,z=2}}
  command("disarm") app:drawPixels(Surface.new(600,500),600,500,palette)
  for _,f in ipairs(app.nativePanel.state.model.fields) do
    if f.label=="Frequency transmitter" then assert(f.value=="","ambiguous endpoint selected itself") end
    if f.label=="Detected receiver frequency" then assert(f.value=="Choose detected pair","ambiguous pair selected itself") end
  end
  snapshot={available=false,ok=false,status="Vehicle bridge not installed",error="mintcraft_vehicle API missing"}
  command("guide") assert(not app.setup and app.message:find("0.2.1",1,true))
  app:draw(width,height)
  -- New height-table proposals must render in both clients (no legacy speed fields).
  app.page="sweep" app.sweepEditing=false app.confirm=nil
  app.flight.sweep={state="complete",reason="Stable heights",signal=15,count=100,options={first=7,last=9},levels={},
    proposal={kind="altitude-table",hover=8,neutral=8,tau=2,r2=0.99,gains={kp=0.05,ki=0,kd=0.2},note="Measured dynamics",
      measuredRange={first=7,last=9,minAltitude=65,maxAltitude=75},points={{heat=7,altitude=65},{heat=8,altitude=70},{heat=9,altitude=75}}}}
  width,height=80,28 app:draw(width,height)
  app:drawPixels(Surface.new(600,500),600,500,palette)
  app.page="control" app.pilotTargets=nil
  app.flight.differentialReady=false
  app:drawPixels(Surface.new(600,500),600,500,palette)
  assert(#app.nativePanel.state.model.fields==1,'altitude-only craft exposed unsupported horizontal commands')
  app.flight.differentialReady=true app.flight.maxSpeed=2
  app:drawPixels(Surface.new(600,500),600,500,palette)
  assert(#app.nativePanel.state.model.fields==3,'cockpit lacks altitude/speed/heading fields')
  win.closed=true return {name="test",args={}}
 end})
print("Navigation equipment UI: passive diagram/inspection, live guide, missing bridge, bounded viewports and apply-time inventory rejection passed")
