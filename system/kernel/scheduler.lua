local log = require("system.libraries.log")
local permissions = require("system.security.permissions")

local Scheduler = {}
Scheduler.__index = Scheduler

local function eventMatches(filter, event)
  return filter == nil or filter == event.name
end

function Scheduler.new()
  return setmetatable({ processes = {}, nextPid = 1, ctx = nil, history={}, historyLimit=64, timerOwners={} }, Scheduler)
end

local function safeLog(level,source,message)
  if type(log[level])=="function" then pcall(log[level],source,message) end
end

local function milliseconds()
  if not os.epoch then return nil end
  local ok,value=pcall(os.epoch,"utc")
  return ok and type(value)=="number" and value or nil
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
    resumes = 0,
    runtimeMs = 0,
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
    local cleanup=process.cleanup or {}
    process.cleanup=nil
    for _, callback in ipairs(cleanup) do
      local ok, err = pcall(callback, process.state)
      if not ok then safeLog("error","process","cleanup: "..tostring(err)) end
    end
    process.windowId=process.window and process.window.id
    process.co,process.window,process.windows,process.filter=nil,nil,{},nil
    process.finishedAt=milliseconds()
    for id,owner in pairs(self.timerOwners) do if owner==process.pid then
      if os.cancelTimer then pcall(os.cancelTimer,id) end self.timerOwners[id]=nil
    end end
    self.history[#self.history+1]=process.pid
    while #self.history>self.historyLimit do
      local old=table.remove(self.history,1)
      if self.processes[old] and self.processes[old].state~="ready" then self.processes[old]=nil end
    end
  end
end

function Scheduler:resume(process, event)
  if process.state ~= "ready" then return end

  local ok, filterOrErr
  local started=milliseconds()
  process.resumes=process.resumes+1
  if process.meta.eventMode == "raw" then
    if event.raw then ok, filterOrErr = coroutine.resume(process.co, table.unpack(event.raw,1,event.raw.n or #event.raw))
    else ok, filterOrErr = coroutine.resume(process.co, event.name, table.unpack(event.args, 1, event.args.n or #event.args)) end
  else
    ok, filterOrErr = coroutine.resume(process.co, event)
  end
  local finished=milliseconds()
  if started and finished then process.runtimeMs=process.runtimeMs+math.max(0,finished-started) process.runtimeAvailable=true end
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
  self:closeWindows(process)
  safeLog("error","process",process.name..": "..tostring(err))
  if self.ctx and self.ctx.notifications then
    pcall(self.ctx.notifications.push,self.ctx.notifications,"error", "App crashed", process.name, 5)
  end
  return true
end

function Scheduler:dispatch(event)
  local timerOwner=event.name=="timer" and self.timerOwners[event.args[1]]
  for _, process in pairs(self.processes) do
    local match = process.meta.eventMode == "raw" and event.raw and {name=event.raw[1]} or event
    if process.state == "ready" and eventMatches(process.filter, match) then
      self:resume(process, event)
    end
  end
  if timerOwner then
    local process=self.processes[timerOwner]
    if process then for _,win in ipairs(process.windows) do win.dirty=true end end
    self.timerOwners[event.args[1]]=nil
  end
end

function Scheduler:kill(pid, serviceStop)
  local process = self.processes[pid]
  if not process or process.state ~= "ready" then return false, "Process not running" end
  if process.meta.protected and serviceStop~=true then return false,"critical worker; use its service controls" end
  process.state = "killed"
  self:closeWindows(process)
  safeLog("warn","process","killed "..process.name.." #"..tostring(pid))
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
      permissions = {table.unpack(process.permissions)},
      windowId = process.window and process.window.id or process.windowId,
      startedAt = process.startedAt,
      finishedAt = process.finishedAt,
      resumes = process.resumes,
      runtimeMs = process.runtimeAvailable and process.runtimeMs or nil,
      protected = process.meta.protected==true,
      eventMode = process.meta.eventMode or "structured",
    })
  end
  table.sort(rows, function(a, b) return a.pid < b.pid end)
  return rows
end

function Scheduler:makeContext(pid)
  local scheduler = self
  return {
    pid = pid,
    startTimer = function(seconds)
      local id=os.startTimer(seconds) scheduler.timerOwners[id]=pid return id
    end,
    cancelTimer = function(id)
      if scheduler.timerOwners[id]==pid then scheduler.timerOwners[id]=nil if os.cancelTimer then os.cancelTimer(id) end end
    end,
    invalidate = function()
      local process=scheduler.processes[pid]
      if process then for _,win in ipairs(process.windows) do win.dirty=true end end
    end,
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
      if permissions.require then
        local process=scheduler.processes[pid]
        local ok=permissions.require({pid=pid,appId=process.meta.appId,permissions=process.permissions},"process.list")
        if not ok then return {} end
      end
      return scheduler:list()
    end,
    kill = function(targetPid)
      local process=scheduler.processes[pid]
      if not process or process.state~="ready" then return false,"Owner not running" end
      if not permissions.require then return false,"Permission service unavailable" end
      local ok,reason=permissions.require({pid=pid,appId=process.meta.appId,permissions=process.permissions},"process.kill",tostring(targetPid))
      if not ok then return false,reason end
      safeLog("warn","process","pid "..tostring(pid).." requested kill "..tostring(targetPid))
      return scheduler:kill(targetPid)
    end,
  }
end

return Scheduler
