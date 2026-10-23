package.path = "./?.lua;" .. package.path
local fixture=assert(loadfile("tests/storage-fixture.lua"))()
local function service()
  for _,name in ipairs({"system.libraries.safe_write","system.libraries.config","system.services.updated"}) do package.loaded[name]=nil end
  return require("system.services.updated")
end
local state=fixture()
local updated=service()
for id=1,4 do
  state.config("/var/backups/update/"..id.."/manifest.cfg",{id=tostring(id),paths={"/VERSION"}})
  state.put("/var/backups/update/"..id.."/VERSION","old")
end
state.config("/var/backups/update/latest.cfg",{id="4"})
state.config("/var/backups/update/previous.cfg",{id="3"})
assert(updated.setStoragePolicy({quotaBytes=0,retainCount=2}))
assert(#updated.report().backups==4 and updated.report().bytes>0)
assert(not updated.cleanup("updates",{}))
assert(not updated.cleanup("updates",{confirm=true,id="4"}))
assert(updated.cleanup("updates",{confirm=true}))
assert(#updated.report().backups==2)
assert(fs.exists("/var/backups/update/3/VERSION") and fs.exists("/var/backups/update/4/VERSION"))
state.config("/var/tmp/mintcraft-rollback.cfg",{id="3"})
assert(not updated.purgeBackup("3",true))
fs.delete("/var/tmp/mintcraft-rollback.cfg")
state=fixture() updated=service()
state.put("/var/backups/update/1/VERSION","only recovery copy")
assert(not updated.purgeBackup("1",true))
assert(fs.exists("/var/backups/update/1/VERSION"))
-- Incomplete directories must not make the sole usable checkpoint purgeable.
state.config("/var/backups/update/1/manifest.cfg",{id="1",paths={"/VERSION"}})
state.put("/var/backups/update/2/partial","incomplete")
assert(not updated.purgeBackup("1",true))
assert(not updated.purgeBackup("2",true))
assert(not updated.setStoragePolicy({quotaBytes=-1,retainCount=0}))
state.put("/VERSION","1.0.0")
assert(updated.setStoragePolicy({quotaBytes=1,retainCount=3}))
assert(not updated.createRollback("test",{"VERSION"}))
assert(fs.exists("/var/backups/update/1/VERSION"))

-- Apply/Rollback share one lock, and the version is rechecked after HTTP yields.
state=fixture() updated=service()
state.put("/VERSION","1.0.0")
local source=require("system.libraries.update_source")
local resolve,url=source.resolve,source.url
source.resolve=function() return {sha="pinned"} end
source.url=function(_,path) return path end
local script="-- MintCraft installer protocol: 2\nmintcraftInstallOptions.beforeInstall({version='2.0.0',stageBytes=1,backupBytes=1,changed={'VERSION'}})"
http={get=function(path)
  local data="2.0.0"
  if path=="install.lua" then
    local ok,reason=updated.rollback() assert(not ok and reason:find("in progress",1,true))
    ok,reason=updated.apply() assert(not ok and reason:find("in progress",1,true))
    state.put("/VERSION","2.0.0") data=script
  end
  local offset=1
  return {read=function(n)
    if offset>#data then return nil end
    local chunk=data:sub(offset,offset+n-1)
    offset=offset+#chunk
    return chunk
  end,close=function() end,getResponseCode=function() return 200 end}
end}
local ok,reason=updated.apply()
assert(not ok and reason:find("Installed version changed",1,true))
assert(not fs.exists("/var/backups/update/latest.cfg"))
ok,reason=updated.rollback()
assert(not ok and not reason:find("in progress",1,true),"Operation lock leaked after failure")
source.resolve,source.url=resolve,url

-- Legacy tree checkpoints remain usable, but current configs and packages survive.
state=fixture()
state.config("/var/backups/update/latest.cfg",{id="1"})
state.config("/var/backups/update/1/manifest.cfg",{id="1",paths={"/VERSION","/system","/packages"}})
state.put("/var/backups/update/1/VERSION","old")
state.put("/var/backups/update/1/system/libraries/code.lua","old code")
state.put("/var/backups/update/1/system/config/custom.cfg","old defaults")
state.put("/var/backups/update/1/packages/installed.db","old packages")
state.put("/VERSION","new") state.put("/system/config/custom.cfg","current user config")
state.put("/system/libraries/code.lua","new code") state.put("/packages/installed.db","current packages")
state.put("/system/libraries/packed_source_v2.lua","retained format decoder")
local raw=assert(loadfile("system/boot/recovery.lua"))
assert(raw("--raw-rollback"))
assert(state.nodes["/system/config/custom.cfg"]=="current user config")
assert(state.nodes["/system/libraries/code.lua"]=="old code")
assert(state.nodes["/system/libraries/packed_source_v2.lua"]=="retained format decoder")
assert(state.nodes["/packages/installed.db"]=="current packages")
assert(state.nodes["/var/backups/update/1/system/config/custom.cfg"]=="old defaults")
print("update storage, locking, version recheck and legacy preservation tests passed")
state=fixture() updated=service()
state.config('/system/config/update-storage.cfg',{quotaBytes=0,retainCount=1,retainRollback=false})
assert(updated.setStoragePolicy({quotaBytes=0,retainCount=2}))
assert(updated.storageInfo().policy.retainRollback==false,'storage edits reenabled version history')
local ok,info=updated.createRollback('disabled history')
assert(ok and info.disabled and not fs.exists('/var/backups/update'),'disabled policy created retained checkpoint')
assert(not updated.setStoragePolicy({quotaBytes=0,retainCount=1,retainRollback='false'}))
print('no-history policy: disabled checkpoint creation and preserved retention setting passed')
