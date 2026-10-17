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

function M.readResponse(handle, limit, url)
  local ok,result=pcall(function()
    assert(type(limit)=="number" and limit>=0 and limit<=8388608 and limit%1==0,"Invalid byte limit")
    assert(type(handle.read)=="function","Response does not support bounded reads")
    local chunks,size={},0
    while true do
      local chunk=handle.read(math.min(8192,limit-size+1))
      if chunk==nil or chunk=="" then break end
      if type(chunk)=="number" then chunk=string.char(chunk) end
      assert(type(chunk)=="string","Invalid response body")
      size=size+#chunk
      assert(size<=limit,"Response exceeds "..limit.." byte limit")
      chunks[#chunks+1]=chunk
    end
    local body=table.concat(chunks)
    return {url=url,code=handle.getResponseCode and handle.getResponseCode() or 200,
      headers=handle.getResponseHeaders and handle.getResponseHeaders() or {},body=body,size=#body}
  end)
  if handle and handle.close then pcall(handle.close) end
  if not ok then return nil,"RESPONSE_READ_FAILED: "..tostring(result) end
  return result
end

local function request(method, url, opts)
  opts = opts or {}
  url = trim(url)
  if url == "" then return nil, "empty URL" end
  if not url:match("^https?://") then url = "https://" .. url end
  if not M.available() then return nil, "HTTP_DISABLED: HTTP API disabled" end

  log.info("http", tostring(method or "GET") .. " " .. url)
  local options = { url=url, method=method, headers=opts.headers, binary=opts.binary,
    redirect=opts.redirect, timeout=opts.timeout }
  if method == "POST" then options.body=opts.body or "" end
  local limit=opts.maxBytes or 2097152
  if type(limit)~="number" or limit~=limit or limit<0 or limit>8388608 or limit%1~=0 then
    return nil,"INVALID_LIMIT: maxBytes must be an integer from 0 to 8388608"
  end
  local ok, handle,problem,failureHandle = pcall(method=="POST" and http.post or http.get, options)
  if not ok then
    local err = classifyHttpFailure(handle)
    log.error("http", err)
    return nil, err
  end
  if not handle then
    if failureHandle and opts.allowStatus and failureHandle.getResponseCode then
      local codeOK,code=pcall(failureHandle.getResponseCode)
      if codeOK and opts.allowStatus[code] then handle=failureHandle end
    end
  end
  if not handle then
    if failureHandle and failureHandle.close then pcall(failureHandle.close) end
    local err = "REQUEST_FAILED: "..classifyHttpFailure(problem or ("no response handle for "..url))
    log.warn("http", err)
    return nil, err
  end

  return M.readResponse(handle,limit,url)
end

function M.get(url, opts)
  return request("GET", url, opts)
end

function M.post(url, body, opts)
  local options={}
  for key,value in pairs(opts or {}) do options[key]=value end
  options.body = body or ""
  return request("POST", url, options)
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
