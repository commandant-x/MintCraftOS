local renderer = require("system.gui.renderer")
local ui = require("system.gui.components")
local config = require("system.libraries.config")
local log = require("system.libraries.log")
local keyboard = require("system.gui.keyboard")
local sabled = require("system.services.sabled")
local avionicsd = require("system.services.avionicsd")

local M = {}

local CFG = "/system/config/navigation.cfg"
local SIDES = { "left", "right", "front", "back", "top", "bottom" }

local function aircraftDefaults()
  return {
    name = "Quad Heavy",
    massKg = 126093,
    declaredWeightNewton = 1400000,
    gravityMultiplier = 11,
    seaLevelY = 60,
    altitudeLevels = {
      { level = 0, y = 289 },
      { level = 1, y = 282 },
      { level = 2, y = 278 },
      { level = 3, y = 270 },
      { level = 4, y = 248 },
      { level = 5, y = 224 },
      { level = 6, y = 198 },
      { level = 7, y = 178 },
      { level = 8, y = 134 },
      { level = 9, y = 96 },
      { level = 10, y = 60 },
    },
    rearThrustVacuum = {
      [15] = 0,
      [14] = 38896,
      [13] = 77792,
      [12] = 116688,
      [11] = 155584,
      [10] = 194480,
      [9] = 233376,
      [8] = 272272,
      [7] = 311168,
      [6] = 350065,
      [5] = 388961,
      [4] = 427857,
      [3] = 466753,
      [2] = 505650,
      [1] = 544545,
      [0] = 622637,
    },
    densityCalibration = {
      level = 6,
      density = 0.6906,
      vacuumForce = 622637,
      measuredForce = 1822183,
    },
    commands = {
      { id = "forward", name = "Forward", frequency = "2x green concrete powder", role = "rear thrust forward" },
      { id = "reverse", name = "Reverse", frequency = "2x red concrete powder", role = "rear thrust reverse" },
      { id = "yawRight", name = "Yaw Right", frequency = "2x yellow concrete powder", role = "2 push / 2 pull right yaw" },
      { id = "yawLeft", name = "Yaw Left", frequency = "2x blue concrete powder", role = "2 push / 2 pull left yaw" },
      { id = "strafeRight", name = "Strafe Right", frequency = "2x pink concrete powder", role = "weak lateral right" },
      { id = "strafeLeft", name = "Strafe Left", frequency = "2x magenta concrete powder", role = "weak lateral left" },
      { id = "correctionUp", name = "Correction Up", frequency = "2x white concrete powder", role = "vertical trim up" },
      { id = "correctionDown", name = "Correction Down", frequency = "2x black concrete powder", role = "vertical trim down" },
      { id = "rollRight", name = "Roll Right", frequency = "2x orange concrete powder", role = "roll correction right" },
      { id = "rollLeft", name = "Roll Left", frequency = "2x light blue concrete powder", role = "roll correction left" },
      { id = "diagPrimary", name = "Diag Primary", frequency = "2x lime concrete powder", role = "loss motor 1/3, keep 2/4 stable" },
      { id = "diagSecondary", name = "Diag Secondary", frequency = "2x purple concrete powder", role = "loss motor 2/4, keep 1/3 stable" },
    },
    modes = {
      { name = "Turn left spot", detail = "blue only: yaw around center; add roll/diagonal correction if rear thrust tilts" },
      { name = "Turn right spot", detail = "yellow only: yaw around center; add roll/diagonal correction if rear thrust tilts" },
      { name = "Advance + left", detail = "green + blue, advanced: keep outside rear motors, cut motors in turn direction" },
      { name = "Advance + right", detail = "green + yellow, advanced: keep outside rear motors, cut motors in turn direction" },
      { name = "Reverse + left", detail = "red + blue, advanced reverse yaw trim" },
      { name = "Reverse + right", detail = "red + yellow, advanced reverse yaw trim" },
    },
  }
end

local function defaults()
  return {
    refreshSeconds = 1,
    aircraft = aircraftDefaults(),
    redstoneProfiles = {
      { name = "Brake", side = "back", pulseSeconds = 0.5, description = "short braking pulse" },
      { name = "Lift", side = "top", pulseSeconds = 0.5, description = "short lift pulse" },
      { name = "Yaw Left", side = "left", pulseSeconds = 0.25, description = "short yaw-left pulse" },
      { name = "Yaw Right", side = "right", pulseSeconds = 0.25, description = "short yaw-right pulse" },
      { name = "Forward", side = "front", pulseSeconds = 0.5, description = "short forward pulse" },
      { name = "Reverse", side = "bottom", pulseSeconds = 0.5, description = "short reverse pulse" },
    },
  }
