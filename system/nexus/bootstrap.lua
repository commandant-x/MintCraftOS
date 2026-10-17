local wire=require("system.nexus.protocol")
local store=require("system.nexus.storage")
local M={marker="-- MintCraft NEXUS bootstrap v1"}
M.files={"system/nexus/protocol.lua","system/nexus/storage.lua","system/nexus/agent.lua","system/nexus/observe.lua","system/libraries/password_crypto.lua","system/nexus/uninstall.lua"}
M.launcher=M.marker.."\n"..[=[
if not fs.exists('/nexus/config.cfg') and fs.exists('/nexus/config.cfg.backup') then fs.move('/nexus/config.cfg.backup','/nexus/config.cfg') end
local h=assert(fs.open('/nexus/config.cfg','r')) local cfg=textutils.unserialize(h.readAll()) h.close()
assert(type(cfg)=='table' and type(cfg.active)=='string' and cfg.active:match('^[%w_-]+$'),'Invalid NEXUS slot')
local function run(slot)
  package.path='/nexus/versions/'..slot..'/?.lua;'..package.path
  for _,name in ipairs({'system.nexus.protocol','system.nexus.agent','system.nexus.storage','system.nexus.observe','system.libraries.password_crypto'}) do package.loaded[name]=nil end
  return require('system.nexus.agent').run()
end
local ok,err=pcall(run,cfg.active)
if not ok then
  printError('NEXUS agent stopped: '..tostring(err))
  if type(cfg.previous)=='string' and cfg.previous:match('^[%w_-]+$') then
    print('Trying previous NEXUS slot') run(cfg.previous)
  end
end
]=]
local function eraseInternal(mount)
  assert(type(fs.getDrive)=="function" and type(fs.isReadOnly)=="function","Cannot identify internal storage safely")
  local drive=fs.getDrive('/')
  assert(drive=='hdd' and fs.getDrive(mount)~=drive and not fs.isReadOnly('/'),"Reset requires a separate boot disk and writable internal hdd")
  local function erase(path)
    if fs.getDrive(path)~=drive or fs.isReadOnly(path) then return end
    if fs.isDir(path) then
      for _,name in ipairs(fs.list(path)) do erase('/'..fs.combine(path,name):gsub('^/+','')) end
      if #fs.list(path)>0 then return end
    end
    fs.delete(path)
  end
  for _,name in ipairs(fs.list('/')) do erase('/'..name) end
