local config = require("system.libraries.config")
local log = require("system.libraries.log")
local users = require("system.security.users")

local M = {
  cfgPath = "/system/config/security.cfg",
  status = "not started",
  cfg = nil,
}

function M.load()
  M.cfg = config.load(M.cfgPath, {
    enabled = true,
    mode = "users",
    currentUser = "admin",
    logDenied = true,
    logSensitive = true,
  })
  if M.cfg.mode == "single-user" then
    M.cfg.mode = "users"
    config.save(M.cfgPath, M.cfg)
  end
  users.load()
  return M.cfg
end

function M.statusText()
  if not M.cfg then M.load() end
  local user, db = users.current()
  return tostring(M.cfg.mode) .. " user=" .. tostring(user and user.name or "?") .. (db.locked and " locked" or " unlocked")
end

function M.currentUser()
  local user = users.current()
  return user
end

function M.isLocked()
  return users.isLocked()
end

function M.login(name, password)
  local ok, msg = users.login(name, password)
  log.info("securityd", ok and msg or ("login failed " .. tostring(name)))
  return ok, msg
end

function M.unlock(password)
  local ok, msg = users.unlock(password)
  log.info("securityd", ok and "session unlocked" or "unlock failed")
  return ok, msg
end

function M.lock()
  users.lock()
  log.info("securityd", "session locked")
  return true
end

function M.logout()
  users.logout()
  log.info("securityd", "logged out to guest")
  return true
end

function M.setPassword(name, password)
  local ok, msg = users.setPassword(name, password)
  log.info("securityd", ok and ("password changed for " .. tostring(name)) or tostring(msg))
  return ok, msg
end

function M.users()
  return users.list()
end

function M.authorize(actor, permission)
  if not M.cfg then M.load() end
  if M.cfg.enabled == false then return true end
  if actor and actor.system == true then return true end
  if permission == nil or permission == "" then return true end
  if users.isLocked() and permission ~= "system.auth" then return false, "session locked" end
  if not users.hasPermission(permission) then return false, "user permission denied: " .. tostring(permission) end
  return true
end

function M.start()
  M.load()
  M.status = "running"
  log.info("securityd", M.statusText())
end

function M.stop()
  M.status = "stopped"
end

return M
