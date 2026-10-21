package.path="./?.lua;"..package.path
local function copy(v) if type(v)~="table" then return v end local out={} for k,x in pairs(v) do out[k]=copy(x) end return out end
local stored,serialized,writes,fail,now=nil,nil,0,false,0
os.epoch=function() return now*1000 end
os.clock=function() return now end
os.getComputerID=function() return 0 end
fs={exists=function() return stored~=nil end}
textutils={serialize=function(v) serialized=copy(v) return "serialized" end}
package.loaded["system.libraries.config"]={load=function(_,fallback) return stored or fallback end,save=function() error("non-transactional write") end}
package.loaded["system.libraries.safe_write"]={write=function()
  writes=writes+1 if fail then return false,"disk full" end stored=copy(serialized) return true
end}
local hook
package.loaded["system.libraries.password_crypto"]={
  create=function(password) if hook then hook() end return {algorithm="test-kdf",digest=password} end,
  verify=function(password,value) return value.digest==password end,
}
local users=require("system.security.users")
assert(users.current().name=="admin") assert(#users.list()==2) users.hasPermission("system.config") users.isLocked()
assert(writes==0,"reads saved users.db")
assert(users.lock()) local before=writes
assert(not users.setPassword("admin","new password","")) assert(writes==before,"locked admin changed password")
assert(users.unlock("")) assert(type(stored.users.admin.passwordHash)=="table","legacy credential not migrated")
assert(not users.setPassword("admin","new password","wrong"))
assert(users.setPassword("admin","new password",""))
assert(not users.verify("admin","")) assert(users.verify("admin","new password"))
assert(users.logout()) assert(not users.setPassword("admin","another password","new password"),"guest reset admin")
assert(users.login("admin","new password"))
local hash=stored.users.admin.passwordHash.digest
fail=true assert(not users.setPassword("admin","another password","new password"))
assert(stored.users.admin.passwordHash.digest==hash,"failed write mutated live credentials")
assert(not users.lock()) assert(not stored.locked,"failed lock changed live database")
assert(not users.logout()) assert(stored.currentUser=="admin","failed logout changed live database")
fail=false
hook=function() stored.locked=true end
assert(not users.setPassword("admin","another password","new password"),"stale KDF overwrote concurrent session lock")
assert(stored.locked and stored.users.admin.passwordHash.digest==hash) hook=nil
assert(users.unlock("new password"))
for _=1,5 do assert(not users.verify("unknown","bad")) end
local ok,err=users.login("admin","new password") assert(not ok and err:find("Too many"),"auth flood not throttled")
now=301 assert(users.login("admin","new password"))
local provider=package.loaded["system.libraries.password_crypto"]
package.loaded["system.libraries.password_crypto"]=nil
package.preload["system.libraries.password_crypto"]=function() error("provider missing") end
assert(not users.setPassword("admin","another password","new password"),"missing provider downgraded password")
package.loaded["system.libraries.password_crypto"]=provider
package.loaded["system.libraries.log"]={info=function() end}
package.loaded["system.security.permissions"]={require=function(actor,permission) assert(permission=="system.security.admin") return actor.allowed==true,"denied" end}
local security=require("system.services.securityd")
assert(not security.setPassword("admin","another password","new password",{allowed=false}))
assert(security.setPassword("admin","another password","new password",{allowed=true}))
fail=true assert(not security.lock()) assert(security.isLocked(),"disk failure left console unlocked") assert(not security.logout())
fail=false
hook=function() coroutine.yield("kdf") end
local pending=coroutine.create(function() return users.setPassword("admin","yet another password","another password") end)
local resumed,stage=coroutine.resume(pending) assert(resumed and stage=="kdf")
local concurrent,busy=users.login("admin","another password")
assert(not concurrent and busy:find("in progress"),"concurrent auth bypassed global mutex")
assert(users.logout(),"logout must remain available during hashing")
local finished,changed,stale=coroutine.resume(pending)
assert(finished and not changed and stale:find("Session changed"),"yielded KDF overwrote logout")
assert(stored.currentUser=="guest" and stored.users.admin.passwordHash.digest=="another password")
hook=nil
assert(users.login("admin","another password"),"completed auth failed to release mutex")
local revision=security.sessionRevision()
assert(not security.login('admin','wrong')) assert(security.sessionRevision()==revision,'Failed login changed session identity')
assert(security.lock()) assert(security.sessionRevision()==revision+1)
assert(security.unlock('another password')) assert(security.sessionRevision()==revision+2)
assert(security.logout()) assert(security.sessionRevision()==revision+3)
assert(security.login('admin','another password')) assert(security.sessionRevision()==revision+4,'Same-user login reused session identity')
security.start() assert(security.isLocked(),"reboot retained unlocked session")
assert(security.login('admin','another password'))
print("read-only users, locked/guest reset denial, reauth, migration, transactional saves, stale writes, throttle and actor permission passed")
