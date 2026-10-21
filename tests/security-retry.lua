package.path="./?.lua;"..package.path
local function copy(v) if type(v)~="table" then return v end local t={} for k,x in pairs(v) do t[k]=copy(x) end return t end
local now,mono=1000,0
os.epoch=function() return now*1000 end os.clock=function() return mono end os.getComputerID=function() return 0 end
local function advance(n) now=now+n mono=mono+n end
local stored={currentUser="admin",locked=true,users={admin={role="admin",permissions={"*"},passwordHash={algorithm="test",iterations=600000,digest="correct password"}}},roles={admin={"*"}}}
local serialized,fail,checked,quickCreates,hook=nil,false,{},0,nil
fs={exists=function() return true end}
textutils={serialize=function(v) serialized=copy(v) return "serialized" end}
package.loaded["system.libraries.config"]={load=function() return copy(stored) end}
package.loaded["system.libraries.safe_write"]={write=function() if fail then return false,"disk full" end stored=copy(serialized) return true end}
package.loaded["system.libraries.password_crypto"]={
 verify=function(password,value) checked[#checked+1]=value.iterations if hook then hook() end return password==value.digest end,
 create=function(password) return {algorithm="test",iterations=600000,digest=password} end,
 createQuick=function(password) quickCreates=quickCreates+1 return {algorithm="test",iterations=15000,digest=password} end,
}
local function reload()
 package.loaded["system.security.users"]=nil package.loaded["system.security.auth_throttle"]=nil
 return require("system.security.users")
end
local users=reload()
local original=copy(stored.users.admin.passwordHash)
for _=1,4 do assert(not users.login("admin","wrong")) assert(users.authenticationStatus().retryAfter==0) end
for _,delay in ipairs({30,60,300,900,3600,3600}) do
 assert(not users.login("admin","wrong"))
 assert(users.authenticationStatus().retryAfter==delay)
 local before=#checked
 for _=1,10 do assert(not users.login("admin","correct password")) end
 assert(#checked==before,"cooldown computed a password hash")
 users=reload()
 assert(users.authenticationStatus().retryAfter==delay,"restart discarded cooldown")
 advance(delay-1) assert(not users.login("admin","correct password"))
 advance(1)
end
assert(users.login("admin","correct password"))
assert(stored.authThrottle==nil and quickCreates==1 and not stored.locked)
assert(stored.users.admin.passwordHash.iterations==original.iterations and stored.users.admin.passwordHash.digest==original.digest,"rollback credential changed")
assert(checked[#checked]==600000)
if arg[1] then
 local old=assert(loadfile(arg[1]))()
 assert(old.lock() and old.login("admin","correct password"))
 assert(checked[#checked]==600000,"older release used quick credential")
end
assert(users.lock()) assert(users.login("admin","correct password"))
assert(checked[#checked]==15000 and quickCreates==1,"repeat login recomputed old credential")
-- Simulate an older release changing the high-cost credential: the quick record
-- must no longer accept the old password, even though it is still on disk.
stored.users.admin.passwordHash.digest="replacement password"
assert(not users.login("admin","correct password"))
assert(checked[#checked]==600000)
assert(users.login("admin","replacement password"))
assert(quickCreates==2)
assert(users.setPassword("admin","new password","replacement password"))
assert(stored.users.admin.passwordHash.digest=="new password" and stored.users.admin.quickPasswordHash.digest=="new password")
-- Reserve before yielding: an interrupted fifth attempt remains delayed after reboot.
for _=1,4 do assert(not users.login("admin","wrong")) end
hook=function() coroutine.yield("hashing") end
local pending=coroutine.create(function() return users.login("admin","wrong") end)
local ok,stage=coroutine.resume(pending) assert(ok and stage=="hashing")
assert(stored.authThrottle.failures==5)
users=reload() assert(users.authenticationStatus().retryAfter==30)
hook=nil advance(30)
-- Persistence failure refuses before any password comparison.
fail=true local count=#checked
assert(not users.login("admin","new password")) assert(#checked==count)
fail=false
-- Corrupt retry data fails closed instead of starting with an empty counter.
stored.authThrottle={version=1,failures=-1,at=0,untilAt=0,clock="utc"}
assert(not users.authenticationStatus()) assert(not users.login("admin","new password"))
-- UTC rollback and no-UTC environments retain a monotonic, bounded wait.
local throttle=require("system.security.auth_throttle")
local t={version=1,failures=5,at=now,untilAt=now+30,clock="utc"}
assert(throttle.status(t).retryAfter==30)
now=now-100 advance(10) assert(throttle.status(t).retryAfter==20)
advance(20) assert(throttle.status(t).retryAfter==0)
os.epoch=nil
local u={version=1,failures=5,at=20,untilAt=50,clock="uptime"}
assert(throttle.status(u).retryAfter==30) mono=mono+30 assert(throttle.status(u).retryAfter==0)
print("persistent auth: escalating/capped delays, no KDF while blocked, reboot and interrupted reservation, quick migration, rollback credential, stale quick invalidation, disk errors and clocks passed")
