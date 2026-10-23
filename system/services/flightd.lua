-- Cobalt permits at most 60 captures per function; keep dependencies grouped.
local deps={}
deps.addon=require("system.libraries.addon")
deps.geometry=require("system.navigation.geometry")
deps.pid=require("system.navigation.pid")
local config = require("system.libraries.config")
local safeWrite = require("system.libraries.safe_write")
local permissions = require("system.security.permissions")
local avionics = require("system.services.avionicsd")
deps.sable=require("system.services.sabled")
local log = require("system.libraries.log")
deps.mode=require("system.navigation.control_mode")
local linkOutput = require("system.navigation.link_output")
deps.vehicleBridge=require("system.services.vehiclebridged")
deps.Autopilot=require("system.navigation.autopilot")
local Sweep=require("system.navigation.altitude_sweep")
local sweep,sweepChannel,sweepAppliedAt,sweepSource,sweepReport,sweepOrigin
local sweepOwner,measuredHold
local calibration,calibrationSaved
local activation
local calibrationToken={}
deps.Drive=require("system.navigation.drivetrain")
deps.Trim=require("system.navigation.flight_trim")
deps.MotorHealth=require("system.navigation.motor_health")
deps.Characterization=require("system.navigation.known_flight")
deps.Contracts=require("system.ascendancy.contracts")
local Authority=require("system.navigation.authority")
local Estimator=require("system.navigation.state_estimator")
deps.Catalogue=require("system.navigation.command_catalogue")
deps.Experiments=require("system.navigation.experiments")
local kinematics=Estimator.new()
local commandCatalogue,catalogueAt=nil,nil
local horizontalIssue,horizontalMonitor=nil,Authority.monitor()
local pilotDemand
local drive={}
local Calibration=require("system.navigation.auto_calibration")
local autopilot=deps.Autopilot.new()
local routeForward,routeRight=0,0
local M = {}
local axes = {"pitch","roll","altitude","heading"}
local routeMix={"routeForward","routeReverse","routeRight","routeLeft"}
local sides = {top=true,bottom=true,left=true,right=true,front=true,back=true}
local ctx, runner, cfg, inventory, last, controllers, manual = nil,nil,{}, {},{}, {},{}
local state, reason, owner, targets, timestamp = "disarmed","not calibrated",nil,{},0
local rescuePending, lastTick, inventoryDirty = false, nil, true
local tested, rescueTested, session = {}, false, false
local burnerInitialization,burnerDemand,burnerHeatSince=nil,false,nil
local outputResults, rescueResults = {}, {}
local rankConfig, mixerRank

local function authorize(actor, permission)
  local process = ctx and actor and ctx.scheduler.processes[actor.pid]
  if not process or process.state~="ready" or process.meta.appId~="navigation" then return false,"Navigation owner not running" end
  return permissions.require({pid=process.pid,appId="navigation",permissions=process.permissions},permission)
end

local function migrate()
  cfg = config.load("/system/config/navigation.cfg",{})
  if type(cfg)~="table" then cfg={} end
  cfg.control = cfg.control or {}
  if type(cfg.control)~="table" then cfg.control={} end
  local c = cfg.control
  c.channels, c.gains, c.sensors, c.manualInputs = c.channels or {}, c.gains or {}, c.sensors or {}, c.manualInputs or {}
  for _,key in ipairs({"channels","gains","sensors","manualInputs"}) do if type(c[key])~="table" then c[key]={} end end
  for _, axis in ipairs(axes) do
    c.gains[axis] = c.gains[axis] or {kp=0,ki=0,kd=0,limit=1,slew=1,integralLimit=1,deadband=0}
  end
  c.enabled = false
  if c.mode==nil then c.mode="full" end
  rankConfig,mixerRank=nil,nil
end

local function persist()
  cfg.control.enabled=false
  commandCatalogue,catalogueAt=nil,nil
  return safeWrite.write("/system/config/navigation.cfg",textutils.serialize(cfg))
end

local function selected(rows,name)
  for _, row in ipairs(rows or {}) do if row.name==name and row.ok then return row.data end end
  return {}
end

function M.telemetry()
  local c = cfg.control or {sensors={}}
  if avionics.flightTelemetry then
    local t=avionics.flightTelemetry(c.sensors)
    local sub=deps.sable.flightStatus and deps.sable.flightStatus() or deps.sable.status()
    local observed=sub.timestamp
    if not observed then observed=deps.sable.snapshot().timestamp end
    t.inSublevel=sub.inSublevel==true and deps.addon.finite(observed) and os.clock()-observed<=0.5
    if not deps.addon.finite(t.heading) and not (c.sensors.nav and c.sensors.nav~="") and deps.sable.pose then
      local pose=deps.sable.pose()
      if t.inSublevel and pose and pose.inSublevel and pose.frame=="world" and deps.addon.finite(pose.timestamp) and os.clock()-pose.timestamp<=0.5 then
        local heading=deps.geometry.heading(pose.logicalPose and pose.logicalPose.orientation)
        if heading then
          t.heading=heading t.headingSource="Sable orientation (+Z)"
          t.timestamp=math.min(t.timestamp,pose.timestamp)
          t.measurements=t.measurements or {}
          t.measurements.heading={valid=true,value=heading,source="sable",method="getLogicalPose",frame="world",unit="deg",observedAt=pose.timestamp,validUntil=pose.timestamp+0.5}
        end
      end
    elseif deps.addon.finite(t.heading) then t.headingSource="Avionics navigation table" end
    if c.mode=="altitude" and t.measurements then
      local a,v=t.measurements.altitude,t.measurements.altitudeRate
      if a and v and a.valid and v.valid and deps.addon.finite(a.observedAt) and deps.addon.finite(v.observedAt)
        and a.validUntil and v.validUntil and os.clock()<=math.min(a.validUntil,v.validUntil) then
        t.altitude,t.altitudeRate=a.value,v.value t.timestamp=math.min(a.observedAt,v.observedAt)
      else t.altitude,t.altitudeRate,t.timestamp=nil,nil,0 end
    end
    if drive.characterization and drive.characterization.job.controller then
      local observed=kinematics:status(os.clock())
      if observed.available and observed.position and observed.velocity then
        t.altitude,t.altitudeRate,t.timestamp=observed.position.y,observed.velocity.y,observed.poseAt
      end
    end
    return t
  end
  local snap = avionics.snapshot()
  local g = selected(snap.gimbal,c.sensors.gimbal)
  local a = selected(snap.altitude,c.sensors.altitude)
  local nav = selected(snap.nav,c.sensors.nav)
  local angle, rate = g.angles or {},g.angularRates or {}
  local sub=deps.sable.snapshot()
  return {pitch=angle[1],roll=angle[2],altitude=a.height,heading=nav.heading,
    pitchRate=rate[1],rollRate=rate[3],headingRate=rate[2],altitudeRate=a.verticalSpeed,
    gravity=deps.addon.vec(g.gravity),pressure=a.airPressure,timestamp=snap.timestamp or 0,
    inSublevel=deps.sable.status().inSublevel==true and os.clock()-(sub.timestamp or 0)<=0.5}
end

local function endpoint(channel)
  if channel.backend=="frequency" and type(channel.name)=="string" and channel.name~="" then return linkOutput.key(channel) end
  if channel.backend=="redstone" then return channel.side and sides[channel.side] and ("redstone:"..channel.side) end
  if channel.backend=="avionics" and type(channel.name)=="string" and channel.name~="" then return "avionics:"..channel.name end
  if channel.backend=="relay" and type(channel.name)=="string" and channel.name~="" and sides[channel.side] then
    return "relay:"..channel.name..":"..channel.side
  end
end

local function deviceFor(channel)
  for _, row in ipairs(inventory) do if row.name==channel.name then return row end end
end

local function channelValid(channel)
  if type(channel)~="table" or type(channel.id)~="string" or channel.id=="" then return false,"output ID missing" end
  if not endpoint(channel) then return false,"invalid endpoint" end
  for _, key in ipairs({"min","max","neutral","rescue"}) do
    if not deps.addon.finite(channel[key]) or channel[key]%1~=0 then return false,key.." must be an integer" end
  end
  if channel.min < 0 or channel.max > 15 or channel.min>channel.max then return false,"signal limits must be within 0..15" end
  if channel.neutral<channel.min or channel.neutral>channel.max or channel.rescue<channel.min or channel.rescue>channel.max then return false,"neutral/rescue outside limits" end
  if channel.backend=="avionics" then
    local row=deviceFor(channel)
    if not row or not row.set.setSignal or not (deps.addon.hasType(row,"analog_transmission") or deps.addon.hasType(row,"throttle_lever")) then return false,"supported Avionics signal endpoint missing" end
  end
  if channel.backend=="relay" then
    local row=deviceFor(channel)
    if not row or not deps.addon.hasType(row,"redstone_relay") or not row.set.setAnalogOutput then return false,"redstone relay endpoint missing" end
  end
  if channel.backend=="frequency" and not linkOutput.device(deviceFor(channel)) then return false,"CC Create Redstone Link transmitter missing" end
  return true
end

local function commandIdsValid(control)
  if control.drivetrain~=nil and type(control.drivetrain)~="table" then return false,"Malformed drivetrain mapping" end
  local reserved={}
  for _,c in ipairs(deps.Drive.channels(control.drivetrain)) do reserved[c.id]=true end
  for _,c in ipairs(control.channels or {}) do
    if type(c)=="table" and reserved[c.id] then return false,"Output ID collides with a motor chain: "..c.id end
  end
  return true
end

local function rank(matrix,columns)
  local n, pivot = #matrix,1
  for col=1,columns do
    local selectedRow
    for row=pivot,n do if math.abs(matrix[row][col])>1e-8 then selectedRow=row break end end
    if selectedRow then
      matrix[pivot],matrix[selectedRow]=matrix[selectedRow],matrix[pivot]
      local divisor=matrix[pivot][col]
      for j=col,columns do matrix[pivot][j]=matrix[pivot][j]/divisor end
      for row=pivot+1,n do
        local factor=matrix[row][col]
        for j=col,columns do matrix[row][j]=matrix[row][j]-factor*matrix[pivot][j] end
      end
      pivot=pivot+1
    end
  end
  return pivot-1
end

local function balloonStatus()
  local demand=state=="armed" and {active=burnerDemand,since=burnerHeatSince} or nil
  return deps.vehicleBridge.balloonStatus(cfg.control.balloonSetup,burnerInitialization,demand)
