local M = {}

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

function M.read(device, methods, timeout)
  local values, errors, branches = {}, {}, {}
  for _, name in ipairs(methods) do
    if type(device[name]) == "function" then
      branches[#branches + 1] = function()
        local ok, value, err = M.bounded(function() return M.call(device, name) end, timeout or 0.15)
        if ok then values[name], errors[name] = value, err
        else errors[name] = tostring(value) end
      end
    end
  end
  if #branches > 0 then parallel.waitForAll(table.unpack(branches)) end
  return values, errors
end

function M.inventory()
  local rows = {}
  if not peripheral or not peripheral.getNames then return rows, "peripheral API unavailable" end
  local ok, names = pcall(peripheral.getNames)
  if not ok then return rows, tostring(names) end
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
  return rows
end

function M.hasType(row, name)
  for _, value in ipairs(row.types) do if value == name then return true end end
  return false
end

function M.bounded(fn, seconds)
  local timer = os.startTimer(seconds or 0.5)
  local result, finished
  parallel.waitForAny(function()
    result = table.pack(pcall(fn))
    finished = true
  end, function()
    while true do local _, id = os.pullEvent("timer") if id == timer then return end end
  end)
  os.cancelTimer(timer)
  if not finished then return false, "timeout; result uncertain" end
  return table.unpack(result, 1, result.n)
end

-- Raw workers preserve task_complete's native argument layout and may yield.
function M.periodic(ctx, name, interval, refresh, timeout)
  ctx.workerTimers=ctx.workerTimers or {}
  local runner = { ctx = ctx, dirty = true, stopped = false, interval = interval, listeners = {} }
  local pid
  pid = ctx.scheduler:spawn(name, function()
    while not runner.stopped do
      local started = os.clock()
      local ok, err = M.bounded(function() refresh(runner.dirty) end, timeout or 0.5)
      if ok then runner.dirty = false runner.error = nil runner.lastSuccess = os.clock() else
        runner.error = tostring(err)
        if runner.onError then runner.onError(runner.error) end
      end
      local timer = os.startTimer(math.max(0.05, runner.interval - (os.clock() - started)))
      ctx.workerTimers[timer]=true
      runner.timer = timer
      while not runner.stopped do
        local event, id = os.pullEvent()
        if (event == "timer" and id == timer) or (event == "mintcraft_rescan" and id == pid) then break end
      end
      os.cancelTimer(timer)
      ctx.workerTimers[timer]=nil
    end
  end, { eventMode = "raw", appId = name, permissions = {}, protected = true })
  runner.pid = pid
  function runner:rescan()
    self.dirty = true
    os.queueEvent("mintcraft_rescan", self.pid)
  end
  for _, event in ipairs({ "peripheral", "peripheral_detach" }) do
    runner.listeners[#runner.listeners + 1] = ctx.eventBus:on(event, function() runner:rescan() end)
  end
  function runner:stop()
    self.stopped = true
    if self.timer then os.cancelTimer(self.timer) ctx.workerTimers[self.timer]=nil end
    for _, id in ipairs(self.listeners) do ctx.eventBus:off(id) end
    ctx.scheduler:kill(self.pid,true)
  end
  ctx.scheduler:start(pid)
  return runner
end

return M
