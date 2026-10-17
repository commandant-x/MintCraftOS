local M = {}
local settings = { concurrency = 4, readsPerTick = 16 }
local counters = { reads = 0, readSeconds = 0, timeouts = 0, overruns = 0,
  peakInFlight = 0, inventoryScans = 0, readsByPriority = {} }
local windowStart, windowReads = 0, 0
local inventoryCache
local activeReads = {}
local queuedReads = {}
local runners = {}
local scopes = setmetatable({}, { __mode = "k" })
local priorities = { diagnostics = 1, contacts = 2, commands = 3, flight = 4 }
local ticketSerial = 0
local function currentScope() return scopes[coroutine.running()] end
local function priority(value)
  if value == nil then return priorities.contacts end
  assert(priorities[value], "invalid acquisition priority")
  return priorities[value]
end
local function live(scope)
  while scope do
    if scope.closed then return false end
    scope = scope.parent
  end
  return true
end
local function startTimer(seconds, scope)
  scope = scope or currentScope()
  local id = os.startTimer(seconds)
  if scope then
    scope.timers = scope.timers or {}
    scope.timers[id] = scope
    if scope.workerTimers then scope.workerTimers[id] = true end
  end
  return id
end
local function cancelTimer(id, scope)
  scope = scope or currentScope()
  os.cancelTimer(id)
  if scope then
    if scope.timers then scope.timers[id] = nil end
    if scope.workerTimers then scope.workerTimers[id] = nil end
  end
end
local function closeScope(scope)
  scope.closed = true
  for id, owner in pairs(scope.timers or {}) do
    if not live(owner) then cancelTimer(id, scope) end
  end
  for token, lease in pairs(activeReads) do if not live(lease.scope) then activeReads[token] = nil end end
  for ticket, entry in pairs(queuedReads) do if not live(entry.scope) then queuedReads[ticket] = nil end end
end
local function childScope(parent)
  return { parent = parent, priority = parent and parent.priority,
    timers = parent and parent.timers or {}, workerTimers = parent and parent.workerTimers }
end
-- Lua 5.2 pcall may yield. Restore ownership before propagating branch failures.
local function scoped(fn, ...)
  local thread, parent = coroutine.running(), currentScope()
  local scope = childScope(parent)
  scopes[thread] = scope
  local result = table.pack(pcall(fn, ...))
  scopes[thread] = parent
  closeScope(scope)
  if not result[1] then error(result[2], 0) end
  return table.unpack(result, 2, result.n)
end
local function activeCount()
  local count = 0
  for token, lease in pairs(activeReads) do
    if not live(lease.scope) then activeReads[token] = nil else count = count + 1 end
  end
  return count
end

local function firstTicket(ticket)
  local selected = queuedReads[ticket]
  for key, other in pairs(queuedReads) do
    if not live(other.scope) then queuedReads[key] = nil
    elseif other.priority > selected.priority or
      (other.priority == selected.priority and other.serial < selected.serial) then return false end
  end
  return true
end

function M.configure(options)
  for _, key in ipairs({ "concurrency", "readsPerTick" }) do
    local value = options and options[key]
    if type(value) == "number" and value == value and value >= 1 and value < math.huge then
      settings[key] = math.floor(value)
    end
  end
end

function M.metrics()
  local result = M.copy(counters)
  result.inFlight = activeCount()
  result.queue = 0
  result.queueByPriority = {}
  for token, ticket in pairs(queuedReads) do
    if live(ticket.scope) then
      result.queue = result.queue + 1
      for name, rank in pairs(priorities) do
        if rank == ticket.priority then result.queueByPriority[name] = (result.queueByPriority[name] or 0) + 1 end
      end
    else queuedReads[token] = nil end
  end
  result.concurrency, result.readsPerTick = settings.concurrency, settings.readsPerTick
  result.budgetWindowSeconds = 0.05
  result.runners = {}
  for runner, name in pairs(runners) do result.runners[name] = runner:metrics() end
  return result
end

