local log = require("system.libraries.log")

local M = {
  lastStatus = {
    available = false,
    message = "not checked",
  },
}

local function trim(text)
  return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function M.available()
  return http ~= nil and type(http.get) == "function"
end

function M.check()
  M.lastStatus = {
    available = M.available(),
    message = M.available() and "HTTP available" or "HTTP API disabled",
  }
  return M.lastStatus
end

local function classifyHttpFailure(err)
  local text = tostring(err or "")
  local lower = text:lower()
  if lower:find("http api disabled", 1, true) then return "HTTP_DISABLED: " .. text end
  if lower:find("ssl", 1, true) or lower:find("certificate", 1, true) or lower:find("handshake", 1, true) then return "TLS_ERROR: " .. text end
  if lower:find("dns", 1, true) or lower:find("unknown host", 1, true) or lower:find("name", 1, true) then return "DNS_ERROR: " .. text end
  if lower:find("timeout", 1, true) or lower:find("timed", 1, true) then return "TIMEOUT: " .. text end
  if lower:find("refused", 1, true) then return "CONNECTION_REFUSED: " .. text end
  if lower:find("closed", 1, true) or lower:find("reset", 1, true) then return "CONNECTION_CLOSED: " .. text end
  return text
end

local function request(method, url, opts)
  opts = opts or {}
  url = trim(url)
  if url == "" then return nil, "empty URL" end
  if not url:match("^https?://") then url = "https://" .. url end
  if not M.available() then return nil, "HTTP_DISABLED: HTTP API disabled" end

  log.info("http", tostring(method or "GET") .. " " .. url)
  local ok, handle
  if method == "POST" and http.post then
    ok, handle = pcall(http.post, url, opts.body or "", opts.headers)
  else
    ok, handle = pcall(http.get, url, opts.headers)
  end
  if not ok then
    local err = classifyHttpFailure(handle)
    log.error("http", err)
    return nil, err
  end
  if not handle then
    local err = "REQUEST_FAILED: no response handle for " .. url
    log.warn("http", err)
    return nil, err
  end

  local body = handle.readAll() or ""
  local code = handle.getResponseCode and handle.getResponseCode() or 200
  local headers = handle.getResponseHeaders and handle.getResponseHeaders() or {}
  handle.close()
  return {
    url = url,
    code = code,
    headers = headers,
    body = body,
    size = #body,
  }
end

function M.get(url, opts)
  return request("GET", url, opts)
end

function M.post(url, body, opts)
  opts = opts or {}
  opts.body = body or ""
  return request("POST", url, opts)
end

function M.json(url, opts)
  local response, err = M.get(url, opts)
  if not response then return nil, err end
  if not textutils.unserializeJSON then return nil, "JSON unavailable" end
  local ok, parsed = pcall(textutils.unserializeJSON, response.body)
  if not ok then return nil, tostring(parsed) end
  response.json = parsed
  return response
end

return M
