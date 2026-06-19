local config = require("system.libraries.config")
local log = require("system.libraries.log")

local M = {
  ctx = nil,
  cfgPath = "/system/config/combat.cfg",
  lastSnapshot = nil,
  lastStatus = { available = false, counts = {}, error = "not started" },
}

local DEFAULT_CFG = {
  refreshSeconds = 0.5,
  semiAuto = true,
  requireFireConfirmation = true,
  ballistics = { gravity = 9.81, muzzleVelocity = 120, drag = 0 },
  radar = { maxTargets = 64, staleSeconds = 5 },
}

local READ_METHODS = {
  "getYaw", "getPitch", "getX", "getY", "getZ", "isRunning",
  "isAssembled", "isLoaded", "isReady", "getAmmo", "getAmmunition",
  "getRange", "getHeading", "getTarget", "getTargets", "scan",
  "getDetectedTargets", "getTrackedTargets", "getEntities", "getContacts",
}

local function cfg()
  local out = config.load(M.cfgPath, {})
  for k, v in pairs(DEFAULT_CFG) do if out[k] == nil then out[k] = v end end
  out.ballistics = out.ballistics or DEFAULT_CFG.ballistics
  out.radar = out.radar or DEFAULT_CFG.radar
  return out
end

local function norm(value)
  return tostring(value or ""):lower():gsub("[^%w_]", "_")
end

local function hasAny(value, tokens)
  value = norm(value)
  for _, token in ipairs(tokens) do
    if value:find(token, 1, true) then return true end
  end
  return false
end

local function call(device, method, ...)
  if not device or type(device[method]) ~= "function" then return nil, method .. " unavailable" end
  local fn = device[method]
  local ok, value = pcall(fn, ...)
  if ok then return value, nil end
  ok, value = pcall(fn, device, ...)
  if ok then return value, nil end
  return nil, tostring(value)
end

local function requireUserPermission(permission, target)
  local ok, securityd = pcall(require, "system.services.securityd")
  if ok and securityd and securityd.authorize then
    local allowed, reason = securityd.authorize({ appId = "combatd", permissions = { permission } }, permission)
    if not allowed then
      local message = tostring(reason or ("permission denied: " .. tostring(permission)))
      if target then message = message .. " on " .. tostring(target) end
      return false, message
    end
  end
  return true
end

local function copy(value, depth)
  if type(value) ~= "table" then return value end
  depth = depth or 0
  if depth > 2 then return "table" end
  local out = {}
  local count = 0
  for k, v in pairs(value) do
    count = count + 1
    if count > 64 then out.more = true break end
    out[k] = copy(v, depth + 1)
  end
  return out
end

local function typesOf(name)
  if not peripheral or not peripheral.getType then return {} end
  local ok, a, b, c = pcall(peripheral.getType, name)
  if not ok then return {} end
  local out = {}
  for _, value in ipairs({ a, b, c }) do if value then table.insert(out, tostring(value)) end end
  return out
end

local function methodsOf(name)
  if not peripheral or not peripheral.getMethods then return {} end
  local ok, methods = pcall(peripheral.getMethods, name)
  if ok and type(methods) == "table" then table.sort(methods) return methods end
  return {}
end

local function methodSet(methods)
  local set = {}
  for _, method in ipairs(methods or {}) do set[method] = true end
  return set
end

local function classify(name, types, methods)
  local text = norm(name) .. " " .. table.concat(types or {}, " ") .. " " .. table.concat(methods or {}, " ")
  local set = methodSet(methods)
  local roles = {}
  if hasAny(text, { "radar", "target", "contact", "detector" }) or set.getTargets or set.scan or set.getDetectedTargets or set.getTrackedTargets then roles.radar = true end
  if hasAny(text, { "cbc", "cannon", "autocannon", "mount" }) or set.fire or set.assemble or set.setYaw or set.setPitch then roles.cannon = true end
  if hasAny(text, { "mount" }) or set.getYaw or set.getPitch or set.setYaw or set.setPitch then roles.mount = true end
  if hasAny(text, { "controller", "fire_control", "firecontrol" }) then roles.controller = true end
  if roles.radar or roles.cannon or roles.mount or roles.controller then return roles end
  if hasAny(text, { "radar", "cbc", "cannon", "autocannon", "munition", "shell" }) then roles.unknownCombat = true end
  return roles
