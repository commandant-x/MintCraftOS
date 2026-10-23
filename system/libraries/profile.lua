local M={name="MintCraftOS apps"}
local settings
local core={settings=true,editor=true}
local mobile={settings=true,terminal=true,files=true,editor=true,update=true,messenger=true,devices=true}
local function load()
  if settings then return end
  local ok,value=pcall(function() return require("system.libraries.config").load("/system/config/profile.cfg",{}) end)
  settings=ok and type(value)=="table" and value or {}
  if settings.mode~="desktop" and settings.mode~="pocket" then settings.mode="auto" end
  settings.apps=type(settings.apps)=="table" and settings.apps or {}
end
function M.mode()
  load() if settings.mode=="auto" then return pocket and "pocket" or "desktop" end return settings.mode
end
function M.appEnabled(id)
  load() if core[id] then return true end
  if type(settings.apps[id])=="boolean" then return settings.apps[id] end
  return M.mode()=="desktop" or mobile[id]==true
end
function M.isCore(id) return core[id]==true end
function M.configuration() load() return require("system.libraries.addon").copy(settings) end
function M.configure(value)
  if type(value)~="table" or (value.mode~="auto" and value.mode~="desktop" and value.mode~="pocket") or type(value.apps)~="table" then return false,"Invalid app profile" end
  for id,enabled in pairs(value.apps) do
    if type(id)~="string" or type(enabled)~="boolean" then return false,"Invalid app choice" end
    if core[id] and not enabled then return false,"Essential app: "..id end
  end
  local ok,err=require("system.libraries.safe_write").write("/system/config/profile.cfg",textutils.serialize(value))
  if ok then settings=require("system.libraries.addon").copy(value) end
  return ok,err
end
function M.serviceEnabled(id)
  if id=="nexusd" then return M.appEnabled("nexus") end
  if id=="vehiclebridged" or id=="atlasd" then return M.appEnabled("navigation") end
  if id=="sabled" or id=="avionicsd" then return M.appEnabled("navigation") or M.appEnabled("combat") end
  if id=="flightd" then return M.appEnabled("navigation") end
  if id=="combatd" or id=="radarnetd" then return M.appEnabled("combat") end
  if id=="messaged" then return M.appEnabled("messenger") end
  if id=="updated" then return M.appEnabled("update") end
  return true
end
function M.dependencies(id)
  if id=="settings" then return {"settingsd"} end
  if id=="nexus" then return {"nexusd"} end
  if id=="navigation" then return {"sabled","avionicsd","vehiclebridged","atlasd","flightd"} end
  if id=="combat" then return {"sabled","avionicsd","combatd","radarnetd"} end
  if id=="messenger" then return {"messaged"} end
  if id=="update" then return {"updated"} end
  return {}
end
return M
