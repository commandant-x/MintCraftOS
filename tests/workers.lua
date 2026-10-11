package.path="./?.lua;"..package.path
package.loaded["system.libraries.log"]={info=function() end,warn=function() end,error=function() end}
os.epoch=function() return 0 end
os.pullEvent=function(filter) return coroutine.yield(filter) end
local scheduler=require("system.kernel.scheduler").new()
local native,structured,cleaned
local pid=scheduler:spawn("native",function()
  local name,id,ok,value,trailing=os.pullEvent("task_complete")
  native={name,id,ok,value,trailing}
end,{eventMode="raw"})
scheduler:makeContext(pid).onCleanup(function() cleaned=true end)
scheduler:start(pid)
local second=scheduler:spawn("app",function() structured=coroutine.yield("task_complete") end)
scheduler:start(second)
scheduler:dispatch({name="other",args={}})
assert(not native)
scheduler:dispatch({name="task_complete",args=table.pack(42,true,nil,"last"),raw=table.pack("task_complete",42,true,nil,"last")})
assert(native[1]=="task_complete" and native[2]==42 and native[3] and native[4]==nil and native[5]=="last")
assert(structured.name=="task_complete" and cleaned)
print("native suspended worker arguments and legacy app event tests passed")
