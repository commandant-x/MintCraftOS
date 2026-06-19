local renderer = require("system.gui.renderer")
local ui = require("system.gui.components")
local config = require("system.libraries.config")
local combatd = require("system.services.combatd")

local M = {}

local CFG = "/system/config/combat.cfg"

local function scalar(v)
  if v == nil then return "-" end
  if type(v) == "number" then return string.format("%.2f", v) end
  return tostring(v)
end

local function loadCfg()
  return config.load(CFG, {
    refreshSeconds = 0.5,
    semiAuto = true,
    requireFireConfirmation = true,
    ballistics = { gravity = 9.81, muzzleVelocity = 120, drag = 0 },
    radar = { maxTargets = 64, staleSeconds = 5 },
  })
end

local function typeLabel(types)
  return table.concat(types or {}, ",")
end

local function selected(list, index)
  if not list or #list == 0 then return nil end
  index = math.max(1, math.min(#list, tonumber(index) or 1))
  return list[index]
end

function M.run(ctx)
  local cfg = loadCfg()
  local app = {
    page = "radar",
    targetIndex = 1,
    cannonIndex = 1,
    deviceIndex = 1,
    confirmFire = nil,
    message = "Combat ready",
    solution = nil,
    snapshot = nil,
  }

  local tabs = {
    { id = "radar", label = "Radar" },
    { id = "targets", label = "Targets" },
    { id = "cannons", label = "Cannons" },
    { id = "fire", label = "Fire" },
    { id = "probe", label = "Probe" },
    { id = "config", label = "Config" },
  }

  local fireActions = {
    { id = "solve", label = "Solve" },
    { id = "aim", label = "Aim" },
    { id = "fire", label = "Fire" },
  }

  local probeActions = {
    { id = "export", label = "Export" },
    { id = "refresh", label = "Refresh" },
  }

  local function refresh()
    local allowed, denied = ctx.security.require("combat.read", "combat")
    if not allowed then
      app.snapshot = { ok = false, status = tostring(denied), counts = {}, radars = {}, targets = {}, cannons = {}, devices = {}, errors = { tostring(denied) } }
    else
      local ok, snap = pcall(combatd.snapshot)
      app.snapshot = (ok and snap) or { ok = false, status = "combatd error", counts = {}, radars = {}, targets = {}, cannons = {}, devices = {}, errors = { tostring(snap) } }
    end
    return app.snapshot
  end

  local function currentTarget()
    local snap = app.snapshot or refresh()
    return selected(snap.targets or {}, app.targetIndex)
  end

  local function currentCannon()
    local snap = app.snapshot or refresh()
    return selected(snap.cannons or {}, app.cannonIndex)
  end

  local function solve()
    local cannon = currentCannon()
    local target = currentTarget()
    if not cannon or not target then app.message = "Need cannon and target" return end
    local solution, err = combatd.solution(cannon.id, target)
    if solution then
      app.solution = solution
      app.message = "Solution yaw=" .. scalar(solution.yaw) .. " pitch=" .. scalar(solution.pitch)
    else
      app.message = tostring(err)
    end
  end

  local function aim()
    local allowed, denied = ctx.security.require("combat.aim", "aim")
    if not allowed then app.message = tostring(denied) return end
    local cannon = currentCannon()
    if not cannon then app.message = "No cannon" return end
    if not app.solution then solve() end
    local ok, msg = combatd.aim(cannon.id, app.solution)
    app.message = tostring(msg)
    if ctx.notifications then ctx.notifications:push(ok and "success" or "warn", "Combat", app.message, 3) end
  end

  local function requestFire()
    local allowed, denied = ctx.security.require("combat.fire", "fire")
    if not allowed then app.message = tostring(denied) return end
    local cannon = currentCannon()
    if not cannon then app.message = "No cannon" return end
    app.confirmFire = cannon
    app.message = "Confirm fire: " .. tostring(cannon.name)
  end

  local function fire(cannon)
    local ok, msg = combatd.fire(cannon.id)
    app.message = tostring(msg)
    if ctx.notifications then ctx.notifications:push(ok and "warn" or "error", "Combat", app.message, 4) end
  end

  local function drawMap(w, h, targets)
    local mapX, mapY = 2, 8
    local mapW, mapH = math.max(20, math.min(w - 4, 42)), math.max(7, math.min(h - 10, 13))
    renderer.fill(mapX, mapY, mapW, mapH, colors.gray)
    local cx, cy = mapX + math.floor(mapW / 2), mapY + math.floor(mapH / 2)
    renderer.writeAt(cx, cy, "+", colors.white, colors.gray)
    for i, target in ipairs(targets or {}) do
      local bearing = tonumber(target.bearing) or (i * 45)
      local dist = tonumber(target.distance) or (i * 10)
      local r = math.min(math.floor(dist / 50) + 1, math.min(math.floor(mapW / 2) - 1, math.floor(mapH / 2) - 1))
      local rad = math.rad(bearing)
      local x = math.max(mapX, math.min(mapX + mapW - 1, cx + math.floor(math.sin(rad) * r)))
      local y = math.max(mapY, math.min(mapY + mapH - 1, cy - math.floor(math.cos(rad) * r)))
      renderer.writeAt(x, y, i == app.targetIndex and "X" or "*", i == app.targetIndex and colors.red or colors.yellow, colors.gray)
    end
    return mapY + mapH
  end

  local function drawRadar(w, h)
    local snap = app.snapshot or refresh()
    local counts = snap.counts or {}
    renderer.writeAt(1, 3, renderer.crop("Status: " .. tostring(snap.status or "-"), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 4, renderer.crop("Radars=" .. tostring(counts.radars or 0) .. " Targets=" .. tostring(counts.targets or 0) .. " Cannons=" .. tostring(counts.cannons or 0) .. " Unknown=" .. tostring(counts.unknown or 0), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 6, renderer.crop("Tactical map: center=ship, *=target, X=selected", w), colors.gray, colors.lightGray)
    local bottom = drawMap(w, h, snap.targets or {})
    for i = 1, math.min(#(snap.radars or {}), math.max(0, h - bottom - 1)) do
      local radar = snap.radars[i]
      renderer.writeAt(1, bottom + i, renderer.crop("Radar " .. tostring(i) .. ": " .. tostring(radar.name) .. " " .. typeLabel(radar.types), w), colors.black, colors.lightGray)
    end
  end

  local function drawTargets(w, h)
    local snap = app.snapshot or refresh()
    renderer.writeAt(1, 3, renderer.crop("TARGETS  click row to select", w), colors.black, colors.gray)
    if #(snap.targets or {}) == 0 then renderer.writeAt(1, 5, renderer.crop("No target from radar/probe.", w), colors.gray, colors.lightGray) end
    for i, target in ipairs(snap.targets or {}) do
      if i > h - 4 then break end
      local bg = i == app.targetIndex and colors.cyan or colors.lightGray
      local line = tostring(i) .. " " .. tostring(target.label) .. " dist=" .. scalar(target.distance) .. " bearing=" .. scalar(target.bearing) .. " xyz=" .. scalar(target.x) .. "," .. scalar(target.y) .. "," .. scalar(target.z)
      renderer.writeAt(1, i + 3, renderer.crop(line, w), colors.black, bg)
    end
  end

  local function drawCannons(w, h)
    local snap = app.snapshot or refresh()
    renderer.writeAt(1, 3, renderer.crop("CANNONS / MOUNTS  click row to select", w), colors.black, colors.gray)
    if #(snap.cannons or {}) == 0 then renderer.writeAt(1, 5, renderer.crop("No CBC cannon peripheral detected. Use Probe to inspect devices.", w), colors.gray, colors.lightGray) end
    for i, cannon in ipairs(snap.cannons or {}) do
      if i > h - 4 then break end
      local bg = i == app.cannonIndex and colors.cyan or colors.lightGray
      local line = tostring(i) .. " " .. tostring(cannon.name) .. " yaw=" .. scalar(cannon.yaw) .. " pitch=" .. scalar(cannon.pitch) .. " loaded=" .. tostring(cannon.loaded) .. " aim=" .. tostring(cannon.canAim) .. " fire=" .. tostring(cannon.canFire)
      renderer.writeAt(1, i + 3, renderer.crop(line, w), colors.black, bg)
    end
  end

  local function drawFire(w, h)
    app.fireToolbar = ui.toolbar(1, 2, w, fireActions)
    local cannon, target = currentCannon(), currentTarget()
    renderer.writeAt(1, 4, renderer.crop("Mode: semi-auto. Aim may move cannon; Fire always asks confirmation.", w), colors.black, colors.lightGray)
    renderer.writeAt(1, 6, renderer.crop("Cannon: " .. tostring(cannon and cannon.name or "-"), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 7, renderer.crop("Target: " .. tostring(target and target.label or "-"), w), colors.black, colors.lightGray)
    if app.solution then
      renderer.writeAt(1, 9, renderer.crop("Solution yaw=" .. scalar(app.solution.yaw) .. " pitch=" .. scalar(app.solution.pitch) .. " distance=" .. scalar(app.solution.distance) .. " dy=" .. scalar(app.solution.deltaY), w), colors.black, colors.lightGray)
    else
      renderer.writeAt(1, 9, renderer.crop("No solution yet. Tap Solve.", w), colors.gray, colors.lightGray)
    end
    renderer.writeAt(1, h - 1, renderer.crop(app.message, w), colors.white, colors.gray)
    if app.confirmFire then
      local dx, dy = 3, math.max(4, math.floor(h / 2) - 2)
      local dw = math.min(44, w - 4)
      app.confirmBox = { x = dx + 1, y = dy + 4, w = math.min(12, dw - 2), h = 1 }
      ui.dialog(dx, dy, dw, "Confirm Fire", tostring(app.confirmFire.name), "Fire")
    end
  end

  local function drawProbe(w, h)
    local snap = app.snapshot or refresh()
    app.probeToolbar = ui.toolbar(1, 2, w, probeActions)
    renderer.writeAt(1, 4, renderer.crop("Probe devices. Export writes /var/logs/peripheral_probe.log", w), colors.black, colors.lightGray)
    local devices = snap.devices or {}
    if #devices == 0 then renderer.writeAt(1, 6, renderer.crop("No combat-like peripheral detected.", w), colors.gray, colors.lightGray) end
    for i, device in ipairs(devices) do
      if i > math.min(6, h - 8) then break end
      local bg = i == app.deviceIndex and colors.cyan or colors.lightGray
      renderer.writeAt(1, i + 5, renderer.crop(tostring(i) .. " " .. tostring(device.name) .. " " .. typeLabel(device.types), w), colors.black, bg)
    end
    local item = selected(devices, app.deviceIndex)
    if item then
      local probe = combatd.probe(item.name)
      local y = 13
      renderer.writeAt(1, y, renderer.crop("Methods: " .. table.concat(probe.methods or {}, ","), w), colors.black, colors.lightGray)
      local line = y + 2
      for method, value in pairs(probe.reads or {}) do
        if line > h - 1 then break end
        renderer.writeAt(1, line, renderer.crop(method .. " = " .. textutils.serialize(value), w), colors.black, colors.lightGray)
        line = line + 1
      end
    end
  end

  local function drawConfig(w, h)
    renderer.writeAt(1, 3, renderer.crop("Config: /system/config/combat.cfg", w), colors.black, colors.lightGray)
    renderer.writeAt(1, 5, renderer.crop("refreshSeconds=" .. scalar(cfg.refreshSeconds) .. " semiAuto=" .. tostring(cfg.semiAuto) .. " confirmFire=" .. tostring(cfg.requireFireConfirmation), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 6, renderer.crop("gravity=" .. scalar(cfg.ballistics and cfg.ballistics.gravity) .. " muzzleVelocity=" .. scalar(cfg.ballistics and cfg.ballistics.muzzleVelocity) .. " drag=" .. scalar(cfg.ballistics and cfg.ballistics.drag), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 8, renderer.crop("Radar maxTargets=" .. scalar(cfg.radar and cfg.radar.maxTargets) .. " staleSeconds=" .. scalar(cfg.radar and cfg.radar.staleSeconds), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 10, renderer.crop("Edit config from Files for now; app reloads values on launch.", w), colors.gray, colors.lightGray)
  end

  function app:draw(w, h)
    refresh()
    self.tabs = ui.tabs(1, 1, w, tabs, self.page)
    if self.page == "radar" then drawRadar(w, h)
    elseif self.page == "targets" then drawTargets(w, h)
    elseif self.page == "cannons" then drawCannons(w, h)
    elseif self.page == "fire" then drawFire(w, h)
    elseif self.page == "probe" then drawProbe(w, h)
    elseif self.page == "config" then drawConfig(w, h)
    end
  end

  function app:handle(event)
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    for _, tab in ipairs(self.tabs or {}) do
      if ui.hit(tab, x, y) then self.page = tab.id self.confirmFire = nil return true end
    end
    if self.confirmFire then
      if ui.hit(self.confirmBox, x, y) then fire(self.confirmFire) end
      self.confirmFire = nil
      return true
    end
    if self.page == "targets" and y >= 4 then
      local idx = y - 3
      if (self.snapshot.targets or {})[idx] then self.targetIndex = idx self.message = "Target " .. tostring(idx) return true end
    elseif self.page == "cannons" and y >= 4 then
      local idx = y - 3
      if (self.snapshot.cannons or {})[idx] then self.cannonIndex = idx self.message = "Cannon " .. tostring(idx) return true end
    elseif self.page == "fire" then
      local action = ui.toolbarHit(self.fireToolbar, x, y)
      if action == "solve" then solve() return true end
      if action == "aim" then aim() return true end
      if action == "fire" then requestFire() return true end
    elseif self.page == "probe" then
      local action = ui.toolbarHit(self.probeToolbar, x, y)
      if action == "export" then
        local allowed, denied = ctx.security.require("peripheral.probe", "export")
        if allowed then
          local ok, msg = combatd.exportProbe()
          self.message = tostring(msg)
          ctx.notifications:push(ok and "success" or "warn", "Probe", tostring(msg), 3)
        else
          self.message = tostring(denied)
        end
        return true
      elseif action == "refresh" then
        refresh()
        return true
      elseif y >= 6 and y <= 11 then
        local idx = y - 5
        if (self.snapshot.devices or {})[idx] then self.deviceIndex = idx return true end
      end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Combat", w = math.min(86, sw - 4), h = math.min(25, sh - 3), x = 6, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
