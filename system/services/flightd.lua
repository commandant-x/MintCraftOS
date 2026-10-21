local addon = require("system.libraries.addon")
local geometry = require("system.navigation.geometry")
local pid = require("system.navigation.pid")
local config = require("system.libraries.config")
local safeWrite = require("system.libraries.safe_write")
local permissions = require("system.security.permissions")
local avionics = require("system.services.avionicsd")
local sable = require("system.services.sabled")
local log = require("system.libraries.log")
local mode = require("system.navigation.control_mode")
local linkOutput = require("system.navigation.link_output")
local vehicleBridge = require("system.services.vehiclebridged")
local Autopilot = require("system.navigation.autopilot")
local Sweep=require("system.navigation.altitude_sweep")
local sweep,sweepChannel,sweepAppliedAt,sweepSource,sweepReport,sweepOrigin
local autopilot=Autopilot.new()
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
    local sub=sable.flightStatus and sable.flightStatus() or sable.status()
    local observed=sub.timestamp
    if not observed then observed=sable.snapshot().timestamp end
    t.inSublevel=sub.inSublevel==true and addon.finite(observed) and os.clock()-observed<=0.5
    if not addon.finite(t.heading) and not (c.sensors.nav and c.sensors.nav~="") and sable.pose then
      local pose=sable.pose()
      if t.inSublevel and pose and pose.inSublevel and pose.frame=="world" and addon.finite(pose.timestamp) and os.clock()-pose.timestamp<=0.5 then
        local heading=geometry.heading(pose.logicalPose and pose.logicalPose.orientation)
        if heading then
          t.heading=heading t.headingSource="Sable orientation (+Z)"
          t.timestamp=math.min(t.timestamp,pose.timestamp)
          t.measurements=t.measurements or {}
          t.measurements.heading={valid=true,value=heading,source="sable",method="getLogicalPose",frame="world",unit="deg",observedAt=pose.timestamp,validUntil=pose.timestamp+0.5}
        end
      end
    elseif addon.finite(t.heading) then t.headingSource="Avionics navigation table" end
    if c.mode=="altitude" and t.measurements then
      local a,v=t.measurements.altitude,t.measurements.altitudeRate
      if a and v and a.valid and v.valid and addon.finite(a.observedAt) and addon.finite(v.observedAt)
        and a.validUntil and v.validUntil and os.clock()<=math.min(a.validUntil,v.validUntil) then
        t.altitude,t.altitudeRate=a.value,v.value t.timestamp=math.min(a.observedAt,v.observedAt)
      else t.altitude,t.altitudeRate,t.timestamp=nil,nil,0 end
    end
    return t
  end
  local snap = avionics.snapshot()
  local g = selected(snap.gimbal,c.sensors.gimbal)
  local a = selected(snap.altitude,c.sensors.altitude)
  local nav = selected(snap.nav,c.sensors.nav)
  local angle, rate = g.angles or {},g.angularRates or {}
  local sub=sable.snapshot()
  return {pitch=angle[1],roll=angle[2],altitude=a.height,heading=nav.heading,
    pitchRate=rate[1],rollRate=rate[3],headingRate=rate[2],altitudeRate=a.verticalSpeed,
    gravity=addon.vec(g.gravity),pressure=a.airPressure,timestamp=snap.timestamp or 0,
    inSublevel=sable.status().inSublevel==true and os.clock()-(sub.timestamp or 0)<=0.5}
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
    if not addon.finite(channel[key]) or channel[key]%1~=0 then return false,key.." must be an integer" end
  end
  if channel.min < 0 or channel.max > 15 or channel.min>channel.max then return false,"signal limits must be within 0..15" end
  if channel.neutral<channel.min or channel.neutral>channel.max or channel.rescue<channel.min or channel.rescue>channel.max then return false,"neutral/rescue outside limits" end
  if channel.backend=="avionics" then
    local row=deviceFor(channel)
    if not row or not row.set.setSignal or not (addon.hasType(row,"analog_transmission") or addon.hasType(row,"throttle_lever")) then return false,"supported Avionics signal endpoint missing" end
  end
  if channel.backend=="relay" then
    local row=deviceFor(channel)
    if not row or not addon.hasType(row,"redstone_relay") or not row.set.setAnalogOutput then return false,"redstone relay endpoint missing" end
  end
  if channel.backend=="frequency" and not linkOutput.device(deviceFor(channel)) then return false,"CC Create Redstone Link transmitter missing" end
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
  return vehicleBridge.balloonStatus(cfg.control.balloonSetup,burnerInitialization,demand)