end

local function idOf(prefix, index, name)
  return prefix .. tostring(index) .. ":" .. tostring(name)
end

local function numberField(value, ...)
  if type(value) ~= "table" then return nil end
  for i = 1, select("#", ...) do
    local key = select(i, ...)
    local v = value[key]
    if tonumber(v) then return tonumber(v) end
  end
  return nil
end

local function atan2(y, x)
  if math.atan2 then return math.atan2(y, x) end
  if x > 0 then return math.atan(y / x) end
  if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
  if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
  if x == 0 and y > 0 then return math.pi / 2 end
  if x == 0 and y < 0 then return -math.pi / 2 end
  return 0
end

local function normalizeTarget(raw, index)
  local t = type(raw) == "table" and raw or { label = tostring(raw) }
  local x = numberField(t, "x", "X", "posX", "targetX") or numberField(t.position, "x", 1)
  local y = numberField(t, "y", "Y", "posY", "altitude", "height", "targetY") or numberField(t.position, "y", 2)
  local z = numberField(t, "z", "Z", "posZ", "targetZ") or numberField(t.position, "z", 3)
  local distance = tonumber(t.distance or t.range or t.r or t.dist)
  local bearing = tonumber(t.bearing or t.heading or t.yaw)
  return {
    id = tostring(t.id or t.uuid or t.name or ("target-" .. tostring(index))),
    label = tostring(t.label or t.name or t.type or t.id or ("Target " .. tostring(index))),
    x = x,
    y = y,
    z = z,
    distance = distance,
    bearing = bearing,
    altitude = tonumber(t.altitude or y),
    velocity = copy(t.velocity or t.vel),
    raw = copy(t),
  }
end

