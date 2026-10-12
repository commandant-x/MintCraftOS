local log = require("system.libraries.log")
local profile = require("system.libraries.profile")

local ServiceManager = {}
ServiceManager.__index = ServiceManager

function ServiceManager.new(ctx)
  return setmetatable({ ctx = ctx, services = {}, order = {} }, ServiceManager)
end

function ServiceManager:register(name, moduleName, autostart)
  if not self.services[name] then table.insert(self.order, name) end
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
  if not profile.serviceEnabled(name) then return false,"Disabled by app profile" end

  local ok, mod = pcall(require, service.moduleName)
  if not ok then
    service.state = "crashed"
    service.error = tostring(mod)
    log.error("service", name .. ": " .. tostring(mod))
    return false, tostring(mod)
  end

  service.module = mod
  if mod.start then
    local started, result, detail = pcall(mod.start, self.ctx)
    if not started or result == false then
      local err = started and (detail or "start refused") or result
      if mod.stop then pcall(mod.stop, self.ctx) end
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
  if service.module and service.module.stop then
    local ok, result, detail = pcall(service.module.stop, self.ctx)
    if not ok or result == false then
      -- A refused stop leaves its worker running (for example, pending rescue).
      if not ok then service.state = "crashed" end
      service.error = tostring(ok and (detail or "stop refused") or result)
      log.error("service", name .. ": " .. service.error)
      return false, service.error
    end
  end
  service.state = "stopped"
  log.info("service", name .. " stopped")
  return true
end

function ServiceManager:startAutostart()
  for _, name in ipairs(self.order) do
    local service = self.services[name]
    if service.autostart and profile.serviceEnabled(name) then self:start(name) end
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
