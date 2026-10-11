package.path = "./?.lua;" .. package.path
package.loaded["system.gui.renderer"] = {writeAt = function() end, crop = function(t) return t end}
package.loaded["system.gui.components"] = {toolbar = function() return {} end, toolbarHit = function() return "refresh" end}
colors = {black=32768,white=1,gray=128,lightGray=256,cyan=512}
local now, queries, disk = 0, 0, 0
os.clock = function() return now end
fs = {getFreeSpace = function() disk = disk + 1 return 100 end, getCapacity = function() return 1000 end}
term = {getSize = function() return 80, 30 end}
local app
local ctx = {listProcesses = function() queries = queries + 1 return {} end,
  windowManager = {create = function(_, options) app = options.app return {closed=false} end},
  pullEvent = function() coroutine.yield() end}
assert(coroutine.resume(coroutine.create(function() require("apps.taskmanager.main").run(ctx) end)))
for i = 1, 100 do app:draw(58, 16) end
assert(queries == 1 and disk == 1, "metrics sampled every redraw")
now = 1
app:draw(58, 16)
assert(queries == 2 and disk == 2)
app:handle({name="mouse_click",args={1,1,1}})
app:draw(58, 16)
assert(queries == 3 and disk == 3, "Refresh did not invalidate sample")
print("task manager sampling tests passed")
