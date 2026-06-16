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

local function request(method, url, opts)
  opts = opts or {}
  url = trim(url)
  if url == "" then return nil, "empty URL" end
  if not url:match("^https?://") then url = "https://" .. url end
  if not M.available() then return nil, "HTTP API disabled" end

  log.info("http", tostring(method or "GET") .. " " .. url)
  local ok, handle
  if method == "POST" and http.post then
    ok, handle = pcall(http.post, url, opts.body or "", opts.headers)
  else
    ok, handle = pcall(http.get, url, opts.headers)
  end
  if not ok then
    log.error("http", tostring(handle))
    return nil, tostring(handle)
  end
  if not handle then
    log.warn("http", "request failed: " .. url)
    return nil, "request failed"
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
