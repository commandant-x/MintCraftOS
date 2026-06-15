local log = require("system.libraries.log")

local M = {}

local function listToSet(list)
  local set = {}
  for _, item in ipairs(list or {}) do set[item] = true end
  return set
end

local function actorLabel(actor)
  if type(actor) ~= "table" then return "system" end
  return tostring(actor.appId or actor.name or ("pid " .. tostring(actor.pid or "?")))
end

function M.has(actor, permission)
  if permission == nil or permission == "" then return true end
  if actor == nil then return true end
  if actor.system == true then return true end
  local okSecurity, securityd = pcall(require, "system.services.securityd")
  if okSecurity and securityd and securityd.authorize then
    local allowed = securityd.authorize(actor, permission)
    if not allowed then return false end
  end
  local permissions = actor.permissions or {}
  if permissions[permission] == true then return true end
  local set = listToSet(permissions)
  return set[permission] == true or set["*"] == true
end

function M.require(actor, permission, target)
  if M.has(actor, permission) then return true end
  local okSecurity, securityd = pcall(require, "system.services.securityd")
  if okSecurity and securityd and securityd.authorize then
    local allowed, reason = securityd.authorize(actor, permission)
    if not allowed then
      local message = tostring(reason)
      if target then message = message .. " on " .. tostring(target) end
      log.warn("security", actorLabel(actor) .. " " .. message)
      return false, message
    end
  end
  local message = "permission denied: " .. tostring(permission)
  if target then message = message .. " on " .. tostring(target) end
  log.warn("security", actorLabel(actor) .. " " .. message)
  return false, message
end

function M.audit(actor, action, target)
  local message = actorLabel(actor) .. " " .. tostring(action)
  if target then message = message .. " " .. tostring(target) end
  log.info("security", message)
end

return M
