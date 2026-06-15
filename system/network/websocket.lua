local M = {}

function M.available()
  return http ~= nil and type(http.websocket) == "function"
end

function M.connect(url, headers)
  if not M.available() then return nil, "WebSocket API disabled" end
  if not url:match("^wss?://") then url = "wss://" .. url end
  local ok, socket = pcall(http.websocket, url, headers)
  if not ok then return nil, tostring(socket) end
  return socket
end

return M
