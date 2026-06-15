local config = require("system.libraries.config")
local log = require("system.libraries.log")

local M = {
  cfgPath = "/system/config/security.cfg",
  status = "not started",
  cfg = nil,
}

function M.load()
  M.cfg = config.load(M.cfgPath, {
    enabled = true,
    mode = "single-user",
    currentUser = "admin",
    logDenied = true,
    logSensitive = true,
  })
  return M.cfg
end

function M.statusText()
  if not M.cfg then M.load() end
  return tostring(M.cfg.mode) .. " user=" .. tostring(M.cfg.currentUser)
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
