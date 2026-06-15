local log = require("system.libraries.log")

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

  if monitor.setTextScale then monitor.setTextScale(0.5) end
  if monitor.setBackgroundColor then monitor.setBackgroundColor(colors.black) end
  if monitor.clear then monitor.clear() end

  if not M.nativeTerm then M.nativeTerm = term.current() end
  term.redirect(monitor)
  M.redirected = true
  local w, h = term.getSize()
  M.display = {
    target = "monitor",
    scale = 0.5,
    width = w,
    height = h,
    monitorSide = side or "unknown",
  }
  log.info("deviced", "using monitor " .. tostring(M.display.monitorSide) .. " at " .. tostring(w) .. "x" .. tostring(h) .. " scale 0.5")
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
