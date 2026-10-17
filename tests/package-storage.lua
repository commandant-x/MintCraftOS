package.path = "./?.lua;" .. package.path
local fixture = assert(loadfile("tests/storage-fixture.lua"))()
package.loaded["system.libraries.log"]={info=function() end,warn=function() end}
local function manager()
  _G.mintcraftStorageOperation=nil -- A new manager here models a fresh boot after power loss.
  for _,name in ipairs({"system.libraries.safe_write","system.libraries.config","system.package.manifest","system.package.package_manager"}) do package.loaded[name]=nil end
  return require("system.package.package_manager")
end
local function source(state, files, id)
  id=id or "demo"
  state.config("/packages/sources.db",{packages={{id=id,name="Demo",version="1",files=files or {["apps/demo/main.lua"]="return {}"},app={id=id,module="apps."..id..".main"}}}})
end
local state=fixture()
local pkg=manager()
source(state)
local metadata
pkg.setContext({apps={register=function(_,_,_,meta) metadata=meta end}})
assert(pkg.install("demo"))
assert(metadata.builtin==false)
local installed=textutils.unserialize(state.nodes["/packages/installed.db"])
assert(installed.demo.files["apps/demo/main.lua"]==true)
assert(not state.nodes["/packages/installed.db"]:find("return {}",1,true))
assert(pkg.remove("demo")) assert(not fs.exists("/apps/demo/main.lua"))

for _,path in ipairs({"boot.lua","startup.lua","system/config/security.cfg","packages/installed.db","apps/settings/main.lua","apps/demo/../terminal/main.lua","apps/demo//main.lua","apps/demo/.mintcraft-save/next","apps/demo\\evil.lua","home/user/note"}) do
  state=fixture() pkg=manager() source(state,{[path]="return {}"})
  assert(not pkg.install("demo"),"Accepted protected path "..path)
  assert(not fs.exists("/packages/installed.db"))
end
state=fixture() pkg=manager() source(state,{["apps/settings/main.lua"]="return {}"},"settings")
assert(not pkg.install("settings"))
state=fixture() pkg=manager() source(state)
state.put("/apps/demo/main.lua","user")
assert(not pkg.install("demo")) assert(state.nodes["/apps/demo/main.lua"]=="user")
state=fixture() pkg=manager() source(state)
pkg.setContext({apps={get=function() return {builtin=true} end}})
assert(not pkg.install("demo")) assert(not fs.exists("/apps/demo/main.lua"))

-- Legacy payload metadata migrates without touching files or executing code.
state=fixture() pkg=manager()
state.config("/packages/installed.db",{demo={id="demo",name="Demo",version="1",files={["apps/demo/main.lua"]="return 'payload'"},app={id="demo",module="apps.demo.main"}}})
assert(#pkg.installed()==1)
assert(textutils.unserialize(state.nodes["/packages/installed.db"]).demo.files["apps/demo/main.lua"]==true)

-- Invalid legacy records are quarantined, retained, and never break boot registration.
state=fixture() pkg=manager()
local bad={id="settings",name="Hijack",version="1",files={["apps/settings/main.lua"]="payload"},app={id="settings",module="apps.settings.main"}}
state.config("/packages/installed.db",{settings=bad}) state.put("/apps/settings/main.lua","original")
local original=state.nodes["/packages/installed.db"]
pkg.setContext({apps={register=function() error("Quarantined app was registered") end}})
assert(pcall(pkg.registerInstalledApps))
assert(#pkg.quarantined==1 and #pkg.installed()==0)
assert(state.nodes["/packages/installed.db"]==original and state.nodes["/apps/settings/main.lua"]=="original")
assert(not pkg.remove("settings"))

-- Crash each install/remove mutation; files and ownership must recover together.
local counts={}
for _,mode in ipairs({"install","remove"}) do
  local stages=0
  for crashAt=1,200 do
    state=fixture() pkg=manager() source(state)
    if mode=="remove" then assert(pkg.install("demo")) end
    local operations=0
    state.hook=function()
      operations=operations+1
      if operations==crashAt then coroutine.yield("power loss") end
    end
    local co=coroutine.create(function() assert(pkg[mode]("demo")) end)
    assert(coroutine.resume(co))
    local crashed=coroutine.status(co)=="suspended"
    state.hook=nil
    pkg=manager()
    local ok, rows=pcall(pkg.installed)
    if ok then
      assert((#rows==1)==fs.exists("/apps/demo/main.lua"),"Package files/database mismatch")
    else
      assert(fs.exists("/var/tmp/mintcraft-package"),"Recovery failure discarded journal")
    end
    if not crashed then break end
    stages=stages+1
  end
  assert(stages>=10) counts[mode]=stages
end
print("package storage tests passed: "..counts.install.." install / "..counts.remove.." remove crash stages")
