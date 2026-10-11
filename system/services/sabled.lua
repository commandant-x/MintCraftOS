local log = require("system.libraries.log")
local addon = require("system.libraries.addon")
local runner, revision, detected, slowAt, slowData = nil, 0, nil, -math.huge, nil
local diagnostics, diagnosticsAt = {}, -math.huge

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

local function readSublevel(sub)
  local out = { errors = {} }
  local grid, gridErr = call(sub, "isInPlotGrid")
  out.plotGrid = grid
  if gridErr then out.errors.isInPlotGrid = gridErr end
  if grid ~= true then out.inSublevel = false return out end

  local fast={logicalPose="getLogicalPose",lastPose="getLastPose",velocity="getVelocity",linearVelocity="getLinearVelocity",angularVelocity="getAngularVelocity"}
  local slow={uuid="getUniqueId",name="getName",centerOfMass="getCenterOfMass",mass="getMass",inverseMass="getInverseMass",inertiaTensor="getInertiaTensor",inverseInertiaTensor="getInverseInertiaTensor"}
  local methods={}
  for _,method in pairs(fast) do methods[#methods+1]=method end
  local values,errors=addon.read(sub,methods)
  for field,method in pairs(fast) do out[field]=addon.copy(values[method]) end
  for method,err in pairs(errors) do out.errors[method]=err end
  if os.clock()-diagnosticsAt>=1 then
    methods={}
    for _,method in pairs(slow) do methods[#methods+1]=method end
    local data,problems=addon.read(sub,methods)
    diagnostics={}
    for field,method in pairs(slow) do diagnostics[field]=addon.copy(data[method]) end
    for method,err in pairs(problems) do out.errors[method]=err end
    diagnosticsAt=os.clock()
  end
  for field,value in pairs(diagnostics) do out[field]=addon.copy(value) end

  out.inSublevel = grid == true
  return out
end

local function readAero(aero, subData)
  if not aero then return nil end
  local values=addon.read(aero,{"getGravity","getMagneticNorth","getUniversalDrag","getRaw","getDefault"})
  local out = {}
  out.gravity = addon.vec(values.getGravity)
  out.magneticNorth = addon.vec(values.getMagneticNorth)
  out.universalDrag = values.getUniversalDrag
  out.raw = addon.copy(values.getRaw)
  out.default = addon.copy(values.getDefault)
  local position = subData and subData.logicalPose and (subData.logicalPose.position or subData.logicalPose.pos)
  if position then out.airPressure = call(aero, "getAirPressure", position) end
  return out
end

function M.status()
  return addon.copy(M.lastStatus)
end

function M.acquire(rescan)
  if rescan or not detected then detected = table.pack(pcall(detect)) diagnosticsAt=-math.huge end
  local okDetect, sub, aero, names = table.unpack(detected, 1, detected.n)
  if not okDetect then
    M.lastStatus = { available = false, inSublevel = false, error = tostring(sub), apiNames = {} }
    M.lastSnapshot = { ok = false, status = "CC:Sable detection failed", error = tostring(sub) }
    return M.lastSnapshot
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
    M.lastSnapshot = result
    return result
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
  local okAero, aeroData = true, slowData
  if rescan or os.clock()-slowAt>=1 then
    okAero, aeroData = pcall(readAero, aero, subData)
    if okAero then slowAt, slowData = os.clock(), aeroData end
  end
  if okAero then
    result.aero = aeroData
  else
    log.warn("sabled", "aero read failed: " .. tostring(aeroData))
  end

  local inSublevel = subData and subData.inSublevel == true
  result.ok = true
  result.status = inSublevel and "sublevel telemetry ready" or (sub and "sublevel API ready, no pose" or "not on sublevel")
  M.lastStatus = { available = true, inSublevel = inSublevel, error = result.error, apiNames = names or {} }
  M.lastSnapshot = result
  revision = revision + 1
  result.revision, result.timestamp, result.frame = revision, os.clock(), "world"
  result.measurements = {}
  for key, unit in pairs({ mass = "kg", linearVelocity = "m/s", angularVelocity = "rad/s", centerOfMass = "m" }) do
    result.measurements[key] = addon.measure(subData and subData[key], unit, key == "centerOfMass" and "body" or "world", "CC:Sable", result.timestamp)
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
  if runner then runner:stop() end
  M.ctx = ctx
  runner = addon.periodic(ctx, "sabled", 0.1, M.acquire)
  runner.onError = function(err)
    if M.lastStatus.error~=err then pcall(log.warn,"sabled",err) end
    M.lastStatus.error = err
  end
  if runner.error then runner.onError(runner.error) end
end

function M.stop()
  if runner then runner:stop() runner = nil end
  M.ctx = nil
end

function M.snapshot()
  return addon.copy(M.lastSnapshot or { ok = false, status = "waiting for Sable", revision = 0, timestamp = 0 })
end

function M.rescan() if runner then runner:rescan() end end

function M.probe()
  return { apiNames = addon.copy(M.lastStatus.apiNames), snapshot = M.snapshot() }
end

return M
