local log = require("system.libraries.log")
local config = require("system.libraries.config")
local sizeWorker

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

local function normalizeScale(value)
  value = tonumber(value) or 0.5
  if value ~= value then value = 0.5 end
  return math.floor(math.max(0.5, math.min(5, value)) * 2 + 0.5) / 2
end

local function validTarget(target)
  return type(target) == "string" and target:find("%S") ~= nil and not target:find("%c")
end
local function displayKind(device)
  if not device then return nil end
  if device.type=="monitor" or device.types and device.types.monitor then return "monitor" end
  if device.type=="terminal" or device.types and device.types.terminal then return "terminal" end
end

function M.getPreference()
  local cfg = config.load("/system/config/system.cfg", {})
  return validTarget(cfg.displayTarget) and cfg.displayTarget or "auto"
end

local function readScale(target)
  local cfg = config.load("/system/config/system.cfg", {})
  local scales = type(cfg.displayScales) == "table" and cfg.displayScales or {}
  return normalizeScale(scales[target] or cfg.displayScale)
end

function M.setTarget(target)
  local ok, err = M.setPreference(target)
  if not ok then return false, err end
  if target ~= "auto" and target ~= "computer" and (M.display.monitorSide or M.display.terminalSide) ~= target then
    return false, "Display unavailable; preference saved; using computer"
  end
  return true
end

function M.setPreference(target)
  if not validTarget(target) then return false, "Invalid display target" end
  local cfg = config.load("/system/config/system.cfg", {})
  cfg.displayTarget = target
  local ok, err = config.save("/system/config/system.cfg", cfg)
  if not ok then return false, err end
  M.refreshDisplay()
  return true
end

function M.listDisplays()
  local preference = M.getPreference()
  local rows = {
    {name = "auto", label = "Auto", available = true, selected = preference == "auto"},
    {name = "computer", label = "Computer", available = true, selected = preference == "computer"},
  }
  local names, found = {}, false
  for name, device in pairs(M.devices) do
    if displayKind(device) then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  for _, name in ipairs(names) do
    rows[#rows + 1] = {name = name, label = name, type=displayKind(M.devices[name]), available = true, selected = preference == name}
    if preference == name then found = true end
  end
  if preference ~= "auto" and preference ~= "computer" and not found then
    rows[#rows + 1] = {name = preference, label = preference, available = false, selected = true}
  end
  return rows
end

function M.setScale(scale, target)
  local cfg = config.load("/system/config/system.cfg", {})
  target = target or M.display.monitorSide or M.getPreference()
  if not validTarget(target) then return false, "Invalid display target" end
  if displayKind(M.devices[target])=="terminal" or target==M.display.terminalSide then
    return false,"CC Terminals does not expose monitor text scale"
  end
  scale = normalizeScale(tonumber(scale) or readScale(target))
  if type(cfg.displayScales) ~= "table" then cfg.displayScales = {} end
  cfg.displayScales[target] = scale
  if target == "auto" then cfg.displayScale = scale end
  local ok, err = config.save("/system/config/system.cfg", cfg)
  if not ok then return false, err end
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
  local preference = M.getPreference()
  if preference == "computer" then return false end
  if not peripheral or not peripheral.wrap then return false end
  local names = {}
  for name, device in pairs(M.devices) do
    local kind=displayKind(device)
    if (preference == "auto" and kind=="monitor") or preference==name and kind then
      names[#names + 1] = name
    end
  end
  table.sort(names, function(a, b)
    if a == b then return false end
    if a == M.display.monitorSide then return true end
    if b == M.display.monitorSide then return false end
    return a < b
  end)
  local scale
  local monitor, side, w, h
  for _, name in ipairs(names) do
    scale = readScale(name)
    local ok, candidate, width, height = pcall(function()
      local device = peripheral.wrap(name)
      if not device then error("Display detached") end
      if displayKind(M.devices[name])=="monitor" then device.setTextScale(scale) end
      local width, height = device.getSize()
      if type(width) ~= "number" or type(height) ~= "number" or width%1~=0 or height%1~=0
        or width<1 or height<1 or width*height>65536 then error("Invalid display size") end
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
  local kind=displayKind(M.devices[side])
  local color=false
  if monitor.isColor then local ok,value=pcall(monitor.isColor) color=ok and value==true end
  M.display = {
    target = kind,
    scale = kind=="monitor" and scale or nil,
    width = w,
    height = h,
    monitorSide = kind=="monitor" and side or nil,
    terminalSide = kind=="terminal" and side or nil,
    color = color,
    keyboard = kind=="terminal",
    mouse = kind=="terminal" and color,
  }
  log.info("deviced", "using "..kind.." "..tostring(side).." at "..w.."x"..h)
  return true
end

function M.refreshDisplay()
  if not M.nativeTerm then M.nativeTerm = term.native and term.native() or term.current() end
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

function M.outputFailed(target, problem)
  if target ~= M.getTarget() then return false end
  M.nativeTerm = M.nativeTerm or (term.native and term.native())
  M.displayTerm, M.redirected = M.nativeTerm, false
  term.redirect(M.nativeTerm)
  M.getDisplay()
  log.error("deviced", "display output failed: " .. tostring(problem))
  if M.ctx and M.ctx.invalidateDisplay then pcall(M.ctx.invalidateDisplay) end
  if M.ctx and M.ctx.notifications then
    pcall(function() M.ctx.notifications:push("error", "Display", "Display unavailable; using computer", 5) end)
  end
  return true
end

function M.refreshSize()
  local target=M.getTarget()
  local ok,w,h=pcall(target.getSize)
  if target~=M.getTarget() then return false end
  if not ok then M.outputFailed(target,w) return false end
  if type(w)~="number" or type(h)~="number" or w%1~=0 or h%1~=0 or w<1 or h<1 or w*h>65536 then return false end
  if w==M.display.width and h==M.display.height then return false end
  M.display.width,M.display.height=w,h
  if M.ctx and M.ctx.invalidateDisplay then M.ctx.invalidateDisplay() end
  if os.queueEvent then os.queueEvent("mintcraft_display_resize",M.display.terminalSide or M.display.monitorSide or "computer") end
  return true
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
  if ctx and ctx.scheduler and ctx.scheduler.spawn then
    sizeWorker=require("system.libraries.addon").periodic(ctx,"Display geometry",1,M.refreshSize,{budget=0.5})
  end
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
  if sizeWorker then sizeWorker.stop() sizeWorker=nil end
  if M.ctx and M.ctx.eventBus then
    for _, id in ipairs(M.listeners) do M.ctx.eventBus:off(id) end
  end
  M.listeners = {}
  M.ctx = nil
  if M.nativeTerm then
    term.redirect(M.nativeTerm)
    M.redirected = false
    M.displayTerm = M.nativeTerm
    M.getDisplay()
  end
end

function M.list()
  local rows = {}
  for _, device in pairs(M.devices) do
    local types,seen={},{}
    for kind,present in pairs(device.types or {}) do if present and type(kind)=='string' then types[#types+1]=kind seen[kind]=true end end
    if not seen[device.type] then types[#types+1]=device.type end
    table.sort(types)
    table.insert(rows, { name = device.name, type = device.type, types=types })
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

return M
