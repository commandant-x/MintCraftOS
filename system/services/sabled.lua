local log = require("system.libraries.log")

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
  ok, value = pcall(fn, target, ...)
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
  local yard, yardErr = call(sub, "isInPlotYard")
  out.plotGrid = grid
  out.plotYard = yard
  if gridErr then out.errors.isInPlotGrid = gridErr end
  if yardErr then out.errors.isInPlotYard = yardErr end

  local function get(field, method, transform)
    local value, err = call(sub, method)
    if err then out.errors[method] = err else out[field] = transform and transform(value) or value end
  end

  get("uuid", "getUniqueId")
  get("name", "getName")
  get("logicalPose", "getLogicalPose", vec)
  get("lastPose", "getLastPose", vec)
  get("velocity", "getVelocity", vec)
  get("linearVelocity", "getLinearVelocity", vec)
  get("angularVelocity", "getAngularVelocity", vec)
  get("centerOfMass", "getCenterOfMass", vec)
  get("mass", "getMass")
  get("inverseMass", "getInverseMass")
  get("inertiaTensor", "getInertiaTensor", vec)
  get("inverseInertiaTensor", "getInverseInertiaTensor", vec)

  out.inSublevel = grid == true or yard == true or out.logicalPose ~= nil or out.uuid ~= nil or out.name ~= nil
  return out
end

local function readAero(aero, subData)
  if not aero then return nil end
  local out = {}
  out.gravity = vec(call(aero, "getGravity"))
  out.magneticNorth = vec(call(aero, "getMagneticNorth"))
  out.universalDrag = call(aero, "getUniversalDrag")
  out.raw = vec(call(aero, "getRaw"))
  out.default = vec(call(aero, "getDefault"))
  local position = subData and subData.logicalPose and (subData.logicalPose.position or subData.logicalPose.pos)
  if position then out.airPressure = call(aero, "getAirPressure", position) end
  return out
end

function M.status()
  M.snapshot()
  return M.lastStatus
end

function M.snapshot()
  local okDetect, sub, aero, names = pcall(detect)
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
  local okAero, aeroData = pcall(readAero, aero, subData)
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
  M.ctx = ctx
  local snap = M.snapshot()
  log.info("sabled", snap.status or tostring(snap.error))
end

function M.stop()
  M.ctx = nil
end

return M
