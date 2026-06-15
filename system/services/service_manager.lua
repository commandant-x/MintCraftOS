local log = require("system.libraries.log")

local ServiceManager = {}
ServiceManager.__index = ServiceManager

function ServiceManager.new(ctx)
  return setmetatable({ ctx = ctx, services = {} }, ServiceManager)
end

function ServiceManager:register(name, moduleName, autostart)
  self.services[name] = {
    name = name,
    moduleName = moduleName,
    state = "stopped",
    autostart = autostart ~= false,
  }
end

function ServiceManager:start(name)
  local service = self.services[name]
  if not service then return false, "No such service" end
  if service.state == "running" then return true end

  local ok, mod = pcall(require, service.moduleName)
  if not ok then
    service.state = "crashed"
    service.error = tostring(mod)
    log.error("service", name .. ": " .. tostring(mod))
    return false, tostring(mod)
  end

  service.module = mod
  if mod.start then
    local started, err = pcall(mod.start, self.ctx)
    if not started then
      service.state = "crashed"
      service.error = tostring(err)
      log.error("service", name .. ": " .. tostring(err))
      return false, tostring(err)
    end
  end

  service.state = "running"
  service.error = nil
  log.info("service", name .. " running")
  return true
end

function ServiceManager:stop(name)
  local service = self.services[name]
  if not service then return false, "No such service" end
  if service.module and service.module.stop then pcall(service.module.stop, self.ctx) end
  service.state = "stopped"
  log.info("service", name .. " stopped")
  return true
end

function ServiceManager:startAutostart()
  for name, service in pairs(self.services) do
    if service.autostart then self:start(name) end
  end
end

function ServiceManager:list()
  local rows = {}
  for _, service in pairs(self.services) do
    table.insert(rows, {
      name = service.name,
      state = service.state,
      autostart = service.autostart,
      error = service.error,
    })
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

return ServiceManager
