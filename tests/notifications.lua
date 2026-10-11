package.path = "./?.lua;" .. package.path
package.loaded["system.gui.renderer"] = {}
package.loaded["system.gui.theme"] = {}
package.loaded["system.services.audiod"] = {}
local now, nextTimer, scheduled, cancelled = 0, 0, {}, {}
os.clock = function() return now end
os.startTimer = function(delay)
  nextTimer = nextTimer + 1
  scheduled[nextTimer] = delay
  return nextTimer
end
os.cancelTimer = function(id) cancelled[id] = true end
local n = require("system.services.notifd").new()
n:push("info", "first", "", 5)
local first = n.timer
assert(scheduled[first] == 5)
n:handle({name = "char", args = {"x"}})
assert(n.timer == first, "unrelated event reset expiry timer")
n:push("warn", "urgent", "", 1)
assert(cancelled[first] and scheduled[n.timer] == 1)
now = 1
n:handle({name = "timer", args = {n.timer}})
assert(#n.queue == 1 and n.queue[1].title == "first")
assert(scheduled[n.timer] == 4)
now = 5
n:handle({name = "timer", args = {n.timer}})
assert(#n.queue == 0 and n.timer == nil)
for i = 1, 100 do n:push("info", tostring(i), "", 10) end
assert(#n.queue == 32 and n.queue[1].title == "69")
now = 15
n:handle({name = "timer", args = {n.timer}})
assert(#n.queue == 0 and not n.timer)
print("notification expiry tests passed")
