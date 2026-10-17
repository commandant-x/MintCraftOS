local wire=require("system.nexus.protocol")
local store=require("system.nexus.storage")
local M={marker="-- MintCraft NEXUS bootstrap v1"}
M.files={"system/nexus/protocol.lua","system/nexus/storage.lua","system/nexus/agent.lua","system/libraries/password_crypto.lua","system/nexus/uninstall.lua"}
M.launcher=M.marker.."\n"..[=[
if not fs.exists('/nexus/config.cfg') and fs.exists('/nexus/config.cfg.backup') then fs.move('/nexus/config.cfg.backup','/nexus/config.cfg') end
local h=assert(fs.open('/nexus/config.cfg','r')) local cfg=textutils.unserialize(h.readAll()) h.close()
assert(type(cfg)=='table' and type(cfg.active)=='string' and cfg.active:match('^[%w_-]+$'),'Invalid NEXUS slot')
local function run(slot)
  package.path='/nexus/versions/'..slot..'/?.lua;'..package.path
  for _,name in ipairs({'system.nexus.protocol','system.nexus.agent','system.nexus.storage','system.libraries.password_crypto'}) do package.loaded[name]=nil end
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
function M.install(mount)
  local manifest=assert(store.load(fs.combine(mount,"nexus/manifest.cfg")),"NEXUS manifest missing")
  assert(manifest.schema==1 and type(manifest.release)=="string" and manifest.release:match("^[%w_-]+$") and #manifest.release<=64,"Invalid NEXUS release")
  local id=os.getComputerID()
  local association=type(manifest.nodes)=="table" and manifest.nodes[tostring(id)]
  if not association or manifest.master==id then return false,"Computer not selected" end
  assert(wire.validKey(association.key) and type(association.group)=="string","Invalid bootstrap association")
  store.recover("/nexus/config.cfg")
  local existing=store.load("/nexus/config.cfg")
  local startup=store.read("/startup.lua")
  if startup and startup:sub(1,#M.marker)~=M.marker then return false,"Existing startup protected; use an explicitly provisioned blank computer" end
  if fs.exists("/startup") or fs.exists("/system") or fs.exists("/boot.lua") then return false,"Existing installation protected" end
  if existing and (existing.master~=manifest.master or existing.id~=id or existing.key~=association.key) then return false,"Existing NEXUS association protected" end
  local root="/nexus/versions/"..manifest.release
  local source=fs.combine(mount,"nexus/payload")
  for _,path in ipairs(M.files) do
    local data=assert(store.read(fs.combine(source,path)),"Missing payload: "..path)
    assert(type(manifest.hashes)=="table" and manifest.hashes[path]==wire.hash(data),"Payload integrity mismatch: "..path)
    assert(load(data,"nexus/"..path,"t",{}),"Invalid Lua payload: "..path)
  end
  if existing and existing.active==manifest.release then
    for _,path in ipairs(M.files) do assert(wire.hash(assert(store.read(fs.combine(root,path)),"Installed payload missing"))==manifest.hashes[path],"Installed payload corrupt; prepare a repair disk") end
    if not fs.exists('/nexus/uninstall.lua') then store.write('/nexus/uninstall.lua',assert(store.read(fs.combine(root,'system/nexus/uninstall.lua')))) end
    if not startup then store.write('/startup.lua',M.launcher) end
    return true,"Already installed"
  end
  local stage="/nexus/staging/"..manifest.release
  if fs.exists(stage) then fs.delete(stage) end
  for _,path in ipairs(M.files) do
    local data=assert(store.read(fs.combine(source,path)))
    assert(wire.hash(data)==manifest.hashes[path],"Payload changed during installation")
    store.write(fs.combine(stage,path),data)
  end
  if fs.exists(root) then fs.delete(root) end
  fs.move(stage,root)
  local cfg=existing or {role="agent",id=id,master=manifest.master,key=association.key,group=association.group}
  cfg.previous,cfg.active=cfg.active,manifest.release
  cfg.group=association.group
  store.save("/nexus/config.cfg",cfg)
  store.write('/nexus/uninstall.lua',assert(store.read(fs.combine(root,'system/nexus/uninstall.lua'))))
  store.write("/startup.lua",M.launcher)
  return true,"Installed"
end
return M
