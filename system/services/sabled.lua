local log = require("system.libraries.log")
local addon = require("system.libraries.addon")
local runner, revision, detected, slowAt, slowData = nil, 0, nil, -math.huge, nil
local diagnostics, diagnosticsAt, diagnosticsErrors = {}, -math.huge, {}
local diagnosticsReceivedAt
local diagnosticsTimings={}
local diagnosticRunner,generation=nil,0
local slowFields={name="getName",centerOfMass="getCenterOfMass",mass="getMass",inverseMass="getInverseMass",inertiaTensor="getInertiaTensor",inverseInertiaTensor="getInverseInertiaTensor"}

local M = {
  ctx = nil,
  lastStatus = {
    available = false,
    inSublevel = false,
    error = "not started",
    apiNames = {},
  },
  lastSnapshot = nil,
  warnedLost = false,
}

local function api(name)
  local value = rawget(_G, name)
  if value ~= nil then return value end
  local ok, mod = pcall(require, name)
  if ok then return mod end
  return nil
end

local function call(target, method, ...)
  if not target or type(target[method]) ~= "function" then
    return nil, method .. " unavailable"
  end
  local fn = target[method]
  local ok, value = pcall(fn, ...)
  if ok then return value, nil end
  return nil, tostring(value)
end

local function vec(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[k] = v end
  return out
end

local function detect()
  local sub = api("sublevel")
  local aero = api("aero") or api("aerodynamics")
  local names = {}
  if sub then table.insert(names, "sublevel") end
  if api("aero") then table.insert(names, "aero") end
  if api("aerodynamics") then table.insert(names, "aerodynamics") end
  return sub, aero, names
end

local readAero
local function readSublevel(sub)
  local out = { errors = {}, observedAt=os.clock(),timings={} }
  local gridValues,gridErrors,gridTimings=addon.read(sub,{"isInPlotGrid"},0.15,{priority="flight"})
  local grid,gridErr=gridValues.isInPlotGrid,gridErrors.isInPlotGrid
  if type(sub.isInPlotGrid)~="function" then gridErr="isInPlotGrid unavailable" end
  local gridTiming=gridTimings and gridTimings.isInPlotGrid or {}
  out.observedAt=gridTiming.startedAt or out.observedAt
  out.receivedAt=gridTiming.receivedAt or os.clock()
  out.plotGrid = grid
  if gridErr then out.errors.isInPlotGrid = gridErr end
  if grid ~= true then out.inSublevel = false return out end

  local fast={uuid="getUniqueId",logicalPose="getLogicalPose",lastPose="getLastPose",velocity="getVelocity",linearVelocity="getLinearVelocity",angularVelocity="getAngularVelocity"}
  local methods={}
  for _,method in pairs(fast) do methods[#methods+1]=method end
  local started=os.clock()
  local values,errors,timings=addon.read(sub,methods,0.15,{priority="flight"})
  for field,method in pairs(fast) do
    out[field]=addon.copy(values[method])
    out.timings[field]=addon.copy(timings and timings[method] or {startedAt=started,receivedAt=os.clock()})
  end
  for method,err in pairs(errors) do out.errors[method]=err end
  for method,err in pairs(diagnosticsErrors) do out.errors[method]=err end
  for field,value in pairs(diagnostics) do out[field]=addon.copy(value) end
  for field,value in pairs(diagnosticsTimings) do out.timings[field]=addon.copy(value) end
  out.diagnosticsAt=diagnosticsAt
  out.diagnosticsReceivedAt=diagnosticsReceivedAt

  out.inSublevel = grid == true
  return out
end

function M.acquireDiagnostics()
  if not detected or not detected[1] then return end
  local token=generation
  local sub,aero=detected[2],detected[3]
  local poseData=addon.copy(M.lastSnapshot and M.lastSnapshot.sublevel)
  if sub and poseData and poseData.inSublevel and os.clock()-diagnosticsAt>=1 then
    local methods={}
    for _,method in pairs(slowFields) do methods[#methods+1]=method end
    local started=os.clock()
    local data,problems,timing=addon.read(sub,methods,0.15,{priority="diagnostics"})
    if token~=generation then return end
    local nextData,nextTimings={},{}
    for field,method in pairs(slowFields) do
      nextData[field]=addon.copy(data[method])
      nextTimings[field]=addon.copy(timing and timing[method] or {startedAt=started,receivedAt=os.clock()})
    end
    diagnostics,diagnosticsTimings,diagnosticsErrors=nextData,nextTimings,problems
    diagnosticsAt,diagnosticsReceivedAt=started,os.clock()
  end
  if os.clock()-slowAt>=1 then
    local data=readAero(aero,poseData)
    if token==generation then slowAt,slowData=os.clock(),data end
  end
end

readAero=function(aero, subData)
  if not aero then return nil end
  local started=os.clock()
  local values,errors,timings=addon.read(aero,{"getGravity","getMagneticNorth","getUniversalDrag","getRaw","getDefault"},0.15,{priority="diagnostics"})
  local out = {errors=errors,observedAt=started,timings=timings or {}}
  out.gravity = addon.vec(values.getGravity)
  out.magneticNorth = addon.vec(values.getMagneticNorth)
  out.universalDrag = values.getUniversalDrag
  out.raw = addon.copy(values.getRaw)
  out.default = addon.copy(values.getDefault)
  local position = subData and subData.logicalPose and (subData.logicalPose.position or subData.logicalPose.pos)
  if position then
    position=addon.vec(position)
    local pressureStarted=os.clock()
    local data,problems,timing=addon.read({getAirPressure=function()
      if not position then error("invalid pressure position") end
      local value,err=call(aero,"getAirPressure",position.x,position.y,position.z)
      if err then error(err) end
      return value
    end},{"getAirPressure"},0.15,{priority="diagnostics"})
    out.airPressure=data.getAirPressure
    out.errors.getAirPressure=problems.getAirPressure
    out.timings.getAirPressure=timing and timing.getAirPressure or {startedAt=pressureStarted,receivedAt=os.clock()}
  end
  out.receivedAt=os.clock()
  return out
end

function M.status()
  return addon.copy(M.lastStatus)
end

function M.health()
  local health=M.status()
  health.pid,health.lastSuccess=runner and runner.pid,runner and runner.lastSuccess
  return health
end

local function publish(result)
  revision=revision+1
  result.revision,result.timestamp,result.frame=revision,os.clock(),"world"
  M.lastSnapshot=result
  M.lastStatus.ok,M.lastStatus.status=result.ok,result.status
  M.lastStatus.revision,M.lastStatus.timestamp=revision,result.timestamp
  M.lastStatus.lastFault=result.error
  M.lastStatus.errors=addon.copy(result.errors or {})
  return result
end

function M.acquire(rescan)
  if rescan or not detected then
    detected = table.pack(pcall(detect)) generation=generation+1
    diagnostics,diagnosticsErrors,diagnosticsTimings={},{},{}
    diagnosticsAt,slowAt,slowData=-math.huge,-math.huge,nil
  end
  local okDetect, sub, aero, names = table.unpack(detected, 1, detected.n)
  if not okDetect then
    M.lastStatus = { available = false, inSublevel = false, error = tostring(sub), apiNames = {} }
    return publish({ ok = false, status = "CC:Sable detection failed", error = tostring(sub) })
  end
  local available = sub ~= nil or aero ~= nil
  local result = {
    ok = false,
    status = "missing CC:Sable APIs",
    sublevel = nil,
    aero = nil,
    error = nil,
  }

  if not available then
    M.lastStatus = { available = false, inSublevel = false, error = "CC:Sable APIs not found", apiNames = names }
    result.error = M.lastStatus.error
    return publish(result)
  end

  local subData = nil
  if sub then
    local okSub, data = pcall(readSublevel, sub)
    if okSub then
      subData = data
      result.sublevel = subData
    else
      result.error = tostring(data)
      log.warn("sabled", "sublevel read failed: " .. tostring(data))
    end
  end
  result.aero=slowData

  local inSublevel = subData and subData.inSublevel == true
  result.errors={}
  for source,data in pairs({sublevel=subData or {},aero=result.aero or {}}) do
    for method,err in pairs(data.errors or {}) do result.errors[#result.errors+1]=source..":"..method..": "..err end
  end
  if result.error then result.errors[#result.errors+1]=result.error end
  result.error=result.errors[1]
  result.ok = #result.errors==0
  result.status = inSublevel and "sublevel telemetry ready" or (sub and "sublevel API ready, no pose" or "not on sublevel")
  if not result.ok then result.status="Sable telemetry degraded" end
  M.lastStatus = { available = true, inSublevel = inSublevel, error = result.error, apiNames = names or {} }
  publish(result)
  result.measurements = {}
  for key, unit in pairs({ mass = "kg", linearVelocity = "m/s", angularVelocity = "rad/s", centerOfMass = "m" }) do
    local stamp=subData and ((key=="mass" or key=="centerOfMass") and subData.diagnosticsAt or subData.observedAt)
    local timing=subData and subData.timings and subData.timings[key] or {}
    stamp=timing.startedAt or stamp
    local value=subData and subData[key]
    local valid=key=="mass" and addon.finite(value) or key~="mass" and addon.vec(value)~=nil
    local m=addon.measure(valid and value or nil, unit, key == "centerOfMass" and "unknown" or "world", "CC:Sable", stamp or 0)
    local received=timing.receivedAt or (subData and ((key=="mass" or key=="centerOfMass") and subData.diagnosticsReceivedAt or subData.receivedAt))
    m.observedAt,m.receivedAt,m.validUntil=stamp,received,stamp and stamp+((key=="mass" or key=="centerOfMass") and 1 or 0.5)
    m.valid=m.valid and os.clock()<=m.validUntil
    result.measurements[key]=m
  end
  for key,unit in pairs({gravity="m/s2",magneticNorth="direction",airPressure="fraction"}) do
    local data=result.aero or {}
    local value=data[key]
    local valid=key=="airPressure" and addon.finite(value) or key~="airPressure" and addon.vec(value)~=nil
    local method=({gravity="getGravity",magneticNorth="getMagneticNorth",airPressure="getAirPressure"})[key]
    local timing=data.timings and data.timings[method] or {}
    local observed=timing.startedAt or data.observedAt
    local m=addon.measure(valid and value or nil,unit,"world","CC:Sable",observed or 0)
    m.observedAt,m.receivedAt,m.validUntil=observed,timing.receivedAt or data.receivedAt,(observed or 0)+1
    m.valid=m.valid and os.clock()<=m.validUntil
    result.measurements[key]=m
  end

  if M.ctx and M.ctx.notifications then
    if M.warnedLost == false and M.lastStatus.available and not inSublevel then
      M.warnedLost = true
      M.ctx.notifications:push("warn", "Navigation", "No Sable sublevel detected", 3)
    elseif inSublevel then
      M.warnedLost = false
    end
  end
  return result
end

function M.start(ctx)
  M.stop()
  M.ctx = ctx
  detected,slowData,slowAt,diagnostics,diagnosticsAt,diagnosticsErrors=nil,nil,-math.huge,{},-math.huge,{}
  runner = addon.periodic(ctx, "sabled", 0.1, M.acquire)
  runner.onError = function(err)
    if M.lastStatus.error~=err then pcall(log.warn,"sabled",err) end
    M.lastStatus.error = err
    M.lastStatus.inSublevel=false
    local result=M.snapshot()
    result.ok,result.error,result.status,result.errors=false,err,"Sable acquisition failed",{err}
    publish(result)
  end
  if runner.error then runner.onError(runner.error) end
  diagnosticRunner=addon.periodic(ctx,"sabled-diagnostics",1,M.acquireDiagnostics)
end

function M.stop()
  if runner then runner:stop() runner = nil end
  if diagnosticRunner then diagnosticRunner:stop() diagnosticRunner=nil end
  generation=generation+1
  M.ctx = nil
end

function M.snapshot()
  return addon.copy(M.lastSnapshot or { ok = false, status = "waiting for Sable", revision = 0, timestamp = 0 })
end
function M.flightStatus()
  local sub=M.lastSnapshot and M.lastSnapshot.sublevel or {}
  return {inSublevel=M.lastStatus.inSublevel==true,timestamp=sub.observedAt or 0,
    observedAt=sub.observedAt,receivedAt=sub.receivedAt,validUntil=sub.observedAt and sub.observedAt+0.5,
    ok=M.lastStatus.ok,available=M.lastStatus.available,revision=revision}
end
function M.pose()
  local snap=M.lastSnapshot or {}
  local timing=snap.sublevel and snap.sublevel.timings and snap.sublevel.timings.logicalPose or {}
  local physical=snap.sublevel or {}
  local identity=physical.timings and physical.timings.uuid or {}
  return {logicalPose=addon.copy(snap.sublevel and snap.sublevel.logicalPose),timestamp=timing.startedAt or (snap.sublevel and snap.sublevel.observedAt) or 0,
    frame="world",inSublevel=M.lastStatus.inSublevel==true,revision=revision,
    vehicleId=type(physical.uuid)=="string" and physical.uuid or nil,identityAt=identity.startedAt}
end

function M.rescan() if runner then runner:rescan() end end

function M.probe()
  return { apiNames = addon.copy(M.lastStatus.apiNames), snapshot = M.snapshot() }
end

return M
