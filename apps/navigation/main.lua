local renderer=require("system.gui.renderer")
local ui=require("system.gui.components")
local menus=require("system.gui.action_menu")
local forms=require("system.gui.form")
local addon=require("system.libraries.addon")
local instruments=require("system.navigation.instruments")
local attitude=require("system.navigation.attitude")
local sable=require("system.services.sabled")
local avionics=require("system.services.avionicsd")
local flight=require("system.services.flightd")
local config=require("system.libraries.config")
local M={}
local axes={"pitch","roll","altitude","heading"}
local sides={"top","bottom","left","right","front","back"}
local function fmt(value,unit)
  return addon.finite(value) and string.format("%.1f%s",value,unit or "") or "unavailable"
end
function M.run(ctx)
  local actor={pid=ctx.pid}
  local draft=flight.configuration()
  local original=config.load("/system/config/navigation.cfg",{})
  local app={page="flight",tabState={},barState={},pages=menus.new(),commands=menus.new(),form=forms.new(),index=1,axis=1,scroll=1,message="Control disarmed",av={},sub={},flight={},confirm=nil}
  local tabs={{id="flight",label="Flight"},{id="control",label="Control"},{id="mapping",label="Outputs"},{id="gains",label="PID gains"},{id="sensors",label="Sensors"},{id="manual",label="Manual inputs"},{id="calibration",label="Calibration"},{id="environment",label="Environment"},{id="estimates",label="Estimates"},{id="frequencies",label="Frequencies"}}
  local win,timer
  local function refresh()
    app.av,app.sub,app.flight=avionics.snapshot(),sable.snapshot(),flight.status()
  end
  local function report(ok,message) app.message=ok and (message or "Done") or tostring(message or "Refused") end
  local function confirm(title,callback) app.confirm={title=title,callback=callback} end
  local function fields()
    local rows={}
    local function field(object,key,label,kind,options)
      local item=forms.field(object,key,label,kind,options)
      local set=item.set item.set=function(value) set(value) app.dirty=true end
      rows[#rows+1]=item
    end
    if app.page=="mapping" then
      local channel=draft.channels[app.index]
      if not channel then return rows end
      field(channel,"id","Output ID","string")
      field(channel,"backend","Backend",nil,{"redstone","avionics","relay"})
      if channel.backend=="redstone" then field(channel,"side","PC side",nil,sides)
      else
        local names={}
        for _,row in ipairs(flight.endpoints()) do if row.backend==channel.backend then names[#names+1]=row.name end end
        local label=channel.backend=="relay" and "Redstone relay" or "Avionics endpoint"
        if #names>0 then field(channel,"name",label,nil,names) else field(channel,"name",label,"string") end
        if channel.backend=="relay" then field(channel,"side","Relay side",nil,sides) end
      end
      for _,key in ipairs({"min","max","neutral","rescue"}) do field(channel,key,key,"number") end
      channel.mix=channel.mix or {}
      for _,axis in ipairs(axes) do field(channel.mix,axis,"Mix "..axis,"number") end
      field(channel,"frequency","Create frequency (label)","string")
    elseif app.page=="gains" then
      local axis=axes[app.axis]
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
        field(binding,"axis","Axis",nil,axes)
        field(binding,"side","Digital input side",nil,sides)
        field(binding,"value","Override -1..1","number")
      end
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
    if app.page=="mapping" or app.page=="manual" then return {{id="previous",label="Prev"},{id="next",label="Next"},{id="add",label="Add"},{id="remove",label="Remove"},{id="save",label="Save"}}
    elseif app.page=="gains" then return {{id="previous",label="Prev axis"},{id="next",label="Next axis"},{id="save",label="Save"}}
    elseif app.page=="sensors" then return {{id="save",label="Save"},{id="rescan",label="Rescan"}}
    elseif app.page=="control" then return {{id="arm",label="Arm"},{id="disarm",label="Disarm"},{id="altDown",label="Alt-"},{id="altUp",label="Alt+"},{id="yawLeft",label="Yaw-"},{id="yawRight",label="Yaw+"}}
    elseif app.page=="calibration" then return {{id="previous",label="Prev"},{id="next",label="Next"},{id="test",label="Test"},{id="channel",label="Verify direction"},{id="hover",label="Hover OK"},{id="manual",label="Manual OK"},{id="rescue",label="Test rescue"},{id="rescueConfirm",label="Rescue OK"},{id="disarm",label="Acknowledge"}}
    else return {{id="rescan",label="Rescan"},{id="devices",label="Devices"},{id="logs",label="Logs"}} end
  end
  function app:draw(w,h)
    if h<9 then renderer.writeAt(1,1,renderer.crop("Navigation: enlarge window",w)) return end
    local title="Navigation"
    for _,tab in ipairs(tabs) do if tab.id==self.page then title=tab.label end end
    menus.bar(self.pages,1,1,w,tabs,{selector=true,label="Views: "..title,title="Navigation views",selected=self.page})
    local commands=actions()
    for _,command in ipairs(commands) do
      command.primary=command.id=="save" or command.id=="disarm" or command.id=="arm" or command.id=="test" or command.id=="previous" or command.id=="next" or command.id=="rescan"
      command.danger=command.id=="arm"
    end
    self.bar=menus.bar(self.commands,1,2,w,commands,{title=title.." actions"})
    if self.page=="mapping" or self.page=="manual" or self.page=="gains" or self.page=="sensors" then
      self.form:draw(w,h,fields())
      if not self.form.edit then renderer.writeAt(1,3,renderer.crop(self.page=="mapping" and ("Output "..self.index.."/"..#draft.channels.." | PC / Avionics / relay") or "Configuration draft",w),colors.cyan) end
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
      local rows={"State: "..tostring(self.flight.state),tostring(self.flight.reason),"Pitch/roll setpoint: 0 deg at arm","Altitude: "..fmt(self.flight.targets and self.flight.targets.altitude,"m"),"Heading: "..fmt(self.flight.targets and self.flight.targets.heading,"deg"),"Readiness:"}
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
      lines(w,h,rows,6)
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
    renderer.writeAt(1,h,renderer.crop(self.dirty and "Unsaved mapping; Save before calibration/arm" or self.message,w),colors.white,colors.gray)
    if self.confirm then
      renderer.fill(1,3,w,h-3,colors.gray)
      renderer.writeAt(1,4,renderer.crop(self.confirm.title,w),colors.white,colors.gray)
      self.confirmBar=ui.toolbar(1,math.min(h-1,6),w,{{id="confirm",label="Confirm"},{id="cancel",label="Cancel"}})
    end
    if not self.confirm and not self.form.edit then menus.overlay(self.pages,w,h) menus.overlay(self.commands,w,h) end
  end
  function app:handle(event)
    if self.confirm then
      if event.name=="mouse_click" then
        local id=ui.toolbarHit(self.confirmBar,event.args[2],event.args[3])
        if id=="confirm" then local callback=self.confirm.callback self.confirm=nil callback() refresh()
        elseif id=="cancel" then self.confirm=nil end
      end
      return true
    end
    if self.form.edit then return self.form:handle(event) end
    local section,command,handled=menus.route({{name="pages",state=self.pages},{name="commands",state=self.commands}},event)
    if handled then
      if section=="pages" then
        if command then self.page=command self.form.scroll=1 self.scroll=1 self.testValue=nil end
        return true
      end
      if not command then return true end
    end
    if event.name=="mouse_scroll" and self.page~="mapping" and self.page~="manual" and self.page~="gains" and self.page~="sensors" then self.scroll=self.scroll+event.args[1] return true end
    if event.name=="mouse_click" or command then
      local _,x,y=table.unpack(event.args)
      local id=command
      if id=="previous" or id=="next" then
        if self.page=="gains" then self.axis=(self.axis+(id=="next" and 1 or -1)-1)%4+1
        else self.index=math.max(1,math.min(self.page=="manual" and #draft.manualInputs or #draft.channels,self.index+(id=="next" and 1 or -1))) end
        self.testValue=nil self.form.scroll=1 return true
      elseif id=="add" then
        self.dirty=true
        if self.page=="manual" then draft.manualInputs[#draft.manualInputs+1]={axis="altitude",side="back",value=1} self.index=#draft.manualInputs return true end
        draft.channels[#draft.channels+1]={id="output"..(#draft.channels+1),backend="redstone",side=sides[math.min(6,#draft.channels+1)],min=0,max=15,neutral=15,rescue=15,mix={pitch=0,roll=0,altitude=0,heading=0},validated=false,frequency=""}
        self.index=#draft.channels return true
      elseif id=="remove" then self.dirty=true local rows=self.page=="manual" and draft.manualInputs or draft.channels if self.index<=#rows then table.remove(rows,self.index) end self.index=math.max(1,math.min(self.index,#rows)) return true
      elseif id=="save" then report(flight.configure(actor,draft)) if self.message=="Done" then draft=flight.configuration() self.dirty=false end refresh() return true
      elseif id=="rescan" then avionics.rescan() sable.rescan() return true
      elseif id=="devices" or id=="logs" then ctx.apps.launch(id) return true
      elseif id=="arm" then if self.dirty then self.message="Save changes first" return true end confirm("Arm horizontal attitude + current altitude/heading?",function() report(flight.arm(actor)) end) return true
      elseif id=="disarm" then report(flight.disarm(actor)) refresh() return true
      elseif id=="altDown" or id=="altUp" then report(flight.manual(actor,"altitude",id=="altUp" and 1 or -1)) return true
      elseif id=="yawLeft" or id=="yawRight" then report(flight.manual(actor,"heading",id=="yawRight" and 1 or -1)) return true
      elseif id=="test" then
        if self.dirty then self.message="Save changes first" return true end
        local channel=draft.channels[self.index]
        if channel then
          self.testValue=self.testValue or {value=channel.neutral}
          confirm("Test "..channel.id.." at signal "..tostring(self.testValue.value).."?",function() report(flight.testOutput(actor,channel.id,self.testValue.value,true)) end)
        else self.message="Add and save outputs in Outputs first" end return true
      elseif id=="channel" or id=="hover" or id=="manual" or id=="rescue" or id=="rescueConfirm" then
        if self.dirty then self.message="Save changes first" return true end
        local channel=draft.channels[self.index]
        confirm("Physically verify "..id.." before confirming",function()
          local ok,message=flight.calibrate(actor,id,channel and channel.id,true)
          report(ok,message)
          if ok then draft=flight.configuration() end
        end) return true
      elseif self.page=="calibration" and y==4 then
        local channel=draft.channels[self.index]
        self.testValue=self.testValue or {value=channel and channel.neutral or 0}
        self.form.edit=forms.field(self.testValue,"value","Test signal","number") self.form.text=tostring(self.testValue.value) return true
      end
    end
    if self.page=="mapping" or self.page=="manual" or self.page=="gains" or self.page=="sensors" then return self.form:handle(event) end
    return false
  end
  refresh()
  local w,h=term.getSize()
  win=ctx.windowManager:create({title="Navigation",w=math.min(110,w-2),h=math.min(36,h-2),x=2,y=2,app=app})
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
