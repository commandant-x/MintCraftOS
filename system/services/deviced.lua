local log = require("system.libraries.log")
local config = require("system.libraries.config")

local M = {
  devices = {},
  redirected = false,
  nativeTerm = nil,
  display = {
    target = "computer",
    scale = nil,
    width = 0,
    height = 0,
    monitorSide = nil,
  },
  ctx = nil,
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
    for _, name in ipairs(peripheral.getNames()) do
      devices[name] = {
        name = name,
        type = peripheral.getType(name),
      }
    end
  end
  M.devices = devices
  return devices
end

function M.useMonitor()
  if not peripheral or not peripheral.find then return false end
  local monitor, side = peripheral.find("monitor")
  if not monitor then return false end

  local scale = readScale()
  if monitor.setTextScale then monitor.setTextScale(scale) end
  if monitor.setBackgroundColor then monitor.setBackgroundColor(colors.black) end
  if monitor.clear then monitor.clear() end

  if not M.nativeTerm then M.nativeTerm = term.current() end
  term.redirect(monitor)
  M.redirected = true
  local w, h = term.getSize()
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
  M.scan()
  local oldW, oldH = M.display.width, M.display.height
  local ok = M.useMonitor()
  if not ok then
    if M.redirected and M.nativeTerm then
      term.redirect(M.nativeTerm)
    end
    M.redirected = false
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

function M.getDisplay()
  if not M.redirected then
    local w, h = term.getSize()
    M.display = {
      target = "computer",
      scale = nil,
      width = w,
      height = h,
      monitorSide = nil,
    }
  end
  return M.display
end

function M.start(ctx)
  M.ctx = ctx
  M.refreshDisplay()
  if ctx and ctx.eventBus then
    ctx.eventBus:on("peripheral", function()
      M.refreshDisplay()
    end)
    ctx.eventBus:on("peripheral_detach", function()
      M.refreshDisplay()
    end)
  end
  log.info("deviced", "device service ready")
end

function M.stop()
  if M.redirected and M.nativeTerm then
    term.redirect(M.nativeTerm)
    M.redirected = false
    M.getDisplay()
  end
end

function M.list()
  M.scan()
  local rows = {}
  for _, device in pairs(M.devices) do table.insert(rows, device) end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

return M
