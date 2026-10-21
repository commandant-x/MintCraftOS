package.path="./?.lua;"..package.path
local function copy(v) if type(v)~="table" then return v end local t={} for k,x in pairs(v) do t[k]=copy(x) end return t end
local now=100 os.clock=function() return now end os.epoch=function() return now*1000 end
local stored={currentUser="admin",locked=true,users={admin={role="admin",permissions={"*"},passwordHash={algorithm="test",iterations=600000,digest="correct password"}}},roles={admin={"*"}}}
local serialized,fail,kdfs,checks,created=nil,false,0,0,0
fs={exists=function() return true end}
textutils={serialize=function(v) serialized=copy(v) return "serialized" end}
package.loaded["system.libraries.config"]={load=function() return copy(stored) end}
package.loaded["system.libraries.safe_write"]={write=function() if fail then return false,"disk full" end stored=copy(serialized) return true end}
package.loaded["system.libraries.password_crypto"]={
 verify=function(p,v) kdfs=kdfs+1 return p==v.digest end,
 create=function(p) return {algorithm="test",iterations=600000,digest=p} end,
 createQuick=function(p) return {algorithm="test",iterations=15000,digest=p} end,
 memoryVerifier=function(p) created=created+1 return function(candidate) checks=checks+1 return p==candidate end end,
}
local function reload() package.loaded["system.security.users"]=nil return require("system.security.users") end
local users=reload()
local stages={}
assert(users.login("admin","correct password",{stage=function(s) stages[#stages+1]=s end}))
assert(kdfs==1 and created==1 and stages[1]=="First verification (slow)" and stages[2]=="Preparing quick unlock")
assert(stored.memoryCredential==nil and stored.users.admin.verify==nil,"RAM verifier serialized")
assert(users.lock())
assert(users.login("admin","correct password",{stage=function(s) assert(s=="Quick unlock") end}))
assert(kdfs==1 and checks==1,"repeat lock computed a KDF")
assert(not users.login("admin","wrong")) assert(checks==2 and kdfs==1)
assert(users.login("admin","correct password"))
for _=1,5 do assert(not users.login("admin","wrong")) end
local before=checks
assert(not users.login("admin","correct password")) assert(checks==before,"volatile cache bypassed retry delay")
now=now+30 assert(users.login("admin","correct password"))
fail=true before=checks
assert(not users.login("admin","correct password")) assert(checks==before,"cache bypassed durable reservation")
fail=false
-- Reboot discards RAM but preserves the quick persistent credential.
users=reload()
assert(users.login("admin","correct password")) assert(kdfs==2)
-- Logout, including a failed logout, drops the volatile verifier.
assert(users.logout()) assert(users.login("admin","correct password")) assert(kdfs==3)
fail=true assert(not users.logout()) fail=false
assert(users.login("admin","correct password")) assert(kdfs==4)
-- Source credential changes invalidate both quick and RAM credentials.
stored.users.admin.passwordHash.digest="replacement password"
assert(not users.login("admin","correct password")) assert(kdfs==5)
assert(users.login("admin","replacement password")) assert(kdfs==6)
assert(users.setPassword("admin","new password","replacement password"))
assert(not users.login("admin","replacement password"))
assert(users.login("admin","new password")) assert(kdfs==6,"password change retained stale cache")
-- A session change during the stage callback must still lose the CAS race.
assert(users.lock())
local ok=users.login("admin","new password",{stage=function() stored.users.admin.permissions={"filesystem.read"} end})
assert(not ok and stored.locked,"fast verification overwrote concurrent permissions/session")
local prior=checks
assert(not users.login("admin","new password",{cancelled=function() return true end}))
assert(checks==prior,"cancelled auth used RAM verifier")
print("volatile unlock: first/reboot KDF, repeated locks without KDF, failed guesses/delays, durable writes, logout, credential changes, stages, cancellation and stale writes passed")
