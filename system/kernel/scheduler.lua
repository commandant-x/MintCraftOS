local log = require("system.libraries.log")

local Scheduler = {}
Scheduler.__index = Scheduler

local function eventMatches(filter, event)
  return filter == nil or filter == event.name
end

function Scheduler.new()
  return setmetatable({ processes = {}, nextPid = 1, ctx = nil }, Scheduler)
end

function Scheduler:spawn(name, fn, meta)
  local pid = self.nextPid
  self.nextPid = self.nextPid + 1

  local process = {
    pid = pid,
    name = name,
    co = coroutine.create(fn),
    state = "ready",
    filter = nil,
    meta = meta or {},
    permissions = (meta and meta.permissions) or {},
    startedAt = os.epoch("utc"),
    window = nil,
    windows = {},
  }

  self.processes[pid] = process
  return pid
end

function Scheduler:start(pid)
  local process = self.processes[pid]
  if not process then return false, "No such process" end
  self:resume(process, { name = "mintcraft_start", args = {} })
  if process.state == "crashed" then return false, process.error end
  return true
end

function Scheduler:closeWindows(process)
  for _, win in ipairs(process.windows) do win.closed = true end
  if not process.cleaned then
    process.cleaned = true
    for _, callback in ipairs(process.cleanup or {}) do
      local ok, err = pcall(callback, process.state)
      if not ok then log.error("process", "cleanup: " .. tostring(err)) end
    end
  end
end

function Scheduler:resume(process, event)
  if process.state ~= "ready" then return end

  local ok, filterOrErr
  if process.meta.eventMode == "raw" then
    if event.raw then ok, filterOrErr = coroutine.resume(process.co, table.unpack(event.raw,1,event.raw.n or #event.raw))
    else ok, filterOrErr = coroutine.resume(process.co, event.name, table.unpack(event.args, 1, event.args.n or #event.args)) end
  else
    ok, filterOrErr = coroutine.resume(process.co, event)
  end
  if not ok then
    self:crash(process.pid, filterOrErr)
    return
  end

  if coroutine.status(process.co) == "dead" then
    process.state = "stopped"
    self:closeWindows(process)
  else
    process.filter = filterOrErr
  end
end

function Scheduler:crash(pid, err)
  local process = self.processes[pid]
  if not process or process.state ~= "ready" then return false, "Process not running" end
  process.state = "crashed"
  process.error = tostring(err)
  log.error("process", process.name .. ": " .. tostring(err))
  self:closeWindows(process)
  if self.ctx and self.ctx.notifications then
    self.ctx.notifications:push("error", "App crashed", process.name, 5)
  end
  return true
end

function Scheduler:dispatch(event)
  for _, process in pairs(self.processes) do
    local match = process.meta.eventMode == "raw" and event.raw and {name=event.raw[1]} or event
    if process.state == "ready" and eventMatches(process.filter, match) then
      self:resume(process, event)
    end
  end
end

function Scheduler:kill(pid, serviceStop)
  local process = self.processes[pid]
  if not process or process.state ~= "ready" then return false, "Process not running" end
  if process.meta.protected and serviceStop~=true then return false,"critical worker; use its service controls" end
  process.state = "killed"
  self:closeWindows(process)
  log.warn("process", "killed " .. process.name .. " #" .. tostring(pid))
  return true
end

function Scheduler:attachWindow(pid, win)
  local process = self.processes[pid]
  if process and process.state == "ready" then
    process.window = win
    table.insert(process.windows, win)
  else
    win.closed = true
  end
end

function Scheduler:list()
  local rows = {}
  for _, process in pairs(self.processes) do
    table.insert(rows, {
      pid = process.pid,
      name = process.name,
      state = process.state,
      appId = process.meta and process.meta.appId or nil,
      filter = process.filter,
      error = process.error,
      permissions = process.permissions,
      windowId = process.window and process.window.id or nil,
      startedAt = process.startedAt,
    })
  end
  table.sort(rows, function(a, b) return a.pid < b.pid end)
  return rows
end

function Scheduler:makeContext(pid)
  local scheduler = self
  return {
    pid = pid,
    onCleanup = function(callback)
      local process = scheduler.processes[pid]
      process.cleanup = process.cleanup or {}
      table.insert(process.cleanup, callback)
    end,
    pullEvent = function(filter)
      while true do
        local event = coroutine.yield(filter)
        if not filter or event.name == filter then return event end
      end
    end,
    listProcesses = function()
      return scheduler:list()
    end,
    kill = function(targetPid)
      log.warn("process", "pid " .. tostring(pid) .. " requested kill " .. tostring(targetPid))
      return scheduler:kill(targetPid)
    end,
  }
end

return Scheduler
