local log = require("system.libraries.log")

local M = {}

function M.start()
  log.info("logd", "log service ready")
end

function M.stop()
  log.info("logd", "log service stopped")
end

return M