end
function M.validate()
  local c, errors, used, matrix = cfg.control,{}, {},{}
  if not c then return false,{"configuration missing"} end
  if type(c.channels)~="table" or type(c.gains)~="table" then return false,{"configuration malformed"} end
  local active=mode.axes(c)
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
      if not addon.finite(weight) or math.abs(weight)>10 then errors[#errors+1]="invalid mixer coefficient" weight=0 end
    end
    for _,key in ipairs(routeMix) do
      local weight=(channel.mix or {})[key]
      if weight~=nil and (not addon.finite(weight) or math.abs(weight)>15) then errors[#errors+1]="invalid directional thrust mix" end
    end
    for index,axis in ipairs(active) do row[index]=addon.finite((channel.mix or {})[axis]) and channel.mix[axis] or 0 end
    matrix[#matrix+1]=row
  end
  if rankConfig~=c then mixerRank,rankConfig=rank(matrix,#active),c end
  if mixerRank<#active then errors[#errors+1]="outputs cannot independently correct enabled axes" end
  for _, axis in ipairs(active) do
    local g=c.gains[axis] or {}
    for _, key in ipairs({"kp","ki","kd","limit","slew","integralLimit","deadband"}) do
      if not addon.finite(g[key]) or g[key]<0 then errors[#errors+1]=axis..": invalid "..key end
    end
    if not (g.kp and g.kp>0 and g.limit and g.limit>0 and g.slew and g.slew>0) then errors[#errors+1]=axis..": gains not configured" end
  end
  if not c.hoverValidated then errors[#errors+1]="hover baseline not validated" end
  if not c.rescueValidated then errors[#errors+1]="rescue profile not tested" end
  if not c.manualValidated then errors[#errors+1]="manual priority bindings not validated" end
  for _,binding in ipairs(c.manualInputs or {}) do
    if type(binding)~="table" or not sides[binding.side] or not c.gains[binding.axis] or not addon.finite(binding.value) or math.abs(binding.value)>1 then errors[#errors+1]="invalid manual input binding"
    elseif not mode.enabled(c,binding.axis) then errors[#errors+1]="manual input axis disabled: "..binding.axis
    elseif used["redstone:"..binding.side] then errors[#errors+1]="manual input shares output side "..binding.side end
  end
  local t=M.telemetry()
  if not t.inSublevel then errors[#errors+1]="not on a Sable sublevel" end
  if os.clock()-t.timestamp>0.5 then errors[#errors+1]="flight telemetry stale" end
  for _, axis in ipairs(active) do
    if not addon.finite(t[axis]) then errors[#errors+1]=axis..": sensor unavailable (check Sensors / Devices)" end
    if not addon.finite(t[axis.."Rate"]) then errors[#errors+1]=axis..": rate unavailable (gimbal / altitude sensor)" end
  end
  return #errors==0,errors
end

function M.configuration() return addon.copy(cfg.control) end
local function same(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~="table" then return a==b end
  for key,value in pairs(a) do if not same(value,b[key]) then return false end end
  for key in pairs(b) do if a[key]==nil then return false end end
  return true
end
function M.configure(actor, value)
  local ok, err=authorize(actor,"navigation.calibrate")
  if not ok then return false,err end
  if state=="armed" or state=="calibration" or rescuePending then return false,"disarm and finish pending outputs before editing" end
  if type(value)~="table" then return false,"invalid control config" end
  if type(value.channels)~="table" or type(value.gains)~="table" or type(value.sensors)~="table" or #value.channels>32 then return false,"invalid mapping" end
  if value.mode~=nil and value.mode~="full" and value.mode~="altitude" then return false,"invalid control mode" end
  for _,channel in ipairs(value.channels) do
    local valid,why=channelValid(channel)
    if not valid then return false,why end
    if type(channel.mix)~="table" then return false,"mixer required" end
  end
  if same(value,cfg.control) then return true end
  local previous=cfg.control
  cfg.control=addon.copy(value)
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
  burnerInitialization,burnerDemand,burnerHeatSince=nil,false,nil
  return true
end

function M.fail(message)
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
  cfg.control.sessionActive=true
  local saved,why=persist()
  if not saved then cfg.control.sessionActive=false return false,why end
  session=true
  burnerDemand,burnerHeatSince=false,nil
  targets={pitch=0,roll=0,altitude=t.altitude,heading=t.heading}
  controllers,manual={},{}
  owner,state,reason,lastTick=actor.pid,"armed","stabilisation armed",os.clock()
  pcall(log.warn,"navigation","armed owner="..owner)
  return true
end

function M.disarm(actor)
  local ok,err=authorize(actor,"navigation.control")
  if not ok then return false,err end
  if state=="armed" or state=="calibration" then M.fail("manual disarm: calibrated rescue") end
  if not rescuePending then
    cfg.control.sessionActive=false
    local saved,why=persist()
    if not saved then return false,why end
    state,reason,owner,session="disarmed","disarmed",nil,false
  end
  return true
end

function M.release(pid, message) if owner==pid then M.fail(message or "Navigation closed") end end

local function takeover(message,t)
  if not autopilot:running() then return end
  autopilot:cancel(message)
  routeForward,routeRight=0,0
  t=t or M.telemetry()
  targets={pitch=0,roll=0,altitude=t.altitude,heading=t.heading}
  controllers={}
end

function M.startMission(actor,plan,confirmed)
  local ok,err=authorize(actor,"navigation.autopilot")
  if not ok then return false,err end
  ok,err=authorize(actor,"navigation.control") if not ok then return false,err end
  if confirmed~=true then return false,"Confirm autonomous flight explicitly" end
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
  if sable.pose then autopilot:observe(sable.pose(),os.clock()) end
  local vehicle=cfg.control.vehicle
  if vehicle and vehicle.bridgeVehicleId and autopilot.sample and vehicle.bridgeVehicleId~=autopilot.sample.vehicleId then return false,"Imported vehicle geometry belongs to another sublevel; Discover and calibrate this vehicle" end
  return autopilot:start(plan,M.telemetry(),os.clock())
end

function M.stopMission(actor)
  local ok,err=authorize(actor,"navigation.control") if not ok then return false,err end
  if owner~=actor.pid or state~="armed" then return false,"Flight owner mismatch" end
  takeover("Pilot stopped mission; manual stabilization")
  return true
end

function M.setSetpoint(actor,axis,value)
  local ok,err=authorize(actor,"navigation.control")
  if not ok then return false,err end
  if owner~=actor.pid or state~="armed" then return false,"not armed by this owner" end
  if not addon.finite(value) or not mode.enabled(cfg.control,axis) then return false,"invalid or disabled setpoint" end
  if (axis=="pitch" or axis=="roll") and math.abs(value)>30 then return false,"attitude setpoint limited to 30 degrees" end
  takeover("Pilot changed setpoint")
  targets[axis]=axis=="heading" and value%360 or value
  controllers[axis]={}
  return true
end

function M.manual(actor,axis,value)
  local ok,err=authorize(actor,"navigation.control")
  if not ok then return false,err end
  if state~="armed" or owner~=actor.pid or not mode.enabled(cfg.control,axis) or not addon.finite(value) then return false,"manual override unavailable" end
  takeover("Manual pilot override")
  manual[axis]={value=math.max(-1,math.min(1,value)),expires=os.clock()+0.3}
  return true
end

local function writeOutputs(values, force, results)
  local branches, failures={}, {}
  results=results or {}
  for _,channel in ipairs(cfg.control.channels) do
    local key,value=endpoint(channel),values[channel.id]
    if force then value=channel.rescue end
    if force or (value~=nil and last[key]~=value) then
      local valid,why=channelValid(channel)
      local result={endpoint=key,value=value,state="unavailable",error=why}
      results[channel.id]=result outputResults[channel.id]=result
      if not valid or not addon.finite(value) or value<channel.min or value>channel.max then
        result.error=why or "unsafe output value"
      else
        -- A suspended write may already have reached hardware. Never infer failure
        -- from a timeout, or retry it implicitly in a later rescue tick.
        result.state,result.error="uncertain","output not confirmed"
        branches[#branches+1]=function()
          local ok,accepted,err=addon.bounded(function()
            if channel.backend=="redstone" then redstone.setAnalogOutput(channel.side,value) return true end
            local row=deviceFor(channel)
            if not row then return false,"actuator detached: "..tostring(channel.name) end
            if channel.backend=="frequency" then return linkOutput.write(row,channel,value) end
            if channel.backend=="relay" then
              local accepted,problem=addon.call(row.device,"setAnalogOutput",channel.side,value)
              if problem then error(problem) end
              return accepted~=false,accepted==false and "relay refused" or nil
            end
            local returned,problem=addon.call(row.device,"setSignal",value)
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
  return #failures==0,table.concat(failures,"; "),results
end

function M.endpoints()
  local rows={}
  for _,row in ipairs(inventory) do
    if linkOutput.device(row) then rows[#rows+1]={name=row.name,backend="frequency"}
    elseif addon.hasType(row,"redstone_relay") and row.set.setAnalogOutput then
      rows[#rows+1]={name=row.name,backend="relay",sides={"top","bottom","left","right","front","back"}}
    elseif row.set.setSignal and (addon.hasType(row,"analog_transmission") or addon.hasType(row,"throttle_lever")) then
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
  if not addon.finite(duration) or duration<0.1 or duration>2 then return false,"test duration must be 0.1..2 seconds" end
  if state=="armed" or state=="calibration" or rescuePending or confirmed~=true then return false,"test requires idle state and confirmation" end
  for _,channel in ipairs(cfg.control.channels) do
    if channel.id==id then
      local valid,why=channelValid(channel)
      if not valid or not addon.finite(value) or value<channel.min or value>channel.max then return false,why or "test outside calibrated limits" end
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
      local inverted=burnerTest and type(channel.mix)=="table" and addon.finite(channel.mix.altitude) and channel.mix.altitude<0
      M.test={id=id,value=math.floor(value+0.5),expires=os.clock()+duration,burnerTest=burnerTest==true,
        expectedBurnerSignal=inverted and 15-math.floor(value+0.5) or math.floor(value+0.5)}
      return true
    end
  end
  return false,"unknown output"
end

local function sweepPose(now,vehicleId)
  local pose=sable.pose and sable.pose()
  if not pose or pose.vehicleId~=vehicleId or not pose.inSublevel or pose.frame~="world" or not addon.finite(pose.timestamp)
    or not addon.finite(pose.identityAt) or now<pose.timestamp or now<pose.identityAt or now-pose.timestamp>0.5 or now-pose.identityAt>0.5 then return nil,"Fresh containing-vehicle world pose/identity required" end
  local logical=pose.logicalPose or {}
  local position=addon.vec(logical.position or logical.pos)
  local q=logical.orientation
  if not position or type(q)~="table" then return nil,"World position/orientation unavailable" end
  local x,y,z,w
  if q.a~=nil or q.v~=nil then
    -- Sable uses scalar a + vector v; retain support for flat CC-Sable poses.
    if type(q.v)~="table" then return nil,"Invalid sweep orientation vector" end
    x,y,z,w=q.v.x,q.v.y,q.v.z,q.a
  else x,y,z,w=q.x or q[1],q.y or q[2],q.z or q[3],q.w or q[4] end
  if not (addon.finite(x) and addon.finite(y) and addon.finite(z) and addon.finite(w)) then return nil,"Invalid sweep orientation" end
  local norm=x*x+y*y+z*z+w*w
  if not addon.finite(norm) or norm<1e-8 then return nil,"Invalid sweep orientation" end
  local tilt=math.deg(math.acos(math.max(-1,math.min(1,1-2*(x*x+z*z)/norm))))
  if tilt>10 then return nil,"Sweep tilt limit (10 degrees) reached" end
  return position
end
function M.startSweep(actor,options,confirmed,expectedControl)
  local ok,err=authorize(actor,"navigation.calibrate") if not ok then return false,err end
  ok,err=authorize(actor,"navigation.control") if not ok then return false,err end
  if confirmed~=true or state~="disarmed" or rescuePending then return false,"Sweep needs idle state and explicit confirmation" end
  local c=cfg.control
  if expectedControl and not same(c,expectedControl) then return false,"Control changed while reviewing sweep; review again" end
  if c.mode~="altitude" or not c.balloonSetup or #c.channels~=1 then return false,"One collective burner altitude channel required" end
  local channel=c.channels[1]
  local valid,why=channelValid(channel) if not valid then return false,why end
  if not channel.actuator or channel.actuator.role~="buoyancy" or math.abs(channel.mix.altitude or 0)~=1 then return false,"Verified burner channel with unit altitude mix required" end
  local missing={}
  if not burnerInitialization then missing[#missing+1]="Initialize (2s): fresh feedback from both/all selected burners" end
  if not channel.validated then missing[#missing+1]="Verify direction (after Initialize completes)" end
  if not c.manualValidated then missing[#missing+1]="Manual OK" end
  if not c.rescueValidated then missing[#missing+1]=rescueTested and "Rescue OK (Test rescue completed; confirmation still missing)" or "Test rescue, then Rescue OK" end
  if #missing>0 then return false,"Sweep blocked: "..table.concat(missing,"; ") end
  local ready,problem=balloonStatus() if not ready then return false,problem end
  local plan,planErr=Sweep.validate(options) if not plan then return false,planErr end
  local inverted=channel.mix.altitude<0
  for _,heat in ipairs({plan.first,plan.last}) do
    local value=inverted and 15-heat or heat
    if value<channel.min or value>channel.max then return false,"Sweep outside calibrated channel limits" end
  end
  local origin,poseErr=sweepPose(os.clock(),c.balloonSetup.vehicleId)
  if not origin then return false,poseErr end
  local telemetry=M.telemetry()
  local probe,probeErr=Sweep.new(plan,telemetry.altitude,os.clock()) if not probe then return false,probeErr end
  local signal,guardErr=probe:step(telemetry,os.clock(),false) if not signal then return false,guardErr end
  local original=addon.copy(c)
  owner,state,reason=actor.pid,"calibration","Preparing altitude sweep"
  c.sessionActive=true
  local saved,saveErr=persist()
  if not saved then c.sessionActive=original.sessionActive state,owner="disarmed",nil return false,saveErr end
  if state~="calibration" or owner~=actor.pid or ctx.scheduler.processes[actor.pid].state~="ready" then return false,"Sweep cancelled while preparing" end
  sweep,sweepChannel,sweepAppliedAt,sweepSource,sweepReport=probe,channel.id,nil,original,nil
  sweepOrigin=origin
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
  report.worldOrigin=addon.copy(sweepOrigin)
  report.vehicleId=sweepSource.balloonSetup.vehicleId report.burnerIds=addon.copy(sweepSource.balloonSetup.burnerIds)
  local content=textutils.serialize(report)
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
  local current,original=addon.copy(cfg.control),addon.copy(sweepSource)
  current.sessionActive=nil original.sessionActive=nil
  if not same(current,original) then return false,"Control configuration changed; repeat sweep" end
  local nextValue=addon.copy(cfg.control)
  nextValue.channels[1].neutral=nextValue.channels[1].mix.altitude<0 and 15-sweep.proposal.neutral or sweep.proposal.neutral
  nextValue.gains.altitude=addon.copy(sweep.proposal.gains)
  -- No physical confirmation is forged by a model fit. Generic configure resets them.
  return M.configure(actor,nextValue)
end
function M.step(rescan)
  if rescan or inventoryDirty then inventory=addon.inventory() inventoryDirty=false end
  local now,t=os.clock(),M.telemetry()
  if sable.pose then autopilot:observe(sable.pose(),now) end
  timestamp=now
  if state=="armed" then
    local process=ctx and ctx.scheduler.processes[owner]
    if not process or process.state~="ready" then M.fail("Navigation owner stopped")
    elseif not t.inSublevel or now-t.timestamp>0.5 then M.fail("sublevel/telemetry lost")
    else
      for _,axis in ipairs(mode.axes(cfg.control)) do if not addon.finite(t[axis]) or not addon.finite(t[axis.."Rate"]) then M.fail(axis.." sensor invalid") break end end
      for _,channel in ipairs(cfg.control.channels) do local valid,why=channelValid(channel) if not valid then M.fail(why) break end end
      if cfg.control.balloonSetup then local valid,why=balloonStatus() if not valid then M.fail(why) end end
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
          burnerIds=addon.copy(cfg.control.balloonSetup.burnerIds),channelId=M.test.id,confirmedAt=now}
      end
      if state=="calibration" and reason=="output test returning to rescue" then
        state,reason,owner="disarmed",M.test.burnerTest and not M.test.burnerFeedback and
          ("Burner test NOT confirmed: "..tostring(M.test.feedbackError)) or "Output test complete; verify physical direction",nil
      end
    end
    M.test=nil
    if sweep and sweep.state~="running" and cfg.control.sessionActive then
      if ok then
        cfg.control.sessionActive=false
        local saved,problem=persist()
        if saved then
          sweepReport=sweep:status(true)
          if sweep.state=="complete" then state,reason,owner="disarmed","Sweep complete; inspect measurements and candidate",nil end
        else cfg.control.sessionActive=true state,reason="failsafe","Sweep rescue applied but session save failed: "..tostring(problem) end
      end
    end
    return
  end
  if sweep and sweep.state=="running" then
    local process=ctx and ctx.scheduler.processes[owner]
    if not process or process.state~="ready" then M.fail("Sweep owner stopped") return M.step(false) end
    for _,binding in ipairs(cfg.control.manualInputs or {}) do
      if sides[binding.side] and redstone.getInput(binding.side) then M.fail("Physical manual input stopped sweep") return M.step(false) end
    end
    local permitted,denial=authorize({pid=owner},"navigation.control")
    if not permitted then M.fail(denial) return M.step(false) end
    local position,poseErr=sweepPose(now,cfg.control.balloonSetup.vehicleId)
    if not position then M.fail(poseErr) return M.step(false) end
    local distance=math.sqrt((position.x-sweepOrigin.x)^2+(position.y-sweepOrigin.y)^2+(position.z-sweepOrigin.z)^2)
    if distance>sweep.options.maxTravel then M.fail("Sweep world travel limit reached") return M.step(false) end
    local channel=cfg.control.channels[1]
    local valid,problem=channelValid(channel)
    if not valid then M.fail(problem) return M.step(false) end
    local current=vehicleBridge.snapshot()
    if not current.ok or not current.inventoryComplete or current.vehicleId~=cfg.control.balloonSetup.vehicleId then M.fail("Sweep inventory lost/changed/stale") return M.step(false) end
    local ack,why=false,"Waiting for heater feedback"
    if sweepAppliedAt then ack,why=vehicleBridge.burnerFeedback(cfg.control.balloonSetup,sweep.signal,sweepAppliedAt) end
    if sweepAppliedAt and now-sweepAppliedAt>=2 and not ack then M.fail("Sweep: "..tostring(why)) return M.step(false) end
    ack=ack and t.timestamp>sweepAppliedAt
    local previous=sweep.signal
    local heat,guardErr=sweep:step(t,now,ack)
    if not heat then
      if sweep.state=="complete" then reason,rescuePending="Sweep returning to rescue",true
      else M.fail(guardErr) end
      return M.step(false)
    end
    local value=channel.mix.altitude<0 and 15-heat or heat
    local ok,err=writeOutputs({[sweepChannel]=value})
    if not ok then M.fail("Sweep actuator error: "..err) return M.step(false) end
    if state~="calibration" or sweep.state~="running" then return M.step(false) end
    if not sweepAppliedAt or heat~=previous then sweepAppliedAt=os.clock() end
    reason="Sweep heat "..heat.." | "..#sweep.samples.." samples"
    return
  end
  if state=="calibration" and M.test then
    if M.test.burnerTest and M.test.appliedAt then
      local confirmed,problem=vehicleBridge.burnerFeedback(cfg.control.balloonSetup,M.test.expectedBurnerSignal,M.test.appliedAt)
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
  for _,axis in ipairs(mode.axes(cfg.control)) do
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
      if axis=="heading" then error=geometry.wrap(error) end
      output[axis]=pid.step(controllers[axis],cfg.control.gains[axis],error,t[axis.."Rate"],dt)
    end
  end
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
    for _,axis in ipairs(mode.axes(cfg.control)) do value=value+(channel.mix[axis] or 0)*output[axis] end
    if autopilot:running() and targets.translation then
      local forward,right=targets.translation.forward,targets.translation.right
      value=value+(channel.mix.routeForward or 0)*math.max(0,forward)+(channel.mix.routeReverse or 0)*math.max(0,-forward)
        +(channel.mix.routeRight or 0)*math.max(0,right)+(channel.mix.routeLeft or 0)*math.max(0,-right)
    end
    values[channel.id]=math.floor(math.max(channel.min,math.min(channel.max,value))+0.5)
  end
  local ok,err=writeOutputs(values)
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

function M.status()
  local valid,errors=M.validate()
  return {state=state=="disarmed" and valid and "ready" or state,reason=reason,ownerPid=owner,ready=valid,errors=errors,targets=addon.copy(targets),
    mode=cfg.control and cfg.control.mode or "full",axes=mode.axes(cfg.control),
    autopilot=autopilot:status(),
    sweep=sweep and sweep:status(false) or nil,
    calibration={tested=addon.copy(tested),rescueTested=rescueTested,test=addon.copy(M.test),initializationConfirmed=burnerInitialization~=nil},
    outputs=addon.copy(last),outputResults=addon.copy(outputResults),rescueResults=addon.copy(rescueResults),rescuePending=rescuePending,timestamp=timestamp}
end

function M.health()
  return {ok=state~="failsafe",status=reason,lastFault=state=="failsafe" and reason or nil,timestamp=timestamp,rescuePending=rescuePending,
    pid=runner and runner.pid,lastSuccess=runner and runner.lastSuccess,outputResults=addon.copy(outputResults),rescueResults=addon.copy(rescueResults)}
end

function M.start(context)
  if runner then runner:stop() end
  ctx=context
  autopilot=Autopilot.new()
  sweep,sweepChannel,sweepAppliedAt,sweepSource,sweepReport,sweepOrigin=nil,nil,nil,nil,nil,nil
  routeForward,routeRight=0,0
  migrate()
  state,owner,rescuePending="disarmed",nil,false
  reason="not armed; calibration required"
  controllers,manual,last,tested={}, {}, {}, {}
  outputResults,rescueResults={},{}
  rescueTested=false
  burnerInitialization,burnerDemand,burnerHeatSince=nil,false,nil
  M.test=nil
  if cfg.control.sessionActive then state,reason,rescuePending="failsafe","previous session interrupted; rescue required",true end
  runner=addon.periodic(ctx,"flightd",0.1,M.step)
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
          local ok,err=addon.bounded(function() M.step(true) end,0.5)
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
