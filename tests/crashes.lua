package.path = "./?.lua;" .. package.path
local errors, notices = {}, {}
package.loaded["system.libraries.log"] = {
  error = function(source, message) errors[#errors + 1] = message end,
  warn = function() end,
}
package.loaded["system.security.permissions"] = {}
os.epoch = function() return 123 end
local scheduler = require("system.kernel.scheduler").new()
local notifications = {push = function(_, kind, title) notices[#notices + 1] = title end}
scheduler.ctx = {notifications = notifications}
local first, second = {}, {}
local failed = scheduler:spawn("broken", function() error("intentional crash") end)
scheduler:attachWindow(failed, first)
scheduler:attachWindow(failed, second)
local ok, err = scheduler:start(failed)
assert(not ok and err:find("intentional crash", 1, true))
assert(first.closed and second.closed)
assert(#notices == 1 and #errors == 1)
assert(not scheduler:crash(failed, "again"))
assert(not scheduler:kill(failed))
assert(scheduler.processes[failed].state == "crashed")
assert(#notices == 1)
local ticks = 0
local healthy = scheduler:spawn("healthy", function()
  while true do coroutine.yield() ticks = ticks + 1 end
end)
scheduler:start(healthy)
local later = scheduler:spawn("later crash", function()
  coroutine.yield()
  error("event crash")
end)
scheduler:start(later)
scheduler:dispatch({name = "timer", args = {1}})
assert(ticks == 1 and scheduler.processes[healthy].state == "ready")
assert(scheduler.processes[later].state == "crashed" and #notices == 2)
local window = {}
local finished = scheduler:spawn("finished", function() end)
scheduler:attachWindow(finished, window)
assert(scheduler:start(finished))
assert(window.closed and scheduler.processes[finished].state == "stopped")
local a, b = {}, {}
scheduler:attachWindow(healthy, a)
scheduler:attachWindow(healthy, b)
assert(scheduler:kill(healthy) and a.closed and b.closed)
local apps = require("system.libraries.apps")
apps.setContext({scheduler = scheduler, notifications = notifications})
package.preload["test.bad.import"] = function() error("import failure") end
package.preload["test.bad.module"] = function() return true end
package.preload["test.bad.run"] = function() return {run = function() error("run failure") end} end
for i, module in ipairs({"test.bad.import", "test.bad.module", "test.bad.run"}) do
  apps.register("bad" .. i, "Bad " .. i, module,{builtin=true})
  local count = #notices
  local launched, reason = apps.launch("bad" .. i)
  assert(not launched and type(reason) == "string")
  assert(#notices == count + 1, "missing or duplicate launch notification")
end
print("crash isolation tests passed")
