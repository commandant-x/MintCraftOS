package.path="./?.lua;"..package.path
local function copy(t) if type(t)~="table" then return t end local out={} for k,v in pairs(t) do out[k]=copy(v) end return out end
local stored,serialized,fail,hook
os.getComputerID=function() return 0 end
os.epoch=function() return 1000 end
fs={exists=function() return stored~=nil end}
textutils={serialize=function(v) serialized=copy(v) return "db" end}
package.loaded["system.libraries.config"]={load=function(_,fallback) return stored or fallback end}
package.loaded["system.libraries.safe_write"]={write=function() if fail then return false,"disk full" end stored=copy(serialized) return true end}
package.loaded["system.libraries.password_crypto"]={create=function(password) if hook then hook() end return {digest=password} end,verify=function(p,v) if hook then hook() end return p==v.digest end}
package.loaded["system.libraries.log"]={info=function() end}
local users=require("system.security.users") local security=require("system.services.securityd")
assert(users.needsEnrollment())
assert(not users.login("admin",""),"factory empty password authenticated")
assert(not security.authorize({pid=7},"system.config"),"unenrolled factory admin authorized mutation")
assert(security.authorize({pid=7},"system.auth"))
assert(not security.enroll("short")) assert(not stored)
fail=true assert(not security.enroll("long password")) assert(users.needsEnrollment())
fail=false assert(security.enroll("long password")) assert(not users.needsEnrollment())
assert(not security.enroll("replace password"),"enrollment reset configured credential")
assert(stored.users.admin.passwordHash.digest=="long password")
security.lock()
hook=function() coroutine.yield("kdf") end
local pending=coroutine.create(function() return security.login("admin","long password") end)
local ok,stage=coroutine.resume(pending) assert(ok and stage=="kdf")
assert(security.lock(),"relocking must work during authentication")
hook=nil local finished,loggedIn=coroutine.resume(pending)
assert(finished and not loggedIn and security.isLocked(),"identical repeated lock was overwritten by stale authentication")
assert(security.login("admin","long password")) assert(not security.isLocked())
print("enrollment: no default password bypass, minimum length, atomic disk failure, no re-enrollment and repeated-lock auth cancellation passed")

local migrated=users.load()
migrated.users.captain=migrated.users.admin migrated.users.admin=nil migrated.users.captain.name="captain" migrated.currentUser="captain"
assert(users.save(migrated))
assert(users.loginIdentity()=="captain","custom account stranded behind admin-only lock")
assert(users.login("captain","long password"))
migrated=users.load() migrated.currentUser="guest" assert(users.save(migrated))
assert(users.loginIdentity()=="captain","empty guest chosen as protected console identity")
print("enrollment API gate and custom-identity migration passed")
