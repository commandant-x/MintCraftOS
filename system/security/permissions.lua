local log = require("system.libraries.log")
local names = require("system.libraries.file_names")
local M = {}

local function actorLabel(actor)
  if type(actor) ~= "table" then return "invalid actor" end
  return tostring(actor.appId or actor.name or ("pid " .. tostring(actor.pid or "?")))
end
local function declares(actor,permission)
  local list=actor.permissions
  if type(list)~="table" then return false end
  if list[permission]==true or list["*"]==true then return true end
  for _,item in ipairs(list) do if item==permission or item=="*" then return true end end
  return false
end
local function sensitive(path)
  path=names.absolute(path)
  for _,root in ipairs({"/system/config","/var/backups","/var/tmp/mintcraft-install","/var/tmp/mintcraft-package","/var/tmp/mintcraft-restore"}) do
    if path==root or path:sub(1,#root+1)==root.."/" then return true end
  end
  return path=="/system/security/users.db" or path:match("^/system/security/users%.db%.mintcraft%-save")~=nil
end
local function check(actor,permission,target)
  if permission==nil or permission=="" then return true end
  if type(permission)~="string" then return false,"invalid permission" end
  -- Nil/system actors are reserved for trusted internal services, not app input.
  if actor==nil then return true end
  if type(actor)~="table" then return false,"invalid actor" end
  if actor.system==true then return true end
  local loaded,security=pcall(require,"system.services.securityd")
  if not loaded or type(security)~="table" or type(security.authorize)~="function" then
    return false,"security service unavailable"
  end
  local function authorize(name)
    local ok,allowed,reason=pcall(security.authorize,actor,name)
    if not ok then return false,"security verification failed" end
    if allowed~=true then return false,type(reason)=="string" and reason or "session authorization denied" end
    return true
  end
  local ok,reason=authorize(permission)
  if not ok then return false,reason end
  if not declares(actor,permission) then return false,"permission denied: "..permission end
  if permission=="filesystem.read" and type(target)=="string" and sensitive(target) then
    ok,reason=authorize("system.security.admin")
    if not ok or not declares(actor,"system.security.admin") then return false,"protected security data" end
  end
  return true
end
function M.has(actor,permission,target) local allowed=check(actor,permission,target) return allowed end
function M.require(actor,permission,target)
  local allowed,reason=check(actor,permission,target)
  if allowed then return true end
  local message=tostring(reason)
  if target then message=message.." on "..tostring(target) end
  pcall(log.warn,"security",actorLabel(actor).." "..message)
  return false,message
end
function M.audit(actor,action,target)
  local message=actorLabel(actor).." "..tostring(action)
  if target then message=message.." "..tostring(target) end
  log.info("security",message)
end
return M
