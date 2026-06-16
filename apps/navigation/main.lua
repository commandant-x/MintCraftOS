local renderer = require("system.gui.renderer")
local ui = require("system.gui.components")
local config = require("system.libraries.config")
local log = require("system.libraries.log")
local keyboard = require("system.gui.keyboard")
local sabled = require("system.services.sabled")

local M = {}

local CFG = "/system/config/navigation.cfg"
local SIDES = { "left", "right", "front", "back", "top", "bottom" }

local function defaults()
  return {
    refreshSeconds = 1,
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

local function loadCfg()
  local cfg = config.load(CFG, {})
  local def = defaults()
  if type(cfg.redstoneProfiles) ~= "table" then cfg.redstoneProfiles = def.redstoneProfiles end
  cfg.refreshSeconds = tonumber(cfg.refreshSeconds) or def.refreshSeconds
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

local function vec(v)
  if type(v) ~= "table" then return scalar(v) end
  local x = v.x or v[1] or v.X
  local y = v.y or v[2] or v.Y
  local z = v.z or v[3] or v.Z
  if x or y or z then
    return scalar(x or 0) .. ", " .. scalar(y or 0) .. ", " .. scalar(z or 0)
  end
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
  }

  local tabs = {
    { id = "flight", label = "Flight" },
    { id = "environment", label = "Environment" },
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

  local function refresh()
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
    local snap = app.snapshot or refresh()
    local okStatus, st = pcall(sabled.status)
    if not okStatus or not st then
      st = { available = false, inSublevel = false, apiNames = {}, error = tostring(st) }
    end
    renderer.writeAt(1, 3, renderer.crop("CC:Sable: " .. tostring(st.available and "available" or "missing") .. "  APIs: " .. table.concat(st.apiNames or {}, ","), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 4, renderer.crop("Sublevel: " .. tostring(st.inSublevel and "ready" or "not on sublevel") .. "  Status: " .. tostring(snap.status or snap.error or "-"), w), colors.black, colors.lightGray)
    if not st.available or not snap.sublevel or not snap.sublevel.inSublevel then
      renderer.writeAt(1, 6, renderer.crop("Diagnostic: install CC:Sable and place this computer on a Sable sublevel.", w), colors.gray, colors.lightGray)
      renderer.writeAt(1, 7, renderer.crop("Open Devices/Logs if the API should be present but is not detected.", w), colors.gray, colors.lightGray)
      renderer.button(1, 9, 12, "Devices", false)
      renderer.button(15, 9, 10, "Logs", false)
      return
    end
    local sub = snap.sublevel
    local rows = {
      "Name: " .. scalar(sub.name),
      "UUID: " .. scalar(sub.uuid),
      "Flags: grid=" .. tostring(sub.plotGrid) .. " yard=" .. tostring(sub.plotYard),
      "Logical: " .. poseLine(sub.logicalPose),
      "Last: " .. poseLine(sub.lastPose),
      "Velocity: " .. vec(sub.velocity),
      "Linear: " .. vec(sub.linearVelocity),
      "Angular: " .. vec(sub.angularVelocity),
      "Mass: " .. scalar(sub.mass) .. "  inverse " .. scalar(sub.inverseMass),
      "Center: " .. vec(sub.centerOfMass),
      "Inertia: " .. vec(sub.inertiaTensor),
    }
    for i = 1, math.min(#rows, h - 3) do
      renderer.writeAt(1, i + 5, renderer.crop(rows[i], w), colors.black, colors.lightGray)
    end
  end

  local function drawEnvironment(w, h)
    local snap = app.snapshot or refresh()
    local aero = snap.aero or {}
    local rows = {
      "Gravity: " .. vec(aero.gravity),
      "Magnetic north: " .. vec(aero.magneticNorth),
      "Air pressure: " .. scalar(aero.airPressure),
      "Universal drag: " .. scalar(aero.universalDrag),
      "Raw: " .. vec(aero.raw),
      "Default: " .. vec(aero.default),
    }
    for i = 1, math.min(#rows, h - 2) do
      renderer.writeAt(1, i + 2, renderer.crop(rows[i], w), colors.black, colors.lightGray)
    end
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
    renderer.writeAt(1, 4, renderer.crop("Selected profile: " .. tostring(profile and profile.name or "-"), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 5, renderer.crop("Side options: left right front back top bottom", w), colors.gray, colors.lightGray)
    if profile then
      renderer.writeAt(1, 7, renderer.crop("Name: " .. tostring(profile.name), w), colors.black, colors.lightGray)
      renderer.writeAt(1, 8, renderer.crop("Side: " .. tostring(profile.side), w), colors.black, colors.lightGray)
      renderer.writeAt(1, 9, renderer.crop("Duration: " .. scalar(profile.pulseSeconds), w), colors.black, colors.lightGray)
      renderer.writeAt(1, 10, renderer.crop("Desc: " .. tostring(profile.description or ""), w), colors.black, colors.lightGray)
    end
    if app.inputMode then
      renderer.writeAt(1, h - keyboard.height(), renderer.crop(app.inputMode .. ": " .. app.input, w), colors.white, colors.gray)
      app.keyboard.x = 1
      app.keyboard.y = h - keyboard.height() + 1
      keyboard.draw(1, app.keyboard.y, w, app.keyboard)
    end
  end

  function app:draw(w, h)
    refresh()
    self.tabs = ui.tabs(1, 1, w, tabs, self.page)
    if self.page == "flight" then drawFlight(w, h)
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
  local win = ctx.windowManager:create({ title = "Navigation", w = math.min(76, sw - 4), h = math.min(22, sh - 3), x = 5, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
