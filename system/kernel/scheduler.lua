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
  }

  self.processes[pid] = process
  return pid
end

function Scheduler:start(pid)
  local process = self.processes[pid]
  if not process then return false, "No such process" end
  self:resume(process, { name = "mintcraft_start", args = {} })
  return true
end

function Scheduler:resume(process, event)
  if process.state ~= "ready" then return end

  local ok, filterOrErr = coroutine.resume(process.co, event)
  if not ok then
    process.state = "crashed"
    process.error = tostring(filterOrErr)
    log.error("process", process.name .. ": " .. tostring(filterOrErr))
    if process.window then process.window.closed = true end
    if self.ctx and self.ctx.notifications then
      self.ctx.notifications:push("error", "App crashed", process.name, 5)
    end
    return
  end

  if coroutine.status(process.co) == "dead" then
    process.state = "stopped"
  else
    process.filter = filterOrErr
  end
end

function Scheduler:dispatch(event)
  for _, process in pairs(self.processes) do
    if process.state == "ready" and eventMatches(process.filter, event) then
      self:resume(process, event)
    end
  end
end

function Scheduler:kill(pid)
  local process = self.processes[pid]
  if not process then return false, "No such process" end
  process.state = "killed"
  if process.window then process.window.closed = true end
  log.warn("process", "killed " .. process.name .. " #" .. tostring(pid))
  return true
end

function Scheduler:attachWindow(pid, win)
  local process = self.processes[pid]
  if process then process.window = win end
end

function Scheduler:list()
  local rows = {}
  for _, process in pairs(self.processes) do
    table.insert(rows, {
      pid = process.pid,
      name = process.name,
      state = process.state,
      filter = process.filter,
      error = process.error,
      permissions = process.permissions,
      windowId = process.window and process.window.id or nil,
    })
  end
  table.sort(rows, function(a, b) return a.pid < b.pid end)
  return rows
end

function Scheduler:makeContext(pid)
  local scheduler = self
  return {
    pid = pid,
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
      return scheduler:kill(targetPid)
    end,
  }
end

return Scheduler
