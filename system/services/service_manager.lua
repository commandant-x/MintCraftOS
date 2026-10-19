local log = require("system.libraries.log")
local profile = require("system.libraries.profile")

local ServiceManager = {}
ServiceManager.__index = ServiceManager
local protected={deviced=true,notifd=true,logd=true,securityd=true}

function ServiceManager:isProtected(name) return protected[name]==true end
function ServiceManager:requestAction(actor,action,name)
  if not self.control then self.control=require("system.services.service_control").new(self) end
  return self.control:request(actor,action,name)
end
function ServiceManager:controlStatus() return self.control and self.control:status() or {busy=false} end

function ServiceManager.new(ctx)
  return setmetatable({ ctx = ctx, services = {}, order = {}, transitions={} }, ServiceManager)
end

function ServiceManager:withTransition(name,fn)
  if type(name)~="string" or not self.services[name] then return false,"No such service" end
  local owner=coroutine.running()
  local lock=self.transitions[name]
  if lock then
    if lock.owner~=owner then return false,"Service transition in progress: "..name end
    return fn()
  end
  self.transitions[name]={owner=owner}
  local result=table.pack(pcall(fn))
  self.transitions[name]=nil
  if not result[1] then return false,tostring(result[2]) end
  return table.unpack(result,2,result.n)
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

function ServiceManager:start(name) return self:withTransition(name,function() return self:_start(name) end) end
function ServiceManager:_start(name)
  local service = self.services[name]
  if not service then return false, "No such service" end
  if service.uncertain then return false,"Service state uncertain; inspect and complete cleanup before starting" end
  if service.started then return true end
  if not profile.serviceEnabled(name) then return false,"Disabled by app profile" end

  local ok, mod = pcall(require, service.moduleName)
  if not ok then
    service.state = "crashed"
    service.error = tostring(mod)
    log.error("service", name .. ": " .. tostring(mod))
    return false, tostring(mod)
  end

  if type(mod) ~= "table" then
    service.state, service.error = "crashed", "Invalid service module"
    return false, service.error
  end
  service.module = mod
  if type(mod.start) == "function" then
    local started, result, detail = pcall(mod.start, self.ctx)
    if not started or result == false then
      local err = started and (detail or "start refused") or result
      local cleaned,result=false,nil
      if type(mod.stop) == "function" then cleaned,result=pcall(mod.stop,self.ctx) end
      service.uncertain=not cleaned or result==false
      if service.uncertain then err=tostring(err).."; startup cleanup unconfirmed" end
      service.state = "crashed"
      service.error = tostring(err)
      log.error("service", name .. ": " .. tostring(err))
      return false, tostring(err)
    end
  end

  service.state = "running"
  service.started = true
  service.workerPid = nil
  for pid, worker in pairs(self.ctx.scheduler and self.ctx.scheduler.processes or {}) do
    if worker.name == name and worker.meta and worker.meta.appId == name then
      if not service.workerPid or pid > service.workerPid then service.workerPid = pid end
    end
  end
  service.error = nil
  service.uncertain = false
  log.info("service", name .. " running")
  return true
end

function ServiceManager:stop(name) return self:withTransition(name,function() return self:_stop(name) end) end
function ServiceManager:_stop(name)
  local service = self.services[name]
  if not service then return false, "No such service" end
  if service.uncertain and (not service.module or type(service.module.stop)~="function") then
    return false,"Service cleanup unavailable; inspect uncertain state before recovery"
  end
  if service.module and type(service.module.stop) == "function" then
    local ok, result, detail = pcall(service.module.stop, self.ctx)
    if not ok or result == false then
      -- A refused stop leaves its worker running (for example, pending rescue).
      if not ok then service.state = "crashed" service.uncertain=true end
      service.error = tostring(ok and (detail or "stop refused") or result)
      log.error("service", name .. ": " .. service.error)
      return false, service.error
    end
  end
  service.state = "stopped"
  service.started, service.error = false, nil
  service.uncertain=false
  log.info("service", name .. " stopped")
  return true
end

function ServiceManager:startAutostart()
  for _, name in ipairs(self.order) do
    local service = self.services[name]
    if service.autostart and profile.serviceEnabled(name) then self:start(name) end
  end
end

-- health/status must return cached data only: never call acquisition from a draw.
function ServiceManager:health(service)
  local result = {state=service.state,error=service.error,lastSuccess=service.lastSuccess}
  if not service.started then return result end
  if service.state == "crashed" then return result end
  result.state = "running"
  local mod = service.module
  local query = type(mod.health) == "function" and mod.health or type(mod.status) == "function" and mod.status
  local ok, snap = true, {}
  if query then ok, snap = pcall(query, self.ctx) end
  if not ok then result.state, result.error = "degraded", tostring(snap) return result end
  if type(snap) ~= "table" then snap = {} end
  result.lastSuccess, result.pid = snap.lastSuccess or service.lastSuccess, snap.pid or snap.workerPid or service.workerPid
  service.lastSuccess = result.lastSuccess
  local state = snap.state or snap.status
  local problem = snap.error
  if not problem and snap.ok == false then problem = snap.lastFault or snap.reason end
  if not problem and type(snap.errors) == "table" then
    for _, err in pairs(snap.errors) do if err then problem = tostring(err) break end end
  end
  if problem or snap.ok == false or snap.available == false or state == "degraded" or state == "failsafe" then
    result.state, result.error = "degraded", problem or snap.reason or state or "Unavailable"
  else result.error = service.error end
  if state == "crashed" or state == "stopped" or state == "killed" then
    result.state, result.error = "crashed", problem or "Worker " .. state
  end
  local processes = self.ctx.scheduler and self.ctx.scheduler.processes
  if result.pid and processes then
    local worker = processes[result.pid]
    if not worker or worker.state ~= "ready" then
      result.state, result.error = "crashed", worker and worker.error or "Worker stopped"
    end
  end
  return result
end

function ServiceManager:list()
  local rows = {}
  for _, service in pairs(self.services) do
    local health = self:health(service)
    table.insert(rows, {
      name = service.name,
      state = health.state,
      autostart = service.autostart,
      error = health.error,
      lastSuccess = health.lastSuccess,
      pid = health.pid,
      protected = self:isProtected(service.name),
      transitioning = self.transitions[service.name]~=nil,
      uncertain = service.uncertain==true,
    })
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

return ServiceManager