end
function M.validate()
  if state=="armed" and drive.characterization and drive.characterization.job.active then
    local job=drive.characterization local current=deps.vehicleBridge.snapshot() local k=kinematics:status(os.clock())
    local process=ctx and ctx.scheduler.processes[job.owner]
    local valid=process and process.state=="ready" and k.available and k.vehicleId==job.vehicleId and current.ok and current.inventoryComplete and current.vehicleId==job.vehicleId
    return valid==true,valid and {} or {"Measured local hold observations/owner unavailable"}
  end
  local c, errors, used, matrix = cfg.control,{}, {},{}
  if not c then return false,{"configuration missing"} end
  if type(c.channels)~="table" or type(c.gains)~="table" then return false,{"configuration malformed"} end
  local distinct,conflict=commandIdsValid(c) if not distinct then errors[#errors+1]=conflict end
  local active=deps.mode.axes(c)
  if c.balloonSetup then local valid,why=balloonStatus() if not valid then errors[#errors+1]=why end end
  if c.mode~=nil and c.mode~="full" and c.mode~="altitude" then errors[#errors+1]="unknown control mode" end
  if #c.channels<#active then errors[#errors+1]="at least "..#active.." independent mapped outputs required" end
  local ids={}
  for _, channel in ipairs(c.channels) do
    if type(channel)~="table" then return false,{"output malformed"} end
    local ok, err=channelValid(channel)
    if not ok then errors[#errors+1]=(channel.id or "output")..": "..err end
    if ids[channel.id] then errors[#errors+1]="duplicate output ID" end
    if channel.id then ids[channel.id]=true end
    local key=endpoint(channel)
    if key and used[key] then errors[#errors+1]="duplicate output "..key end
    if key then used[key]=true end
    if not channel.validated then errors[#errors+1]=(channel.id or "output")..": calibration unconfirmed" end
    local row={}
    for _,axis in ipairs(axes) do
      local weight=(channel.mix or {})[axis] or 0
      if not deps.addon.finite(weight) or math.abs(weight)>10 then errors[#errors+1]="invalid mixer coefficient" weight=0 end
    end
    for _,key in ipairs(routeMix) do
      local weight=(channel.mix or {})[key]
      if weight~=nil and (not deps.addon.finite(weight) or math.abs(weight)>15) then errors[#errors+1]="invalid directional thrust mix" end
    end
    for index,axis in ipairs(active) do row[index]=deps.addon.finite((channel.mix or {})[axis]) and channel.mix[axis] or 0 end
    matrix[#matrix+1]=row
  end
  if rankConfig~=c then mixerRank,rankConfig=rank(matrix,#active),c end
  if mixerRank<#active then errors[#errors+1]="outputs cannot independently correct enabled axes" end
  for _, axis in ipairs(active) do
    local g=c.gains[axis] or {}
    for _, key in ipairs({"kp","ki","kd","limit","slew","integralLimit","deadband"}) do
      if not deps.addon.finite(g[key]) or g[key]<0 then errors[#errors+1]=axis..": invalid "..key end
    end
    if not (g.kp and g.kp>0 and g.limit and g.limit>0 and g.slew and g.slew>0) then errors[#errors+1]=axis..": gains not configured" end
  end
  if not c.hoverValidated then errors[#errors+1]="hover baseline not validated" end
  if not c.rescueValidated then errors[#errors+1]="rescue profile not tested" end
  if not c.manualValidated then errors[#errors+1]="manual priority bindings not validated" end
  for _,binding in ipairs(c.manualInputs or {}) do
    if type(binding)~="table" or not sides[binding.side] or not c.gains[binding.axis] or not deps.addon.finite(binding.value) or math.abs(binding.value)>1 then errors[#errors+1]="invalid manual input binding"
    elseif not deps.mode.enabled(c,binding.axis) then errors[#errors+1]="manual input axis disabled: "..binding.axis
    elseif used["redstone:"..binding.side] then errors[#errors+1]="manual input shares output side "..binding.side end
  end
  local t=M.telemetry()
  if not t.inSublevel then errors[#errors+1]="not on a Sable sublevel" end
  if os.clock()-t.timestamp>0.5 then errors[#errors+1]="flight telemetry stale" end
  for _, axis in ipairs(active) do
    if not deps.addon.finite(t[axis]) then errors[#errors+1]=axis..": sensor unavailable (check Sensors / Devices)" end
    if not deps.addon.finite(t[axis.."Rate"]) then errors[#errors+1]=axis..": rate unavailable (gimbal / altitude sensor)" end
  end
  return #errors==0,errors
end

function M.configuration() return deps.addon.copy(cfg.control) end
local function same(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~="table" then return a==b end
  for key,value in pairs(a) do if not same(value,b[key]) then return false end end
  for key in pairs(b) do if a[key]==nil then return false end end
  return true
end
local function altitudeBinding(c)
  local rows={}
  for _,channel in ipairs(c.channels or {}) do
    rows[#rows+1]={id=channel.id,backend=channel.backend,name=channel.name,side=channel.side,
      link=deps.addon.copy(channel.link),min=channel.min,max=channel.max,rescue=channel.rescue,mix=deps.addon.copy(channel.mix)}
  end
  return {mode=c.mode,channels=rows,sensors=deps.addon.copy(c.sensors),balloonSetup=deps.addon.copy(c.balloonSetup),drivetrain=deps.addon.copy(c.drivetrain)}
end
local function differentialCurrent(token)
  if state~="armed" or not measuredHold then return false,"Activate measured altitude hold before differential travel" end
  if measuredHold.trim and measuredHold.trim.active then return false,"Mass changed: airborne altitude adaptation; horizontal response needs revalidation" end
  if horizontalIssue then return false,horizontalIssue end
  if not calibration or (calibration.state~="complete" and not (token==calibrationToken and calibration.phase=="routeCheck")) or not calibration.driveModel then return false,"Measured differential calibration required" end
  if not same(calibration.binding,altitudeBinding(cfg.control)) then return false,"Motor mapping/configuration changed; repeat calibration" end
  local current=deps.vehicleBridge.snapshot()
  if not current.ok or not current.inventoryComplete or current.vehicleId~=(calibration.binding.balloonSetup or {}).vehicleId then return false,"Containing vehicle inventory unavailable/changed" end
  if deps.addon.finite(calibration.mass) and calibration.mass>0 and (not deps.addon.finite(current.mass) or (current.units or {}).mass~=calibration.massUnit or math.abs(current.mass-calibration.mass)>calibration.mass*0.02) then return false,"Vehicle mass changed; repeat measured calibration" end
  return true
end
function M.configure(actor, value)
  local ok, err=authorize(actor,"navigation.calibrate")
  if not ok then return false,err end
  if state=="armed" or state=="calibration" or rescuePending then return false,"disarm and finish pending outputs before editing" end
  if calibration and calibration:running() then return false,"Stop automatic calibration before editing" end
  if type(value)~="table" then return false,"invalid control config" end
  if type(value.channels)~="table" or type(value.gains)~="table" or type(value.sensors)~="table" or #value.channels>32 then return false,"invalid mapping" end
  if value.mode~=nil and value.mode~="full" and value.mode~="altitude" then return false,"invalid control mode" end
  for _,channel in ipairs(value.channels) do
    local valid,why=channelValid(channel)
    if not valid then return false,why end
    if type(channel.mix)~="table" then return false,"mixer required" end
  end
  local driveValid,driveError=deps.Drive.validate(value.drivetrain,value.channels) if not driveValid then return false,driveError end
  local distinct,conflict=commandIdsValid(value) if not distinct then return false,conflict end
  if value.altitudeModel and (type(value.altitudeModel)~="table" or not same(value.altitudeModel.binding,altitudeBinding(value))) then
    value=deps.addon.copy(value) value.altitudeModel=nil
  end
  if same(value,cfg.control) then return true end
  local previous=cfg.control
  cfg.control=deps.addon.copy(value)
  cfg.control.enabled=false
  cfg.control.channels,cfg.control.gains,cfg.control.sensors,cfg.control.manualInputs=cfg.control.channels or {},cfg.control.gains or {},cfg.control.sensors or {},cfg.control.manualInputs or {}
  cfg.control.hoverValidated,cfg.control.rescueValidated,cfg.control.manualValidated=false,false,false
  for _, channel in ipairs(cfg.control.channels) do channel.validated=false end
  for _,axis in ipairs(axes) do cfg.control.gains[axis]=cfg.control.gains[axis] or {kp=0,ki=0,kd=0,limit=1,slew=1,integralLimit=1,deadband=0} end
  controllers,manual,last={},{},{}
  state,reason="disarmed","configuration changed; recalibration required"
  inventoryDirty=true
  local saved,why=persist()
  if not saved then cfg.control=previous return false,why end
  tested,rescueTested={},false
  drive.demand,drive.values,drive.appliedAt=nil,nil,nil
  burnerInitialization,burnerDemand,burnerHeatSince=nil,false,nil
  return true
end

function M.fail(message,token)
  if drive.characterization and drive.characterization.job.state=="running" then
    drive.characterization.job:abort(message)
    if drive.characterization.fast then deps.vehicleBridge.releaseFeedback(drive.characterization) end
  end
  if activation and (activation.state=="running" or activation.state=="active") and token~=calibrationToken then activation.state,activation.reason="blocked",message end
  if calibration and calibration:running() and token~=calibrationToken then calibration:abort(message) end
  measuredHold=nil drive.demand=nil pilotDemand=nil
  if sweep and sweep.state=="running" then sweep:abort(message) end
  burnerInitialization,burnerDemand,burnerHeatSince=nil,false,nil
  autopilot:cancel(message,true)
  if state=="armed" or state=="calibration" then
    state,reason,rescuePending="failsafe",message,true
    controllers,manual={},{}
    pcall(log.error,"navigation",message)
    if ctx and ctx.notifications then pcall(ctx.notifications.push,ctx.notifications,"error","Flight failsafe",message,5) end
  end
end

function M.arm(actor)
  local ok, err=authorize(actor,"navigation.control")
  if not ok then return false,err end
  if state~="disarmed" or rescuePending then return false,"disarm/acknowledge pending state first" end
  local valid,errors=M.validate()
  if not valid then return false,table.concat(errors,"; ") end
  local t=M.telemetry()
  local storedModel=cfg.control.altitudeModel
  if storedModel then
    if cfg.control.mode~="altitude" or #cfg.control.channels~=1 or type(storedModel)~="table" or storedModel.kind~="altitude-table" or not same(storedModel.binding,altitudeBinding(cfg.control)) then return false,"Measured altitude model does not match collective vertical configuration" end
    local heat,problem=require("system.navigation.altitude_model").heatAt(storedModel,t.altitude)
    if not heat then return false,problem end
  end
  cfg.control.sessionActive=true
  local saved,why=persist()
  if not saved then cfg.control.sessionActive=false return false,why end
  session=true
  measuredHold=storedModel and {model=deps.addon.copy(storedModel),vehicleId=cfg.control.balloonSetup and cfg.control.balloonSetup.vehicleId} or nil
  if measuredHold then
    measuredHold.trim=deps.Trim.new(deps.vehicleBridge.snapshot())
    measuredHold.model.gains=deps.addon.copy(cfg.control.gains.altitude)
    local points=measuredHold.model.points
    measuredHold.model.measuredRange={first=points[1].heat,last=points[#points].heat,minAltitude=points[1].altitude,maxAltitude=points[#points].altitude}
  end
  burnerDemand,burnerHeatSince=false,nil
  targets={pitch=0,roll=0,altitude=t.altitude,heading=t.heading}
  controllers,manual={},{}
  owner,state,reason,lastTick=actor.pid,"armed","stabilisation armed",os.clock()
  pcall(log.warn,"navigation","armed owner="..owner)
  return true
end

function M.disarm(actor,token)
  local ok,err=authorize(actor,"navigation.control")
  if not ok then return false,err end
  if activation and (activation.state=="running" or activation.state=="active") and token~=calibrationToken then activation.state,activation.reason="blocked","Stopped by operator" end
  if calibration and calibration:running() and token~=calibrationToken then calibration:abort("Stopped by operator") end
  if state=="armed" or state=="calibration" then M.fail("manual disarm: calibrated rescue",token) end
  if not rescuePending then
    cfg.control.sessionActive=false
    local saved,why=persist()
    if not saved then return false,why end
    state,reason,owner,session="disarmed","disarmed",nil,false
  end
  return true
end

function M.release(pid, message) if owner==pid or calibration and calibration:running() and calibration.owner==pid or activation and activation.state=="running" and activation.owner==pid then M.fail(message or "Navigation closed") end end

local function takeover(message,t)
  if not autopilot:running() and not pilotDemand then return end
  pilotDemand=nil
  autopilot:cancel(message)
  routeForward,routeRight=0,0 drive.demand=nil
  t=t or M.telemetry()
  targets={pitch=0,roll=0,altitude=t.altitude,heading=t.heading}
  controllers={}
end

function M.startMission(actor,plan,confirmed,token)
  local ok,err=authorize(actor,"navigation.autopilot")
  if not ok then return false,err end
  ok,err=authorize(actor,"navigation.control") if not ok then return false,err end
  if confirmed~=true then return false,"Confirm autonomous flight explicitly" end
  if measuredHold and owner==actor.pid and state=="armed" and calibration and (calibration.state=="complete" or token==calibrationToken and calibration.phase=="routeCheck") and calibration.driveModel then
    local ready,issue=differentialCurrent(token) if not ready then return false,issue end
    for _,value in pairs(manual) do if value.expires>os.clock() then return false,"Release manual controls first" end end
    for _,binding in ipairs(cfg.control.manualInputs or {}) do if redstone.getInput(binding.side) then return false,"Release physical pilot controls first" end end
    local route=deps.addon.copy(plan)
    if type(route)~="table" then return false,"Route required" end
    route.driveMode="differential" route.translationVerified=true route.verifiedVehicleId=cfg.control.balloonSetup.vehicleId
    route.braking=deps.addon.copy(calibration.driveModel.braking)
    route.maxSpeed=math.min(route.maxSpeed or 0,calibration.driveModel.maxSpeed)
    local sample=autopilot.sample local t=M.telemetry()
    if not sample or not sample.velocity or not drive.pose or not deps.addon.finite(drive.pose.yawRate) then return false,"Fresh differential velocity/yaw required" end
    for _,point in ipairs(route.points or {}) do
      local heat,issue=require("system.navigation.altitude_model").heatAt(measuredHold.model,t.altitude+point.y-sample.position.y)
      if not heat then return false,issue end
    end
    local started,problem=autopilot:start(route,t,os.clock())
    if started then pilotDemand=nil end return started,problem
  end
  if owner~=actor.pid or state~="armed" or cfg.control.mode=="altitude" then return false,"Arm calibrated full flight control with this Navigation window first" end
  for _,value in pairs(manual) do if value.expires>os.clock() then return false,"Release manual controls first" end end
  for _,binding in ipairs(cfg.control.manualInputs or {}) do if redstone.getInput(binding.side) then return false,"Release physical pilot controls first" end end
  local valid,errors=M.validate() if not valid then return false,table.concat(errors,"; ") end
  if type(plan)=="table" and plan.driveMode=="thrusters" then
    local found,matrix={},{}
    for _,channel in ipairs(cfg.control.channels) do
      local translated=false
      for _,key in ipairs(routeMix) do if (channel.mix[key] or 0)~=0 then found[key]=true translated=true end end
      if translated then
        for _,axis in ipairs(axes) do if (channel.mix[axis] or 0)~=0 then return false,"Use dedicated translation channels, separate from attitude/altitude mixing" end end
        if ((channel.mix.routeForward or 0)~=0 or (channel.mix.routeReverse or 0)~=0) and ((channel.mix.routeRight or 0)~=0 or (channel.mix.routeLeft or 0)~=0) then return false,"Separate longitudinal and lateral translation endpoints" end
        matrix[#matrix+1]={(channel.mix.routeForward or 0)-(channel.mix.routeReverse or 0),(channel.mix.routeRight or 0)-(channel.mix.routeLeft or 0)}
      end
    end
    for _,key in ipairs(routeMix) do if not found[key] then return false,"Map and physically calibrate directional output: "..key end end
    if rank(matrix,2)<2 then return false,"Directional thrusters need independent forward/reverse and lateral control" end
  end
  if deps.sable.pose then autopilot:observe(deps.sable.pose(),os.clock()) end
  local vehicle=cfg.control.vehicle
  if vehicle and vehicle.bridgeVehicleId and autopilot.sample and vehicle.bridgeVehicleId~=autopilot.sample.vehicleId then return false,"Imported vehicle geometry belongs to another sublevel; Discover and calibrate this vehicle" end
  local generic=deps.addon.copy(plan) if type(generic)=="table" then generic.braking=nil end
  local started,problem=autopilot:start(generic,M.telemetry(),os.clock())
  if started then pilotDemand=nil end return started,problem
end

function M.stopMission(actor,token)
  local ok,err=authorize(actor,"navigation.control") if not ok then return false,err end
  if owner~=actor.pid or state~="armed" then return false,"Flight owner mismatch" end
  if measuredHold or drive.characterization and drive.characterization.job.active then M.fail("Pilot STOP: measured hold rescue",token) return true end
  takeover("Pilot stopped mission; manual stabilization")
  return true
end

-- Direct cockpit guidance uses the same measured authority and output interlocks as routes.
function M.setFlightTargets(actor,request)
  for _,permission in ipairs({"navigation.control","navigation.autopilot"}) do
    local ok,why=authorize(actor,permission) if not ok then return false,why end
  end
  if state=="armed" and owner==actor.pid and drive.characterization and drive.characterization.job.active then
    local ok,why=drive.characterization.job:setTargets(request)
    if ok then targets.altitude=request.altitude reason="Measured known-output altitude target applied" end
    return ok,why
  end
  if state~="armed" or owner~=actor.pid or not measuredHold or not calibration or (calibration.state~="complete" and not (measuredHold.trim and measuredHold.trim.active)) then return false,"Finish automatic preparation with this Navigation window first" end
  if type(request)~="table" or not deps.addon.finite(request.altitude) then return false,"World altitude required" end
  local heat,why=require("system.navigation.altitude_model").heatAt(measuredHold.model,request.altitude)
  if not heat then return false,why end
  local demand
  if request.speed~=nil or request.heading~=nil then
    local ready,issue=differentialCurrent() if not ready then return false,issue end
    if not deps.addon.finite(request.heading) or not deps.addon.finite(request.speed) or request.speed<0 or request.speed>calibration.driveModel.maxSpeed then return false,"Speed must be within the measured motor range; heading must be finite" end
    if not drive.pose or os.clock()-drive.pose.at>0.5 then return false,"Fresh motor pose required" end
    demand={speed=request.speed,heading=request.heading%360}
  end
  -- Validate the whole request before replacing an existing route or target.
  takeover("Cockpit targets applied")
  pilotDemand=demand targets={altitude=request.altitude}
  controllers={} reason=demand and "Cockpit altitude / speed / heading hold" or "Cockpit altitude hold"
  return true
end

function M.setSetpoint(actor,axis,value,token)
  local ok,err=authorize(actor,"navigation.control")
  if not ok then return false,err end
  if owner~=actor.pid or state~="armed" then return false,"not armed by this owner" end
  if drive.characterization and drive.characterization.job.active then
    if axis~="altitude" then return false,"Use the qualified known-output hold targets" end
    return M.setFlightTargets(actor,{altitude=value})
  end
  if calibration and calibration:running() and token~=calibrationToken then return false,"Automatic calibration running; STOP before changing targets" end
  if not deps.addon.finite(value) or not deps.mode.enabled(cfg.control,axis) then return false,"invalid or disabled setpoint" end
  if (axis=="pitch" or axis=="roll") and math.abs(value)>30 then return false,"attitude setpoint limited to 30 degrees" end
  if measuredHold and axis=="altitude" then
    local heat,problem=require("system.navigation.altitude_model").heatAt(measuredHold.model,value)
    if not heat then return false,problem end
  end
  takeover("Pilot changed setpoint")
  targets[axis]=axis=="heading" and value%360 or value
  controllers[axis]={}
  return true
end

function M.manual(actor,axis,value)
  local ok,err=authorize(actor,"navigation.control")
  if not ok then return false,err end
  if state~="armed" or owner~=actor.pid or not deps.mode.enabled(cfg.control,axis) or not deps.addon.finite(value) then return false,"manual override unavailable" end
  if measuredHold or drive.characterization and drive.characterization.job.active then M.fail("Manual takeover stopped measured hold") return true end
  takeover("Manual pilot override")
  manual[axis]={value=math.max(-1,math.min(1,value)),expires=os.clock()+0.3}
  return true
end

local function writeOutputs(values, force, results)
  local branches, failures={}, {}
  results=results or {}
  local channels={} for _,c in ipairs(cfg.control.channels) do channels[#channels+1]=c end
  local motors=deps.Drive.channels(cfg.control.drivetrain) local expected={} local motorObjects={}
  if #motors>0 then
    local d=cfg.control.drivetrain local previous=drive.values or deps.Drive.observed(d,deps.vehicleBridge.snapshot())
    if force then expected=deps.Drive.stop(d,previous)
    elseif not previous then return false,"Motor receiver states unavailable before output"
    else
      local wanted=drive.demand or deps.Drive.commands(d)
      local ack=not drive.appliedAt or deps.Drive.feedback(d,deps.vehicleBridge.snapshot(),previous,drive.appliedAt)
      expected=ack and deps.Drive.transition(d,previous,wanted) or previous
    end
    for _,c in ipairs(motors) do if expected[c.id]~=nil then channels[#channels+1]=c motorObjects[c]=true end end
  end
  for _,channel in ipairs(channels) do
    local key,value=endpoint(channel),expected[channel.id] or values[channel.id]
    if force then value=motorObjects[channel] and expected[channel.id] or channel.rescue end
    if (force and (not motorObjects[channel] or channel.id:match("clutch$"))) or (not force and value~=nil and last[key]~=value) then
      local valid,why=channelValid(channel)
      local result={endpoint=key,value=value,state="unavailable",error=why}
      results[channel.id]=result outputResults[channel.id]=result
      if not valid or not deps.addon.finite(value) or value<channel.min or value>channel.max then
        result.error=why or "unsafe output value"
      else
        -- A suspended write may already have reached hardware. Never infer failure
        -- from a timeout, or retry it implicitly in a later rescue tick.
        result.state,result.error="uncertain","output not confirmed"
        branches[#branches+1]=function()
          local ok,accepted,err=deps.addon.bounded(function()
            if channel.backend=="redstone" then redstone.setAnalogOutput(channel.side,value) return true end
            local row=deviceFor(channel)
            if not row then return false,"actuator detached: "..tostring(channel.name) end
            if channel.backend=="frequency" then return linkOutput.write(row,channel,value) end
            if channel.backend=="relay" then
              local accepted,problem=deps.addon.call(row.device,"setAnalogOutput",channel.side,value)
              if problem then error(problem) end
              return accepted~=false,accepted==false and "relay refused" or nil
            end
            local returned,problem=deps.addon.call(row.device,"setSignal",value)
            if problem then error(problem) end
            return returned~=false,returned==false and "actuator refused" or nil
          end,0.15)
          if ok and accepted then
            result.state,result.error="confirmed",nil last[key]=value
          else
            result.state=ok and "refused" or "uncertain"
            result.error=tostring(ok and err or accepted)
          end
        end
      end
    end
  end
  if #branches>0 then parallel.waitForAll(table.unpack(branches)) end
  for id,result in pairs(results) do
    if result.state~="confirmed" then failures[#failures+1]=id..": "..result.state..": "..tostring(result.error) end
  end
  if #motors>0 and #failures==0 then
    if force or not drive.values or not same(drive.values,expected) then drive.appliedAt=os.clock() end
    drive.values=deps.addon.copy(expected)
  end
  return #failures==0,table.concat(failures,"; "),results
end

-- Generic measurements use assigned outputs only. No additional writer exists.
function M.startKnownOutputCalibration(actor,confirmed,duration,automatic)
  for _,permission in ipairs({"navigation.calibrate","navigation.control"}) do local ok,err=authorize(actor,permission) if not ok then return false,err end end
  if automatic==true then local ok,why=authorize(actor,"navigation.autopilot") if not ok then return false,why end end
  if confirmed~=true then return false,"Confirm known-output tests, neutral hover and a clear test area" end
  if state~="disarmed" or rescuePending then return false,"Disarm and finish pending rescue before known-output calibration" end
  if cfg.control.balloonSetup or cfg.control.drivetrain and cfg.control.drivetrain.enabled then return false,"Use the existing collective burner/differential sequence for this configuration" end
  if cfg.control.hoverValidated~=true then return false,"Confirm the assigned neutral outputs physically support hover first; no neutral thrust is invented" end
  if automatic==true and (cfg.control.rescueValidated~=true or cfg.control.manualValidated~=true) then return false,"Verify configured rescue behaviour and physical manual takeover once before automatic flight; software readback cannot prove them" end
  local pose=deps.sable.pose and deps.sable.pose() local k=kinematics:status(os.clock())
  local current=deps.vehicleBridge.snapshot()
  if not k.available or not pose or pose.vehicleId~=k.vehicleId or not current.ok or not current.inventoryComplete or current.vehicleId~=k.vehicleId then return false,"Fresh world derivatives and matching containing vehicle inventory required" end
  local used={} local selectedIds,selectedSeen={},{} local hasFrequency=false
  for _,c in ipairs(cfg.control.channels) do
    local ok,err=channelValid(c) if not ok then return false,err end
    local keys=c.backend=="frequency" and linkOutput.keys(c) or {endpoint(c)}
    if #keys==0 then return false,"No assigned output frequency" end
    for _,key in ipairs(keys) do
      local physical=c.backend=="frequency" and "frequency:"..key or key
      if used[physical] then return false,"Shared physical output cannot be characterized independently: "..c.id end used[physical]=true
    end
    if c.backend=="frequency" then
      hasFrequency=true
      local signal,why=linkOutput.received(c,current,c.neutral) if signal==nil then return false,"Establish the saved neutral hover signal before characterization: "..tostring(why) end
      local frequencies={} for _,key in ipairs(keys) do frequencies[key]=true end
      for _,receiver in ipairs(current.links or {}) do
        if receiver.receiver and frequencies[linkOutput.receiverKey(receiver)] and not selectedSeen[receiver.id] then
          selectedSeen[receiver.id]=true selectedIds[#selectedIds+1]=receiver.id
        end
      end
    end
    if c.backend=="avionics" and not deviceFor(c).set.getSignal then return false,"Readback unavailable for assigned Avionics output "..c.id end
    if c.backend=="relay" and not deviceFor(c).set.getAnalogOutput then return false,"Readback unavailable for assigned relay output "..c.id end
  end
  for _,binding in ipairs(cfg.control.manualInputs or {}) do if sides[binding.side] and redstone.getInput(binding.side) then return false,"Release physical manual input before calibration" end end
  local channels=deps.addon.copy(cfg.control.channels)
  for _,c in ipairs(channels) do c.validated=false end
  local job,err=deps.Characterization.new(channels,k.vehicleId,duration or 2,automatic) if not job then return false,err end
  local previous,previousSession=cfg.control.channels,cfg.control.sessionActive
  cfg.control.channels=channels cfg.control.sessionActive=true
  local saved,why=persist() if not saved then cfg.control.channels=previous cfg.control.sessionActive=previousSession return false,why end
  drive.characterization={job=job,owner=actor.pid,binding=deps.addon.copy(cfg.control.channels),vehicleId=k.vehicleId,mass=current.mass,massUnit=(current.units or {}).mass,structureFingerprint=deps.vehicleBridge.structureFingerprint(),hasFrequency=hasFrequency,selectedIds=selectedIds}
  if hasFrequency then drive.characterization.fast=deps.vehicleBridge.requestFeedback(k.vehicleId,selectedIds,drive.characterization)==true end
  calibration,calibrationSaved,activation=nil,false,nil
  drive.health,drive.healthJob=nil,nil
  M.test=nil owner,state,reason=actor.pid,"calibration",job.reason
  return true
end
function M.characterizationReport(actor)
  for _,permission in ipairs({"navigation.calibrate","navigation.assist"}) do local ok,why=authorize(actor,permission) if not ok then return nil,why end end
  local job=drive.characterization
  if job and (job.job.massAdaptation or job.job.degraded) then return nil,"Passive adaptation/degraded authority is not a full response-model recalibration" end
  if not job or (job.job.state~="complete" and not (job.job.qualification and job.job.qualification.state=="complete")) then return nil,"No complete known-output characterization in this session" end
  return {schema=1,kind="known-output-characterization-not-flight-certificate",vehicleId=job.vehicleId,binding=deps.addon.copy(job.binding),
    clock="local_uptime",clockId=deps.Contracts.clockId(),archivedAt=os.clock(),source="Sable logicalPose derivatives and confirmed assigned-output readback",
    structureFingerprint=job.structureFingerprint,mass=job.mass,massUnit=job.massUnit,model=deps.addon.copy(job.job.model),
    worldBounds=deps.addon.copy(job.job.worldBounds),observations=deps.addon.copy(job.job.rows),rejected=deps.addon.copy(job.job.rejected),
    qualification=job.job.qualification and job.job.qualification:status() or nil,
    attitudeQualification=job.job.attitudeQualification and job.job.attitudeQualification:status() or nil,tilt=deps.addon.copy(job.job.tiltModel),
    validity="Historical measured domain only; fresh identity, structure, bindings, mass and closed-loop checks required; never restores outputs"}
end
function M.saveCharacterizationReport(actor)
  local report,why=M.characterizationReport(actor) if not report then return false,why end
  local content=textutils.serialize(report,{compact=true})
  if #content>32768 or fs.getFreeSpace("/")<2*#content+2048 then return false,"No space for bounded response report; measurements remain in RAM" end
  return safeWrite.write("/system/config/navigation-response.cfg",content)
end
-- Call only on the service worker. Accepted writes alone are not physical RX.
deps.characterizationFeedback=function(job,now)
  local run=job.job
  if not run.appliedAt then return false,"Waiting for assigned output application" end
  local current=deps.vehicleBridge.snapshot()
  if not current.ok or not current.inventoryComplete or current.vehicleId~=job.vehicleId then return false,"Fresh containing-vehicle inventory required" end
  local receivers=current
  if job.fast then
    local ok,why=deps.vehicleBridge.requestFeedback(job.vehicleId,job.selectedIds,job) if not ok then return false,why end
    receivers=deps.vehicleBridge.selectedSnapshot()
  end
  if job.hasFrequency and (not receivers.ok or receivers.vehicleId~=job.vehicleId or not receivers.observedAt or receivers.observedAt<=run.appliedAt) then return false,"Fresh containing-vehicle receiver observations required" end
  local confirmed=job.hasFrequency and receivers.observedAt or run.appliedAt
  for _,c in ipairs(job.binding) do
    local wanted=run.values[c.id]
    if last[endpoint(c)]~=wanted then return false,"Assigned output not yet written" end
    if c.backend=="frequency" then
      local signal,why=linkOutput.received(c,receivers,wanted) if signal==nil then return false,why end
    else
      local ok,signal=deps.addon.bounded(function()
        if c.backend=="redstone" then return redstone.getAnalogOutput(c.side) end
        local row=deviceFor(c) if not row then return nil end
        local value,problem
        if c.backend=="relay" then value,problem=deps.addon.call(row.device,"getAnalogOutput",c.side)
        else value,problem=deps.addon.call(row.device,"getSignal") end
        if problem then return nil end return value
      end,.15)
      if not ok or signal~=wanted then return false,"Assigned output readback mismatch: "..c.id end
      confirmed=math.max(confirmed,os.clock())
    end
  end
  if os.clock()-now>.5 then return false,"Assigned output readback interval stale" end
  return true,nil,confirmed
end

deps.characterizationStep=function(now)
  local job=drive.characterization
  if not job or (state~="calibration" and not (state=="armed" and job.job.active)) or job.job.state~="running" then return false end
  local function fail(why) M.fail(why) return true end
  for _,permission in ipairs(job.job.automatic and {"navigation.calibrate","navigation.control","navigation.autopilot"} or {"navigation.calibrate","navigation.control"}) do local ok,why=authorize({pid=job.owner},permission) if not ok then return fail(why) end end
  if not same(job.binding,cfg.control.channels) then return fail("Assigned outputs changed during characterization") end
  local current=deps.vehicleBridge.snapshot()
  if not current.ok or not current.inventoryComplete or current.vehicleId~=job.vehicleId then return fail("Characterization vehicle inventory lost/changed") end
  if job.mass and (not deps.addon.finite(current.mass) or (current.units or {}).mass~=job.massUnit or math.abs(current.mass-job.mass)>math.abs(job.mass)*.02) then
    if job.job.active and deps.addon.finite(current.mass) and current.mass>0 and (current.units or {}).mass==job.massUnit then
      local ok,why=job.job:massChanged(current.mass,job.mass,kinematics:status(now)) if not ok then return fail(why) end
      job.mass=current.mass
    else return fail("Mass observation changed/lost during output characterization") end
  end
  for _,binding in ipairs(cfg.control.manualInputs or {}) do if sides[binding.side] and redstone.getInput(binding.side) then return fail("Physical manual input stopped output characterization") end end
  local ack,why,ackAt=deps.characterizationFeedback(job,now)
  if job.job.appliedAt and now-job.job.appliedAt>=2 and not ack then return fail(why) end
  job.job:step(kinematics:status(now),deps.sable.pose(),ack,now,ackAt)
  if (state~="calibration" and state~="armed") or drive.characterization~=job then return true end
  if job.job.state=="aborted" then return fail(job.job.reason) end
  reason=job.job.reason
  if job.job.active then state="armed" targets.altitude=job.job.controller.position.y end
  if job.job.state=="complete" then
    job.finished=true reason="Known-output characterization complete; returning to configured rescue" rescuePending=true return true
  end
  local requestedGeneration=job.job.generation
  local ok,problem=writeOutputs(job.job.values)
  if (state~="calibration" and state~="armed") or drive.characterization~=job or job.job.state~="running" then return true end
  if not ok then return fail("Known-output actuator error: "..problem) end
  job.job:applied(requestedGeneration,os.clock())
  return true
end

function M.endpoints()
  local rows={}
  for _,row in ipairs(inventory) do
    if linkOutput.device(row) then rows[#rows+1]={name=row.name,backend="frequency"}
    elseif deps.addon.hasType(row,"redstone_relay") and row.set.setAnalogOutput then
      rows[#rows+1]={name=row.name,backend="relay",sides={"top","bottom","left","right","front","back"}}
    elseif row.set.setSignal and (deps.addon.hasType(row,"analog_transmission") or deps.addon.hasType(row,"throttle_lever")) then
      rows[#rows+1]={name=row.name,backend="avionics"}
    end
  end
  return rows
end

function M.calibrate(actor,kind,id, confirmed)
  local ok,err=authorize(actor,"navigation.calibrate")
  if not ok then return false,err end
  if state=="armed" or state=="calibration" or rescuePending then return false,"outputs busy" end
  if confirmed~=true then return false,"explicit confirmation required" end
  if kind=="channel" then
    for _,channel in ipairs(cfg.control.channels) do
      if channel.id==id then
        local valid,why=channelValid(channel)
        if not valid then return false,why end
        if not tested[id] then return false,"test this output and verify correction direction first" end
        channel.validated=true
        return persist()
      end
    end
    return false,"unknown output"
  elseif kind=="hover" then cfg.control.hoverValidated=true
  elseif kind=="manual" then cfg.control.manualValidated=true
  elseif kind=="rescue" then
    for _,channel in ipairs(cfg.control.channels) do local valid,why=channelValid(channel) if not valid then return false,why end end
    owner,state,reason,rescuePending=actor.pid,"calibration","rescue test queued",true
    return true
  elseif kind=="rescueConfirm" then
    if not rescueTested then return false,"apply rescue test and verify physical behaviour first" end
    cfg.control.rescueValidated=true
  else return false,"invalid calibration step" end
  return persist()
end

function M.testOutput(actor,id,value,confirmed,duration)
  local ok,err=authorize(actor,"navigation.calibrate")
  if not ok then return false,err end
  duration=duration==nil and 0.3 or duration
  if not deps.addon.finite(duration) or duration<0.1 or duration>2 then return false,"test duration must be 0.1..2 seconds" end
  if state=="armed" or state=="calibration" or rescuePending or confirmed~=true then return false,"test requires idle state and confirmation" end
  for _,channel in ipairs(cfg.control.channels) do
    if channel.id==id then
      local valid,why=channelValid(channel)
      if not valid or not deps.addon.finite(value) or value<channel.min or value>channel.max then return false,why or "test outside calibrated limits" end
      if cfg.control.balloonSetup and channel.actuator and channel.actuator.role=="buoyancy" and duration<2 then return false,"Burner feedback requires Initialize (2s)" end
      if channel.validated then
        channel.validated=false
        local saved,problem=persist()
        if not saved then channel.validated=true return false,problem end
      end
      tested[id]=nil
      if cfg.control.balloonSetup then burnerInitialization,burnerDemand,burnerHeatSince=nil,false,nil end
      owner,state,reason=actor.pid,"calibration","output test"
      local burnerTest=cfg.control.balloonSetup and channel.actuator and channel.actuator.role=="buoyancy"
      local inverted=burnerTest and type(channel.mix)=="table" and deps.addon.finite(channel.mix.altitude) and channel.mix.altitude<0
      M.test={id=id,value=math.floor(value+0.5),expires=os.clock()+duration,burnerTest=burnerTest==true,
        expectedBurnerSignal=inverted and 15-math.floor(value+0.5) or math.floor(value+0.5)}
      return true
    end
  end
  return false,"unknown output"
end

local function sweepPose(now,vehicleId)
  local pose=deps.sable.pose and deps.sable.pose()
  if not pose or pose.vehicleId~=vehicleId or not pose.inSublevel or pose.frame~="world" or not deps.addon.finite(pose.timestamp)
    or not deps.addon.finite(pose.identityAt) or now<pose.timestamp or now<pose.identityAt or now-pose.timestamp>0.5 or now-pose.identityAt>0.5 then return nil,"Fresh containing-vehicle world pose/identity required" end
  local logical=pose.logicalPose or {}
  local position=deps.addon.vec(logical.position or logical.pos)
  local q=logical.orientation
  if not position or type(q)~="table" then return nil,"World position/orientation unavailable" end
  local x,y,z,w
  if q.a~=nil or q.v~=nil then
    -- Sable uses scalar a + vector v; retain support for flat CC-Sable poses.
    if type(q.v)~="table" then return nil,"Invalid sweep orientation vector" end
    x,y,z,w=q.v.x,q.v.y,q.v.z,q.a
  else x,y,z,w=q.x or q[1],q.y or q[2],q.z or q[3],q.w or q[4] end
  if not (deps.addon.finite(x) and deps.addon.finite(y) and deps.addon.finite(z) and deps.addon.finite(w)) then return nil,"Invalid sweep orientation" end
  local norm=x*x+y*y+z*z+w*w
  if not deps.addon.finite(norm) or norm<1e-8 then return nil,"Invalid sweep orientation" end
  local tilt=math.deg(math.acos(math.max(-1,math.min(1,1-2*(x*x+z*z)/norm))))
  if tilt>10 then return nil,"Sweep tilt limit (10 degrees) reached" end
  return position
end
function M.startSweep(actor,options,confirmed,expectedControl)
  if calibration and calibration:running() then return false,"Automatic calibration already running" end
  local ok,err=authorize(actor,"navigation.calibrate") if not ok then return false,err end
  ok,err=authorize(actor,"navigation.control") if not ok then return false,err end
  if confirmed~=true or state~="disarmed" or rescuePending then return false,"Sweep needs idle state and explicit confirmation" end
  local c=cfg.control
  local distinct,conflict=commandIdsValid(c) if not distinct then return false,conflict end
  if expectedControl and not same(c,expectedControl) then return false,"Control changed while reviewing sweep; review again" end
  if c.mode~="altitude" or not c.balloonSetup or #c.channels~=1 then return false,"One collective command channel required (it may control one burner)" end
  local channel=c.channels[1]
  local valid,why=channelValid(channel) if not valid then return false,why end
  if not channel.actuator or channel.actuator.role~="buoyancy" or math.abs(channel.mix.altitude or 0)~=1 then return false,"Verified burner channel with unit altitude mix required" end
  local missing={}
  if not burnerInitialization then missing[#missing+1]="Initialize (2s): fresh feedback from both/all selected burners" end
  if not channel.validated then missing[#missing+1]="Verify direction (after Initialize completes)" end
  if not c.manualValidated then missing[#missing+1]="Manual OK" end
  if not c.rescueValidated then missing[#missing+1]=rescueTested and "Rescue OK (Test rescue completed; confirmation still missing)" or "Test rescue, then Rescue OK" end
  local plan,planErr=Sweep.validate(options) if not plan then return false,planErr end
  if not plan.autoPrepare then
    if #missing>0 then return false,"Sweep blocked: "..table.concat(missing,"; ") end
    local ready,problem=balloonStatus() if not ready then return false,problem end
  else
    local current=deps.vehicleBridge.snapshot()
    if not current.ok or not current.inventoryComplete or current.vehicleId~=c.balloonSetup.vehicleId then return false,"Fresh complete containing-vehicle burner inventory required" end
    local found,seen={},{} for _,b in ipairs(current.burners or {}) do found[b.id]=true end
    if type(c.balloonSetup.burnerIds)~="table" or #c.balloonSetup.burnerIds==0 then return false,"Burner group missing" end
    for _,id in ipairs(c.balloonSetup.burnerIds) do if not found[id] or seen[id] then return false,"Burner group missing/duplicated" end seen[id]=true end
  end
  local inverted=channel.mix.altitude<0
  for _,heat in ipairs({plan.first,plan.last}) do
    local value=inverted and 15-heat or heat
    if value<channel.min or value>channel.max then return false,"Sweep outside calibrated channel limits" end
  end
  local origin,poseErr=sweepPose(os.clock(),c.balloonSetup.vehicleId)
  if not origin then return false,poseErr end
  local telemetry=M.telemetry()
  local probe,probeErr=Sweep.new(plan,telemetry.altitude,os.clock()) if not probe then return false,probeErr end
  probe.rescueHeat=inverted and 15-channel.rescue or channel.rescue
  local signal,guardErr=probe:step(telemetry,os.clock(),false) if not signal then return false,guardErr end
  local original=deps.addon.copy(c)
  owner,state,reason=actor.pid,"calibration","Preparing altitude sweep"
  c.sessionActive=true
  local saved,saveErr=persist()
  if not saved then c.sessionActive=original.sessionActive state,owner="disarmed",nil return false,saveErr end
  if state~="calibration" or owner~=actor.pid or ctx.scheduler.processes[actor.pid].state~="ready" then return false,"Sweep cancelled while preparing" end
  sweep,sweepChannel,sweepAppliedAt,sweepSource,sweepReport=probe,channel.id,nil,original,nil
  sweepOrigin=origin sweepOwner=actor.pid
  drive.demand,drive.values,drive.appliedAt=nil,nil,nil
  measuredHold=nil
  calibration,calibrationSaved=nil,false
  horizontalIssue,horizontalMonitor=nil,Authority.monitor()
  if plan.certify then
    local snapshot=deps.vehicleBridge.snapshot()
    calibration=Calibration.new(actor.pid,altitudeBinding(c),snapshot.mass,(snapshot.units or {}).mass)
    calibration.proof=deps.addon.copy(burnerInitialization)
  end
  M.test=nil
  reason="Automatic altitude sweep"
  return true
end
function M.stopSweep(actor)
  local ok,err=authorize(actor,"navigation.control") if not ok then return false,err end
  if not sweep or sweep.state~="running" then return false,"No running sweep" end
  M.fail("Sweep stopped by operator") return true
end
function M.sweepReport(actor)
  local ok,err=authorize(actor,"navigation.calibrate") if not ok then return nil,err end
  if not sweep then return nil,"No sweep report" end
  return sweep:status(true)
end
function M.exportSweep(actor)
  local ok,err=authorize(actor,"navigation.calibrate") if not ok then return false,err end
  if not sweep or sweep.state=="running" or rescuePending or state=="calibration" or cfg.control.sessionActive then return false,"Finish/stop sweep and confirm rescue before saving report" end
  local report=sweep:status(true)
  report.worldOrigin=deps.addon.copy(sweepOrigin)
  report.vehicleId=sweepSource.balloonSetup.vehicleId report.burnerIds=deps.addon.copy(sweepSource.balloonSetup.burnerIds)
  local content=textutils.serialize(report,{compact=true})
  if #content>100000 or fs.getFreeSpace("/")<2*#content+2048 then return false,"Not enough space for durable sweep report; measurements remain in RAM" end
  local stamp=tostring(math.floor(os.epoch and os.epoch("utc") or os.clock()*1000))
  for i=1,99 do
    local path="/home/user/documents/altitude-sweep-"..stamp.."-"..i..".cfg"
    if not fs.exists(path) then
      local saved,problem=safeWrite.write(path,content)
      return saved,saved and path or problem
    end
  end
  return false,"Too many reports with this timestamp"
end
function M.applySweep(actor,confirmed)
  local ok,err=authorize(actor,"navigation.calibrate") if not ok then return false,err end
  if confirmed~=true or state~="disarmed" or rescuePending then return false,"Acknowledge idle state and confirm proposal first" end
  if not sweep or sweep.state~="complete" or not sweep.proposal then return false,"No validated response proposal" end
  if not sweepReport then return false,"Rescue/persistence not confirmed after sweep" end
  local current,original=deps.addon.copy(cfg.control),deps.addon.copy(sweepSource)
  current.sessionActive=nil original.sessionActive=nil
  if not same(current,original) then return false,"Control configuration changed; repeat sweep" end
  local nextValue=deps.addon.copy(cfg.control)
  nextValue.channels[1].neutral=nextValue.channels[1].mix.altitude<0 and 15-sweep.proposal.neutral or sweep.proposal.neutral
  nextValue.gains.altitude=deps.addon.copy(sweep.proposal.gains)
  nextValue.altitudeModel=deps.addon.copy(sweep.proposal)
  nextValue.altitudeModel.binding=altitudeBinding(nextValue)
  -- No physical confirmation is forged by a model fit. Generic configure resets them.
  return M.configure(actor,nextValue)
end
-- A separately authorized, session-only vertical controller. This does not
-- grant generic full-flight readiness or forge the persisted physical flags.
function M.startMeasuredHold(actor,target,confirmed)
  local ok,err=authorize(actor,"navigation.control") if not ok then return false,err end
  ok,err=authorize(actor,"navigation.calibrate") if not ok then return false,err end
  if confirmed~=true or state~="disarmed" or rescuePending or actor.pid~=sweepOwner then return false,"Confirmed completed sweep from this Navigation owner required" end
  if not sweep or sweep.state~="complete" or not sweep.prepared or not sweepReport or not sweep.proposal then return false,"Acknowledged tests and qualified measured altitude model required" end
  local current,original=deps.addon.copy(cfg.control),deps.addon.copy(sweepSource)
  current.sessionActive=nil original.sessionActive=nil
  if not same(current,original) then return false,"Configuration changed; repeat measurement sequence" end
  local model=sweep.proposal
  if target==nil then target=sweep.reusedModel and math.max(model.points[1].altitude,math.min(model.points[#model.points].altitude,M.telemetry().altitude)) or model.points[#model.points].altitude end
  local heat,problem=require("system.navigation.altitude_model").heatAt(model,target)
  if not heat then return false,problem end
  local pose,why=sweepPose(os.clock(),cfg.control.balloonSetup.vehicleId) if not pose then return false,why end
  local valid,issue=balloonStatus() if not valid then return false,issue end
  local t=M.telemetry()
  if not t.inSublevel or not deps.addon.finite(t.altitude) or not deps.addon.finite(t.altitudeRate) or os.clock()<t.timestamp or os.clock()-t.timestamp>0.5 then return false,"Fresh altitude/rate required" end
  owner,state,reason=actor.pid,"calibration","Preparing measured altitude hold"
  cfg.control.sessionActive=true
  local saved,saveErr=persist()
  if not saved then cfg.control.sessionActive=false state,owner="disarmed",nil return false,saveErr end
  if state~="calibration" or owner~=actor.pid then return false,"Measured altitude hold cancelled" end
  local permitted,denial=authorize(actor,"navigation.control")
  if not permitted then M.fail(denial) return false,denial end
  measuredHold={model=deps.addon.copy(model),vehicleId=cfg.control.balloonSetup.vehicleId,trim=deps.Trim.new(deps.vehicleBridge.snapshot())}
  targets={altitude=target} controllers,manual={},{}
  state,reason,lastTick="armed","Measured altitude hold (vertical only)",os.clock()
  return true
end
function M.startAutoCalibration(actor,confirmed)
  if measuredHold and measuredHold.trim and measuredHold.trim.active then return false,"Airborne trim active; stop before starting motion tests" end
  local ok,err=authorize(actor,"navigation.calibrate") if not ok then return false,err end
  ok,err=authorize(actor,"navigation.control") if not ok then return false,err end
  if confirmed~=true then return false,"Confirm automatic motion calibration first" end
  if calibration and calibration:running() then return false,"Calibration already running" end
  if measuredHold and owner==actor.pid and sweep and sweep.proposal then
    local snapshot=deps.vehicleBridge.snapshot()
    calibration=Calibration.new(actor.pid,altitudeBinding(cfg.control),snapshot.mass,(snapshot.units or {}).mass)
    calibration.proof=deps.addon.copy(burnerInitialization) calibrationSaved=false
    local attached=calibration:attach(measuredHold.model) return attached,not attached and calibration.reason or nil
  end
  local options=Sweep.defaults() options.certify=true options.autoPrepare=true options.autoHold=true
  return M.startSweep(actor,options,true,cfg.control)
end
-- Entry point owns the whole sequence. Nothing moves before explicit confirmation.
function M.activateAutomatic(actor,confirmed,options)
  for _,permission in ipairs({"navigation.control","navigation.calibrate","navigation.autopilot"}) do
    local ok,err=authorize(actor,permission) if not ok then return false,err end
  end
  if confirmed~=true then return false,"Confirm automatic preparation, movement tests and clear area" end
  local detected=deps.vehicleBridge.snapshot()
  if not cfg.control.balloonSetup and #(detected.burners or {})==0 and not (cfg.control.drivetrain and cfg.control.drivetrain.enabled) then
    return M.startKnownOutputCalibration(actor,true,2,true)
  end
  local plan,problem=Sweep.validate(options or Sweep.defaults())
  if not plan then return false,problem end
  if not plan.autoPrepare or not plan.autoHold or not plan.certify then return false,"Automatic pilot requires initialization, hold and certification enabled in Options; use Start sequence for measurement-only options" end
  if horizontalIssue and state=="armed" then return false,horizontalIssue.."; STOP before motor revalidation" end
  if state=="armed" and measuredHold and measuredHold.trim and measuredHold.trim.active then return false,"Airborne altitude trim active: no motion tests in flight; STOP before full horizontal calibration" end
  if activation and activation.state=="running" then return false,"Automatic preparation already running" end
  if state=="armed" and measuredHold and owner==actor.pid and calibration and calibration.state=="complete" then
    if not activation or not same(activation.options,plan) then return false,"STOP before applying different calibration options; use Control for live altitude/speed/heading targets" end
    return true,"Measured pilot already active"
  end
  if state=="failsafe" and not rescuePending then local ok,err=M.disarm(actor) if not ok then return false,err end end
  if state~="disarmed" or rescuePending then return false,"Wait for pending rescue before automatic activation" end
  local current=deps.vehicleBridge.snapshot()
  if not current.ok or not current.inventoryComplete then return false,"Fresh complete Vehicle Bridge inventory required" end
  local position,err=sweepPose(os.clock(),current.vehicleId) if not position then return false,err end
  for _,binding in ipairs(cfg.control.manualInputs or {}) do if redstone.getInput(binding.side) then return false,"Release physical pilot input first" end end
  activation={state="running",phase="survey",reason="Surveying structure before preparing pilot",owner=actor.pid,vehicleId=current.vehicleId,target=M.telemetry().altitude,options=deps.addon.copy(plan)}
  deps.vehicleBridge.requestGeometry()
  return true
end
local function prepareAutomatic()
  local job=activation
  if not job or job.state~="running" then return end
  for _,permission in ipairs({"navigation.control","navigation.calibrate","navigation.autopilot"}) do
    local ok,err=authorize({pid=job.owner},permission) if not ok then M.fail(err) return end
  end
  local current=deps.vehicleBridge.snapshot()
  if not current.ok or not current.inventoryComplete or current.vehicleId~=job.vehicleId then M.fail("Automatic preparation lost its containing vehicle") return end
  local position,err=sweepPose(os.clock(),job.vehicleId) if not position then M.fail(err) return end
  for _,binding in ipairs(cfg.control.manualInputs or {}) do if redstone.getInput(binding.side) then M.fail("Physical pilot input stopped automatic preparation") return end end
  if job.phase=="survey" then
    local hull=deps.vehicleBridge.geometryStatus()
    local api=rawget(_G,"mintcraft_vehicle")
    if type(api)=="table" and type(api.geometryPage)=="function" then
      if not hull or hull.state=="scanning" then return end
      job.fingerprint=deps.vehicleBridge.structureFingerprint()
    end
    local proposed,problem,groups=require("system.navigation.automatic_setup").plan(current,cfg.control,M.endpoints())
    job.groups=groups
    if not proposed then M.fail(problem) return end
    if not same(proposed,cfg.control) then
      local ok,issue=M.configure({pid=job.owner},proposed) if not ok then M.fail(issue) return end
    end
    if not deps.addon.finite(job.target) then job.target=M.telemetry().altitude end
    local report=config.load("/system/config/navigation-calibration.cfg",{})
    local model,issue=require("system.navigation.automatic_setup").candidate(report,job.fingerprint,current)
    if model and not same(report.binding,altitudeBinding(cfg.control)) then model,issue=nil,"Motor/sensor/output binding changed: full measurement required" end
    local horizontalReason=problem
    local options=deps.addon.copy(job.options)
    if model and (model.points[1].heat~=options.first or model.points[#model.points].heat~=options.last) then
      model,issue=nil,"Selected burner heat range changed: fresh measurement required"
    end
    local ok,problem=M.startSweep({pid=job.owner},options,true,cfg.control)
    if not ok then M.fail(problem) return end
    if activation~=job or job.state~="running" then M.fail("Automatic preparation cancelled") return end
    if model and cfg.control.drivetrain and cfg.control.drivetrain.enabled then
      calibration.motorCandidate=require("system.navigation.automatic_setup").motorCandidate(report)
      if calibration.motorCandidate then calibration.motorRows=deps.addon.copy(report.motorTests) calibration.motorExperiments=deps.Experiments.saved(report.motorExperiments,job.vehicleId) end
    end
    if not (cfg.control.drivetrain and cfg.control.drivetrain.enabled) then calibration.horizontal=horizontalReason end
    calibration.structureFingerprint=job.fingerprint
    sweep.reusedModel=model job.reused=model~=nil job.phase="calibration" job.reason=issue or "Measuring current vessel"
  elseif job.phase=="calibration" then
    if calibration and calibration.state=="aborted" then job.state,job.reason="blocked",calibration.reason
    elseif calibration and calibration.state=="complete" and measuredHold and state=="armed" then
      job.state,job.phase="active","hold"
      job.reason=calibration.driveModel and "Measured pilot ready; choose cockpit targets or a route destination" or ("Altitude pilot active; horizontal unavailable: "..tostring(calibration.horizontal))
      local points=measuredHold.model.points
      local target=math.max(points[1].altitude,math.min(points[#points].altitude,job.target))
      local ok,problem=M.setSetpoint({pid=job.owner},"altitude",target)
      if not ok then job.state,job.reason="blocked",problem M.fail(problem) end
    end
  end
end
function M.saveCalibration(actor)
  local ok,err=authorize(actor,"navigation.calibrate") if not ok then return false,err end
  if horizontalIssue then return false,"Horizontal model invalidated; fresh calibration required" end
  if measuredHold and measuredHold.trim and measuredHold.trim.active then return false,"Local airborne trim is not a full calibration report" end
  if not calibration or calibration.state~="complete" then return false,"Complete measured calibration first" end
  local report=calibration:status()
  report.schema=2 report.structureFingerprint=calibration.structureFingerprint report.binding=deps.addon.copy(calibration.binding) report.vehicleId=calibration.binding.balloonSetup.vehicleId
  report.mass=calibration.mass report.massUnit=calibration.massUnit report.model=deps.addon.copy(calibration.model)
  local motor=calibration.driveModel
  -- Curves are derived from motorTests by the existing loader. Persist raw
  -- observations once so transactional writes still fit the 1 MB computer.
  report.drivetrain=motor and {schema=1,kind="derived-motor-summary",source="motorTests",maxSpeed=motor.maxSpeed,
    determinant=motor.determinant,authority=deps.addon.copy(motor.authority),braking=deps.addon.copy(motor.braking)} or nil
  report.motorTests=deps.addon.copy(calibration.motorRows or calibration.driveProbe and calibration.driveProbe.rows)
  report.freshMotorChecks=deps.addon.copy(calibration.freshMotorChecks)
  local experiments=calibration.experiments and calibration.experiments:summary(report.vehicleId)
  report.motorExperiments=calibration.motorRows and deps.addon.copy(calibration.motorExperiments) or experiments
  report.freshMotorExperiments=calibration.motorRows and experiments or nil
  local content=textutils.serialize(report,{compact=true})
  if #content>65536 or fs.getFreeSpace("/")<2*#content+2048 then return false,"No space for calibration report; evidence retained in RAM" end
  local saved,why=safeWrite.write("/system/config/navigation-calibration.cfg",content)
  if saved then calibrationSaved=true end
  return saved,why
end
function M.step(rescan)
  if rescan or inventoryDirty then inventory=deps.addon.inventory() inventoryDirty=false end
  local now,t=os.clock(),M.telemetry()
  if deps.sable.pose then
    local pose=deps.sable.pose() autopilot:observe(pose,now) kinematics:observe(pose,now)
  end
  if not catalogueAt or now-catalogueAt>=1 then
    commandCatalogue=deps.Catalogue.build(cfg.control,deps.vehicleBridge.snapshot(),M.endpoints(),now) catalogueAt=now
  end
  local world=autopilot.sample
  if world and deps.addon.finite(t.heading) and (not drive.pose or drive.pose.at~=world.at) then
    drive.previous=drive.pose
    drive.pose={position=deps.addon.copy(world.position),velocity=deps.addon.copy(world.velocity),vehicleId=world.vehicleId,at=world.at,heading=t.heading,
      orientation=deps.addon.copy(kinematics.previous and kinematics.previous.orientation)}
    local dt=drive.previous and world.at-drive.previous.at
    if dt and dt>0 and dt<=0.5 and drive.previous.vehicleId==world.vehicleId then drive.pose.yawRate=deps.geometry.wrap(t.heading-drive.previous.heading)/dt end
  end
  if activation and activation.state=="running" then prepareAutomatic() now,t=os.clock(),M.telemetry() end
  timestamp=now
  if cfg.control.drivetrain and cfg.control.drivetrain.enabled and drive.values and drive.appliedAt and (state=="armed" or state=="calibration") then
    local ack,issue=deps.Drive.feedback(cfg.control.drivetrain,deps.vehicleBridge.snapshot(),drive.values,drive.appliedAt)
    if not ack and now-drive.appliedAt>=2 then M.fail(issue) end
  end
  if state=="armed" and drive.characterization and drive.characterization.job.active then
    if deps.characterizationStep(now) then
      if rescuePending then return M.step(false) end
      return
    end
  end
  if state=="armed" then
    local process=ctx and ctx.scheduler.processes[owner]
    if measuredHold then
      local permitted,denial=authorize({pid=owner},"navigation.control")
      if permitted then permitted,denial=authorize({pid=owner},"navigation.calibrate") end
      local pose,issue=sweepPose(now,measuredHold.vehicleId)
      if not permitted then M.fail(denial) elseif not pose then M.fail(issue) end
      for _,binding in ipairs(cfg.control.manualInputs or {}) do
        if sides[binding.side] and redstone.getInput(binding.side) then M.fail("Physical manual input stopped measured altitude hold") break end
      end
      if measuredHold and measuredHold.appliedAt then
        local ack,problem=deps.vehicleBridge.burnerFeedback(cfg.control.balloonSetup,measuredHold.heat,measuredHold.appliedAt,burnerInitialization)
        measuredHold.ackAt=ack and deps.vehicleBridge.snapshot().observedAt or nil
        if not ack and now-measuredHold.appliedAt>=2 then M.fail("Measured hold: "..tostring(problem)) end
      end
    end
    if not process or process.state~="ready" then M.fail("Navigation owner stopped")
    elseif not t.inSublevel or now-t.timestamp>0.5 then M.fail("sublevel/telemetry lost")
    else
      for _,axis in ipairs(deps.mode.axes(cfg.control)) do if not deps.addon.finite(t[axis]) or not deps.addon.finite(t[axis.."Rate"]) then M.fail(axis.." sensor invalid") break end end
      for _,channel in ipairs(cfg.control.channels) do local valid,why=channelValid(channel) if not valid then M.fail(why) break end end
      if cfg.control.balloonSetup then local valid,why=balloonStatus() if not valid then M.fail(why) end end
    end
  end
  if state=="armed" and measuredHold then
    local hold=measuredHold local current=deps.vehicleBridge.snapshot()
    if current.ok and current.inventoryComplete and current.vehicleId==hold.vehicleId then
      hold.trim=hold.trim or deps.Trim.new(current)
      local changed,issue=deps.Trim.observe(hold.trim,current)
      if changed==nil then M.fail(issue)
      elseif changed then
        local target=targets.altitude local controller=controllers.altitude
        if calibration and calibration:running() then
          if require("system.navigation.altitude_model").heatAt(hold.model,t.altitude) then target=t.altitude end
          calibration:abort("Mass changed: motion tests interrupted; airborne altitude trim only")
        end
        takeover("Mass changed: horizontal travel paused",t)
        autopilot:cancel("Mass changed: horizontal response requires revalidation")
        pilotDemand,drive.demand=nil,nil targets={altitude=target} controllers={altitude=controller or {}}
        calibrationSaved=false
        reason="Airborne mass adaptation: altitude maintained; horizontal travel paused"
        if activation then activation.state,activation.phase,activation.reason="active","adaptation",reason end
      end
    end
  end
  if rescuePending then
    -- Claim the batch once, before yielding to any output.
    rescuePending=false rescueResults={}
    local ok,err=writeOutputs({},true,rescueResults)
    if not ok then state,reason="failsafe","rescue incomplete: "..err
    elseif state=="calibration" and reason=="rescue test queued" then rescueTested=true state,reason="disarmed","rescue applied; confirm physical behaviour" end
    if ok and M.test and M.test.applied and M.test.completed then
      if not M.test.burnerTest or M.test.burnerFeedback then tested[M.test.id]=true end
      if M.test.burnerTest and M.test.burnerFeedback and M.test.expectedBurnerSignal>0 then
        burnerInitialization={vehicleId=cfg.control.balloonSetup.vehicleId,
          burnerIds=deps.addon.copy(cfg.control.balloonSetup.burnerIds),channelId=M.test.id,confirmedAt=now}
      end
      if state=="calibration" and reason=="output test returning to rescue" then
        state,reason,owner="disarmed",M.test.burnerTest and not M.test.burnerFeedback and
          ("Burner test NOT confirmed: "..tostring(M.test.feedbackError)) or "Output test complete; verify physical direction",nil
      end
    end
    M.test=nil
    if ok and drive.characterization and drive.characterization.finished and state=="calibration" then
      if drive.characterization.fast then deps.vehicleBridge.releaseFeedback(drive.characterization) end
      cfg.control.sessionActive=false
      local saved,why=persist()
      if saved then state,owner,reason="disarmed",nil,drive.characterization.job.reason
      else cfg.control.sessionActive=true state,reason="failsafe","Characterization rescue applied; session save failed: "..tostring(why) end
    end
    if ok and calibration and calibration:running() and (calibration.phase=="rescue" or calibration.phase=="priority") then calibration.rescueAppliedAt=os.clock() end
    if sweep and sweep.state~="running" and cfg.control.sessionActive then
      if ok then
        cfg.control.sessionActive=false
        local saved,problem=persist()
        if saved then
          sweepReport=sweep:status(true)
          if sweep.state=="complete" and state=="calibration" and reason=="Sweep returning to rescue" then
            state,reason,owner="disarmed","Sweep complete; stable heights recorded",nil
            if sweep.options.autoHold and not sweep.autoHoldAttempted then
              sweep.autoHoldAttempted=true
              local held,issue=M.startMeasuredHold({pid=sweepOwner},nil,true)
              if not held then reason="Sweep complete; automatic hold unavailable: "..tostring(issue) end
            end
          end
        else cfg.control.sessionActive=true state,reason="failsafe","Sweep rescue applied but session save failed: "..tostring(problem) end
      end
    end
    return
  end
  if deps.characterizationStep(now) then
    if rescuePending then return M.step(false) end
    return
  end
  if calibration and calibration:running() then
    local job=calibration
    local permitted,denial=authorize({pid=job.owner},"navigation.calibrate")
    if permitted then permitted,denial=authorize({pid=job.owner},"navigation.control") end
    local position,issue=sweepPose(now,(cfg.control.balloonSetup or {}).vehicleId)
    local current=deps.vehicleBridge.snapshot()
    if not permitted then M.fail(denial) return M.step(false) end
    if not position or not current.ok or not current.inventoryComplete then M.fail(issue or "Calibration inventory unavailable") return M.step(false) end
    if not same(job.binding,altitudeBinding(cfg.control)) then M.fail("Calibration configuration changed") return M.step(false) end
    if deps.addon.finite(job.mass) and job.mass>0 and (not deps.addon.finite(current.mass) or (current.units or {}).mass~=job.massUnit or math.abs(current.mass-job.mass)>job.mass*0.02) then M.fail("Vehicle mass changed; repeat calibration") return M.step(false) end
    for _,binding in ipairs(cfg.control.manualInputs or {}) do
      if sides[binding.side] and redstone.getInput(binding.side) then M.fail("Physical pilot input stopped automatic calibration") return M.step(false) end
    end
    if job.state=="waiting_model" and sweep and sweep.state~="running" then
      if measuredHold then job.proof=deps.addon.copy(burnerInitialization) job:attach(measuredHold.model)
      else job:abort("No qualified measured model: "..tostring(sweep.fitError or reason)) end
    end
    if job.state=="running" then
      local ack=measuredHold and measuredHold.ackAt~=nil
      if job.phase=="rescue" or job.phase=="priority" then
        local channel=cfg.control.channels[1]
        local heat=channel.mix.altitude<0 and 15-channel.rescue or channel.rescue
        ack=job.rescueAppliedAt and deps.vehicleBridge.burnerFeedback(cfg.control.balloonSetup,heat,job.rescueAppliedAt,job.proof) or false
      end
      local action
      if job.phase=="routeCheck" then
        local mission=autopilot:status()
        if mission.state=="failed" or mission.state=="cancelled" then M.fail("Calibration route interrupted: "..tostring(mission.reason)) return M.step(false) end
        if mission.state=="holding" and drive.pose and drive.pose.velocity then
          local speed=math.sqrt(drive.pose.velocity.x^2+drive.pose.velocity.z^2)
          if not job.routeLast or drive.pose.at-job.routeLast>=0.5 then
            job.routeSamples=speed<=0.1 and (job.routeSamples or 0)+1 or 0 job.routeLast=drive.pose.at
          end
          if (job.routeSamples or 0)>=8 then
            job.checks.horizontal={passed=true,position=deps.addon.copy(drive.pose.position),speed=speed,observedAt=drive.pose.at}
            takeover("Measured calibration route and braking passed",t)
            job.state,job.phase,job.reason="complete","complete","Automatic vertical + differential calibration passed"
            job.horizontal="Closed-loop short route, forward/reverse, yaw and braking measured"
          end
        end
      elseif job.phase=="motors" then
        if not drive.pose or drive.pose.vehicleId~=(cfg.control.balloonSetup or {}).vehicleId or now-drive.pose.at>0.5 then M.fail("Motor pose/velocity unavailable") return M.step(false) end
        local wanted=drive.demand or deps.Drive.commands(cfg.control.drivetrain)
        if job.driveProbe.phase=="pulse" and not job.driveProbe.appliedAt and same(drive.values,wanted) then job.driveProbe.appliedAt=drive.appliedAt end
        local motorAck=drive.values and drive.appliedAt and same(drive.values,wanted) and deps.Drive.feedback(cfg.control.drivetrain,current,drive.values,drive.appliedAt)
        if drive.healthJob~=job then
          drive.health=deps.MotorHealth.new((cfg.control.balloonSetup or {}).vehicleId,cfg.control.drivetrain)
          drive.healthJob=job
        end
        drive.health:learn(current,cfg.control.drivetrain,drive.values,drive.appliedAt,motorAck,now)
        job.experiments=job.experiments or deps.Experiments.new()
        local phase=job.driveProbe.phase
        job.experiments:observe(job.driveProbe,drive.pose,kinematics:status(now),motorAck,measuredHold.heat,measuredHold.ackAt,current.observedAt)
        local motorAction,issue=job.driveProbe:step(drive.pose,motorAck)
        job.experiments:transition(job.driveProbe,phase,drive.pose)
        if issue then M.fail(issue) return M.step(false) end
        job.horizontal=job.driveProbe.reason
        if motorAction and motorAction.kind=="drive" then drive.demand=deps.Drive.commands(cfg.control.drivetrain,motorAction.selection)
        elseif motorAction and motorAction.kind=="complete" then
          drive.demand=nil
          if job.motorCandidate and not deps.Drive.referencesMatch(job.motorCandidate,job.driveProbe.rows) then
            job.motorCandidate,job.motorRows,job.motorExperiments=nil,nil,nil job.driveProbe=deps.Drive.newProbe() job.experiments=deps.Experiments.new()
            drive.health,drive.healthJob=nil,nil
            job.horizontal="Saved motor response changed; automatically measuring all 60 modes"
          else
          if job.motorCandidate then job.driveModel=deps.addon.copy(job.motorCandidate) job.freshMotorChecks=deps.addon.copy(job.driveProbe.rows)
            if not deps.Drive.evidence(job.driveModel,job.driveProbe.rows) then job.driveModel=nil issue="Fresh measured motor matrix lost independent authority" end
          else job.driveModel,issue=deps.Drive.model(job.driveProbe.rows) end
          job.driveDone=true job.horizontal=job.driveModel and "Measured forward/reverse, yaw and braking: ready" or tostring(issue)
          job.state,job.phase,job.reason="complete","complete","Automatic calibration complete; "..job.horizontal
          if job.driveModel then
            job.state,job.phase,job.reason="running","routeCheck","Checking a short measured differential route"
            local plan=deps.Autopilot.defaults() local p=drive.pose.position local a=math.rad(drive.pose.heading)
            plan.radius=1 plan.altitudeTolerance=0.5 plan.settleSeconds=1 plan.clearRouteConfirmed=true
            plan.points={{x=p.x+2*math.sin(a),y=p.y,z=p.z+2*math.cos(a)},
              {x=p.x+2*math.sin(a)+2*math.cos(a),y=p.y,z=p.z+2*math.cos(a)-2*math.sin(a)}}
            local started,issue=M.startMission({pid=job.owner},plan,true,calibrationToken)
            if not started then M.fail(issue) return M.step(false) end
          end
          end
        end
      else action=job:step(t,now,ack) end
      if job.state=="aborted" then M.fail(job.reason) return M.step(false) end
      if action then
        local ok,problem
        if action.kind=="target" then ok,problem=M.setSetpoint({pid=job.owner},"altitude",action.value,calibrationToken)
        elseif action.kind=="rescue" or action.kind=="priority" then
          job.rescueAppliedAt=nil
          ok,problem=M.stopMission({pid=job.owner},calibrationToken)
          if ok then return M.step(false) end
        elseif action.kind=="restart" then
          ok,problem=M.disarm({pid=job.owner},calibrationToken)
          if ok then burnerInitialization=deps.addon.copy(job.proof) ok,problem=M.startMeasuredHold({pid=job.owner},action.value,true) end
        end
        if not ok then M.fail(problem or "Automatic calibration action refused") return M.step(false) end
      end
      if job.state=="complete" and cfg.control.drivetrain and cfg.control.drivetrain.enabled and not job.driveDone then
        job.driveProbe=deps.Drive.newProbe(job.motorCandidate and deps.Drive.references(job.motorCandidate)) job.state,job.phase="running","motors" job.horizontal="Testing clutch/transmission/reverser combinations" drive.demand=nil
      end
      if job.state=="complete" and not calibrationSaved then
        local saved,why=M.saveCalibration({pid=job.owner})
        if not saved then job.reason=job.reason.."; report not saved: "..tostring(why) end
      end
    end
  end
  if sweep and sweep.state=="running" then
    local process=ctx and ctx.scheduler.processes[owner]
    if not process or process.state~="ready" then M.fail("Sweep owner stopped") return M.step(false) end
    for _,binding in ipairs(cfg.control.manualInputs or {}) do
      if sides[binding.side] and redstone.getInput(binding.side) then M.fail("Physical manual input stopped sweep") return M.step(false) end
    end
    local permitted,denial=authorize({pid=owner},"navigation.control")
    if permitted then permitted,denial=authorize({pid=owner},"navigation.calibrate") end
    if not permitted then M.fail(denial) return M.step(false) end
    local position,poseErr=sweepPose(now,cfg.control.balloonSetup.vehicleId)
    if not position then M.fail(poseErr) return M.step(false) end
    if sweep.options.maxTravel>0 then
      local distance=math.sqrt((position.x-sweepOrigin.x)^2+(position.y-sweepOrigin.y)^2+(position.z-sweepOrigin.z)^2)
      if distance>sweep.options.maxTravel then M.fail("Operator world travel limit reached") return M.step(false) end
    end
    local channel=cfg.control.channels[1]
    local valid,problem=channelValid(channel)
    if not valid then M.fail(problem) return M.step(false) end
    local current=deps.vehicleBridge.snapshot()
    if not current.ok or not current.inventoryComplete or current.vehicleId~=cfg.control.balloonSetup.vehicleId then M.fail("Sweep inventory lost/changed/stale") return M.step(false) end
    local ack,why=false,"Waiting for heater feedback"
    if sweepAppliedAt then ack,why=deps.vehicleBridge.burnerFeedback(cfg.control.balloonSetup,sweep.signal,sweepAppliedAt,burnerInitialization) end
    if sweepAppliedAt and now-sweepAppliedAt>=2 and not ack then M.fail("Sweep: "..tostring(why)) return M.step(false) end
    ack=ack and t.timestamp>sweepAppliedAt
    local previous=sweep.signal
    local phase=sweep.phase
    local heat,guardErr=sweep:step(t,now,ack)
    if sweep.prepared and sweep.reusedModel then
      sweep.proposal=deps.addon.copy(sweep.reusedModel) sweep.state="complete" sweep.reason="Saved model candidate prepared; fresh closed-loop checks required"
      heat=nil
    end
    if phase=="initialize" and sweep.initialized then
      burnerInitialization={vehicleId=cfg.control.balloonSetup.vehicleId,burnerIds=deps.addon.copy(cfg.control.balloonSetup.burnerIds),channelId=sweepChannel,confirmedAt=now}
    end
    if not heat then
      if sweep.state=="complete" then reason,rescuePending="Sweep returning to rescue",true
      else M.fail(guardErr) end
      return M.step(false)
    end
    local value=channel.mix.altitude<0 and 15-heat or heat
    local ok,err=writeOutputs({[sweepChannel]=value})
    if not ok then M.fail("Sweep actuator error: "..err) return M.step(false) end
    if state~="calibration" or sweep.state~="running" then return M.step(false) end
    if not sweepAppliedAt or heat~=previous or sweep.phase~=phase then sweepAppliedAt=os.clock() end
    reason=sweep.reason.." | heat "..heat.." | "..#sweep.samples.." retained samples"
    return
  end
  if state=="calibration" and M.test then
    if M.test.burnerTest and M.test.appliedAt then
      local confirmed,problem=deps.vehicleBridge.burnerFeedback(cfg.control.balloonSetup,M.test.expectedBurnerSignal,M.test.appliedAt)
      -- Latest fresh feedback wins; do not retain an earlier successful sample
      -- after a heater stops responding or the bridge becomes stale.
      M.test.burnerFeedback=confirmed
      M.test.feedbackError=problem
    end
    if now>=M.test.expires then
      if not M.test.applied then M.fail("output test expired before application; test again") return end
      M.test.completed=true
      reason,rescuePending="output test returning to rescue",true
      return
    end
    local ok,err=writeOutputs({[M.test.id]=M.test.value})
    if not ok then M.fail("actuator error: "..err) return end
    if not M.test.applied then M.test.appliedAt=os.clock() end
    M.test.applied=true
    return
  end
  if state~="armed" then return end
  if autopilot:running() then
    for _,binding in ipairs(cfg.control.manualInputs or {}) do
      if sides[binding.side] and redstone.getInput(binding.side) then takeover("Physical pilot override",t) break end
    end
    for _,value in pairs(manual) do if value.expires>now then takeover("Manual pilot override",t) break end end
    if autopilot:running() then
      local nextTargets,problem=autopilot:step(t,now)
      if not nextTargets then M.fail(problem or "Autopilot guidance unavailable") return M.step(false) end
      targets=nextTargets
    end
  end
  local dt=lastTick and now-lastTick or 0.1
  lastTick=now
  local output={}
  for _,axis in ipairs(deps.mode.axes(cfg.control)) do
    local override=manual[axis]
    for _,binding in ipairs(cfg.control.manualInputs or {}) do
      if binding.axis==axis and sides[binding.side] and redstone.getInput(binding.side) then override={value=math.max(-1,math.min(1,tonumber(binding.value) or 0)),expires=now+0.2} manual[axis]=override end
    end
    if override and override.expires>now then
      output[axis]=override.value*cfg.control.gains[axis].limit
      controllers[axis]={}
      targets[axis]=t[axis]
    else
      if override then targets[axis]=t[axis] manual[axis]=nil end
      controllers[axis]=controllers[axis] or {}
      local error=targets[axis]-t[axis]
      if axis=="heading" then error=deps.geometry.wrap(error) end
      output[axis]=deps.pid.step(controllers[axis],measuredHold and measuredHold.model.gains or cfg.control.gains[axis],error,t[axis.."Rate"],dt)
    end
  end
  if (autopilot:running() and targets.drive or pilotDemand) and measuredHold and calibration and calibration.driveModel then
    local permitted,denial=authorize({pid=owner},"navigation.autopilot") if not permitted then M.fail(denial) return M.step(false) end
    local ready,issue=differentialCurrent(calibration.phase=="routeCheck" and calibrationToken or nil) if not ready then M.fail(issue) return M.step(false) end
    if calibration.state=="complete" then
      local values=deps.addon.copy(drive.values or {}) values.engaged=15-cfg.control.drivetrain.clutchOff
      local snapshot=deps.vehicleBridge.snapshot()
      local ack=drive.appliedAt and deps.Drive.feedback(cfg.control.drivetrain,snapshot,values,drive.appliedAt)
      local expected=deps.Drive.expected(calibration.driveModel,values)
      local problem=drive.healthJob==calibration and drive.health:check(snapshot,cfg.control.drivetrain,values,drive.appliedAt,ack,now,expected)
      problem=problem or horizontalMonitor:observe(drive.pose,expected,ack)
      if problem then
        local target,controller=targets.altitude,controllers.altitude
        takeover(problem,t) autopilot:cancel(problem)
        horizontalIssue=problem pilotDemand,drive.demand=nil,nil targets={altitude=target} controllers={altitude=controller or {}}
        reason=problem.."; verified vertical hold retained"
        if activation then activation.reason=reason end
        return M.step(false)
      end
    end
    local selection,issue=deps.Drive.control(calibration.driveModel,drive.pose,pilotDemand or targets.drive)
    if not selection then M.fail(issue) return M.step(false) end
    local desired=deps.Drive.commands(cfg.control.drivetrain,selection)
    if not drive.values or not same(desired,drive.values) then
      local ack=drive.values and drive.appliedAt and deps.Drive.feedback(cfg.control.drivetrain,deps.vehicleBridge.snapshot(),drive.values,drive.appliedAt)
      if not drive.values or ack then drive.demand=desired end
    end
  elseif not (calibration and calibration:running() and calibration.phase=="motors") then drive.demand=nil end
  local values={}
  if autopilot:running() and targets.translation then
    -- Clear the old direction for one complete control tick before requesting
    -- its opposite; peripheral writes are not an atomic multi-device batch.
    local demand=targets.translation
    if routeForward*demand.forward<0 then demand.forward=0 end
    if routeRight*demand.right<0 then demand.right=0 end
    routeForward,routeRight=demand.forward,demand.right
  else routeForward,routeRight=0,0 end
  for _,channel in ipairs(cfg.control.channels) do
    local value=channel.neutral
    if measuredHold then
      local heat,problem=require("system.navigation.altitude_model").heatAt(measuredHold.model,targets.altitude)
      if not heat then M.fail(problem) return M.step(false) end
      deps.Trim.step(measuredHold.trim,measuredHold.model,t,targets.altitude,measuredHold.ackAt,measuredHold.requestedHeat,now,channel.mix.altitude<0 and 15-channel.max or channel.min,channel.mix.altitude<0 and 15-channel.min or channel.max)
      heat=heat+((measuredHold.trim or {}).bias or 0)
      value=(channel.mix.altitude or 0)<0 and 15-heat or heat
    end
    for _,axis in ipairs(deps.mode.axes(cfg.control)) do value=value+(channel.mix[axis] or 0)*output[axis] end
    if autopilot:running() and targets.translation then
      local forward,right=targets.translation.forward,targets.translation.right
      value=value+(channel.mix.routeForward or 0)*math.max(0,forward)+(channel.mix.routeReverse or 0)*math.max(0,-forward)
        +(channel.mix.routeRight or 0)*math.max(0,right)+(channel.mix.routeLeft or 0)*math.max(0,-right)
    end
    if measuredHold then
      local range=measuredHold.model.measuredRange
      local adapting=measuredHold.trim and measuredHold.trim.active
      local low,high=adapting and 0 or range.first,adapting and 15 or range.last
      if channel.mix.altitude<0 then low,high=15-high,15-low end
      value=math.max(low,math.min(high,value))
    end
    value=math.max(channel.min,math.min(channel.max,value))
    if measuredHold then
      -- Fractional heat needs measured duty cycling: integral redstone alone
      -- cannot represent an interpolated height between two heat levels.
      -- Advance the quantizer only on a new receiver acknowledgement. A lost
      -- receiver therefore cannot be hidden by endlessly changing demands.
      measuredHold.requestedHeat=channel.mix.altitude<0 and 15-value or value
      if not measuredHold.heat or measuredHold.ackAt and measuredHold.ackAt~=(measuredHold.quantizedAt or -1) then
        local total=value+(measuredHold.fraction or 0)
        local quantized=math.floor(total+0.5)
        measuredHold.fraction=total-quantized measuredHold.quantizedAt=measuredHold.ackAt
        values[channel.id]=quantized
      else values[channel.id]=channel.mix.altitude<0 and 15-measuredHold.heat or measuredHold.heat end
    else values[channel.id]=math.floor(value+0.5) end
  end
  local hold=measuredHold
  local ok,err=writeOutputs(values)
  if hold and (measuredHold~=hold or state~="armed") then return M.step(false) end
  if hold and ok then
    local channel=cfg.control.channels[1] local heat=values[channel.id]
    if channel.mix.altitude<0 then heat=15-heat end
    if heat~=hold.heat or not hold.appliedAt then hold.heat=heat hold.appliedAt=os.clock() end
  end
  if ok and burnerInitialization then
    for _,channel in ipairs(cfg.control.channels) do
      if channel.id==burnerInitialization.channelId then
        local signal=values[channel.id]
        if (channel.mix.altitude or 0)<0 then signal=15-signal end
        local active=signal>0
        if active and not burnerDemand then burnerHeatSince=os.clock() end
        if not active then burnerHeatSince=nil end
        burnerDemand=active
      end
    end
  end
  if not ok then M.fail("actuator error: "..err) end
end

function M.kinematics() return kinematics:status(os.clock()) end
function M.commandCatalogue()
  local out=deps.addon.copy(commandCatalogue or {schema=1,available=false,reason="Waiting for cached command inventory",commands={},equipment={}})
  if out.validUntil and (os.clock()>out.validUntil or os.clock()<out.observedAt) then
    out.available=false out.reason="Command feedback cache expired"
    for _,row in ipairs(out.commands) do row.feedback={available=false,reason="Receiver cache expired"} end
  end
  return out
end
function M.commands(actor)
  for _,permission in ipairs({"navigation.assist","sable.read"}) do local ok,why=authorize(actor,permission) if not ok then return nil,why end end
  return M.commandCatalogue()
end
function M.status()
  local valid,errors=M.validate()
  local differentialReady,differentialReason=differentialCurrent()
  return {state=state=="disarmed" and valid and "ready" or state,reason=reason,ownerPid=owner,ready=valid,errors=errors,targets=deps.addon.copy(targets),
    mode=cfg.control and cfg.control.mode or "full",axes=deps.mode.axes(cfg.control),
    outputCharacterization=drive.characterization and drive.characterization.job:status() or nil,
    knownOutputHold=state=="armed" and drive.characterization and drive.characterization.job.active and drive.characterization.job.controller:status() or nil,
    motorExperiments=calibration and calibration.experiments and calibration.experiments:summary((cfg.control.balloonSetup or {}).vehicleId) or nil,
    kinematics=M.kinematics(),
    authority=calibration and calibration.driveModel and deps.addon.copy(calibration.driveModel.authority) or nil,
    horizontalDiagnostic={issue=horizontalIssue,noResponseSamples=horizontalMonitor.samples},
    mechanicalDiagnostic=drive.healthJob==calibration and drive.health and drive.health:status(state=="armed" and os.clock() or nil) or nil,
    predictiveBraking=calibration and calibration.driveModel and deps.addon.copy(calibration.driveModel.braking) or nil,
    groundSpeed=drive.pose and drive.pose.velocity and math.sqrt(drive.pose.velocity.x^2+drive.pose.velocity.z^2) or nil,
    pilot=pilotDemand and deps.addon.copy(pilotDemand) or nil,
    maxSpeed=differentialReady and calibration.driveModel.maxSpeed or nil,
    autopilot=autopilot:status(),measuredHold=measuredHold and {active=true,target=targets.altitude,heat=measuredHold.heat,requestedHeat=measuredHold.requestedHeat,adaptation=deps.Trim.status(measuredHold.trim),range=deps.addon.copy(measuredHold.model.measuredRange)} or nil,
    sweep=sweep and sweep:status(false) or nil,
    automatic=activation and deps.addon.copy(activation) or nil,
    autoCalibration=calibration and calibration:status() or nil,differentialReady=differentialReady,differentialReason=differentialReason,calibrationSaved=calibrationSaved,
    calibration={tested=deps.addon.copy(tested),rescueTested=rescueTested,test=deps.addon.copy(M.test),initializationConfirmed=burnerInitialization~=nil},
    outputs=deps.addon.copy(last),outputResults=deps.addon.copy(outputResults),rescueResults=deps.addon.copy(rescueResults),rescuePending=rescuePending,timestamp=timestamp}
end

function M.health()
  return {ok=state~="failsafe",status=reason,lastFault=state=="failsafe" and reason or nil,timestamp=timestamp,rescuePending=rescuePending,
    pid=runner and runner.pid,lastSuccess=runner and runner.lastSuccess,outputResults=deps.addon.copy(outputResults),rescueResults=deps.addon.copy(rescueResults)}
end

function M.start(context)
  if runner then runner:stop() end
  ctx=context
  autopilot=deps.Autopilot.new() pilotDemand=nil
  kinematics=Estimator.new() commandCatalogue,catalogueAt=nil,nil
  horizontalIssue,horizontalMonitor=nil,Authority.monitor()
  sweep,sweepChannel,sweepAppliedAt,sweepSource,sweepReport,sweepOrigin=nil,nil,nil,nil,nil,nil
  routeForward,routeRight=0,0
  sweepOwner,measuredHold=nil,nil
  calibration,calibrationSaved=nil,false activation=nil
  drive.demand,drive.values,drive.appliedAt,drive.pose,drive.previous=nil,nil,nil,nil,nil
  drive.health,drive.healthJob=nil,nil
  drive.characterization=nil
  migrate()
  state,owner,rescuePending="disarmed",nil,false
  reason="not armed; calibration required"
  controllers,manual,last,tested={}, {}, {}, {}
  outputResults,rescueResults={},{}
  rescueTested=false
  burnerInitialization,burnerDemand,burnerHeatSince=nil,false,nil
  M.test=nil
  if cfg.control.sessionActive then state,reason,rescuePending="failsafe","previous session interrupted; rescue required",true end
  runner=deps.addon.periodic(ctx,"flightd",0.1,M.step)
  runner.onError=function(err)
    if state=="failsafe" then rescuePending=false reason="rescue uncertain: "..err
    else M.fail("actuator error: "..err) end
  end
  if runner.error then runner.onError(runner.error) end
  if runner.pid and ctx.scheduler.makeContext then
    ctx.scheduler:makeContext(runner.pid).onCleanup(function()
      if state=="armed" or state=="calibration" or rescuePending then
        M.fail("flight worker stopped unexpectedly")
        local safetyPid=ctx.scheduler:spawn("flight rescue",function()
          local ok,err=deps.addon.bounded(function() M.step(true) end,0.5)
          if not ok then rescuePending=false reason="rescue uncertain: "..tostring(err) pcall(log.error,"navigation",reason) end
        end,{eventMode="raw",appId="flightd",protected=true})
        ctx.scheduler:start(safetyPid)
      end
    end)
  end
end

function M.stop()
  if state=="armed" or state=="calibration" then M.fail("flight service stopping") return false,"rescue queued; disarm before stopping" end
  if rescuePending then return false,"rescue outputs pending" end
  if runner then runner:stop() runner=nil end
  ctx=nil
  return true
end

return M