end
function M.install(mount,options)
  local manifest=assert(store.load(fs.combine(mount,"nexus/manifest.cfg")),"NEXUS manifest missing")
  assert(manifest.schema==1 and type(manifest.release)=="string" and manifest.release:match("^[%w_-]+$") and #manifest.release<=64,"Invalid NEXUS release")
  local id=os.getComputerID()
  local association=type(manifest.nodes)=="table" and manifest.nodes[tostring(id)]
  if not association or manifest.master==id then return false,"Computer not selected" end
  assert(wire.validKey(association.key) and type(association.group)=="string","Invalid bootstrap association")
  local source=fs.combine(mount,"nexus/payload")
  local payload={}
  for _,path in ipairs(M.files) do
    local data=assert(store.read(fs.combine(source,path)),"Missing payload: "..path)
    assert(type(manifest.hashes)=="table" and manifest.hashes[path]==wire.hash(data),"Payload integrity mismatch: "..path)
    assert(load(data,"nexus/"..path,"t",{}),"Invalid Lua payload: "..path)
    payload[path]=data
  end
  store.recover("/nexus/config.cfg")
  local existing=store.load("/nexus/config.cfg")
  local reset=association.resetToken
  if not reset and association.forceToken then
    local startup=store.read('/startup.lua')
    local conflict=(startup and startup:sub(1,#M.marker)~=M.marker) or fs.exists('/startup') or fs.exists('/system') or fs.exists('/boot.lua')
      or (fs.exists('/nexus') and not existing)
      or (existing and (existing.role~='agent' or existing.id~=id or existing.master~=manifest.master or existing.key~=association.key))
    if existing and existing.active==manifest.release and not conflict then
      for _,path in ipairs(M.files) do
        local data=store.read('/nexus/versions/'..manifest.release..'/'..path)
        if not data or wire.hash(data)~=manifest.hashes[path] then conflict=true break end
      end
    end
    -- A trusted provisioning disk can authorize local recovery even when the
    -- old agent's key prevents it from reporting a failure to this MASTER.
    if conflict then reset=association.forceToken end
  end
  if reset~=nil then
    assert(type(reset)=='string' and #reset>=16 and #reset<=100 and reset:match('^[%w_-]+$'),"Invalid reset authorization")
    local completed=existing and existing.role=='agent' and existing.id==id and existing.master==manifest.master
      and existing.key==association.key and existing.provisionToken==reset
    if not completed then eraseInternal(mount) existing=nil end
  end
  local startup=store.read("/startup.lua")
  if startup and startup:sub(1,#M.marker)~=M.marker then return false,"Existing startup protected; use an explicitly provisioned blank computer" end
  if fs.exists("/startup") or fs.exists("/system") or fs.exists("/boot.lua") then return false,"Existing installation protected" end
  local changed=existing and (existing.master~=manifest.master or existing.id~=id or existing.key~=association.key)
  if changed then
    local reason=existing.master~=manifest.master and "MASTER changed" or (existing.id~=id and "agent ID changed" or "association key changed")
    if not options or options.confirmation~=("REASSOCIATE "..id.." MASTER "..manifest.master) then
      return false,"Existing NEXUS association protected: "..reason..". On this agent run: "..fs.combine(mount,"nexus/reassociate.lua")
    end
    assert(existing.role=="agent" and startup and startup:sub(1,#M.marker)==M.marker,"Only an existing NEXUS agent can be reassociated")
  end
  local root="/nexus/versions/"..manifest.release
  if existing and not changed and existing.active==manifest.release then
    for _,path in ipairs(M.files) do assert(wire.hash(assert(store.read(fs.combine(root,path)),"Installed payload missing"))==manifest.hashes[path],"Installed payload corrupt; prepare a repair disk") end
    if not fs.exists('/nexus/uninstall.lua') then store.write('/nexus/uninstall.lua',assert(store.read(fs.combine(root,'system/nexus/uninstall.lua')))) end
    if not startup then store.write('/startup.lua',M.launcher) end
    return true,"Already installed"
  end
  local stage="/nexus/staging/"..manifest.release
  if changed and existing.active==manifest.release then return false,"Reassociation requires a newly prepared release" end
  if fs.exists(stage) then fs.delete(stage) end
  for _,path in ipairs(M.files) do
    local data=payload[path]
    store.write(fs.combine(stage,path),data)
  end
  if fs.exists(root) then fs.delete(root) end
  fs.move(stage,root)
  local cfg=existing or {role="agent",id=id,master=manifest.master,key=association.key,group=association.group}
  if changed then
    store.save('/nexus/previous-association.cfg',existing)
    cfg={role="agent",id=id,master=manifest.master,key=association.key,group=association.group,active=existing.active}
    for _,name in ipairs({'receipts.cfg','receipt-expiry.cfg'}) do
      local path='/nexus/'..name
      if fs.exists(path) then store.write(path..'.previous-association',assert(store.read(path))) fs.delete(path) end
    end
  end
  cfg.previous,cfg.active=cfg.active,manifest.release
  cfg.group=association.group
  store.save("/nexus/config.cfg",cfg)
  store.write('/nexus/uninstall.lua',assert(store.read(fs.combine(root,'system/nexus/uninstall.lua'))))
  store.write("/startup.lua",M.launcher)
  if reset then cfg.provisionToken=reset store.save('/nexus/config.cfg',cfg) end
  return true,"Installed"
end
return M
