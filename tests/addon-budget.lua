package.path = "./?.lua;" .. package.path
local now, serial, timers, events = 0, 0, {}, {}
os.clock = function() return now end
os.startTimer = function(delay) serial = serial + 1 timers[serial] = now + delay return serial end
os.cancelTimer = function(id) timers[id] = nil end
os.pullEvent = function(filter) return coroutine.yield(filter) end
os.queueEvent = function(...) events[#events + 1] = table.pack(...) end
local function wait(any, ...)
  local threads, filters, event = {}, {}, table.pack()
  for i, fn in ipairs({...}) do threads[i] = coroutine.create(fn) end
  while true do
    local alive = 0
    for i, thread in ipairs(threads) do
      if coroutine.status(thread) ~= "dead" then
        if not filters[i] or filters[i] == event[1] then
          local ok, filter = coroutine.resume(thread, table.unpack(event, 1, event.n))
          assert(ok, filter) filters[i] = filter
        end
        if coroutine.status(thread) == "dead" then if any then return end
        else alive = alive + 1 end
      end
    end
    if alive == 0 then return end
    event = table.pack(os.pullEvent())
  end
end
parallel = { waitForAll = function(...) wait(false, ...) end, waitForAny = function(...) wait(true, ...) end }
local function run(fn)
  local thread, event = coroutine.create(fn), table.pack()
  for _ = 1, 20000 do
    local ok, err = coroutine.resume(thread, table.unpack(event, 1, event.n))
    assert(ok, err)
    if coroutine.status(thread) == "dead" then return end
    event = table.remove(events, 1)
    if not event then
      local id, at
      for key, time in pairs(timers) do if not at or time < at then id, at = key, time end end
      assert(id, "deadlock") now = at timers[id] = nil event = table.pack("timer", id)
    end
  end
  error("event budget exhausted")
end
local addon = require("system.libraries.addon")
addon.configure({ concurrency = 4, readsPerTick = 16 })
local active, peak, calls, completed = 0, 0, 0, 0
local device = {}
for i = 1, 6 do
  device["read" .. i] = function()
    calls = calls + 1 active = active + 1 peak = math.max(peak, active)
    local timer = os.startTimer(0.05)
    repeat local _, id = os.pullEvent("timer") until id == timer
    active = active - 1 return 42
  end
end
run(function()
  local branches = {}
  for i = 1, 40 do branches[i] = function()
    local values = addon.read(device, {"read1", "read2", "read3", "read4", "read5", "read6"})
    assert(values.read1 == 42 and values.read6 == 42)
    completed = completed + 1
  end end
  addon.parallel(branches)
end)
assert(calls == 240 and completed == 40 and peak <= 4)
assert(now > 0.5, "large batch was not exercised beyond old deadline")
local metrics = addon.metrics()
assert(metrics.reads == 240 and metrics.inFlight == 0 and metrics.queue == 0 and metrics.peakInFlight <= 4)
assert(metrics.readSeconds > 0)
run(function()
  local ok = addon.bounded(function()
    local branches = {}
    for i=1,40 do branches[i]=function() addon.read({hang=function() os.pullEvent("never") end},{"hang"},1) end end
    addon.parallel(branches)
  end,0.05)
  assert(not ok)
end)
assert(addon.metrics().inFlight==0 and addon.metrics().queue==0,"cancelled work leaked permits")
run(function()
  local values, errors = addon.read({fast=function() return false end,slow=function() os.pullEvent("never") end},{"fast","slow"})
  assert(values.fast==false and errors.slow:find("uncertain",1,true))
end)
assert(addon.metrics().timeouts==1)
-- Even non-yielding methods must observe the shared admission budget.
addon.configure({readsPerTick=3})
local atTime, synchronous = {}, 0
run(function()
  local branches = {}
  for i=1,20 do branches[i]=function()
    addon.read({fast=function()
      atTime[now]=(atTime[now] or 0)+1
      assert(atTime[now]<=3,"synchronous reads bypassed admission budget")
      synchronous=synchronous+1 return true
    end},{"fast"})
  end end
  addon.parallel(branches)
end)
assert(synchronous==20)
addon.configure({concurrency=1,readsPerTick=1})
now=now+0.1
local order, flightTiming = {}, nil
run(function()
  addon.parallel({function()
    addon.read({fast=function() order[#order+1]="contacts" return true end},
      {"fast","fast","fast","fast","fast"},0.001,{priority="contacts"})
  end,function()
    local values, errors, timings=addon.read({fast=function() order[#order+1]="flight" return true end},
      {"fast"},0.001,{priority="flight"})
    assert(values.fast and not errors.fast)
    flightTiming=timings.fast
  end},2)
end)
assert(order[1]=="contacts" and order[2]=="flight","queued flight read starved behind radar")
assert(flightTiming.queueSeconds>0.001 and flightTiming.receivedAt>=flightTiming.startedAt,
  "queue time consumed per-method deadline or missing receipt time")
local scans = 0
peripheral = { getNames = function() scans = scans + 1 return {"radar"} end,
  getType = function() return "radar", "sensor" end,
  getMethods = function() return {"read1"} end, wrap = function() return device end }
local rows = addon.inventory()
assert(rows[1].device.read1 and rows[1].types[2] == "sensor")
rows[1].name = "mutated"
assert(addon.inventory()[1].name == "radar" and scans == 1)
addon.invalidateInventory()
addon.inventory()
addon.inventory(true)
assert(scans == 3)
-- A standalone fan-out must discard both active and not-yet-started reads.
addon.configure({concurrency=1,readsPerTick=1000})
run(function()
  local ok,err=pcall(function()
    addon.parallel({function()
      addon.read({hang=function() os.pullEvent("never") end},{"hang","hang"},10)
    end,function() error("standalone sibling failed") end},2)
  end)
  assert(not ok and tostring(err):find("standalone sibling failed",1,true))
  assert(addon.metrics().inFlight==0 and addon.metrics().queue==0,"branch error leaked standalone reads")
  assert(next(timers)==nil,"branch error leaked standalone timers")
  local values=addon.read({good=function() return 7 end},{"good"})
  assert(values.good==7,"cancelled sibling retained admission")
end)
print("40 radars / 240 reads: bounded fan-out, no deadlock, shared cache passed")