local function appendTargets(out, value)
  if type(value) ~= "table" then return end
  local n = #out
  if #value > 0 then
    for _, item in ipairs(value) do table.insert(out, normalizeTarget(item, #out + 1)) end
  else
    table.insert(out, normalizeTarget(value, n + 1))
  end
end

local function readTargets(device, methods)
  local targets = {}
  local set = methodSet(methods)
  for _, method in ipairs({ "getTargets", "scan", "getDetectedTargets", "getTrackedTargets", "getEntities", "getContacts", "getTarget" }) do
    if set[method] then
      local value = call(device, method)
      appendTargets(targets, value)
      if #targets > 0 then break end
    end
  end
  return targets
end

local function readCannon(device, item, index)
  local methods = item.methods or {}
  local set = methodSet(methods)
  local yaw = set.getYaw and call(device, "getYaw") or nil
  local pitch = set.getPitch and call(device, "getPitch") or nil
  local x = set.getX and call(device, "getX") or nil
  local y = set.getY and call(device, "getY") or nil
  local z = set.getZ and call(device, "getZ") or nil
  local running = set.isRunning and call(device, "isRunning") or (set.isAssembled and call(device, "isAssembled") or nil)
  local loaded = set.isLoaded and call(device, "isLoaded") or (set.isReady and call(device, "isReady") or nil)
  local ammo = set.getAmmo and call(device, "getAmmo") or (set.getAmmunition and call(device, "getAmmunition") or nil)
  return {
    id = idOf("cannon", index, item.name),
    name = item.name,
    types = item.types,
    methods = methods,
    yaw = yaw,
    pitch = pitch,
    x = x,
    y = y,
    z = z,
    running = running,
    loaded = loaded,
    ammo = copy(ammo),
    canAim = set.setYaw or set.setPitch,
    canFire = set.fire,
    canAssemble = set.assemble,
  }
end

local function scanDevices()
  local devices = {}
  local errors = {}
  if not peripheral or not peripheral.getNames or not peripheral.wrap then
    return devices, { "peripheral API unavailable" }
  end
  local ok, names = pcall(peripheral.getNames)
  if not ok then return devices, { tostring(names) } end
  for _, name in ipairs(names or {}) do
    local types = typesOf(name)
    local methods = methodsOf(name)
    local roles = classify(name, types, methods)
    local active = roles.radar or roles.cannon or roles.mount or roles.controller or roles.unknownCombat
    if active then
      local okWrap, device = pcall(peripheral.wrap, name)
      if not okWrap then table.insert(errors, tostring(name) .. ": " .. tostring(device)) end
      table.insert(devices, {
        name = name,
        types = types,
        methods = methods,
        roles = roles,
        device = okWrap and device or nil,
        error = okWrap and nil or tostring(device),
      })
    end
  end
  return devices, errors
end

local function solveBallistics(cannon, target, combatCfg)
  combatCfg = combatCfg or cfg()
  local b = combatCfg.ballistics or {}
  local g = tonumber(b.gravity) or 9.81
  local v = tonumber(b.muzzleVelocity) or 120
  local dx = (tonumber(target.x) and tonumber(cannon.x)) and (tonumber(target.x) - tonumber(cannon.x)) or nil
  local dy = (tonumber(target.y) and tonumber(cannon.y)) and (tonumber(target.y) - tonumber(cannon.y)) or tonumber(target.altitude or 0)
  local dz = (tonumber(target.z) and tonumber(cannon.z)) and (tonumber(target.z) - tonumber(cannon.z)) or nil
  local horizontal = target.distance or (dx and dz and math.sqrt(dx * dx + dz * dz)) or 0
  local yaw = target.bearing
  if dx and dz then yaw = math.deg(atan2(-dx, dz)) end
  local pitch = nil
  if horizontal > 0 and v > 0 then
    local v2 = v * v
    local disc = v2 * v2 - g * (g * horizontal * horizontal + 2 * dy * v2)
    if disc >= 0 then
      pitch = math.deg(math.atan((v2 - math.sqrt(disc)) / (g * horizontal)))
    else
      pitch = math.deg(atan2(dy, horizontal))
    end
  end
  return { yaw = yaw or cannon.yaw or 0, pitch = pitch or cannon.pitch or 0, distance = horizontal, deltaY = dy, estimated = true }
end

function M.snapshot()
  local devices, errors = scanDevices()
  local radars, targets, cannons, mounts, controllers, unknown = {}, {}, {}, {}, {}, {}
  for _, item in ipairs(devices) do
    if item.roles.radar then
      table.insert(radars, { name = item.name, types = item.types, methods = item.methods })
      if item.device then
        for _, target in ipairs(readTargets(item.device, item.methods)) do table.insert(targets, target) end
      end
    end
    if item.roles.cannon then table.insert(cannons, readCannon(item.device, item, #cannons + 1)) end
    if item.roles.mount then table.insert(mounts, { name = item.name, types = item.types, methods = item.methods }) end
    if item.roles.controller then table.insert(controllers, { name = item.name, types = item.types, methods = item.methods }) end
    if item.roles.unknownCombat then table.insert(unknown, { name = item.name, types = item.types, methods = item.methods }) end
  end
  local c = cfg()
  while #targets > (tonumber(c.radar and c.radar.maxTargets) or 64) do table.remove(targets) end
  local snap = {
    ok = true,
    status = (#devices > 0) and "combat peripherals ready" or "no combat peripheral detected",
    devices = devices,
    radars = radars,
    targets = targets,
    cannons = cannons,
    mounts = mounts,
    controllers = controllers,
    unknownCombatDevices = unknown,
    errors = errors,
    counts = {
      radars = #radars,
      targets = #targets,
      cannons = #cannons,
      mounts = #mounts,
      controllers = #controllers,
      unknown = #unknown,
    },
  }
  snap.available = #devices > 0
  M.lastSnapshot = snap
  M.lastStatus = { available = snap.available, status = snap.status, counts = snap.counts, errors = errors }
  return snap
end

function M.status()
  M.snapshot()
  return M.lastStatus
end

function M.probe(name)
  local devices = scanDevices()
  local selected = nil
  for _, item in ipairs(devices) do
    if not name or item.name == name then selected = item break end
  end
  if not selected then return { ok = false, error = "peripheral not found", name = name } end
  local reads = {}
  if selected.device then
    local set = methodSet(selected.methods)
    for _, method in ipairs(READ_METHODS) do
      if set[method] then
        local value, err = call(selected.device, method)
        reads[method] = err and { error = err } or copy(value)
      end
    end
  end
  return { ok = true, name = selected.name, types = selected.types, roles = selected.roles, methods = selected.methods, reads = reads }
end

function M.exportProbe(path)
  local allowed, denied = requireUserPermission("peripheral.probe", path or "probe")
  if not allowed then return false, denied end
  path = path or "/var/logs/peripheral_probe.log"
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local snap = M.snapshot()
  local h = fs.open(path, "w")
  if not h then return false, "cannot write " .. path end
  h.write(textutils.serialize(snap))
  h.close()
  log.info("combatd", "probe exported to " .. path)
  return true, path
end

local function findCannon(snapshot, cannonId)
  for _, cannon in ipairs(snapshot.cannons or {}) do
    if cannon.id == cannonId or cannon.name == cannonId then return cannon end
  end
  return nil
end

local function wrapByName(name)
  if not peripheral or not peripheral.wrap then return nil, "peripheral API unavailable" end
  local ok, wrapped = pcall(peripheral.wrap, name)
  if ok and wrapped then return wrapped end
  return nil, tostring(wrapped)
end

function M.solution(cannonId, target)
  local snap = M.snapshot()
  local cannon = findCannon(snap, cannonId) or (snap.cannons or {})[1]
  if not cannon then return nil, "no cannon" end
  if type(target) ~= "table" then target = (snap.targets or {})[tonumber(target) or 1] end
  if not target then return nil, "no target" end
  return solveBallistics(cannon, target, cfg()), nil
end

function M.aim(cannonId, solution)
  local allowed, denied = requireUserPermission("combat.aim", cannonId)
  if not allowed then return false, denied end
  local snap = M.snapshot()
  local cannon = findCannon(snap, cannonId)
  if not cannon then return false, "no cannon selected" end
  local dev, err = wrapByName(cannon.name)
  if not dev then return false, err end
  solution = solution or { yaw = cannon.yaw, pitch = cannon.pitch }
  local okYaw, errYaw = true, nil
  local okPitch, errPitch = true, nil
  if type(dev.setYaw) == "function" and solution.yaw ~= nil then _, errYaw = call(dev, "setYaw", tonumber(solution.yaw)); okYaw = errYaw == nil end
  if type(dev.setPitch) == "function" and solution.pitch ~= nil then _, errPitch = call(dev, "setPitch", tonumber(solution.pitch)); okPitch = errPitch == nil end
  if okYaw and okPitch then
    log.info("combatd", "aim " .. tostring(cannon.name) .. " yaw=" .. tostring(solution.yaw) .. " pitch=" .. tostring(solution.pitch))
    return true, "aim sent"
  end
  return false, tostring(errYaw or errPitch or "aim unavailable")
end

function M.fire(cannonId)
  local allowed, denied = requireUserPermission("combat.fire", cannonId)
  if not allowed then return false, denied end
  local snap = M.snapshot()
  local cannon = findCannon(snap, cannonId)
  if not cannon then return false, "no cannon selected" end
  local dev, err = wrapByName(cannon.name)
  if not dev then return false, err end
  if type(dev.fire) ~= "function" then return false, "fire unavailable" end
  local _, fireErr = call(dev, "fire")
  if fireErr then return false, fireErr end
  log.warn("combatd", "fire " .. tostring(cannon.name))
  return true, "fire sent"
end

function M.start(ctx)
  M.ctx = ctx
  local st = M.status()
  log.info("combatd", st.status)
end

function M.stop()
  M.ctx = nil
end

return M
