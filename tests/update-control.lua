package.path="./?.lua;"..package.path
package.loaded["system.libraries.log"]={info=function() end,error=function() end,warn=function() end}
local session,user=0,"admin"
package.loaded["system.services.securityd"]={sessionRevision=function() return session end,currentUser=function() return {name=user} end}
local allowed={}
package.loaded["system.security.permissions"]={require=function(actor) return allowed[actor.pid]==true,"permission revoked" end}
local now=0 os.clock=function() return now end os.epoch=function() return 0 end
os.pullEvent=function(filter) return coroutine.yield(filter) end
os.queueEvent=function() end
local scheduler=require("system.kernel.scheduler").new()
local function owner()
  local id=scheduler:spawn("Update",function() while true do coroutine.yield() end end,{appId="update",permissions={"system.update","network.http"}})
  scheduler:start(id) allowed[id]=true return {pid=id}
end
local function wake(name) scheduler:dispatch({name=name,args={},raw={name}}) end
local version,backup="1.0.0","42"
local cfg={repo="owner/repo",branch="main"}
local reads,writes=0,0 local mode="before"
local service={status={ok=true,updateAvailable=true,remoteVersion="2.0.0",source={repo=cfg.repo,ref="main",sha=string.rep("a",40)}},
  loadConfig=function() return cfg end,localVersion=function() return version end,rollbackInfo=function() return {id=backup,fromVersion="0.9.0"} end}
service.check=function(options) reads=reads+1 os.pullEvent("download") assert(options.authorize()) return {ok=true,message="checked"} end
service.apply=function(options)
  reads=reads+1 os.pullEvent("download")
  local ok,err=options.authorize() if not ok then return false,err end
  options.commit() writes=writes+1
  options.progress("install","Writing",1,2)
  os.pullEvent("written")
  assert(options.authorize(),"committed transaction abandoned")
  if mode=="fail" then return false,"disk error" end
  return true,"installed"
end
service.rollback=service.apply
local control=require("system.services.update_control").new({scheduler=scheduler},service)
local first,second=owner(),owner()
assert(not control:request(first,"apply"),"mutation allowed without confirmation")
local function prepare(actor,action) local ok,token=control:prepare(actor,action or "apply") assert(ok,tostring(token)) return token.token end
local token=prepare(first)
assert(not control:request(second,"apply",token),"confirmation transferred to another PID")
token=prepare(first) now=31 assert(not control:request(first,"apply",token),"expired token accepted")
token=prepare(first) version="1.0.1" assert(not control:request(first,"apply",token),"changed installed version accepted") version="1.0.0"
token=prepare(first) cfg.branch="other" assert(not control:request(first,"apply",token),"source switched after confirmation") cfg.branch="main"
token=prepare(first,"rollback") backup="43" assert(not control:request(first,"rollback",token),"rollback target switched") backup="42"
token=prepare(first) assert(control:request(first,"apply",token)) wake("mintcraft_update_action")
assert(control:status().busy and writes==0)
assert(not control:request(second,"check"),"overlapping request accepted")
assert(scheduler:kill(first.pid)) wake("download")
assert(not control:status().busy and not control:status().ok and writes==0,"closed caller wrote installation")
first=owner() token=prepare(first) assert(control:request(first,"apply",token)) wake("mintcraft_update_action")
session=session+1 wake("download")
assert(writes==0 and not control:status().ok,"new session inherited old request")
token=prepare(first) assert(control:request(first,"apply",token)) wake("mintcraft_update_action")
allowed[first.pid]=false wake("download") assert(writes==0 and not control:status().ok)
allowed[first.pid]=true token=prepare(first) assert(control:request(first,"apply",token)) wake("mintcraft_update_action") wake("download")
assert(control:status().committed and control:status().busy and writes==1)
local worker=control:status().pid assert(scheduler:kill(first.pid)) session=session+1 wake("written")
assert(control:status().ok and not control:status().busy and scheduler.processes[worker].state=="ready","closing window abandoned committed installer")
first=owner() mode="fail" token=prepare(first) assert(control:request(first,"apply",token)) wake("mintcraft_update_action") wake("download") wake("written")
assert(not control:status().busy and not control:status().ok and control:status().message=="disk error")
assert(control:request(first,"check")) wake("mintcraft_update_action") wake("download") assert(control:status().ok)
token=prepare(first) assert(control:request(first,"apply",token)) wake("mintcraft_update_action")
assert(scheduler:kill(worker,true))
assert(control:status().phase=="uncertain" and not control:request(first,"check"),"lost worker automatically restarted")
print("update control: single-use confirmations, source/version binding, owner/session/permission revocation, yielding lifecycle and uncertain worker loss passed")