end

local function mergeList(existing, def)
  if type(existing) ~= "table" or #existing == 0 then return def end
  return existing
end

local function mergeAircraft(cfg, def)
  cfg.aircraft = cfg.aircraft or {}
  for key, value in pairs(def.aircraft) do
    if cfg.aircraft[key] == nil then cfg.aircraft[key] = value end
  end
  cfg.aircraft.commands = mergeList(cfg.aircraft.commands, def.aircraft.commands)
  cfg.aircraft.modes = mergeList(cfg.aircraft.modes, def.aircraft.modes)
  cfg.aircraft.altitudeLevels = mergeList(cfg.aircraft.altitudeLevels, def.aircraft.altitudeLevels)
  cfg.aircraft.rearThrustVacuum = cfg.aircraft.rearThrustVacuum or def.aircraft.rearThrustVacuum
  cfg.aircraft.densityCalibration = cfg.aircraft.densityCalibration or def.aircraft.densityCalibration
end

local function loadCfg()
  local cfg = config.load(CFG, {})
  local def = defaults()
  if type(cfg.redstoneProfiles) ~= "table" then cfg.redstoneProfiles = def.redstoneProfiles end
  cfg.refreshSeconds = tonumber(cfg.refreshSeconds) or def.refreshSeconds
  mergeAircraft(cfg, def)
  return cfg
end

local function saveCfg(cfg)
  return config.save(CFG, cfg)
end

local function scalar(v)
  if v == nil then return "-" end
  if type(v) == "number" then return string.format("%.3f", v) end
  return tostring(v)
end

local function integer(v)
  v = tonumber(v)
  if not v then return "-" end
  local s = tostring(math.floor(v + 0.5))
  local out = ""
  while #s > 3 do
    out = " " .. s:sub(-3) .. out
    s = s:sub(1, -4)
  end
  return s .. out
end

local function percent(v)
  v = tonumber(v)
  if not v then return "-" end
  return string.format("%.2f%%", v * 100)
end

local function clamp(v, min, max)
  v = tonumber(v) or 0
  if v < min then return min end
  if v > max then return max end
  return v
end

local function vec(v)
  if type(v) ~= "table" then return scalar(v) end
  local x = v.x or v[1] or v.X
  local y = v.y or v[2] or v.Y
  local z = v.z or v[3] or v.Z
  if x or y or z then return scalar(x or 0) .. ", " .. scalar(y or 0) .. ", " .. scalar(z or 0) end
  local count = 0
  for _ in pairs(v) do count = count + 1 end
  return "table(" .. tostring(count) .. ")"
end

local function poseLine(pose)
  if type(pose) ~= "table" then return "-" end
  return "pos " .. vec(pose.position or pose.pos) .. "  rot " .. vec(pose.orientation or pose.rotation or pose.rot)
end

local function validSide(side)
  for _, item in ipairs(SIDES) do if item == side then return true end end
  return false
end

local function firstData(snap, key)
  local rows = snap and snap[key]
  local first = rows and rows[1]
  return first and first.data or nil
end

local function densityGain(profile)
  local cal = profile.densityCalibration or {}
  local d = tonumber(cal.density) or 0
  local vacuum = tonumber(cal.vacuumForce) or 0
  local measured = tonumber(cal.measuredForce) or 0
  if d <= 0 or vacuum <= 0 or measured <= 0 then return 0 end
  return ((measured / vacuum) - 1) / d
end

local function adjustedThrust(profile, state, density)
  local vacuum = tonumber((profile.rearThrustVacuum or {})[state]) or 0
  return vacuum * (1 + clamp(density, 0, 1) * densityGain(profile))
end

local function nearestAltitudeLevel(profile, height)
  height = tonumber(height)
  if not height then return nil end
  local best = nil
  local bestDist = nil
  for _, row in ipairs(profile.altitudeLevels or {}) do
    local dist = math.abs((tonumber(row.y) or 0) - height)
    if not bestDist or dist < bestDist then
      best = row
      bestDist = dist
    end
  end
  return best
end

