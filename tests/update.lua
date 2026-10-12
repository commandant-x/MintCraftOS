package.path = "./?.lua;" .. package.path
local cfg = { repo = "owner/repo", branch = "main", autoCheck = true }
package.loaded["system.libraries.config"] = { load = function() return cfg end }
package.loaded["system.libraries.log"] = {error=function() end}
fs = {
  exists=function() return true end,
  open=function() return {readAll=function() return "1.0.0" end, close=function() end} end,
}
local timer, requests = 0, 0
os.startTimer = function() timer=timer+1 return timer end
os.cancelTimer = function() end
http = {
  request=function() requests=requests+1 return true end,
  get=function() error("blocking HTTP during boot") end,
}
local bus = require("system.kernel.event_bus").new()
local updated = require("system.services.updated")
local notices = 0
local ctx = { eventBus=bus, notifications={push=function() notices=notices+1 end} }
updated.start(ctx)
assert(requests==1)
local delivered, closed = 0, 0
bus:on("http_success", function() delivered=delivered+1 end)
local function response(v)
  return {readAll=function() return v end,close=function() closed=closed+1 end}
end
bus:emit("http_success", "https://raw.githubusercontent.com/owner/repo/main/VERSION?mintcraft_auto=1", response("1.1.0"))
assert(closed==1 and delivered==1, "listener cleanup skipped another subscriber")
assert(updated.status.updateAvailable and notices==1)
updated.start(ctx)
bus:emit("timer", timer)
assert(updated.status.message=="Update check timed out")
updated.start(ctx)
bus:emit("http_success", "https://raw.githubusercontent.com/owner/repo/main/VERSION?mintcraft_auto=1", response("0.9.0"))
assert(not updated.status.updateAvailable and notices==1)
http=nil
updated.start(ctx)
assert(updated.status.message=="Automatic check unavailable")
print("update tests passed")
