package.path="./?.lua;"..package.path
local state=assert(loadfile("tests/storage-fixture.lua"))()()
state.put("/VERSION","1.0.0")
local nativeLoadfile=loadfile
loadfile=function(path,...) if state.nodes[path] then return load(state.nodes[path],"@"..path,"t",_ENV) end return nativeLoadfile(path,...) end
os.epoch=function() return 123 end
local sha=string.rep("a",40)
state.config("/system/config/update.cfg",{repo="owner/repo",branch=sha,autoCheck=false})
local script
http={get=function(url)
  local data=url:find("install.lua",1,true) and script or "2.0.0"
  local offset=1
  return {read=function(n) local part=data:sub(offset,offset+n-1) offset=offset+#part if part~="" then return part end end,
    close=function() end,getResponseCode=function() return 200 end}
end}
local updated=require("system.services.updated")
script="-- MintCraft installer protocol: 2\nmintcraftInstallOptions.beforeInstall({version='2.0.0',stageBytes=5,backupBytes=5,changed={'VERSION'}})"
local ok,err=updated.apply()
assert(not ok and err:find("UPD-STATE",1,true) and updated.localVersion()=="1.0.0","hook-only installer falsely succeeded")
assert(not _G.mintcraftStorageOperation,"failed installer leaked storage latch")
local phases={}
script="-- MintCraft installer protocol: 2\nrequire('system.libraries.installer').install({VERSION='2.0.0'},mintcraftInstallOptions)"
ok,err=updated.apply({progress=function(phase) phases[phase]=true error('observer failure must not abort') end})
assert(ok,tostring(err)) assert(updated.localVersion()=="2.0.0")
assert(phases.stage and phases.backup and phases.install,"transaction progress not forwarded")
assert(updated.rollback()) assert(updated.localVersion()=="1.0.0")
local changed=false
ok,err=updated.apply({authorize=function() return not changed,"permission revoked" end,progress=function(phase) if phase=="download" then changed=true end end})
assert(not ok and updated.localVersion()=="1.0.0" and not _G.mintcraftStorageOperation,"revoked operation changed installed files or leaked lock")
print("update transaction: hook-only refusal, explicit commit/version verification, observer isolation, rollback and prewrite revocation passed")
