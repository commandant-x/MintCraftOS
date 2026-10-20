package.path="./?.lua;"..package.path
colors={red=2,white=1} keys={escape=1,backspace=2,enter=3}
local w,h=24,17
local pixels={}
local function bounds(x,y,width,height)
  assert(x>=1 and y>=1 and x+width-1<=w and y+(height or 1)-1<=h,"Settings draw out of bounds")
end
package.loaded["system.gui.renderer"]={
  crop=function(s,width) return s:sub(1,math.max(0,width)) end,
  fill=bounds,
  writeAt=function(x,y,text,fg,bg) bounds(x,y,#text) assert(fg and bg) pixels[y]=(pixels[y] or "")..text end,
  button=function(x,y,width) bounds(x,y,width) end,
}
local changes={}
package.loaded["system.gui.theme"]={currentId="dark",get=function(key) return key=="windowFg" and 8 or 16 end,set=function(id) changes.theme=id return true end}
package.loaded["system.libraries.config"]={load=function(_,fallback) return fallback end}
package.loaded["system.libraries.version"]={current=function() return "test" end}
package.loaded["system.services.deviced"]={getDisplay=function() return {width=26,height=20,target="computer",scale=1} end,hasType=function() return false end,
  list=function() return {{name="monitor_0",type="monitor"}} end,getPreference=function() return "auto" end,
  setTarget=function(value) changes.display=value return true end,
  refreshDisplay=function() changes.refresh=true end,setScale=function(value) changes.scale=value return true end}
package.loaded["system.services.networkd"]={getStatus=function() return {} end}
package.loaded["system.services.audiod"]={status=function() return {speakers={{side="left"}},volume=1} end,
  setEnabled=function() changes.audio=true return true end,test=function() changes.test=true return true end,
  setVolume=function(value) changes.volume=value return true end,use=function(value) changes.speaker=value return true end}
local authCalls=0
package.loaded["system.services.securityd"]={currentUser=function() return {name="admin"} end,statusText=function() return "ready" end,users=function() return {} end,
  setPassword=function(name,new,old,actor,options) authCalls=authCalls+1 assert(name=="admin" and new=="new password" and old=="old password") options.progress(5000,600000) return true end,
  unlock=function() authCalls=authCalls+1 return true,"unlocked" end,login=function() authCalls=authCalls+1 return true,"logged in" end,
  lock=function() return true end,logout=function() return true end}
local cleanupCalls=0
package.loaded["system.services.updated"]={storageInfo=function() return {bytes=1024,backups={{id="1",bytes=1024,protected=true}}} end,
  cleanup=function(kind,options) assert(kind=="updates" and options.confirm==true) cleanupCalls=cleanupCalls+1 return true,"Pruned" end}
package.loaded["system.gui.keyboard"]={height=function() return 8 end,draw=function() end,handle=function() return false end}
local configured
package.loaded["system.libraries.profile"]={mode=function() return "desktop" end,isCore=function(id) return id=="settings" end,
  appEnabled=function() return true end,configuration=function() return {mode="desktop",apps={}} end,configure=function(value) configured=value return true end}
package.loaded["system.services.sabled"]={status=function() return {} end}
package.loaded["system.services.avionicsd"]={status=function() return {} end}
package.loaded["system.services.combatd"]={status=function() return {} end}
fs={getFreeSpace=function() return "unlimited" end,getCapacity=function() return "unlimited" end}
term={getSize=function() return 120,40 end} os.setComputerLabel=function(value) changes.label=value end
os.queueEvent=function() end
local permitted=false
package.loaded['system.services.settingsd']={status=function() return {busy=false} end,request=function(_,id,value)
  if not permitted then return false,'denied' end
  if id=='cleanupConfirm' then assert(value==true) cleanupCalls=cleanupCalls+1
  elseif id=='theme:mint' then changes.theme='mint'
  elseif id=='scale:0.5' then changes.scale=0.5
  elseif id=='audio' then changes.audio=true
  elseif id=='display:monitor_0' then changes.display='monitor_0'
  elseif id=='profile:pocket' then configured={mode='pocket'} end
  return true,1
end}
package.loaded['system.libraries.app_worker']={new=function(_,_,read,done)
  return {submit=function(_,request) local ok,result=pcall(read,request) done(request,ok,result) return true end}
end}
local app,worker,cleanup,invalidations,launched=nil,nil,nil,0,nil
local ctx={pid=7,appId="settings",permissions={"system.security.admin"},security={require=function() return permitted,"denied" end},
  notifications={push=function() end},apps={list=function() return {{id="browser",name="Browser"},{id="settings",name="Settings"}} end,launch=function(id) launched=id end},
  system={packages={installed=function() return {} end},scheduler={spawn=function(_,_,callback,meta) assert(meta.eventMode=="raw" and meta.protected) worker=callback return 99 end,start=function() return true end}},
  onCleanup=function(callback) cleanup=callback end,invalidate=function() invalidations=invalidations+1 end,
  startTimer=function() return 1 end,cancelTimer=function() end,
  windowManager={create=function(_,opts) app=opts.app return {closed=true} end}}
require("apps.settings.main").run(ctx)
local function click(x,y) return app:handle({name="mouse_click",args={1,x,y}}) end
for _,size in ipairs({{12,9},{24,17},{70,22}}) do
  w,h=table.unpack(size)
  for _,page in ipairs({"system","display","desktop","network","storage","sound","security","apps","packages","dev","nav","combat"}) do
    app.page=page app:requestRead() app.scroll=1 pixels={} app:draw(w,h)
    app.actions.open=true app:draw(w,h) app.actions.open=false
    app.views.open=true app:draw(w,h) app.views.open=false
  end
end
w,h=24,17
for _,page in ipairs({"nav","combat"}) do
  app.page=page app:requestRead() app:draw(w,h)
  local box=app.actions.boxes[1]
  assert(box and click(box.x,box.y))
  assert(launched==(page=="nav" and "navigation" or "combat"),"local launch hitbox used global term size")
end
for _,id in ipairs({"theme:mint","label","scale:0.5","display:computer","audio","test","volume:0.5","speaker:left","refresh"}) do app:action(id) end
assert(next(changes)==nil,"guest changed Settings")
app:action("passwordOld") assert(not app.mode)
app:action("cleanup") app:action("cleanupConfirm") assert(cleanupCalls==0)
permitted=true
app:action("cleanupConfirm") assert(cleanupCalls==0,"cleanup skipped confirmation")
app:action("cleanup") assert(app.cleanupPending and cleanupCalls==0)
app:action("cleanupConfirm") assert(cleanupCalls==1)
app.page='sound' app:requestRead()
app:action("theme:mint") app:action("scale:0.5") app:action("audio")
assert(changes.theme=="mint" and changes.scale==0.5 and changes.audio)
app:action("display:monitor_0") assert(changes.display=="monitor_0")
app:action("profile:pocket") assert(configured.mode=="pocket")
app:action("passwordOld") app.input="old password" app.keyboard.onEnter()
assert(app.mode=="passwordNew") app.input="new password" app.keyboard.onEnter()
assert(app.mode=="passwordConfirm") app.input="new password" app.keyboard.onEnter()
assert(app.authBusy and authCalls==0 and not app.input:find("password"),"KDF ran synchronously in UI handler")
app:action("adminLogin") assert(app.authBusy and not app.mode,"duplicate auth was allowed")
worker() assert(not app.authBusy and authCalls==1 and invalidations>0)
app:beginInput("passwordOld") app.input="secret" app.keyboard.onEnter()
app:handle({name="key",args={keys.escape}}) assert(not app.mode and not app.oldPassword)
app:beginInput("unlock") app.input="secret" app.keyboard.onEnter() assert(app.authBusy)
app:action("cancelAuth") assert(app.authCancel) cleanup() worker()
assert(not app.authBusy)
print("Settings local launch hitboxes, small/large bounds, menu reachability, guest guards, confirmed cleanup and raw auth worker passed")
