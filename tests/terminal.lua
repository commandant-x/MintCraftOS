package.path = "./?.lua;" .. package.path
for _, name in ipairs({"system.gui.renderer","system.libraries.log","system.gui.keyboard","system.gui.components","system.dev.autocomplete","system.services.securityd"}) do package.loaded[name] = {} end
package.loaded["system.libraries.log"].error = function() end
package.loaded["system.libraries.auth_worker"]={new=function(_,perform,finished)
  return {submit=function(_,request) local ok,result=pcall(perform,request,{}) finished(ok,result) return true end}
end}
term = {getSize = function() return 51,19 end}
local moved, deleted, allowed = 0, 0, true
fs = {
  combine = function(dir, path) return (path:sub(1,1) == "/" and path or (dir .. "/" .. path)):gsub("^/+", "") end,
  exists = function(path) return not path:match("new.txt$") end,
  move = function() moved = moved + 1 end,
  delete = function() deleted = deleted + 1 end,
}
local app
local ctx = {windowManager={create=function(_,opts) app=opts.app return {closed=false} end},pullEvent=function() coroutine.yield() end,
  security={require=function() return allowed, allowed and nil or "denied" end,audit=function() end}}
local co = coroutine.create(function() require("apps.terminal.main").run(ctx) end)
local ok,err = coroutine.resume(co)
assert(ok,tostring(err))
local function command(text) app.input=text app.keyboard.onEnter() end
command("rm /system")
assert(not app.pending and deleted == 0)
command("mv /boot.lua /new.txt")
assert(not app.pending and moved == 0)
command("mv old.txt new.txt")
assert(app.pending and moved == 0)
command("no")
assert(not app.pending and moved == 0)
command("mv old.txt new.txt")
allowed = false
command("yes")
assert(moved == 0 and not app.pending)
allowed = true
command("mv old.txt new.txt")
command("yes")
assert(moved == 1)
fs.move = function() error("disk disconnected") end
command("mv old.txt new.txt")
command("yes")
assert(not app.pending and app.lines[#app.lines]:find("disk disconnected",1,true))
keys = {enter=1,up=2,down=3}
app.input = "pwd"
assert(app:handle({name="key",args={keys.enter}}))
assert(app.history[#app.history] == "pwd" and app.lines[#app.lines] == app.cwd)
for i = 1, 110 do command("pwd") end
assert(#app.history == 100)
local received
package.loaded["system.services.securityd"].unlock = function(password) received = password return true,"unlocked" end
command("unlock example-secret")
assert(received == "example-secret")
for _, line in ipairs(app.lines) do assert(not line:find("example-secret",1,true)) end
for _, line in ipairs(app.history) do assert(not line:find("example-secret",1,true)) end
package.loaded["system.services.securityd"].unlock = function(password) error(password) end
command("unlock second-secret")
for _, line in ipairs(app.lines) do assert(not line:find("second-secret",1,true)) end
package.loaded["system.dev.autocomplete"].suggest = function() error("secret reached autocomplete") end
app.input = "unlock "
app.suggestion = {label = "stale"}
app.keyboard.onText("third-secret")
assert(app.suggestion == nil and app.input == "unlock third-secret")
app.input="unlock " assert(app:handle({name="paste",args={"pasted-secret"}}) and app.suggestion==nil)
print("terminal destructive command tests passed")
local displayCalls=0
package.loaded["system.services.deviced"]={listDisplays=function() return {{name="computer",available=true,selected=true}} end,
  setTarget=function(value) displayCalls=displayCalls+1 assert(value=="computer") return true end}
allowed=true command("display") assert(app.lines[#app.lines]=="* computer")
allowed=false command("display computer") assert(displayCalls==0)
allowed=true command("display computer") assert(displayCalls==1)
package.loaded["system.dev.autocomplete"].suggest=function() return nil end
allowed=false
for _,text in ipairs({'cat private.txt','type private.txt','ls /','cd /','cp private.txt copy.txt','ps','logs'}) do
  command(text) assert(app.lines[#app.lines]=='denied','read command bypassed live permission: '..text)
end
allowed=true
package.loaded["system.dev.autocomplete"].prefix=function() return "computer" end
app.input="" assert(app:handle({name="paste",args={"display computer\nreboot"}}) and app.input=="display computer")
app.keyboard.onEnter() assert(displayCalls==2)

local poseReads=0
package.loaded["system.services.sabled"]={pose=function() poseReads=poseReads+1 return {logicalPose={orientation={x=0,y=0,z=0,w=1}},timestamp=os.clock(),frame="world",inSublevel=true} end}
allowed=false command("navigation pose") assert(poseReads==0)
allowed=true command("navigation pose") assert(poseReads==1)
assert(table.concat(app.lines,"\n"):find("w = 1 [number]",1,true))
package.loaded["system.services.sabled"].pose=function() return {logicalPose={orientation={x="0",y=0,z=0}},timestamp=os.clock()} end
command("navigation pose")
assert(table.concat(app.lines,"\n"):find("w = nil [nil]",1,true))
print("terminal pose diagnostics: permission gate, cached-only read, component types and missing scalar passed")
