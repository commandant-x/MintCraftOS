package.path = "./?.lua;" .. package.path
local fixture = assert(loadfile("tests/storage-fixture.lua"))()
local nativeLoadfile = loadfile
local function fresh(name)
  package.loaded[name]=nil
  return require(name)
end

-- Abruptly abandon a suspended writer after every filesystem mutation.
local stages = 0
for crashAt=1,80 do
  local state=fixture()
  state.put("/system/config/test.cfg", "old")
  local writer=fresh("system.libraries.safe_write")
  local operations=0
  state.hook=function()
    operations=operations+1
    if operations==crashAt then coroutine.yield("power loss") end
  end
  local co=coroutine.create(function() assert(writer.write("/system/config/test.cfg","new")) end)
  assert(coroutine.resume(co))
  local crashed=coroutine.status(co)=="suspended"
  state.hook=nil
  assert(writer.recoverAll("/"))
  local value=state.nodes["/system/config/test.cfg"]
  assert(value=="old" or value=="new", "Save recovery lost both versions")
  if fs.exists("/system/config/test.cfg.mintcraft-save") then
    assert(value=="old" and not fs.exists("/system/config/test.cfg.mintcraft-save/previous"), "Recovery retained a mutated unmarked save")
  end
  if not crashed then break end
  stages=stages+1
end
assert(stages>=7)

-- Never delete arbitrary user directories that happen to have the save suffix.
local unknown=fixture()
unknown.put("/home/user/docs/project.mintcraft-save/important.txt","keep")
local unknownWriter=fresh("system.libraries.safe_write")
assert(unknownWriter.recoverAll("/"))
assert(unknown.nodes["/home/user/docs/project.mintcraft-save/important.txt"]=="keep")
assert(not unknownWriter.recover("/home/user/docs/project"))

-- CC combine commonly strips the initial slash; read-only and mounted roots stay untouched.
local combine, list=fs.combine,fs.list
local visited={}
fs.combine=function(a,b) return combine(a,b):gsub("^/","") end
fs.list=function(path) visited[path]=true return list(path) end
fs.isReadOnly=function(path) return path:match("^/rom")~=nil end
fs.getDrive=function(path) return path:match("^/home/mounted") and "disk" or "hdd" end
unknown.put("/rom/lib/test","rom") unknown.put("/source/repo/test","source")
unknown.put("/home/mounted/file","mounted")
assert(unknownWriter.recoverAll("/"))
assert(not visited["/rom"] and not visited["/source"] and not visited["/home/mounted"])

local transactionStages=0
for crashAt=1,150 do
  local state=fixture()
  state.put("/apps/demo/main.lua","old")
  local writer=fresh("system.libraries.safe_write")
  local allowed=function(path) return path=="apps/demo/main.lua" or path=="apps/demo/new.lua" end
  local operations=0
  state.hook=function()
    operations=operations+1
    if operations==crashAt then coroutine.yield("power loss") end
  end
  local co=coroutine.create(function()
    assert(writer.transaction("/var/tmp/transaction",{["apps/demo/main.lua"]="new",["apps/demo/new.lua"]="added"},allowed))
  end)
  assert(coroutine.resume(co))
  local crashed=coroutine.status(co)=="suspended"
  state.hook=nil
  local recovered=writer.recoverTransaction("/var/tmp/transaction",allowed)
  if recovered then
    local old=state.nodes["/apps/demo/main.lua"]=="old" and not fs.exists("/apps/demo/new.lua")
    local new=state.nodes["/apps/demo/main.lua"]=="new" and state.nodes["/apps/demo/new.lua"]=="added"
    assert(old or new,"Transaction recovered a mixed state")
  else
    assert(fs.exists("/var/tmp/transaction"),"Invalid journal was discarded")
    assert(state.nodes["/apps/demo/main.lua"]=="old","Preparation crash changed live file")
  end
  if not crashed then break end
  transactionStages=transactionStages+1
end
assert(transactionStages>=20)

-- Recovery validates all entries and backup types before touching the first target.
local state=fixture()
local writer=fresh("system.libraries.safe_write")
state.put("/apps/demo/main.lua","current")
state.put("/var/tmp/transaction/backup/apps/demo/main.lua","old")
state.config("/var/tmp/transaction/journal.cfg",{
  {path="apps/demo/main.lua",existed=true},{path="system/config/security.cfg",existed=false},
})
assert(not writer.recoverTransaction("/var/tmp/transaction",function(path) return path:match("^apps/demo/") end))
assert(state.nodes["/apps/demo/main.lua"]=="current")
assert(fs.exists("/var/tmp/transaction/backup/apps/demo/main.lua"))

-- config.ensure recovers a renamed previous save before deciding to create defaults.
state=fixture()
writer=fresh("system.libraries.safe_write")
state.put("/system/config/demo.cfg.mintcraft-save/previous","{custom=true}")
state.put("/system/config/demo.cfg.mintcraft-save/next","{default=true}")
local config=fresh("system.libraries.config")
assert(config.ensure("/system/config/demo.cfg",{default=true}))
assert(config.load("/system/config/demo.cfg",{}).custom)

