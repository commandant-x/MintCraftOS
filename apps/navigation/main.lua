local renderer=require("system.gui.renderer")
local ui=require("system.gui.components")
local menus=require("system.gui.action_menu")
local forms=require("system.gui.form")
local addon=require("system.libraries.addon")
local instruments=require("system.navigation.instruments")
local attitude=require("system.navigation.attitude")
local vehicle=require("system.navigation.vehicle")
local vehicleDiagram=require("system.navigation.vehicle_diagram")
local vehicleBridge=require("system.services.vehiclebridged")
local balloonSetup=require("system.navigation.balloon_setup")
local altitudeSweep=require("system.navigation.altitude_sweep")
local controlMode=require("system.navigation.control_mode")
local sable=require("system.services.sabled")
local avionics=require("system.services.avionicsd")
local flight=require("system.services.flightd")
local config=require("system.libraries.config")
local pixel=require("apps.navigation.pixel")
local M={}
local axes={"pitch","roll","altitude","heading"}
local sides={"top","bottom","left","right","front","back"}
local function fmt(value,unit)
  return addon.finite(value) and string.format("%.1f%s",value,unit or "") or "unavailable"
end
function M.run(ctx)
  local actor={pid=ctx.pid}
  local draft=flight.configuration()
  draft.vehicle=vehicle.profile(draft.vehicle)
  for _,channel in ipairs(draft.channels) do channel.actuator=vehicle.actuator(channel.actuator) end
  local original=config.load("/system/config/navigation.cfg",{})
  local app={page="flight",tabState={},barState={},pages=menus.new(),commands=menus.new(),form=forms.new(),index=1,axis=1,scroll=1,message="Control disarmed",av={},sub={},flight={},confirm=nil,sweepOptions=altitudeSweep.defaults()}
  if draft.vehicle.type=="unknown" then app.page="vehicle" end
  if ctx.args and ctx.args.page=="flight" then app.page="flight" end
  local tabs={{id="flight",label="Flight"},{id="autopilot",label="Autopilot"},{id="sublevel",label="Sublevel equipment"},{id="vehicle",label="Vehicle"},{id="setup",label="Setup guide"},{id="context",label="Vehicle analysis"},{id="control",label="Control"},{id="mapping",label="Actuators"},{id="gains",label="PID gains"},{id="sensors",label="Sensors"},{id="manual",label="Manual inputs"},{id="calibration",label="Calibration"},{id="sweep",label="Auto altitude"},{id="environment",label="Environment"},{id="estimates",label="Estimates"},{id="frequencies",label="Frequencies"}}
  local win,timer
  local function refresh()
    app.av,app.sub,app.flight=avionics.snapshot(),sable.snapshot(),flight.status()
    app.bridge=vehicleBridge.snapshot()
    if app.routePanel then app.routePanel:refresh(app.flight,sable.pose(),app.bridge,flight.endpoints()) end
    app.nativeFlight,app.nativeLastAttitude=pixel.sample(app.av,app.sub,app.flight,flight.telemetry(),app.nativeLastAttitude,os.clock())
    if win then win.dirty=true end
  end
  local function report(ok,message) app.message=ok and (message or "Done") or tostring(message or "Refused") end
  local function confirm(title,callback) app.confirm={title=title,callback=callback} end
  app.routePanel=require("apps.navigation.route").new({
    pose=sable.pose,
    page=function(id) app.page=id app.form.scroll=1 app.scroll=1 end,
    devices=function() ctx.apps.launch("devices") end,
    arm=function() if app.dirty then return false,"Save actuator changes first" end return flight.arm(actor) end,
    start=function(plan) if app.dirty then return false,"Save actuator changes first" end return flight.startMission(actor,plan,true) end,
    stop=function() return flight.stopMission(actor) end,
    disarm=function() return flight.disarm(actor) end,
  })
  local function guide(selection)
    local plan,err=balloonSetup.plan(vehicleBridge.snapshot(),draft,flight.endpoints(),selection)
    app.page="setup" app.setup=plan app.setupStep=1 app.scroll=1
    if not plan then app.message=err return end
    app.setupSelection={}
    for _,id in ipairs(plan.burnerIds) do app.setupSelection[id]=true end
    app.setupOptions={transmitter=plan.transmitter,neutral=plan.baseline or 0,rescue=0,
      inverted=false,wiringConfirmed=false,replaceExisting=false}
    app.message="Detection passive; aucun signal emis"
  end
  local function fields()
    local rows={}
    local function field(object,key,label,kind,options)
      local item=forms.field(object,key,label,kind,options)
      local set=item.set item.set=function(value) set(value) app.dirty=true end
      rows[#rows+1]=item
    end
    if app.page=="vehicle" then
      field(draft.vehicle,"name","Vehicle name","string")
      field(draft.vehicle,"type","Vehicle type",nil,vehicle.types)
      field(draft,"mode","Control mode",nil,{"full","altitude"})
      field(draft.vehicle,"rotorCount","Lift rotor count (0 = unknown)","number")
      field(draft.vehicle,"massKg","Mass (kg)","number")
      for _,axis in ipairs({"x","y","z"}) do field(draft.vehicle.com,axis,"COM body "..axis.." (blocks)","number") end
      field(draft.vehicle,"comVerified","COM body frame verified","boolean")
    elseif app.page=="mapping" then
      local channel=draft.channels[app.index]
      if not channel then return rows end
      field(channel,"id","Output ID","string")
      field(channel,"backend","Backend",nil,{"redstone","avionics","relay","frequency"})
      if channel.backend=="redstone" then field(channel,"side","PC side",nil,sides)
      else
        local names={}
        for _,row in ipairs(flight.endpoints()) do if row.backend==channel.backend then names[#names+1]=row.name end end
        local label=channel.backend=="frequency" and "Frequency transmitter" or (channel.backend=="relay" and "Redstone relay" or "Avionics endpoint")
        if #names>0 then field(channel,"name",label,nil,names) else field(channel,"name",label,"string") end
        if channel.backend=="relay" then field(channel,"side","Relay side",nil,sides) end
      end
      if channel.backend=="frequency" then
        channel.link=channel.link or {first="",second=""}
        field(channel.link,"first","Frequency item 1","string") field(channel.link,"second","Frequency item 2","string")
      end
      for _,key in ipairs({"min","max","neutral","rescue"}) do field(channel,key,key,"number") end
      channel.mix=channel.mix or {}
      for _,axis in ipairs(axes) do field(channel.mix,axis,"Mix "..axis,"number") end
      for _,key in ipairs({"routeForward","routeReverse","routeRight","routeLeft"}) do
        field(channel.mix,key,"Autopilot "..key.." (signal delta)","number")
        rows[#rows].get=function() return channel.mix[key] or 0 end
      end
      field(channel,"frequency","Create frequency (label)","string")
      if not channel.actuator then channel.actuator=vehicle.actuator() end
      if draft.vehicle.bridgeActuators and #draft.vehicle.bridgeActuators>0 then
        local options={"Manual"}
        for i=1,#draft.vehicle.bridgeActuators do options[#options+1]=i end
        rows[#rows+1]={label="Measured actuator #",options=options,get=function()
          for i,row in ipairs(draft.vehicle.bridgeActuators) do if channel.actuator.bridgeId==row.id then return i end end
          return "Manual"
        end,set=function(index)
          local measured=draft.vehicle.bridgeActuators[index]
          if measured then channel.actuator=vehicle.actuator(measured.actuator) channel.actuator.bridgeId=measured.id
          else channel.actuator.bridgeId=nil end
          app.dirty=true
        end}
      end
      field(channel.actuator,"role","Actuator role",nil,vehicle.roles)
      for _,axis in ipairs({"x","y","z"}) do field(channel.actuator.position,axis,"Position body "..axis.." (blocks)","number") end
      for _,axis in ipairs({"x","y","z"}) do field(channel.actuator.direction,axis,"Thrust direction "..axis,"number") end
      field(channel.actuator,"geometryVerified","Geometry physically verified","boolean")
    elseif app.page=="gains" then
      local available=controlMode.axes(draft)
      local axis=available[app.axis] or available[1]
      for _,key in ipairs({"kp","ki","kd","limit","slew","integralLimit","deadband"}) do field(draft.gains[axis],key,axis.." "..key,"number") end
    elseif app.page=="sensors" then
      for _,role in ipairs({"gimbal","altitude","nav"}) do
        local names={""}
        for _,row in ipairs(app.av[role] or {}) do names[#names+1]=row.name end
        field(draft.sensors,role,role.." (blank = auto)",nil,names)
      end
    elseif app.page=="manual" then
      local binding=draft.manualInputs[app.index]
      if binding then
        field(binding,"axis","Axis",nil,controlMode.axes(draft))
        field(binding,"side","Digital input side",nil,sides)
        field(binding,"value","Override -1..1","number")
      end
    elseif app.page=="sweep" then
      -- Options are a test draft, not edits to the saved flight configuration.
      for _,entry in ipairs({{"first","First heat level (1..15)"},{"last","Last heat level (1..15)"},
        {"dwell","Seconds per level (4..15)"},{"maxTravel","Max altitude/world travel (1..32 blocks)"},
        {"maxSpeed","Max vertical speed (0.1..2 blocks/s)"},{"timeout","Total time limit (10..180s)"}}) do
        rows[#rows+1]=forms.field(app.sweepOptions,entry[1],entry[2],"number")
      end
    elseif app.page=="burnerGroup" and app.setup then
      for _,burner in ipairs(app.setup.detectedBurners) do
        local label=burner.id:match("(-?%d+:-?%d+:-?%d+)$") or burner.id
        field(app.setupSelection,burner.id,label.." | "..burner.signal.."/15 | "..(burner.hasBalloon and "associated" or "unconfirmed"),"boolean")
      end
    elseif app.page=="setup" and app.setup and app.setupStep==3 then
      local options=app.setupOptions
      if #app.setup.endpoints>0 then field(options,"transmitter","Frequency transmitter",nil,app.setup.endpoints) end
      field(options,"neutral","Hover baseline signal (verify)","number")
      field(options,"rescue","Rescue transmitted signal (verify)","number")
      field(options,"inverted","Wiring inverts burner signal","boolean")
      field(options,"wiringConfirmed","Receivers/wiring physically checked","boolean")
      if #draft.channels>0 then field(options,"replaceExisting","Replace existing control mapping","boolean") end
    end
    return rows
  end
  local function lines(w,h,rows,y)
    y=y or 4
    local count=math.max(1,h-y-1)
    app.scroll=math.max(1,math.min(app.scroll,math.max(1,#rows-count+1)))
    for i=app.scroll,math.min(#rows,app.scroll+count-1) do renderer.writeAt(1,y+i-app.scroll,renderer.crop(rows[i],w)) end
  end
  local function actions()
    if app.page=="autopilot" or app.page=="sublevel" then return app.routePanel:actions() end
    if app.page=="mapping" or app.page=="manual" then return {{id="add",label="Add"},{id="save",label="Save"},{id="previous",label="Prev"},{id="next",label="Next"},{id="remove",label="Remove"}}
    elseif app.page=="vehicle" then return {{id="discover",label="Discover"},{id="guide",label="Guide"},{id="save",label="Save"},{id="mass",label="Read mass"},{id="analysis",label="Analysis"},{id="diagram",label="Diagram"}}
    elseif app.page=="sweep" or app.page=="sweepResults" then return {{id="sweepStop",label="STOP / rescue"},{id="sweepOptions",label="Options"},{id="sweepStart",label="Start sweep"},{id="sweepResults",label="Results"},{id="sweepApply",label="Apply candidate"},{id="sweepExport",label="Save report"},{id="calibrationPage",label="Calibration"}}
    elseif app.page=="sweepConfirm" then return {{id="sweepStop",label="STOP / rescue"},{id=app.sweepRead and "sweepConfirm" or "sweepRead",label=app.sweepRead and "CONFIRM" or "Read next"},{id="sweepOptions",label="Cancel"}}
    elseif app.page=="burnerGroup" then return {{id="applyGroup",label="Use group"},{id="guide",label="Reset / Detect"}}
    elseif app.page=="setup" then
      if not app.setup then return {{id="guide",label="Detect"},{id="rescan",label="Rescan"},{id="diagram",label="Diagram"},{id="devices",label="Devices"}} end
      if app.setupStep==5 then return {{id="chooseGroup",label="Group"},{id="calibrationPage",label="Calibration"},{id="pidPage",label="PID"},{id="controlPage",label="Control"}} end
      return {{id="chooseGroup",label="Group"},{id="guideBack",label="Back"},{id=app.setupStep==4 and "guideApply" or "guideNext",label=app.setupStep==4 and "Apply + Save" or "Next"},{id="rescan",label="Rescan"},{id="diagram",label="Diagram"},{id="devices",label="Devices"}}
    elseif app.page=="context" then return {{id="guide",label="Setup guide"},{id="vehicle",label="Vehicle"},{id="outputs",label="Actuators"},{id="diagram",label="Diagram"}}
    elseif app.page=="diagram" then return {{id="top",label="Top"},{id="side",label="Side"},{id="front",label="Front"},{id="iso",label="3D"},{id="componentPrev",label="Prev"},{id="componentNext",label="Next"},{id="zoomIn",label="Zoom+"},{id="zoomOut",label="Zoom-"},{id="inspect",label="Details"},{id="rescan",label="Rescan"}}
    elseif app.page=="component" then return {{id="diagram",label="Diagram"},{id="componentPrev",label="Prev"},{id="componentNext",label="Next"},{id="rescan",label="Rescan"}}
    elseif app.page=="gains" then return {{id="previous",label="Prev axis"},{id="next",label="Next axis"},{id="save",label="Save"}}
    elseif app.page=="sensors" then return {{id="save",label="Save"},{id="rescan",label="Rescan"}}
    elseif app.page=="control" then
      local out={{id="arm",label="Arm"},{id="disarm",label="Disarm"},{id="altDown",label="Alt-"},{id="altUp",label="Alt+"}}
      if draft.mode~="altitude" then out[#out+1]={id="yawLeft",label="Yaw-"} out[#out+1]={id="yawRight",label="Yaw+"} end
      return out
    elseif app.page=="calibration" then
      local out={{id="previous",label="Prev"},{id="next",label="Next"},{id="test",label="Test"}}
      if draft.balloonSetup then out[#out+1]={id="initializeBalloon",label="Initialize (2s)"} end
      out[#out+1]={id="sweepOptions",label="Auto altitude"}
      for _,item in ipairs({{id="channel",label="Verify direction"},{id="hover",label="Hover OK"},{id="manual",label="Manual OK"},{id="rescue",label="Test rescue"},{id="rescueConfirm",label="Rescue OK"},{id="disarm",label="Acknowledge"},{id="rescan",label="Rescan"}}) do out[#out+1]=item end
      return out
    else return {{id="rescan",label="Rescan"},{id="devices",label="Devices"},{id="logs",label="Logs"}} end
  end
  function app:draw(w,h)
    if h<9 then renderer.writeAt(1,1,renderer.crop("Navigation: enlarge window",w)) return end
    local title="Navigation"
    for _,tab in ipairs(tabs) do if tab.id==self.page then title=tab.label end end
    menus.bar(self.pages,1,1,w,tabs,{selector=true,label="Views: "..title,title="Navigation views",selected=self.page})
    local commands=actions()
    for _,command in ipairs(commands) do
      command.primary=command.id:match("^sweep")~=nil or self.page=="setup" or command.id=="initializeBalloon" or command.id=="guide" or command.id=="discover" or command.id=="diagram" or command.id=="top" or command.id=="side" or command.id=="add" or command.id=="mass" or command.id=="analysis" or command.id=="vehicle" or command.id=="outputs" or command.id=="save" or command.id=="disarm" or command.id=="arm" or command.id=="test" or command.id=="previous" or command.id=="next" or command.id=="rescan"
      command.danger=command.id=="arm" or command.id=="sweepConfirm"
    end
    self.bar=menus.bar(self.commands,1,2,w,commands,{title=title.." actions"})
    if self.page=="autopilot" or self.page=="sublevel" then self.routePanel:drawText(w,h)
    elseif self.page=="sweep" then
      self.form:draw(w,h,fields())
      if not self.form.edit then renderer.writeAt(1,3,renderer.crop("Sweep options; manual/rescue/direction checks required",w),colors.cyan) end
    elseif self.page=="sweepConfirm" then
      local plan=self.sweepPending
      local channel=(self.sweepPendingControl.channels or {})[1] or {}
      local paragraphs={"MEASUREMENT FLIGHT: vessel will move.","Vehicle: "..tostring((self.sweepPendingControl.balloonSetup or {}).vehicleId),"First heat level: "..plan.first,"Last heat level: "..plan.last,
        "Dwell seconds: "..plan.dwell,"Altitude/world travel limit: "..plan.maxTravel,"Vertical speed limit: "..plan.maxSpeed,
        "Nominal measurement seconds: "..((plan.last-plan.first+1)*plan.dwell),"Total seconds limit: "..plan.timeout,"Rescue transmitted signal: "..tostring(channel.rescue),
        "Tilt limit: 10 degrees. Fresh world pose required.","Shared frequency can affect other machines.","Area must be clear above and below.","F10 / STOP / physical input stops sweep.","Closing Navigation triggers rescue.",
        "Gas inertia can continue moving after cutoff.","No extrapolation outside measured range.","No automatic arming or physical confirmations."}
      local rows={}
      for _,text in ipairs(paragraphs) do
        while #text>w do rows[#rows+1]=text:sub(1,w) text=text:sub(w+1) end
        rows[#rows+1]=text
      end
      self.sweepConfirmCount=math.max(1,h-5)
      self.sweepOffset=math.min(self.sweepOffset or 1,math.max(1,#rows-self.sweepConfirmCount+1))
      for i=self.sweepOffset,math.min(#rows,self.sweepOffset+self.sweepConfirmCount-1) do renderer.writeAt(1,4+i-self.sweepOffset,rows[i]) end
      self.sweepRead=self.sweepOffset+self.sweepConfirmCount-1>=#rows
    elseif self.page=="sweepResults" then
      local s=self.flight.sweep
      local rows={"F10 / STOP stops a running sweep; data stays in RAM until Save report."}
      if not s then rows[#rows+1]="No measurement sweep yet" else
        rows[#rows+1]=s.state..": "..s.reason
        rows[#rows+1]="Heat "..s.signal.." | samples "..s.count
        for i=s.options.first,s.options.last do
          local r=s.levels[i]
          rows[#rows+1]=r and string.format("%d: n=%d | Y %.2f..%.2f | mean V/S %.3f",i,r.count,r.minAltitude,r.maxAltitude,r.sumRate/r.count).." | stable Y="..tostring(r.stableAltitude) or (i..": not measured")
        end
        if s.proposal then
          local p=s.proposal
          rows[#rows+1]=string.format("Candidate hover heat %.3f (rounded %d), tau %.2fs, fit R2 %.3f",p.hover,p.neutral,p.tau,p.r2)
          rows[#rows+1]=string.format("P %.6f | I %.6f | D 0",p.gains.kp,p.gains.ki)
          rows[#rows+1]=p.note
        else rows[#rows+1]=s.fitError or "No model/candidate yet" end
        rows[#rows+1]="Apply candidate saves neutral/PI only; physical calibration is reset, no arming."
      end
      local wrapped={}
      for _,text in ipairs(rows) do while #text>w do wrapped[#wrapped+1]=text:sub(1,w) text=text:sub(w+1) end wrapped[#wrapped+1]=text end
      lines(w,h,wrapped)
    elseif self.page=="setup" then
      renderer.writeAt(1,3,renderer.crop("Ballon : etape "..tostring(self.setupStep or 1).."/5",w),colors.cyan)
      if self.setup and self.setupStep==3 then self.form:draw(w,h,fields())
      else
        local p=self.setup
        local paragraphs=not p and {self.message} or {
          [1]={"Groupe : "..p.burnerCount.." bruleur(s) choisis sur "..#p.detectedBurners.." detectes. Group permet de modifier la selection.","Un seul canal collectif commandera leur chauffe. Maintien d'altitude uniquement : pas de stabilisation du roulis, tangage ou cap.","Aucun signal n'est emis par cet assistant."},
          [2]={"Frequence collective :",tostring(p.frequency.first),tostring(p.frequency.second),"Configurer cette paire sur chaque recepteur Create relie aux bruleurs. Relier un Redstone Link Bridge au PC.","La paire est proposee selon les liens visibles sur ce vehicule, pas reservee globalement. Verifier les machines voisines et le cablage."},
          [4]={"Verifier la frequence et le transmetteur avant Apply + Save.","Transmetteur : "..tostring(self.setupOptions.transmitter),"Stationnaire : "..tostring(self.setupOptions.neutral).." / secours : "..tostring(self.setupOptions.rescue),"Cette operation remplace le mapping seulement avec votre accord. Elle enregistre la configuration sans emettre de signal.","Les gains PID restent nuls : armement bloque avant calibration."},
          [5]={"Configuration enregistree, controle desarme.","Calibration : tester le sens, verifier le signal stationnaire et le secours physiquement. Puis regler les gains d'altitude dans PID.","Au bruleur, 0 coupe l'apport et 15 chauffe au maximum. Un cablage externe peut inverser ce sens.","Couper la chauffe ne vide pas instantanement le ballon. Le delai thermique interdit de supposer que 0 garantit une descente sure."}
        }
        if p then
          paragraphs=paragraphs[self.setupStep] or {}
          if self.setupStep==1 or self.setupStep==4 then
            for _,id in ipairs(p.burnerIds) do paragraphs[#paragraphs+1]="CHOISI : "..id end
            for _,id in ipairs(p.ignoredBurnerIds) do paragraphs[#paragraphs+1]="NON CHOISI : "..id end
            paragraphs[#paragraphs+1]="La frequence peut aussi atteindre des recepteurs non choisis : verifier le cablage et les machines voisines."
          end
        end
        for _,row in ipairs(balloonSetup.diagnostics(self.bridge or {})) do paragraphs[#paragraphs+1]=row end
        local rows={}
        for _,paragraph in ipairs(paragraphs) do
          local line=""
          for word in tostring(paragraph):gmatch("%S+") do
            if #line+#word+1>w and #line>0 then rows[#rows+1]=line line="" end
            while #word>w do rows[#rows+1]=word:sub(1,w) word=word:sub(w+1) end
            line=line=="" and word or line.." "..word
          end
          rows[#rows+1]=line rows[#rows+1]=""
        end
        lines(w,h,rows)
      end
    elseif self.page=="burnerGroup" then
      self.form:draw(w,h,fields())
      if not self.form.edit then renderer.writeAt(1,3,renderer.crop("Choose group | local XYZ / signal / association",w),colors.cyan) end
    elseif self.page=="vehicle" or self.page=="mapping" or self.page=="manual" or self.page=="gains" or self.page=="sensors" then
      self.form:draw(w,h,fields())
      if not self.form.edit then renderer.writeAt(1,3,renderer.crop(self.page=="mapping" and ("Output "..self.index.."/"..#draft.channels.." | PC / Avionics / relay") or "Configuration draft",w),colors.cyan) end
    elseif self.page=="diagram" then
      local analysis=vehicle.analyze(draft.vehicle,draft.channels)
      vehicleDiagram.draw(w,h,analysis,draft.vehicle,false,{snapshot=self.bridge,view=self.diagramView,index=self.componentIndex,zoom=self.diagramZoom})
    elseif self.page=="component" then
      local model=vehicleDiagram.model(vehicle.analyze(draft.vehicle,draft.channels),draft.vehicle,self.bridge)
      local rows={}
      -- Wrap identifiers and coordinates rather than silently cropping diagnostic data.
      for _,row in ipairs(vehicleDiagram.details(model,self.componentIndex or 1)) do
        while #row>w do rows[#rows+1]=row:sub(1,w) row=row:sub(w+1) end
        rows[#rows+1]=row
      end
      lines(w,h,rows)
    elseif self.page=="context" then
      local analysis=vehicle.analyze(draft.vehicle,draft.channels)
      local rows={analysis.frame,draft.vehicle.type.." | "..fmt(draft.vehicle.massKg," kg")}
      rows[#rows+1]="Bridge: "..tostring(self.bridge and self.bridge.status or "waiting")
      rows[#rows+1]="Physical rotors: "..tostring(#(draft.vehicle.bridgeActuators or {})).." | mapped commands: "..tostring(#draft.channels)
      if draft.vehicle.bridgeMass then rows[#rows+1]="Bridge mass: "..fmt(draft.vehicle.bridgeMass).." "..tostring((draft.vehicle.bridgeUnits or {}).mass) end
      for _,link in ipairs(draft.vehicle.bridgeLinks or {}) do rows[#rows+1]=(link.receiver and "RX " or "TX ")..link.first.item.." + "..link.second.item.." | motor link unknown" end
      rows[#rows+1]="Detected propellers: "..tostring(#(self.av.propeller or {})).." | signal endpoints: "..tostring(#flight.endpoints())
      for _,row in ipairs(analysis.rows) do
        rows[#rows+1]=tostring(row.id).." | "..row.role
        if row.torque then rows[#rows+1]=string.format("  geometry/N: pitch %.2f yaw %.2f roll %.2f",row.torque.pitch,row.torque.yaw,row.torque.roll) end
      end
      for _,warning in ipairs(analysis.warnings) do rows[#rows+1]="- "..warning end
      lines(w,h,rows)
    elseif self.page=="flight" then
      local measured=self.av.measurements or {}
      local sample,fresh=attitude.sample(measured,self.lastAttitude,os.clock())
      self.lastAttitude=sample
      local pitch=sample and sample.pitch
      local roll=sample and sample.roll
      renderer.writeAt(1,3,renderer.crop(fresh and "Measured attitude | +Z heading = south" or (sample and "STALE attitude | holding last sample" or "STALE / missing flight telemetry"),w),fresh and colors.cyan or colors.orange)
      local graphW=w>=65 and math.floor(w*0.52) or w
      local graphH=w>=65 and math.max(3,h-5) or math.max(2,math.floor((h-5)/2))
      local key=graphW..":"..graphH..":"..tostring(pitch)..":"..tostring(roll)
      if key~=self.horizonKey and (not self.horizon or os.clock()-(self.graphAt or -1)>=0.2 or self.graphW~=graphW or self.graphH~=graphH) then
        self.horizon=instruments.horizon(graphW,graphH,pitch,roll) self.horizonKey=key self.graphAt=os.clock() self.graphW,self.graphH=graphW,graphH
      end
      self.horizon:draw(1,4)
      if not pitch or not roll then renderer.writeAt(2,4,renderer.crop("Attitude unavailable",math.max(1,graphW-2)),colors.white,colors.black) end
      local x,y=graphW<w and graphW+2 or 1,graphW<w and 4 or 4+graphH
      local t=flight.telemetry()
      local mass=self.sub.sublevel and self.sub.sublevel.mass
      local velocity=addon.vec(self.sub.sublevel and self.sub.sublevel.linearVelocity)
      local speed=velocity and math.sqrt(velocity.x^2+velocity.y^2+velocity.z^2)
      local rows={"REAL | "..tostring(self.sub.status or "waiting"),"Pitch "..fmt(pitch,"deg").." Roll "..fmt(roll,"deg"),"Alt "..fmt(t.altitude,"m").." V/S "..fmt(t.altitudeRate,"m/s"),"Heading "..fmt(t.heading,"deg +Z=0"),"Source: "..tostring(t.headingSource or "missing heading sensor"),"Speed "..fmt(speed,"m/s"),"Mass "..fmt(mass,"kg"),"Control: "..tostring(self.flight.state)}
      for i=1,math.min(#rows,h-y) do renderer.writeAt(x,y+i-1,renderer.crop(rows[i],w-x+1)) end
    elseif self.page=="control" then
      local rows={"State: "..tostring(self.flight.state),tostring(self.flight.reason),draft.mode=="altitude" and "Altitude only; no attitude/heading hold" or "Pitch/roll setpoint: 0 deg at arm","Measured altitude: "..fmt(flight.telemetry().altitude,"m"),"Altitude target: "..(self.flight.targets and self.flight.targets.altitude and fmt(self.flight.targets.altitude,"m") or "set when armed"),"Readiness:"}
      for _,err in ipairs(self.flight.errors or {}) do rows[#rows+1]="- "..err end
      for name,value in pairs(self.flight.outputs or {}) do rows[#rows+1]=name.." signal="..value end
      lines(w,h,rows)
    elseif self.page=="calibration" then
      local channel=draft.channels[self.index]
      local progress=self.flight.calibration or {}
      local tested=channel and progress.tested and progress.tested[channel.id]
      local step=not channel and "Outputs: no saved output" or (not tested and not channel.validated and "Pending: Test" or (not channel.validated and "Pending: Verify direction" or "Direction verified"))
      local rows={"Output: "..tostring(channel and channel.id or "none - add outputs in Outputs"),step,"Neutral "..tostring(channel and channel.neutral).." / rescue "..tostring(channel and channel.rescue),"Hover: "..tostring(draft.hoverValidated==true).." Manual: "..tostring(draft.manualValidated==true),"Rescue tested: "..tostring(progress.rescueTested==true).." Verified: "..tostring(draft.rescueValidated==true),tostring(self.flight.state)..": "..tostring(self.flight.reason),"Arming prerequisites:"}
      for _,err in ipairs(self.flight.errors or {}) do rows[#rows+1]="- "..err end
      if draft.balloonSetup then
        rows[#rows+1]="Initialize (2s): requires fresh signal feedback from EVERY chosen burner"
        rows[#rows+1]="Initialization this run: "..(progress.initializationConfirmed and "confirmed (retained while off)" or "not confirmed")
        if progress.initializationConfirmed then rows[#rows+1]="At signal 0, no_balloon_reference is not a new initialization failure." end
        local test=progress.test
        if test and test.burnerTest then rows[#rows+1]="Burner feedback: "..(test.burnerFeedback and "confirmed" or tostring(test.feedbackError or "waiting")) end
        for _,burner in ipairs((self.bridge or {}).burners or {}) do
          local label=burner.id:match("^[^:]+:(.*)$") or burner.id
          rows[#rows+1]="Burner "..label.." signal="..tostring(burner.signal).." association_now="..tostring(burner.hasBalloon)
          if burner.associationState then rows[#rows+1]="  "..burner.associationState.." | gas active="..tostring(burner.gasActive==true) end
        end
      end
      local wrapped={}
      for _,row in ipairs(rows) do
        while #row>w do wrapped[#wrapped+1]=row:sub(1,w) row=row:sub(w+1) end
        wrapped[#wrapped+1]=row
      end
      lines(w,h,wrapped,6)
      self.testValue=self.testValue or {value=channel and channel.neutral or 0}
      ui.input(1,4,w,"Test signal",self.testValue.value,false)
      if self.form.edit then self.form:draw(w,h,{forms.field(self.testValue,"value","Test signal","number")}) end
    elseif self.page=="environment" then
      local a=self.sub.aero or {}
      local g=addon.vec(a.gravity or ((self.av.measurements or {}).gravity or {}).value)
      local rows={"MEASURED", "Gravity "..(g and fmt(math.sqrt(g.x^2+g.y^2+g.z^2),"m/s2") or "unavailable"),"Pressure "..fmt(((self.av.measurements or {}).pressure or {}).value," fraction"),"Magnetic north: "..(a.magneticNorth and textutils.serialize(a.magneticNorth) or "unavailable"),"Drag: "..tostring(a.universalDrag or "unavailable")}
      for _,row in ipairs(self.av.propeller or {}) do rows[#rows+1]=row.name.." active="..tostring(row.data and row.data.active).." thrust="..fmt(row.data and row.data.thrust,"pN raw") end
      lines(w,h,rows)
    elseif self.page=="estimates" then
      local aircraft=original.aircraft or {}
      local rows={"ESTIMATES - not flight calibration","Declared mass "..fmt(aircraft.massKg,"kg"),"Declared weight "..fmt(aircraft.declaredWeightNewton,"N")}
      for _,level in ipairs(aircraft.altitudeLevels or {}) do rows[#rows+1]="Level "..level.level.." = "..level.y.."m (legacy estimate)" end
      lines(w,h,rows)
    elseif self.page=="frequencies" then
      local rows={}
      for _,command in ipairs((original.aircraft or {}).commands or {}) do rows[#rows+1]=command.name.." : "..command.frequency end
      lines(w,h,rows)
    end
    local message=(self.page=="autopilot" or self.page=="sublevel") and self.routePanel.message or self.message
    renderer.writeAt(1,h,renderer.crop((self.dirty and "Unsaved | " or "")..message,w),colors.white,colors.gray)
    if self.confirm then
      renderer.fill(1,3,w,h-3,colors.gray)
      renderer.writeAt(1,4,renderer.crop(self.confirm.title,w),colors.white,colors.gray)
      self.confirmBar=ui.toolbar(1,math.min(h-1,6),w,{{id="confirm",label="Confirm"},{id="cancel",label="Cancel"}})
    end
    if not self.confirm and not self.form.edit then menus.overlay(self.pages,w,h) menus.overlay(self.commands,w,h) end
  end
  function app:handle(event)
    if event.name=="key" and keys.f10 and event.args[1]==keys.f10 then
      local s=flight.status().sweep
      if s and s.state=="running" then report(flight.stopSweep(actor)) else report(flight.stopMission(actor)) end
      refresh() return true
    end
    local routePage=self.page=="autopilot" or self.page=="sublevel"
    if routePage and self.graphicsActive then
      self.routePanel.graphicsActive=true
      if self.routePanel:handlePixelKey(event) then return true end
    end
    if routePage and self.routePanel.form.edit then return self.routePanel:handleText(event) end
    if self:handleNativeKey(event) then return true end
    if self.confirm then
      if event.name=="mouse_click" then
        local id=ui.toolbarHit(self.confirmBar,event.args[2],event.args[3])
        if id=="confirm" then local callback=self.confirm.callback self.confirm=nil callback() refresh()
        elseif id=="cancel" then self.confirm=nil end
      end
      return true
    end
    if self.form.edit then return self.form:handle(event) end
    local section,command,handled
    if event.navigationCommand then section,command,handled="commands",event.navigationCommand,true
    else section,command,handled=menus.route({{name="pages",state=self.pages},{name="commands",state=self.commands}},event) end
    if handled then
      if section=="pages" then
        if command then self.page=command self.form.scroll=1 self.scroll=1 self.testValue=nil if command=="setup" then guide() end if command=="sublevel" then self.routePanel.view="sublevel" elseif command=="autopilot" then self.routePanel.view="route" end end
        return true
      end
      if not command then return true end
    end
    if command and command:match("^route:") then self.routePanel:action(command) refresh() return true end
    if routePage then return self.routePanel:handleText(event) end
    if event.name=="mouse_scroll" and self.page~="sweep" and self.page~="sweepConfirm" and self.page~="burnerGroup" and self.page~="vehicle" and self.page~="mapping" and self.page~="manual" and self.page~="gains" and self.page~="sensors" and not (self.page=="setup" and self.setupStep==3) then self.scroll=self.scroll+event.args[1] return true end
    if event.name=="mouse_click" or command then
      local _,x,y=table.unpack(event.args)
      local id=command
      if id=="previous" or id=="next" then
        if self.page=="gains" then self.axis=(self.axis+(id=="next" and 1 or -1)-1)%#controlMode.axes(draft)+1
        else self.index=math.max(1,math.min(self.page=="manual" and #draft.manualInputs or #draft.channels,self.index+(id=="next" and 1 or -1))) end
        self.testValue=nil self.form.scroll=1 return true
      elseif id=="add" then
        self.dirty=true
        if self.page=="manual" then draft.manualInputs[#draft.manualInputs+1]={axis="altitude",side="back",value=1} self.index=#draft.manualInputs return true end
        draft.channels[#draft.channels+1]={id="output"..(#draft.channels+1),backend="redstone",side=sides[math.min(6,#draft.channels+1)],min=0,max=15,neutral=15,rescue=15,mix={pitch=0,roll=0,altitude=0,heading=0},validated=false,frequency=""}
        self.index=#draft.channels return true
      elseif id=="remove" then self.dirty=true local rows=self.page=="manual" and draft.manualInputs or draft.channels if self.index<=#rows then table.remove(rows,self.index) end self.index=math.max(1,math.min(self.index,#rows)) return true
      elseif id=="save" then report(flight.configure(actor,draft)) if self.message=="Done" then draft=flight.configuration() draft.vehicle=vehicle.profile(draft.vehicle) self.dirty=false end refresh() return true
      elseif id=="sweepOptions" then self.page="sweep" self.form.scroll=1 self.sweepPending=nil return true
      elseif id=="sweepResults" then self.page="sweepResults" self.scroll=1 return true
      elseif id=="sweepStop" then report(flight.disarm(actor)) refresh() return true
      elseif id=="sweepStart" then
        if self.dirty then report(false,"Save control changes before sweep") return true end
        local plan,err=altitudeSweep.validate(self.sweepOptions)
        if not plan then report(false,err) return true end
        self.sweepPending=addon.copy(plan) self.sweepPendingControl=flight.configuration() self.sweepRead=false self.sweepOffset=1 self.page="sweepConfirm" return true
      elseif id=="sweepRead" then self.sweepOffset=(self.sweepOffset or 1)+(self.sweepConfirmCount or 1) return true
      elseif id=="sweepConfirm" then
        if not self.sweepRead or not self.sweepPending then report(false,"Read all sweep limits first") return true end
        local plan=addon.copy(self.sweepPending) self.sweepPending=nil
        self.page="sweepResults" self.scroll=1 report(flight.startSweep(actor,plan,true,self.sweepPendingControl)) refresh() return true
      elseif id=="sweepExport" then report(flight.exportSweep(actor)) return true
      elseif id=="sweepApply" then
        if self.dirty then report(false,"Save changes before applying candidate") return true end
        confirm("Save measured neutral/PI candidate? Resets physical calibration; does not arm.",function()
          local ok,err=flight.applySweep(actor,true) report(ok,err)
          if ok then draft=flight.configuration() draft.vehicle=vehicle.profile(draft.vehicle) self.dirty=false end
          refresh()
        end) return true
      elseif id=="guide" then guide() return true
      elseif id=="chooseGroup" then self.page="burnerGroup" self.form.scroll=1 return true
      elseif id=="applyGroup" then
        local selection=addon.copy(self.setupSelection)
        local expectedId=self.setup.vehicleId
        local plan,err=balloonSetup.plan(vehicleBridge.snapshot(),draft,flight.endpoints(),selection)
        if not plan then report(false,err) return true end
        confirm("Use "..plan.burnerCount.." selected burners, exclude "..#plan.ignoredBurnerIds.."? Check shared frequency wiring.",function()
          if vehicleBridge.snapshot().vehicleId~=expectedId then report(false,"Vehicle changed; Detect again") return end
          guide(selection)
        end) return true
      elseif id=="guideBack" then self.setupStep=math.max(1,self.setupStep-1) self.form.scroll=1 self.scroll=1 return true
      elseif id=="guideNext" then
        if self.setupStep==3 then local candidate,err=balloonSetup.create(draft,self.setup,self.setupOptions) if not candidate then report(false,err) return true end end
        self.setupStep=math.min(4,self.setupStep+1) self.form.scroll=1 self.scroll=1 return true
      elseif id=="guideApply" then
        confirm("Save collective burner mapping? No signal emitted.",function()
          local latest=vehicleBridge.snapshot()
          if not latest.ok or latest.inventoryComplete~=true or latest.vehicleId~=self.setup.vehicleId then report(false,"Vehicle changed or unavailable; Detect again") return end
          local present={} for _,burner in ipairs(latest.burners or {}) do present[burner.id]=true end
          for _,burnerId in ipairs(self.setup.burnerIds) do if not present[burnerId] then report(false,"Burner missing; Detect again") return end end
          local candidate,err=balloonSetup.create(draft,self.setup,self.setupOptions)
          if not candidate then report(false,err) return end
          local ok,message=flight.configure(actor,candidate) report(ok,message)
          if ok then draft=flight.configuration() draft.vehicle=vehicle.profile(draft.vehicle) self.dirty=false self.setupStep=5 self.scroll=1 end
        end) return true
      elseif id=="calibrationPage" or id=="pidPage" or id=="controlPage" then
        self.page=id=="pidPage" and "gains" or (id=="controlPage" and "control" or "calibration") self.axis=1 self.index=1 self.form.scroll=1 self.scroll=1 return true
      elseif id=="discover" then
        local snapshot=vehicleBridge.snapshot()
        local imported,err=vehicle.import(draft.vehicle,snapshot)
        if not imported then
          self.message=err..": "..tostring(snapshot.status)
          confirm(renderer.crop("Bridge unavailable: "..tostring(snapshot.status)..". Open Logs?",100),function() ctx.apps.launch("logs") end)
        else
          confirm("Import measured geometry? Outputs stay unchanged.",function()
            local latest=vehicleBridge.snapshot()
            if latest.vehicleId~=snapshot.vehicleId then report(false,"Vehicle changed; Discover again") return end
            local current,problem=vehicle.import(draft.vehicle,latest)
            if not current then report(false,problem) return end
            draft.vehicle=current self.dirty=true self.page="context"
            self.message="Geometry imported into draft; confirm type/axes, then Save"
            if #(current.bridgeBurners or {})>0 then guide() end
          end)
        end return true
      elseif id=="mass" then
        local mass=self.sub.measurements and self.sub.measurements.mass
        if mass and mass.valid and addon.finite(mass.value) and mass.value>0 and mass.validUntil and os.clock()<=mass.validUntil then
          draft.vehicle.massKg=mass.value self.dirty=true self.message="Measured mass copied"
        else self.message="Fresh measured Sable mass unavailable" end return true
      elseif id=="analysis" then self.page="context" return true
      elseif id=="diagram" then self.page="diagram" return true
      elseif id=="top" or id=="side" or id=="front" or id=="iso" then self.diagramView=id return true
      elseif id=="componentPrev" or id=="componentNext" then
        local model=vehicleDiagram.model(vehicle.analyze(draft.vehicle,draft.channels),draft.vehicle,self.bridge)
        self.componentIndex=math.max(1,math.min(#model.points,(self.componentIndex or 1)+(id=="componentNext" and 1 or -1))) self.scroll=1 return true
      elseif id=="zoomIn" or id=="zoomOut" then
        self.diagramZoom=math.max(1,math.min(8,(self.diagramZoom or 1)*(id=="zoomIn" and 2 or 0.5))) return true
      elseif id=="inspect" then self.page="component" self.scroll=1 return true
      elseif id=="vehicle" then self.page="vehicle" return true
      elseif id=="outputs" then self.page="mapping" return true
      elseif id=="rescan" then avionics.rescan() sable.rescan() vehicleBridge.rescan() return true
      elseif id=="devices" or id=="logs" then ctx.apps.launch(id) return true
      elseif id=="arm" then if self.dirty then self.message="Save changes first" return true end confirm(draft.mode=="altitude" and "Arm current altitude hold only?" or "Arm horizontal attitude + current altitude/heading?",function() report(flight.arm(actor)) end) return true
      elseif id=="disarm" then report(flight.disarm(actor)) refresh() return true
      elseif id=="altDown" or id=="altUp" then report(flight.manual(actor,"altitude",id=="altUp" and 1 or -1)) return true
      elseif id=="yawLeft" or id=="yawRight" then report(flight.manual(actor,"heading",id=="yawRight" and 1 or -1)) return true
      elseif id=="initializeBalloon" then
        if self.dirty then report(false,"Save changes first") return true end
        local channel=draft.channels[self.index]
        local value=self.testValue and self.testValue.value or channel and channel.neutral
        if not draft.balloonSetup or not channel or channel.backend~="frequency" or not channel.actuator or channel.actuator.role~="buoyancy" then report(false,"Select the collective burner frequency output") return true end
        if not addon.finite(value) or value%1~=0 or value<=0 or value>15 then report(false,"Set Test signal to a physically checked nonzero value (1..15)") return true end
        local expected=(channel.mix.altitude or 0)<0 and 15-value or value
        if expected<=0 then report(false,"Choose a signal that actually heats the burner; check inversion") return true end
        confirm("Transmit "..value.." for 2s; expect burners "..expected..", then rescue "..channel.rescue.."?",function()
          report(flight.testOutput(actor,channel.id,value,true,2))
        end) return true
      elseif id=="test" then
        local function setup()
          self.page="mapping" self.form.scroll=1 self.scroll=1
        end
        if self.dirty then
          self.message="Save changes before testing"
          confirm("Unsaved configuration. Open Outputs to save?",setup)
          return true
        end
        local channel=draft.channels[self.index]
        if channel then
          self.testValue=self.testValue or {value=channel.neutral}
          if self.testValue.value==channel.neutral or self.testValue.value==channel.rescue then
            confirm("Test signal equals neutral/rescue. Edit signal?",function()
              self.form.edit=forms.field(self.testValue,"value","Test signal","number")
              self.form.text=tostring(self.testValue.value)
            end)
            return true
          end
          confirm("Test "..channel.id.." at signal "..tostring(self.testValue.value).."?",function() report(flight.testOutput(actor,channel.id,self.testValue.value,true)) end)
        else
          self.message="No saved output to test"
          confirm("No saved output. Open Outputs setup?",setup)
        end return true
      elseif id=="channel" or id=="hover" or id=="manual" or id=="rescue" or id=="rescueConfirm" then
        if self.dirty then self.message="Save changes first" return true end
        local channel=draft.channels[self.index]
        confirm("Physically verify "..id.." before confirming",function()
          local ok,message=flight.calibrate(actor,id,channel and channel.id,true)
          report(ok,message)
          if ok then draft=flight.configuration() draft.vehicle=vehicle.profile(draft.vehicle) end
        end) return true
      elseif self.page=="calibration" and y==4 then
        local channel=draft.channels[self.index]
        self.testValue=self.testValue or {value=channel and channel.neutral or 0}
        self.form.edit=forms.field(self.testValue,"value","Test signal","number") self.form.text=tostring(self.testValue.value) return true
      end
    end
    if self.page=="sweep" or self.page=="burnerGroup" or self.page=="vehicle" or self.page=="mapping" or self.page=="manual" or self.page=="gains" or self.page=="sensors" or (self.page=="setup" and self.setupStep==3) then return self.form:handle(event) end
    return false
  end
  pixel.attach(app,{
    page=function(id)
      for _,tab in ipairs(tabs) do if tab.id==id then
        app.page=id app.form.scroll=1 app.scroll=1 app.testValue=nil
        if id=="sublevel" then app.routePanel.view="sublevel" elseif id=="autopilot" then app.routePanel.view="route" end
        if id=="setup" then guide() end
        if win then win.dirty=true end
        return
      end end
    end,
    action=function(id)
      if id=="rescan" then app:handle({name="navigation_action",args={},navigationCommand=id}) end
    end,
  },tabs)
  local nativeDraw,nativeHandle=app.drawPixels,app.handlePixels
  app.pixelPages.autopilot=true app.pixelPages.sublevel=true
  function app:drawPixels(s,w,h,p)
    if self.page=="autopilot" or self.page=="sublevel" then self.routePanel:drawPixels(s,w,h,p)
    else nativeDraw(self,s,w,h,p) end
  end
  function app:handlePixels(event)
    if self.page=="autopilot" or self.page=="sublevel" then return self.routePanel:handlePixels(event) end
    return nativeHandle(self,event)
  end
  refresh()
  local w,h=term.getSize()
  win=ctx.windowManager:create({title="Navigation",w=math.min(110,w-2),h=math.min(36,h-2),x=2,y=2,
    minPixelWidth=156,minPixelHeight=180,app=app})
  ctx.onCleanup(function() if timer then os.cancelTimer(timer) end flight.release(ctx.pid,"Navigation closed/crashed/killed") end)
  timer=ctx.startTimer(0.2)
  while not win.closed do
    local event=ctx.pullEvent()
    if event.name=="timer" and event.args[1]==timer then
      if not win.minimized then refresh() end timer=ctx.startTimer(0.2)
    end
  end
end
return M