-- Bound each fan-out level; callers must also use this for device branches.
function M.parallel(branches, limit)
  limit = limit or settings.concurrency
  assert(type(limit) == "number" and limit >= 1 and limit < math.huge, "invalid concurrency")
  return scoped(function()
  local nextIndex, workers = 1, {}
  local scope = currentScope()
  for _ = 1, math.min(#branches, math.floor(limit)) do
    workers[#workers + 1] = function()
      scopes[coroutine.running()] = scope
      while nextIndex <= #branches do
        local index = nextIndex
        nextIndex = index + 1
        branches[index]()
      end
    end
  end
  if #workers > 0 then parallel.waitForAll(table.unpack(workers)) end
  end)
end

function M.invalidateInventory()
  inventoryCache = nil
end

function M.finite(value)
  return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function M.copy(value, depth, seen)
  if type(value) ~= "table" then return value end
  depth = depth or 0
  if depth > 12 then return nil end
  seen = seen or {}
  if seen[value] then return nil end
  seen[value] = true
  local out = {}
  for k, v in pairs(value) do
    if type(v) ~= "function" and type(v) ~= "userdata" and type(v) ~= "thread" then out[k] = M.copy(v, depth + 1, seen) end
  end
  seen[value] = nil
  return out
end

function M.vec(value)
  if type(value) ~= "table" then return nil end
  local out = { x = value.x or value[1], y = value.y or value[2], z = value.z or value[3] }
  if M.finite(out.x) and M.finite(out.y) and M.finite(out.z) then return out end
end

function M.measure(value, unit, frame, source, time)
  return { value = M.copy(value), valid = value ~= nil and (type(value) ~= "number" or M.finite(value)),
    unit = unit, frame = frame, source = source, timestamp = time or os.clock() }
end

function M.call(device, method, ...)
  if not device or type(device[method]) ~= "function" then return nil, method .. " unavailable" end
  local ok, value = pcall(device[method], ...)
  if not ok then return nil, tostring(value) end
  return value
end

local function read(device, methods, timeout, options)
  local scope = currentScope()
  local rank = options and options.priority
  if rank == nil and scope then rank = scope.priority end
  local readPriority = priority(rank)
  local values, errors, branches, timings = {}, {}, {}, {}
  for _, name in ipairs(methods) do
    if type(device[name]) == "function" then
      local ticket = {}
      ticketSerial = ticketSerial + 1
      queuedReads[ticket] = { scope = scope, priority = readPriority, serial = ticketSerial }
      local queuedAt = os.clock()
      branches[#branches + 1] = function()
        while true do
          if os.clock() - windowStart >= 0.05 then windowStart, windowReads = os.clock(), 0 end
          if activeCount() < settings.concurrency and windowReads < settings.readsPerTick and firstTicket(ticket) then break end
          local delay = windowReads >= settings.readsPerTick and math.max(0.001, 0.05 - (os.clock() - windowStart)) or 0.01
          local timer = startTimer(delay)
          repeat local _, id = os.pullEvent("timer") until id == timer
          cancelTimer(timer)
        end
        windowReads = windowReads + 1
        queuedReads[ticket] = nil
        local started = os.clock()
        local token = {}
        activeReads[token] = { scope = currentScope() }
        counters.reads = counters.reads + 1
        for label, rank in pairs(priorities) do
          if rank == readPriority then counters.readsByPriority[label] = (counters.readsByPriority[label] or 0) + 1 end
        end
        local scope = currentScope()
        while scope do scope.reads = (scope.reads or 0) + 1 scope = scope.parent end
        counters.peakInFlight = math.max(counters.peakInFlight, activeCount())
        local ok, value, err = M.bounded(function() return M.call(device, name) end, timeout or 0.15)
        activeReads[token] = nil
        counters.readSeconds = counters.readSeconds + os.clock() - started
        if not ok and tostring(value):find("timeout", 1, true) then counters.timeouts = counters.timeouts + 1 end
        if ok then values[name], errors[name] = value, err
        else errors[name] = tostring(value) end
        timings[name] = { startedAt = started, receivedAt = os.clock(), queueSeconds = started - queuedAt }
      end
    end
  end
  M.parallel(branches)
  return values, errors, timings
end

function M.read(device, methods, timeout, options)
  return scoped(read, device, methods, timeout, options)
end

-- true always forces discovery; several services passing true may repeat it.
-- A coordinated rescan can invalidate once, then let consumers call inventory().
function M.inventory(force)
  if force then M.invalidateInventory() end
  if inventoryCache then
    local result = {}
    for i, row in ipairs(inventoryCache) do result[i] = M.copy(row) result[i].device = row.device end
    return result
  end
  local rows = {}
  if not peripheral or not peripheral.getNames then return rows, "peripheral API unavailable" end
  local ok, names = pcall(peripheral.getNames)
  if not ok then return rows, tostring(names) end
  counters.inventoryScans = counters.inventoryScans + 1
  table.sort(names)
  for _, name in ipairs(names) do
    local types = table.pack(pcall(peripheral.getType, name))
    local methodsOk, methods = pcall(peripheral.getMethods, name)
    local wrapOk, device = pcall(peripheral.wrap, name)
    if types[1] and methodsOk and wrapOk and device then
      local row = { name = name, types = {}, methods = methods or {}, set = {}, device = device }
      for i = 2, types.n do if types[i] then row.types[#row.types + 1] = types[i] end end
      for _, method in ipairs(row.methods) do row.set[method] = true end
      rows[#rows + 1] = row
    end
  end
  inventoryCache = rows
  -- Device wrappers contain functions and must retain their callable identity.
  local result = {}
  for i, row in ipairs(rows) do
    result[i] = M.copy(row)
    result[i].device = row.device
  end
  return result
end

function M.hasType(row, name)
  for _, value in ipairs(row.types) do if value == name then return true end end
  return false
end

function M.bounded(fn, seconds)
  local result, finished
  local parent = currentScope()
  local scope = childScope(parent)
  local timer = startTimer(seconds or 0.5, scope)
  parallel.waitForAny(function()
    scopes[coroutine.running()] = scope
    result = table.pack(pcall(fn))
    finished = true
  end, function()
    while true do local _, id = os.pullEvent("timer") if id == timer then return end end
  end)
  closeScope(scope)
  if not finished then return false, "timeout; result uncertain" end
  return table.unpack(result, 1, result.n)
end

-- Raw workers preserve task_complete's native argument layout and may yield.
function M.periodic(ctx, name, interval, refresh, timeout)
  local options = type(timeout) == "table" and timeout or { budget = timeout }
  ctx.workerTimers=ctx.workerTimers or {}
  local runner = { ctx = ctx, dirty = true, stopped = false, interval = interval, listeners = {} }
  priority(options.priority)
  runner.scope = { priority = options.priority, timers = {}, workerTimers = ctx.workerTimers }
  runner.stats = { cycles = 0, overruns = 0, seconds = 0, reads = 0 }
  local pid
  pid = ctx.scheduler:spawn(name, function()
    scopes[coroutine.running()] = runner.scope
    while not runner.stopped do
      local started = os.clock()
      runner.startedAt = started
      local reads, generation = runner.scope.reads or 0, runner.generation
      local cycle = childScope(runner.scope)
      scopes[coroutine.running()] = cycle
      local ok, err
      if options.budget then ok, err = M.bounded(function() refresh(runner.dirty) end, options.budget)
      else ok, err = pcall(refresh, runner.dirty) end
      scopes[coroutine.running()] = runner.scope
      closeScope(cycle)
      runner.stats.cycles = runner.stats.cycles + 1
      runner.stats.seconds = os.clock() - started
      runner.stats.reads = (runner.scope.reads or 0) - reads
      if runner.stats.seconds > runner.interval then
        runner.stats.overruns = runner.stats.overruns + 1
        counters.overruns = counters.overruns + 1
      end
      if ok then runner.dirty = runner.generation ~= generation runner.error = nil runner.lastSuccess = os.clock() else
        runner.error = tostring(err)
        if options.onPartial then options.onPartial(runner.error) end
        if runner.onError then runner.onError(runner.error) end
      end
      local timer = startTimer(math.max(0.05, runner.interval - (os.clock() - started)))
      runner.timer = timer
      while not runner.stopped do
        local event, id = os.pullEvent()
        if (event == "timer" and id == timer) or (event == "mintcraft_rescan" and id == pid) then break end
      end
      cancelTimer(timer)
    end
  end, { eventMode = "raw", appId = name, permissions = {}, protected = true })
  runner.pid = pid
  -- Scheduler cleanup runs for direct kill, coroutine failure and normal exit.
  local function cleanup()
    runner.stopped = true
    runners[runner] = nil
    closeScope(runner.scope)
    for _, id in ipairs(runner.listeners) do ctx.eventBus:off(id) end
    runner.listeners = {}
    activeCount()
    for token, ticket in pairs(queuedReads) do if not live(ticket.scope) then queuedReads[token] = nil end end
  end
  if ctx.scheduler.makeContext then ctx.scheduler:makeContext(pid).onCleanup(cleanup) end
  function runner:rescan()
    M.invalidateInventory()
    self.generation = (self.generation or 0) + 1
    self.dirty = true
    os.queueEvent("mintcraft_rescan", self.pid)
  end
  function runner:metrics()
    local result = M.copy(self.stats)
    result.interval, result.priority = self.interval, options.priority or "contacts"
    result.startedAt, result.lastSuccess, result.error = self.startedAt, self.lastSuccess, self.error
    return result
  end
  for _, event in ipairs({ "peripheral", "peripheral_detach" }) do
    runner.listeners[#runner.listeners + 1] = ctx.eventBus:on(event, function() runner:rescan() end)
  end
  function runner:stop()
    cleanup()
    ctx.scheduler:kill(self.pid,true)
  end
  runners[runner] = name
  ctx.scheduler:start(pid)
  return runner
end

return M
