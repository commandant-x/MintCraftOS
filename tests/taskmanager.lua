package.path = "./?.lua;" .. package.path
package.loaded["system.gui.renderer"] = {writeAt = function() end, crop = function(t) return t end}
package.loaded["system.gui.components"] = {toolbar = function() return {} end, toolbarHit = function() return "refresh" end}
package.loaded["system.gui.theme"] = {get=function() return 1 end}
colors = {black=32768,white=1,gray=128,lightGray=256,cyan=512}
local now, queries, disk = 0, 0, 0
os.clock = function() return now end
fs = {getFreeSpace = function() disk = disk + 1 return 100 end, getCapacity = function() return 1000 end}
term = {getSize = function() return 80, 30 end}
local app
local ctx = {listProcesses = function() queries = queries + 1 return {} end,
  windowManager = {create = function(_, options) app = options.app return {closed=false} end},
  pullEvent = function() coroutine.yield() end}
ctx.startTimer=function() return 1 end
ctx.onCleanup=function() end
ctx.cancelTimer=function() end
assert(coroutine.resume(coroutine.create(function() require("apps.taskmanager.main").run(ctx) end)))
for i = 1, 100 do app:draw(58, 16) end
assert(queries == 1 and disk == 1, "metrics sampled every redraw")
now = 1
app:refresh() app:draw(58, 16)
assert(queries == 2 and disk == 2)
app:handle({name="mouse_click",args={1,1,1}})
app:draw(58, 16)
assert(queries == 3 and disk == 3, "Refresh did not invalidate sample")
local kills=0
local rows={{pid=5,name="fixture",state="ready",protected=true}}
ctx.listProcesses=function() return rows end
ctx.kill=function(pid) assert(pid==5) kills=kills+1 return false,"permission denied" end
app.selectedPid=5 app:kill(5) assert(kills==0,"protected metadata bypassed before delegated kill")
rows[1].protected=false app.selectedPid=5 app:kill(5)
assert(kills==1 and app.message=="permission denied","kill did not retain context permission boundary")
rows={} app.selectedPid=5 app:kill(5) assert(kills==1 and app.selectedPid==nil,"evicted selection retargeted another process")
local sourceReads=100
require("system.libraries.addon").metrics=function() return sourceReads and {reads=sourceReads} or {} end
now=2 app:refresh(true)
sourceReads=10 now=2.1 app:refresh(true) assert(app.snapshot.gap and not app.snapshot.readRate)
sourceReads=20 now=2.2 app:refresh(true)
sourceReads=110 now=3 app:refresh(true) assert(math.abs(app.snapshot.readRate-100/0.9)<0.001,"rapid reset retained pre-reset baseline")
sourceReads=nil now=3.1 app:refresh(true) assert(app.snapshot.gap)
sourceReads=20 now=3.2 app:refresh(true) assert(app.snapshot.gap)
sourceReads=100 now=4 app:refresh(true) assert(math.abs(app.snapshot.readRate-100)<0.001,"rapid source recovery fabricated a rate")
print("task manager sampling tests passed")
