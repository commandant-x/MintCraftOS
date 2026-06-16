local log = require("system.libraries.log")

local M = {
  ctx = nil,
  lastStatus = { available = false, counts = {}, error = "not started" },
  lastSnapshot = nil,
}

local TYPES = {
  altitude = { "altitude_sensor", "altitudesensor" },
  gimbal = { "gimbal_sensor", "gimbalsensor" },
  nav = { "navigation_table", "navigationtable" },
  propeller = { "propeller", "propeller_bearing", "propellerbearing" },
  throttle = { "throttle_lever", "throttlelever" },
  analog = { "analog_transmission", "analogtransmission" },
}

local function norm(value)
  return tostring(value or ""):lower():gsub("[^%w_]", "_")
end

local function hasToken(value, tokens)
  value = norm(value)
  for _, token in ipairs(tokens) do
    if value == token or value:find(token, 1, true) then return true end
  end
  return false
end

local function call(target, method, ...)
  if not target or type(target[method]) ~= "function" then return nil, method .. " unavailable" end
  local fn = target[method]
  local ok, value = pcall(fn, ...)
  if ok then return value, nil end
  ok, value = pcall(fn, target, ...)
  if ok then return value, nil end
  return nil, tostring(value)
end

local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[k] = v end
  return out
end

local function getTypes(name)
  if not peripheral or not peripheral.getType then return {} end
  local ok, a, b, c = pcall(peripheral.getType, name)
  if not ok then return {} end
  local out = {}
  for _, item in ipairs({ a, b, c }) do
    if item then table.insert(out, tostring(item)) end
  end
  return out
end

local function classify(types)
  local roles = {}
  for _, t in ipairs(types or {}) do
    for role, tokens in pairs(TYPES) do
      if hasToken(t, tokens) then roles[role] = true end
    end
  end
  return roles
end

local function scan()
  local devices = {}
  local counts = {
    altitude = 0,
    gimbal = 0,
    nav = 0,
    propeller = 0,
    throttle = 0,
    analog = 0,
    other = 0,
  }
  if not peripheral or not peripheral.getNames or not peripheral.wrap then
    return devices, counts, "peripheral API unavailable"
  end

  local okNames, names = pcall(peripheral.getNames)
  if not okNames then return devices, counts, tostring(names) end

  for _, name in ipairs(names or {}) do
    local types = getTypes(name)
    local roles = classify(types)
    local matched = false
    for role in pairs(counts) do
      if role ~= "other" and roles[role] then
        counts[role] = counts[role] + 1
        matched = true
      end
    end
    if matched then
      local okWrap, wrapped = pcall(peripheral.wrap, name)
      table.insert(devices, {
        name = name,
        types = types,
        roles = roles,
        device = okWrap and wrapped or nil,
        error = okWrap and nil or tostring(wrapped),
      })
    elseif #types > 0 then
      for _, t in ipairs(types) do
        if norm(t):find("avion", 1, true) or norm(t):find("create", 1, true) then
          counts.other = counts.other + 1
          table.insert(devices, { name = name, types = types, roles = { other = true } })
          break
        end
      end
    end
  end
  return devices, counts, nil
end

local function readAltitude(device)
  local out = {}
  out.height = call(device, "getHeight")
  out.airPressure = call(device, "getAirPressure")
  out.verticalSpeed = call(device, "getVerticalSpeed")
  return out
end

local function readGimbal(device)
  local out = {}
  out.angles = copy(call(device, "getAngles"))
  out.angularRates = copy(call(device, "getAngularRates"))
  out.gravity = copy(call(device, "getGravity"))
  out.linearAcceleration = copy(call(device, "getLinearAcceleration"))
  return out
end

local function readNavigationTable(device)
  local out = {}
  out.heading = call(device, "getHeading")
  out.targetBearing = call(device, "getTargetBearing")
  out.targetDistance = call(device, "getTargetDistance")
  out.targetHeight = call(device, "getTargetHeight")
  out.target = copy(call(device, "getTarget"))
  return out
end

local function readPropeller(device)
  local out = {}
  out.axis = copy(call(device, "getAxis"))
  out.rotationSpeed = call(device, "getRotationSpeed")
  out.thrust = call(device, "getThrust")
  out.airflow = call(device, "getAirflow")
  out.active = call(device, "isActive")
  out.speed = call(device, "getSpeed")
  return out
end

local function readControl(device)
  local out = {}
  out.state = call(device, "getState")
  out.signal = call(device, "getSignal")
  return out
end

local function firstRead(devices, role, reader)
  local rows = {}
  for _, item in ipairs(devices) do
    if item.roles and item.roles[role] and item.device then
      local ok, data = pcall(reader, item.device)
      table.insert(rows, {
        name = item.name,
        types = item.types,
        ok = ok,
        data = ok and data or nil,
        error = ok and nil or tostring(data),
      })
    end
  end
  return rows
end

function M.snapshot()
  local devices, counts, err = scan()
  local available = false
  for role, count in pairs(counts) do
    if role ~= "other" and count > 0 then available = true end
  end

  local snap = {
    ok = err == nil,
    available = available,
    status = available and "Create Avionics peripherals ready" or "Create Avionics peripherals missing",
    counts = counts,
    devices = devices,
    altitude = firstRead(devices, "altitude", readAltitude),
    gimbal = firstRead(devices, "gimbal", readGimbal),
    nav = firstRead(devices, "nav", readNavigationTable),
    propeller = firstRead(devices, "propeller", readPropeller),
    throttle = firstRead(devices, "throttle", readControl),
    analog = firstRead(devices, "analog", readControl),
    error = err,
  }
  M.lastSnapshot = snap
  M.lastStatus = {
    available = available,
    counts = counts,
    error = err,
    status = snap.status,
  }
  return snap
end

function M.status()
  M.snapshot()
  return M.lastStatus
end

function M.list()
  return (M.snapshot().devices or {})
end

function M.start(ctx)
  M.ctx = ctx
  local snap = M.snapshot()
  log.info("avionicsd", snap.status)
end

function M.stop()
  M.ctx = nil
end

return M
