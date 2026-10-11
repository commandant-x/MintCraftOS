local log = require("system.libraries.log")
local config = require("system.libraries.config")

local M = {
  devices = {},
  redirected = false,
  nativeTerm = nil,
  displayTerm = nil,
  display = {
    target = "computer",
    scale = nil,
    width = 0,
    height = 0,
    monitorSide = nil,
  },
  ctx = nil,
  listeners = {},
}

local function readScale()
  local cfg = config.load("/system/config/system.cfg", {})
  local value = tonumber(cfg.displayScale) or 0.5
  if value < 0.5 then value = 0.5 end
  if value > 5 then value = 5 end
  return math.floor(value * 2 + 0.5) / 2
end

function M.setScale(scale)
  local cfg = config.load("/system/config/system.cfg", {})
  scale = tonumber(scale) or readScale()
  if scale < 0.5 then scale = 0.5 end
  if scale > 5 then scale = 5 end
  cfg.displayScale = math.floor(scale * 2 + 0.5) / 2
  config.save("/system/config/system.cfg", cfg)
  return M.refreshDisplay()
end

function M.scan()
  local devices = {}
  if peripheral and peripheral.getNames then
    local ok, names = pcall(peripheral.getNames)
    if not ok or type(names) ~= "table" then
      M.scanError = "Peripheral scan failed: " .. tostring(names)
      log.error("deviced", M.scanError)
      return M.devices, M.scanError
    end
    for _, name in ipairs(names) do
      local result = {pcall(peripheral.getType, name)}
      if result[1] and type(result[2]) == "string" then
        local types = {}
        for i = 2, #result do
          if type(result[i]) == "string" then types[result[i]] = true end
        end
        devices[name] = {name = name, type = result[2], types = types}
      end
    end
  end
  M.scanError = nil
  M.devices = devices
  return devices
end

function M.hasType(kind)
  for _, device in pairs(M.devices) do
    if device.type == kind or (device.types and device.types[kind]) then return true end
  end
  return false
end

function M.useMonitor()
  if not peripheral or not peripheral.wrap then return false end
  local names = {}
  for name, device in pairs(M.devices) do
    if device.type == "monitor" or (device.types and device.types.monitor) then
      names[#names + 1] = name
    end
  end
  table.sort(names, function(a, b)
    if a == b then return false end
    if a == M.display.monitorSide then return true end
    if b == M.display.monitorSide then return false end
    return a < b
  end)
  local scale = readScale()
  local monitor, side, w, h
  for _, name in ipairs(names) do
    local ok, candidate, width, height = pcall(function()
      local device = peripheral.wrap(name)
      if not device then error("Monitor detached") end
      device.setTextScale(scale)
      local width, height = device.getSize()
      if type(width) ~= "number" or type(height) ~= "number" then error("Invalid monitor size") end
      return device, width, height
    end)
    if ok then monitor, side, w, h = candidate, name, width, height break end
    log.error("deviced", "monitor " .. name .. ": " .. tostring(candidate))
  end
  if not monitor then return false end
  if not M.nativeTerm then M.nativeTerm = term.native and term.native() or term.current() end
  M.displayTerm = monitor
  term.redirect(monitor)
  M.redirected = true
  M.display = {
    target = "monitor",
    scale = scale,
    width = w,
    height = h,
    monitorSide = side or "unknown",
  }
  log.info("deviced", "using monitor " .. tostring(M.display.monitorSide) .. " at " .. tostring(w) .. "x" .. tostring(h) .. " scale " .. tostring(scale))
  return true
end

function M.refreshDisplay()
  if M.ctx and M.ctx.invalidateDisplay then M.ctx.invalidateDisplay() end
  M.scan()
  local oldW, oldH = M.display.width, M.display.height
  local success, ok = pcall(M.useMonitor)
  if not success then
    log.error("deviced", "monitor unavailable: " .. tostring(ok))
    ok = false
  end
  if not ok then
    if M.nativeTerm then
      term.redirect(M.nativeTerm)
    end
    M.redirected = false
    M.displayTerm = M.nativeTerm
    M.getDisplay()
  end

  local d = M.getDisplay()
  if M.ctx and M.ctx.notifications and (d.width ~= oldW or d.height ~= oldH) then
    M.ctx.notifications:push("success", "Display", tostring(d.width) .. "x" .. tostring(d.height), 3)
  end
  return ok
end

function M.isRedirected()
  return M.redirected
end

function M.getTarget()
  return M.displayTerm or M.nativeTerm or term.current()
end

function M.getDisplay()
  if not M.redirected then
    local native = M.nativeTerm or term.current()
    local w, h = native.getSize()
    M.display = {
      target = "computer",
      scale = nil,
      width = w,
      height = h,
      monitorSide = nil,
    }
  end
  local display = {}
  for key, value in pairs(M.display) do display[key] = value end
  return display
end

function M.start(ctx)
  if M.ctx then M.stop() end
  M.ctx = ctx
  if not M.nativeTerm then M.nativeTerm = term.native and term.native() or term.current() end
  M.refreshDisplay()
  if ctx and ctx.eventBus then
    table.insert(M.listeners, ctx.eventBus:on("peripheral", function()
      M.refreshDisplay()
    end))
    table.insert(M.listeners, ctx.eventBus:on("peripheral_detach", function()
      M.refreshDisplay()
    end))
    table.insert(M.listeners, ctx.eventBus:on("monitor_resize", function(side)
      if side == M.display.monitorSide then M.refreshDisplay() end
    end))
    table.insert(M.listeners, ctx.eventBus:on("term_resize", function()
      if not M.redirected then M.getDisplay() end
    end))
  end
  log.info("deviced", "device service ready")
end

function M.stop()
  if M.ctx and M.ctx.eventBus then
    for _, id in ipairs(M.listeners) do M.ctx.eventBus:off(id) end
  end
  M.listeners = {}
  M.ctx = nil
  if M.redirected and M.nativeTerm then
    term.redirect(M.nativeTerm)
    M.redirected = false
    M.displayTerm = M.nativeTerm
    M.getDisplay()
  end
end

function M.list()
  local rows = {}
  for _, device in pairs(M.devices) do
    table.insert(rows, { name = device.name, type = device.type })
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

return M