-- Raw fallback: incremental missing originals, strict validation, retained backup.
local raw=assert(nativeLoadfile("system/boot/recovery.lua"))
state=fixture()
state.config("/var/backups/update/latest.cfg",{id="1"})
local manifest={id="1",kind="files",paths={"/VERSION","/apps/demo/new.lua"},existed={["/VERSION"]=true,["/apps/demo/new.lua"]=false}}
state.config("/var/backups/update/1/manifest.cfg",manifest)
state.put("/var/backups/update/1/VERSION","old")
state.put("/VERSION","new") state.put("/apps/demo/new.lua","added")
assert(raw("--raw-rollback"))
assert(state.nodes["/VERSION"]=="old" and not fs.exists("/apps/demo/new.lua"))
assert(state.nodes["/var/backups/update/1/VERSION"]=="old")
for _, bad in ipairs({"/system/config/security.cfg","/system/./config/security.cfg","/system/config","/system//bad.lua","/system/../bad.lua","/home/user/data"}) do
  manifest.paths={"/VERSION",bad} manifest.existed[bad]=false
  state.config("/var/backups/update/1/manifest.cfg",manifest) state.put("/VERSION","current")
  assert(not raw("--raw-rollback"))
  assert(state.nodes["/VERSION"]=="current")
end

-- Standalone installer restores no files until its entire journal validates.
local installStages=0
for crashAt=1,160 do
  state=fixture()
  state.put("/VERSION","old") state.put("/system/demo.lua","return 'old'")
  local crashInstaller=assert(nativeLoadfile("system/libraries/installer.lua"))()
  loadfile=function(path) return load(state.nodes[path],path,"t",_ENV) end
  local operations=0
  state.hook=function()
    operations=operations+1
    if operations==crashAt then coroutine.yield("power loss") end
  end
  local co=coroutine.create(function() assert(crashInstaller.install({VERSION="new",["system/demo.lua"]="return 'new'",["system/added.lua"]="return true"})) end)
  local ran, problem=coroutine.resume(co) assert(ran,problem)
  local crashed=coroutine.status(co)=="suspended"
  state.hook=nil loadfile=nativeLoadfile
  local recovered=crashInstaller.recover()
  if recovered then
    local old=state.nodes["/VERSION"]=="old" and state.nodes["/system/demo.lua"]=="return 'old'" and not fs.exists("/system/added.lua")
    local new=state.nodes["/VERSION"]=="new" and state.nodes["/system/demo.lua"]=="return 'new'" and state.nodes["/system/added.lua"]=="return true"
    assert(old or new,"Installer recovery mixed versions")
  else
    assert(fs.exists("/var/tmp/mintcraft-install"))
    assert(state.nodes["/VERSION"]=="old" and state.nodes["/system/demo.lua"]=="return 'old'","Pre-journal crash changed live data")
  end
  if not crashed then break end
  installStages=installStages+1
end
assert(installStages>=20)
state=fixture()
local installer=assert(nativeLoadfile("system/libraries/installer.lua"))()
state.put("/VERSION","current")
state.put("/var/tmp/mintcraft-install/backup/VERSION","old")
state.config("/var/tmp/mintcraft-install/journal.cfg",{{path="VERSION",existed=true},{path="system/later.lua",existed=true}})
assert(not installer.recover()) assert(state.nodes["/VERSION"]=="current")
state.put("/var/tmp/mintcraft-install/backup/system/later.lua","return true")
assert(installer.recover()) assert(state.nodes["/VERSION"]=="old")

-- A moved /system tree is restored before boot attempts to load any filesystem module.
state=fixture()
state.put("/var/tmp/mintcraft-restore/previous/libraries/sentinel","previous system")
state.put("/var/tmp/mintcraft-restore/next/libraries/sentinel","checkpoint system")
state.config("/var/tmp/mintcraft-restore/target.cfg","/system")
state.put("/var/backups/update/1/system/libraries/sentinel","checkpoint system")
state.config("/var/backups/update/1/manifest.cfg",{id="1",paths={"/system"}})
state.config("/var/tmp/mintcraft-rollback.cfg",{id="1"})
local boot=assert(nativeLoadfile("boot.lua"))
local started=false
package.loaded["system.boot.bootloader"]={start=function() started=true end}
loadfile=function(path)
  assert(fs.exists("/system"),"Filesystem module loaded before /system restoration")
  return nativeLoadfile((path:gsub("^/","")))
end
local booted, bootError=pcall(boot)
loadfile=nativeLoadfile
assert(booted, tostring(bootError).."; "..tostring(state.nodes["/var/logs/last_crash.log"]))
assert(started and state.nodes["/system/libraries/sentinel"]=="checkpoint system")
print("storage recovery tests passed: "..stages.." save / "..transactionStages.." transaction / "..installStages.." installer crash stages")
