local log = require("system.libraries.log")

local M = {
  devices = {},
  redirected = false,
  nativeTerm = nil,
}

local function scan()
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

local function useMonitorIfPresent()
  if not peripheral or not peripheral.find then return false end
  local monitor = peripheral.find("monitor")
  if not monitor then return false end

  if monitor.setTextScale then monitor.setTextScale(0.5) end
  if monitor.setBackgroundColor then monitor.setBackgroundColor(colors.black) end
  if monitor.clear then monitor.clear() end

  M.nativeTerm = term.current()
  term.redirect(monitor)
  M.redirected = true
  log.info("deviced", "using attached monitor as display")
  return true
end

function M.start(ctx)
  scan()
  useMonitorIfPresent()
  if ctx and ctx.eventBus then
    ctx.eventBus:on("peripheral", function()
      scan()
      if not M.redirected then useMonitorIfPresent() end
    end)
    ctx.eventBus:on("peripheral_detach", function()
      scan()
    end)
  end
  log.info("deviced", "device service ready")
end

function M.stop()
  if M.redirected and M.nativeTerm then
    term.redirect(M.nativeTerm)
    M.redirected = false
  end
end

function M.list()
  scan()
  local rows = {}
  for _, device in pairs(M.devices) do table.insert(rows, device) end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

return M
