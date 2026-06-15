local log = require("system.libraries.log")
local httpClient = require("system.network.http_client")
local websocket = require("system.network.websocket")

local M = {
  status = {
    http = false,
    websocket = false,
    message = "not started",
  },
}

function M.refresh()
  local httpStatus = httpClient.check()
  M.status = {
    http = httpStatus.available,
    websocket = websocket.available(),
    message = httpStatus.message,
  }
  return M.status
end

function M.start(ctx)
  local status = M.refresh()
  log.info("networkd", "http=" .. tostring(status.http) .. " websocket=" .. tostring(status.websocket))
  if ctx and ctx.notifications then
    ctx.notifications:push(status.http and "success" or "warn", "Network", status.message, 3)
  end
end

function M.getStatus()
  return M.status
end

return M