function M.run(ctx)
  local cfg = loadCfg()
  local app = {
    page = "flight",
    selected = 1,
    confirm = nil,
    inputMode = nil,
    input = "",
    keyboard = {},
    timers = {},
    message = "Navigation ready",
    snapshot = nil,
    avionics = nil,
  }

  local tabs = {
    { id = "flight", label = "Flight" },
    { id = "avionics", label = "Avion" },
    { id = "quad", label = "Quad" },
    { id = "forces", label = "Force" },
    { id = "assist", label = "Assist" },
    { id = "config", label = "Config" },
  }

  local assistActions = {
    { id = "pulse", label = "Pulse" },
    { id = "edit", label = "Edit" },
    { id = "save", label = "Save" },
  }

  local editActions = {
    { id = "name", label = "Name" },
    { id = "side", label = "Side" },
    { id = "duration", label = "Duration" },
    { id = "desc", label = "Desc" },
  }

  local function refreshSable()
    local allowed, denied = ctx.security.require("sable.read", "navigation")
    if not allowed then
      app.snapshot = { ok = false, status = tostring(denied), error = tostring(denied) }
      return app.snapshot
    end
    local ok, snap = pcall(sabled.snapshot)
    if ok and snap then
      app.snapshot = snap
    else
      app.snapshot = { ok = false, status = "sabled error", error = tostring(snap) }
      log.warn("navigation", "sabled error: " .. tostring(snap))
    end
    return app.snapshot
  end

  local function refreshAvionics()
    local allowed, denied = ctx.security.require("avionics.read", "navigation")
    if not allowed then
      app.avionics = { ok = false, available = false, status = tostring(denied), error = tostring(denied), counts = {} }
      return app.avionics
    end
    local ok, snap = pcall(avionicsd.snapshot)
    if ok and snap then
      app.avionics = snap
    else
      app.avionics = { ok = false, available = false, status = "avionicsd error", error = tostring(snap), counts = {} }
      log.warn("navigation", "avionicsd error: " .. tostring(snap))
    end
    return app.avionics
  end

  local function selectedProfile()
    return cfg.redstoneProfiles[app.selected]
  end

  local function requestPulse()
    local profile = selectedProfile()
    if not profile then app.message = "No profile selected" return end
    local allowed, denied = ctx.security.require("navigation.assist", tostring(profile.name))
    if not allowed then app.message = tostring(denied) return end
    app.confirm = profile
    app.message = "Confirm pulse: " .. tostring(profile.name)
  end

  local function doPulse(profile)
    local allowed, denied = ctx.security.require("redstone.output", tostring(profile.side))
    if not allowed then app.message = tostring(denied) return end
    if not redstone or not redstone.setOutput then app.message = "redstone API unavailable" return end
    if not validSide(profile.side) then app.message = "invalid side: " .. tostring(profile.side) return end
    local seconds = math.max(0.1, math.min(10, tonumber(profile.pulseSeconds) or 0.5))
    redstone.setOutput(profile.side, true)
    local timer = os.startTimer(seconds)
    app.timers[timer] = profile.side
    app.message = "Pulse " .. tostring(profile.name) .. " on " .. tostring(profile.side)
    log.info("navigation", "pulse " .. tostring(profile.name) .. " side=" .. tostring(profile.side) .. " seconds=" .. tostring(seconds))
    if ctx.notifications then ctx.notifications:push("success", "Navigation", app.message, 3) end
  end

  local function startEdit(mode, value)
    app.inputMode = mode
    app.input = tostring(value or "")
    app.keyboard.hint = mode .. ": " .. app.input
  end

  local function applyEdit()
    local profile = selectedProfile()
    if not profile or not app.inputMode then return end
    if app.inputMode == "name" and app.input ~= "" then profile.name = app.input
    elseif app.inputMode == "side" and validSide(app.input) then profile.side = app.input
    elseif app.inputMode == "duration" then profile.pulseSeconds = math.max(0.1, math.min(10, tonumber(app.input) or profile.pulseSeconds or 0.5))
    elseif app.inputMode == "desc" then profile.description = app.input
    else app.message = "Invalid value" end
    app.inputMode = nil
    app.input = ""
    saveCfg(cfg)
  end

  app.keyboard.onText = function(ch) app.input = app.input .. ch end
  app.keyboard.onBackspace = function() app.input = app.input:sub(1, -2) end
  app.keyboard.onEnter = applyEdit

  local function drawFlight(w, h)
    local snap = app.snapshot or refreshSable()
    local av = app.avionics or refreshAvionics()
    local okStatus, st = pcall(sabled.status)
    if not okStatus or not st then st = { available = false, inSublevel = false, apiNames = {}, error = tostring(st) } end
    renderer.writeAt(1, 3, renderer.crop("CC:Sable: " .. tostring(st.available and "available" or "missing") .. "  Sublevel: " .. tostring(st.inSublevel and "ready" or "not detected"), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 4, renderer.crop("Avionics: " .. tostring(av.available and "ready" or "missing") .. "  Alt:" .. tostring((av.counts or {}).altitude or 0) .. " Gimbal:" .. tostring((av.counts or {}).gimbal or 0) .. " Prop:" .. tostring((av.counts or {}).propeller or 0), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 5, renderer.crop("Aircraft: " .. tostring(cfg.aircraft.name) .. "  Mass " .. integer(cfg.aircraft.massKg) .. " kg  declared weight " .. integer(cfg.aircraft.declaredWeightNewton) .. " N", w), colors.black, colors.lightGray)
    if not st.available and not av.available then
      renderer.writeAt(1, 7, renderer.crop("Install CC:Sable or Create: Avionics peripherals. Navigation stays read-only until data exists.", w), colors.gray, colors.lightGray)
      renderer.button(1, 9, 12, "Devices", false)
      renderer.button(15, 9, 10, "Logs", false)
      return
    end
    local sub = snap.sublevel
    if sub and sub.inSublevel then
      local rows = {
        "Name: " .. scalar(sub.name),
        "UUID: " .. scalar(sub.uuid),
        "Flags: grid=" .. tostring(sub.plotGrid) .. " yard=" .. tostring(sub.plotYard),
        "Logical: " .. poseLine(sub.logicalPose),
        "Velocity: " .. vec(sub.velocity),
        "Angular: " .. vec(sub.angularVelocity),
        "Mass: " .. scalar(sub.mass) .. "  Center: " .. vec(sub.centerOfMass),
      }
      for i = 1, math.min(#rows, h - 7) do renderer.writeAt(1, i + 6, renderer.crop(rows[i], w), colors.black, colors.lightGray) end
    else
      renderer.writeAt(1, 7, renderer.crop("Sable pose unavailable. Use Avion/Force tabs for Create: Avionics sensors.", w), colors.gray, colors.lightGray)
    end
  end

  local function drawAvionics(w, h)
    local av = app.avionics or refreshAvionics()
    local counts = av.counts or {}
    renderer.writeAt(1, 3, renderer.crop("Status: " .. tostring(av.status or av.error or "-"), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 4, renderer.crop("Peripherals  altitude=" .. tostring(counts.altitude or 0) .. " gimbal=" .. tostring(counts.gimbal or 0) .. " nav=" .. tostring(counts.nav or 0) .. " prop=" .. tostring(counts.propeller or 0) .. " throttle=" .. tostring(counts.throttle or 0), w), colors.black, colors.lightGray)

    local alt = firstData(av, "altitude") or {}
    local gim = firstData(av, "gimbal") or {}
    local nav = firstData(av, "nav") or {}
    local prop = firstData(av, "propeller") or {}
    local rows = {
      "Altitude height: " .. scalar(alt.height) .. "  pressure: " .. scalar(alt.airPressure) .. "  vertical speed: " .. scalar(alt.verticalSpeed),
      "Gimbal angles: " .. vec(gim.angles),
      "Angular rates: " .. vec(gim.angularRates),
      "Gravity: " .. vec(gim.gravity),
      "Linear accel: " .. vec(gim.linearAcceleration),
      "Heading: " .. scalar(nav.heading) .. "  target bearing: " .. scalar(nav.targetBearing) .. "  distance: " .. scalar(nav.targetDistance),
      "Prop sample thrust: " .. scalar(prop.thrust) .. "  airflow: " .. scalar(prop.airflow) .. "  active: " .. tostring(prop.active),
      "Prop speed: " .. scalar(prop.speed or prop.rotationSpeed) .. "  axis: " .. vec(prop.axis),
    }
    for i = 1, math.min(#rows, h - 6) do renderer.writeAt(1, i + 5, renderer.crop(rows[i], w), colors.black, colors.lightGray) end

    local y = 14
    if y < h then renderer.writeAt(1, y, renderer.crop("Detected Avionics devices:", w), colors.black, colors.gray) end
    for i = 1, math.min(#(av.devices or {}), math.max(0, h - y)) do
      local d = av.devices[i]
      renderer.writeAt(1, y + i, renderer.crop(tostring(d.name) .. "  " .. table.concat(d.types or {}, ","), w), colors.black, colors.lightGray)
    end
  end

  local function drawQuad(w, h)
    renderer.writeAt(1, 3, renderer.crop("Quad profile: 4 vertical props + 4 rear props + weak lateral strafe", w), colors.black, colors.lightGray)
    renderer.writeAt(1, 4, renderer.crop("Corrections are frequency plans only; no automatic actuation in this version.", w), colors.gray, colors.lightGray)
    local y = 6
    for i, cmd in ipairs(cfg.aircraft.commands or {}) do
      if y + i - 1 >= h then break end
      local line = tostring(cmd.name) .. " = " .. tostring(cmd.frequency) .. "  " .. tostring(cmd.role)
      renderer.writeAt(1, y + i - 1, renderer.crop(line, w), colors.black, colors.lightGray)
    end
    local modeY = y + #(cfg.aircraft.commands or {}) + 1
    if modeY < h then renderer.writeAt(1, modeY, renderer.crop("Suggested modes:", w), colors.black, colors.gray) end
    for i, mode in ipairs(cfg.aircraft.modes or {}) do
      if modeY + i >= h then break end
      renderer.writeAt(1, modeY + i, renderer.crop(tostring(mode.name) .. ": " .. tostring(mode.detail), w), colors.black, colors.lightGray)
    end
  end

  local function drawForces(w, h)
    local av = app.avionics or refreshAvionics()
    local alt = firstData(av, "altitude") or {}
    local profile = cfg.aircraft
    local density = tonumber(alt.airPressure) or (profile.densityCalibration and profile.densityCalibration.density) or 0
    density = clamp(density, 0, 1)
    local height = tonumber(alt.height)
    local nearest = nearestAltitudeLevel(profile, height)
    local gain = densityGain(profile)
    renderer.writeAt(1, 3, renderer.crop("Air density: " .. percent(density) .. "  gain factor: " .. scalar(gain) .. "  height: " .. scalar(height), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 4, renderer.crop("Nearest hover level: " .. tostring(nearest and nearest.level or "-") .. " at Y=" .. tostring(nearest and nearest.y or "-"), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 5, renderer.crop("Declared stationary thrust/weight: " .. integer(profile.declaredWeightNewton) .. " N", w), colors.black, colors.lightGray)
    renderer.writeAt(1, 7, renderer.crop("Rear prop thrust table, corrected by current/calibrated air density:", w), colors.black, colors.gray)
    renderer.writeAt(1, 8, renderer.crop("STATE  VACUUM N       ADJUSTED N", w), colors.black, colors.lightGray)
    for state = 0, 15 do
      local row = 9 + state
      if row > h then break end
      local vacuum = (profile.rearThrustVacuum or {})[state] or 0
      local adjusted = adjustedThrust(profile, state, density)
      renderer.writeAt(1, row, renderer.crop(string.format("%2d     %10s     %10s", state, integer(vacuum), integer(adjusted)), w), colors.black, colors.lightGray)
    end
  end

  local function drawEnvironment(w, h)
    local snap = app.snapshot or refreshSable()
    local aero = snap.aero or {}
    local rows = {
      "Gravity: " .. vec(aero.gravity),
      "Magnetic north: " .. vec(aero.magneticNorth),
      "Air pressure: " .. scalar(aero.airPressure),
      "Universal drag: " .. scalar(aero.universalDrag),
      "Raw: " .. vec(aero.raw),
      "Default: " .. vec(aero.default),
    }
    for i = 1, math.min(#rows, h - 2) do renderer.writeAt(1, i + 2, renderer.crop(rows[i], w), colors.black, colors.lightGray) end
  end

  local function drawAssist(w, h)
    app.toolbar = ui.toolbar(1, 2, w, assistActions)
    renderer.writeAt(1, 4, renderer.crop("REDSTONE ASSIST - confirmed pulses only", w), colors.black, colors.gray)
    for i, profile in ipairs(cfg.redstoneProfiles or {}) do
      local bg = i == app.selected and colors.cyan or colors.lightGray
      local line = tostring(i) .. " " .. tostring(profile.name) .. "  " .. tostring(profile.side) .. "  " .. scalar(profile.pulseSeconds) .. "s  " .. tostring(profile.description or "")
      renderer.writeAt(1, i + 4, renderer.crop(line, w), colors.black, bg)
    end
    renderer.writeAt(1, h - 1, renderer.crop(app.message, w), colors.white, colors.gray)
    if app.confirm then
      local dx = 3
      local dy = math.max(4, math.floor(h / 2) - 2)
      local dw = math.min(42, w - 4)
      app.confirmBox = { x = dx + 1, y = dy + 4, w = math.min(12, dw - 2), h = 1 }
      ui.dialog(dx, dy, dw, "Confirm Redstone", tostring(app.confirm.name) .. " on " .. tostring(app.confirm.side), "Pulse")
    end
  end

  local function drawConfig(w, h)
    app.toolbar = ui.toolbar(1, 2, w, editActions)
    local profile = selectedProfile()
    renderer.writeAt(1, 4, renderer.crop("Selected redstone profile: " .. tostring(profile and profile.name or "-"), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 5, renderer.crop("Side options: left right front back top bottom", w), colors.gray, colors.lightGray)
    renderer.writeAt(1, 6, renderer.crop("Aircraft profile is stored in /system/config/navigation.cfg", w), colors.gray, colors.lightGray)
    if profile then
      renderer.writeAt(1, 8, renderer.crop("Name: " .. tostring(profile.name), w), colors.black, colors.lightGray)
      renderer.writeAt(1, 9, renderer.crop("Side: " .. tostring(profile.side), w), colors.black, colors.lightGray)
      renderer.writeAt(1, 10, renderer.crop("Duration: " .. scalar(profile.pulseSeconds), w), colors.black, colors.lightGray)
      renderer.writeAt(1, 11, renderer.crop("Desc: " .. tostring(profile.description or ""), w), colors.black, colors.lightGray)
    end
    if app.inputMode then
      renderer.writeAt(1, h - keyboard.height(), renderer.crop(app.inputMode .. ": " .. app.input, w), colors.white, colors.gray)
      app.keyboard.x = 1
      app.keyboard.y = h - keyboard.height() + 1
      keyboard.draw(1, app.keyboard.y, w, app.keyboard)
    end
  end

  function app:draw(w, h)
    refreshSable()
    refreshAvionics()
    self.tabs = ui.tabs(1, 1, w, tabs, self.page)
    if self.page == "flight" then drawFlight(w, h)
    elseif self.page == "avionics" then drawAvionics(w, h)
    elseif self.page == "quad" then drawQuad(w, h)
    elseif self.page == "forces" then drawForces(w, h)
    elseif self.page == "environment" then drawEnvironment(w, h)
    elseif self.page == "assist" then drawAssist(w, h)
    elseif self.page == "config" then drawConfig(w, h)
    end
  end

  function app:handle(event)
    if event.name == "timer" then
      local side = self.timers[event.args[1]]
      if side and redstone and redstone.setOutput then redstone.setOutput(side, false) end
      self.timers[event.args[1]] = nil
      return true
    end
    if self.inputMode then
      if event.name == "char" then self.input = self.input .. event.args[1] return true end
      if event.name == "key" then
        local key = event.args[1]
        if key == keys.backspace then self.input = self.input:sub(1, -2) return true end
        if key == keys.enter then applyEdit() return true end
      end
      if event.name == "mouse_click" and event.monitorTouch and keyboard.handle(event, self.keyboard) then return true end
    end
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    for _, tab in ipairs(self.tabs or {}) do
      if ui.hit(tab, x, y) then self.page = tab.id self.confirm = nil return true end
    end
    if self.confirm then
      if ui.hit(self.confirmBox, x, y) then doPulse(self.confirm) end
      self.confirm = nil
      return true
    end
    if self.page == "flight" and y == 9 then
      if x <= 12 then ctx.apps.launch("devices") return true end
      if x >= 15 and x <= 24 then ctx.apps.launch("logs") return true end
    elseif self.page == "assist" then
      local action = ui.toolbarHit(self.toolbar, x, y)
      if action == "pulse" then requestPulse() return true end
      if action == "save" then saveCfg(cfg) self.message = "Saved" return true end
      if y >= 5 then
        local idx = y - 4
        if cfg.redstoneProfiles[idx] then self.selected = idx return true end
      end
    elseif self.page == "config" then
      local action = ui.toolbarHit(self.toolbar, x, y)
      local profile = selectedProfile()
      if action and profile then
        if action == "name" then startEdit("name", profile.name) return true end
        if action == "side" then startEdit("side", profile.side) return true end
        if action == "duration" then startEdit("duration", profile.pulseSeconds) return true end
        if action == "desc" then startEdit("desc", profile.description) return true end
      end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Navigation", w = math.min(86, sw - 4), h = math.min(26, sh - 3), x = 5, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
