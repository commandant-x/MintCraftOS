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
  return rawget(_G, name)
end

local function call(target, method, ...)
  if not target or type(target[method]) ~= "function" then
    return nil, method .. " unavailable"
  end
  local ok, value = pcall(target[method], ...)
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
  local out = {}
  out.inSublevel = call(sub, "isInPlotGrid") == true
  if not out.inSublevel then return out end
  out.uuid = call(sub, "getUniqueId")
  out.name = call(sub, "getName")
  out.logicalPose = vec(call(sub, "getLogicalPose"))
  out.lastPose = vec(call(sub, "getLastPose"))
  out.velocity = vec(call(sub, "getVelocity"))
  out.linearVelocity = vec(call(sub, "getLinearVelocity"))
  out.angularVelocity = vec(call(sub, "getAngularVelocity"))
  out.centerOfMass = vec(call(sub, "getCenterOfMass"))
  out.mass = call(sub, "getMass")
  out.inverseMass = call(sub, "getInverseMass")
  out.inertiaTensor = vec(call(sub, "getInertiaTensor"))
  out.inverseInertiaTensor = vec(call(sub, "getInverseInertiaTensor"))
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
  local sub, aero, names = detect()
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
    subData = readSublevel(sub)
    result.sublevel = subData
  end
  result.aero = readAero(aero, subData)

  local inSublevel = subData and subData.inSublevel == true
  result.ok = true
  result.status = inSublevel and "sublevel telemetry ready" or "not on sublevel"
  M.lastStatus = { available = true, inSublevel = inSublevel, error = nil, apiNames = names }
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
