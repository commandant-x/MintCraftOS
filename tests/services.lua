package.path = "./?.lua;" .. package.path
package.loaded["system.libraries.log"] = {info=function() end,error=function() end}
local order, cleaned = {}, 0
package.preload["test.first"] = function() return {start=function() table.insert(order,"first") end} end
package.preload["test.second"] = function() return {start=function() table.insert(order,"second") end} end
package.preload["test.broken"] = function() return {
  start=function() return false,"missing dependency" end,
  stop=function() cleaned=cleaned+1 end,
} end
local manager = require("system.services.service_manager").new({})
manager:register("z", "test.first", true)
manager:register("a", "test.second", true)
manager:register("bad", "test.broken", true)
manager:startAutostart()
assert(table.concat(order,",")=="first,second")
assert(manager.services.bad.state=="crashed" and cleaned==1)
assert(manager.services.bad.error=="missing dependency")
manager.services.z.module.stop=function() error("cannot stop") end
assert(not manager:stop("z"))
assert(manager.services.z.state=="crashed")
print("service tests passed")
