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

local function shortLabel(value, fallback)
  value = tostring(value or fallback or "-")
  if #value > 18 and value:find("%-") then return fallback or "target" end
  if #value > 18 then return string.sub(value, 1, 15) .. "..." end
  return value
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

  local function targetBearing(target, index)
    if tonumber(target.bearing) then return tonumber(target.bearing) end
    if tonumber(target.x) and tonumber(target.z) then
      return math.deg(math.atan2 and math.atan2(tonumber(target.x), tonumber(target.z)) or math.atan(tonumber(target.x) / math.max(1, tonumber(target.z))))
    end
    return (index - 1) * 35 - 70
  end

  local function targetDistance(target, index)
    if tonumber(target.distance) then return tonumber(target.distance) end
    if tonumber(target.x) and tonumber(target.z) then
      local x, z = tonumber(target.x), tonumber(target.z)
      return math.sqrt(x * x + z * z)
    end
    return 80 + index * 35
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
    local mapW, mapH = math.max(26, math.min(w - 4, 54)), math.max(9, math.min(h - 11, 16))
    renderer.fill(mapX, mapY, mapW, mapH, colors.black)
    local cx, cy = mapX + math.floor(mapW / 2), mapY + math.floor(mapH / 2)
    local maxR = math.max(3, math.min(math.floor(mapW / 2) - 2, mapH - 2))
    for r = 2, maxR, 3 do
      renderer.writeAt(cx - r, cy, "-", colors.gray, colors.black)
      renderer.writeAt(cx + r, cy, "-", colors.gray, colors.black)
      if cy - r >= mapY then renderer.writeAt(cx, cy - r, "|", colors.gray, colors.black) end
      if cy + r <= mapY + mapH - 1 then renderer.writeAt(cx, cy + r, "|", colors.gray, colors.black) end
    end
    for y = mapY, mapY + mapH - 1 do
      local dy = cy - y
      for x = mapX, mapX + mapW - 1 do
        local dx = x - cx
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 1 and dist <= maxR then
          local angle = math.deg(math.atan2 and math.atan2(dx, dy) or math.atan(dx / math.max(1, dy)))
          if math.abs(angle) <= 38 then
            local ch = dist > maxR - 1 and "." or " "
            renderer.writeAt(x, y, ch, colors.lime, colors.green)
          end
        end
      end
    end
    renderer.writeAt(cx - 1, mapY, "N", colors.white, colors.black)
    renderer.writeAt(cx, cy, "^", colors.white, colors.blue)
    renderer.writeAt(mapX, mapY, "+", colors.lightGray, colors.black)
    renderer.writeAt(mapX + mapW - 1, mapY, "+", colors.lightGray, colors.black)
    renderer.writeAt(mapX, mapY + mapH - 1, "+", colors.lightGray, colors.black)
    renderer.writeAt(mapX + mapW - 1, mapY + mapH - 1, "+", colors.lightGray, colors.black)
    for i, target in ipairs(targets or {}) do
      local bearing = targetBearing(target, i)
      local dist = targetDistance(target, i)
      local r = math.max(1, math.min(math.floor(dist / 60) + 1, maxR))
      local rad = math.rad(bearing)
      local x = math.max(mapX, math.min(mapX + mapW - 1, cx + math.floor(math.sin(rad) * r)))
      local y = math.max(mapY, math.min(mapY + mapH - 1, cy - math.floor(math.cos(rad) * r)))
      renderer.writeAt(x, y, i == app.targetIndex and "X" or tostring(i % 10), i == app.targetIndex and colors.red or colors.yellow, colors.black)
    end
    return mapY + mapH
  end

  local function drawRadar(w, h)
    local snap = app.snapshot or refresh()
    local counts = snap.counts or {}
    renderer.writeAt(1, 3, renderer.crop("Status: " .. tostring(snap.status or "-"), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 4, renderer.crop("Radars=" .. tostring(counts.radars or 0) .. " Targets=" .. tostring(counts.targets or 0) .. " Cannons=" .. tostring(counts.cannons or 0) .. " Unknown=" .. tostring(counts.unknown or 0), w), colors.black, colors.lightGray)
    if (counts.radars or 0) > 0 and (counts.targets or 0) == 0 then
      renderer.writeAt(1, 6, renderer.crop("Radar visible, no track readable. Select/link target or open Probe.", w), colors.orange, colors.lightGray)
    else
      renderer.writeAt(1, 6, renderer.crop("Radar scope: green=cone, ^=ship, X=selected, numbers=targets", w), colors.gray, colors.lightGray)
    end
    local bottom = drawMap(w, h, snap.targets or {})
    local detailX = math.min(w, 58)
    if detailX + 20 <= w then
      local target = selected(snap.targets or {}, app.targetIndex)
      renderer.writeAt(detailX, 8, renderer.crop("Selected", w - detailX + 1), colors.black, colors.gray)
      if target then
        renderer.writeAt(detailX, 10, renderer.crop(shortLabel(target.label, "T" .. tostring(app.targetIndex)), w - detailX + 1), colors.black, colors.lightGray)
        renderer.writeAt(detailX, 11, renderer.crop("dist " .. scalar(targetDistance(target, app.targetIndex)), w - detailX + 1), colors.black, colors.lightGray)
        renderer.writeAt(detailX, 12, renderer.crop("bear " .. scalar(targetBearing(target, app.targetIndex)), w - detailX + 1), colors.black, colors.lightGray)
        renderer.writeAt(detailX, 13, renderer.crop("alt  " .. scalar(target.altitude), w - detailX + 1), colors.black, colors.lightGray)
      else
        renderer.writeAt(detailX, 10, renderer.crop("No target", w - detailX + 1), colors.gray, colors.lightGray)
      end
    end
    for i = 1, math.min(#(snap.radars or {}), math.max(0, h - bottom - 2)) do
      local radar = snap.radars[i]
      local methods = table.concat(radar.targetMethods or {}, ",")
      if methods == "" then methods = "no target method" end
      renderer.writeAt(1, bottom + i, renderer.crop("Radar " .. tostring(i) .. ": " .. tostring(radar.name) .. " " .. methods, w), colors.black, colors.lightGray)
    end
    if (counts.radars or 0) > 0 and (counts.targets or 0) == 0 and bottom + #(snap.radars or {}) + 1 <= h then
      renderer.writeAt(1, h, renderer.crop("Create Radars: link Bearing -> Network Controller -> Monitor/Fire Controller.", w), colors.gray, colors.lightGray)
    end
  end

  local function drawTargets(w, h)
    local snap = app.snapshot or refresh()
    renderer.writeAt(1, 3, renderer.crop("TARGETS  click row to select", w), colors.black, colors.gray)
    if #(snap.targets or {}) == 0 then renderer.writeAt(1, 5, renderer.crop("No target from radar/probe.", w), colors.gray, colors.lightGray) end
    for i, target in ipairs(snap.targets or {}) do
      if i > h - 4 then break end
      local bg = i == app.targetIndex and colors.cyan or colors.lightGray
      local line = tostring(i) .. " " .. shortLabel(target.label, "T" .. tostring(i)) .. " dist=" .. scalar(targetDistance(target, i)) .. " bearing=" .. scalar(targetBearing(target, i)) .. " xyz=" .. scalar(target.x) .. "," .. scalar(target.y) .. "," .. scalar(target.z)
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
  local win = ctx.windowManager:create({ title = "Combat", w = math.min(94, sw - 4), h = math.min(27, sh - 3), x = 6, y = 3, app = app })
  local refreshTimer = os.startTimer(math.max(0.2, tonumber(cfg.refreshSeconds) or 0.5))
  while not win.closed do
    local event = ctx.pullEvent()
    if event.name == "timer" and event.args[1] == refreshTimer then
      refresh()
      refreshTimer = os.startTimer(math.max(0.2, tonumber(cfg.refreshSeconds) or 0.5))
    end
  end
end

return M
