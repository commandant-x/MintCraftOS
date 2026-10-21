package.path="./?.lua;"..package.path
keys={f12=12,backspace=14,enter=28}
colors={black=32768,white=1}
local locked,enrollment=false,false
local login,created,frames=0,0,0
local now,wait=0,0
os.clock=function() return now end
local scheduled
package.loaded["system.security.users"]={authenticationStatus=function() return {retryAfter=wait} end,needsEnrollment=function() return enrollment end}
package.loaded["system.services.securityd"]={
  isLocked=function() return locked end,
  lock=function() locked=true return false,"disk full" end,
  login=function(name,password,opts)
    assert(name=="admin","guest password bypassed console")
    login=login+1 opts.progress(1,2) coroutine.yield("timer")
    if password=="secret password" then locked=false return true end
    return false,"invalid credentials"
  end,
  enroll=function(password)
    created=created+1 assert(password=="new password") enrollment=false return true
  end,
}
local ctx={invalidateDisplay=function() frames=frames+1 end,pixelWorkspace={deactivate=function() end},
  scheduler={spawn=function(_,_,fn) scheduled=coroutine.create(fn) return 1 end,
    start=function() local ok,err=coroutine.resume(scheduled) return ok,err end}}
os.queueEvent=function() end
local screen=require("system.security.session_screen").new(ctx)
local function event(name,...) return screen:handle({name=name,args={...}}) end
assert(not screen:sync())
assert(event("key",keys.f12) and screen:blocked(),"failed persistence exposed unlocked desktop")
for _,name in ipairs({"char","paste","key","key_up","mouse_click","mouse_drag","mouse_up","mouse_scroll","file_transfer","terminate"}) do
  assert(event(name,"x",1,1),"locked input escaped: "..name)
end
screen.password=""
assert(not event("timer",123) and not event("modem_message","left"),"background acquisition suspended")
event("paste","wrong") event("key",keys.enter)
assert(screen.busy and screen.password=="" and login==1)
event("paste","secret password") assert(screen.password=="","busy auth accepted duplicate credentials")
assert(coroutine.resume(scheduled,"timer",1)) assert(not screen.busy and screen:blocked())
event("paste","secret password") event("key",keys.enter)
assert(coroutine.resume(scheduled,"timer",2)) assert(not screen:blocked())
enrollment=true screen:sync()
event("paste","short") event("key",keys.enter) assert(created==0)
screen.password="" event("paste","new password") event("key",keys.enter) assert(created==0)
event("paste","different password") event("key",keys.enter) assert(created==0 and screen.password=="")
event("paste","new password") event("key",keys.enter)
event("paste","new password") event("key",keys.enter)
assert(created==1 and not screen:blocked())
locked=true wait=30 screen:sync() screen.password="secret password"
local previous=login
screen:submit() assert(login==previous and screen:retrySeconds()==30,"cooldown started a KDF")
assert(screen:messageText():find("30s",1,true))
now=1 assert(screen:tick() and screen:retrySeconds()==29)
now=31 wait=0 assert(screen:tick() and screen:retrySeconds()==0)
screen.password="secret password"
local Surface=require("system.graphics.surface")
local backend={surface=Surface.new(306,171,4)}
screen:drawPixels(backend)
for _,row in ipairs(backend.surface.rows) do assert(not row:find("secret password",1,true)) end
assert(frames>0)
print("session screen: fail-closed lock, input isolation, background events, async auth, admin login, enrollment and masking passed")
