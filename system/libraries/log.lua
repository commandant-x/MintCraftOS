local M = {}
local LOG_PATH = "/var/logs/system.log"
local MAX_BYTES, MAX_RECORDS = 65536, 512
local revision, cachedRevision, cached = 0, -1, {}

local function safeString(value)
  local ok, result = pcall(tostring, value)
  return ok and result or "<unprintable>"
end

local function quote(value)
  local value = safeString(value):sub(1, 8192)
  return '"' .. value:gsub('[%z\1-\31\\"]', function(c)
    return string.format("\\%03d", c:byte())
  end) .. '"'
end

local function encode(row)
  return "{time=" .. quote(row.time) .. ",level=" .. quote(row.level) ..
    ",source=" .. quote(row.source) .. ",message=" .. quote(row.message) .. "}"
end

local function withFile(path, mode, fn)
  local handle, reason = fs.open(path, mode)
  if not handle then error(reason or "log unavailable", 0) end
  local ok, result = pcall(fn, handle)
  local closed, err = pcall(handle.close)
  if not ok then error(result, 0) end
  if not closed then error(err, 0) end
  return result
end

-- Rotate only owned logs, never crash/recovery/probe files.
local function rotate(bytes)
  if fs.exists(LOG_PATH) and fs.getSize(LOG_PATH) + bytes > MAX_BYTES then
    if fs.exists(LOG_PATH .. ".2") then fs.delete(LOG_PATH .. ".2") end
    if fs.exists(LOG_PATH .. ".1") then fs.move(LOG_PATH .. ".1", LOG_PATH .. ".2") end
    fs.move(LOG_PATH, LOG_PATH .. ".1")
  end
  -- Pre-quota installations may already contain oversized owned archives.
  for _, suffix in ipairs({".1", ".2"}) do
    local path = LOG_PATH .. suffix
    if fs.exists(path) and fs.getSize(path) > MAX_BYTES then fs.delete(path) end
  end
end

function M.write(level, source, message)
  local ok, err = pcall(function()
    if not fs.exists("/var/logs") then fs.makeDir("/var/logs") end
    local line = encode({time=os.date(),level=level,source=source,message=message})
    if #line + 1 > MAX_BYTES then error("log record too large", 0) end
    rotate(#line + 1)
    withFile(LOG_PATH, "a", function(handle) handle.writeLine(line) end)
  end)
  -- Even failed appends can rotate files or leave a partial record.
  revision = revision + 1
  return ok, not ok and safeString(err) or nil
end

function M.info(source, message) return M.write("info", source, message) end
function M.warn(source, message) return M.write("warn", source, message) end
function M.error(source, message) return M.write("error", source, message) end
function M.debug(source, message) return M.write("debug", source, message) end
function M.revision() return revision end
function M.invalidate() revision = revision + 1 end

local function decode(line)
  local ok, row = pcall(function() return textutils.unserialize(line) end)
  if ok and type(row) == "table" then return row end
end

function M.parse(line)
  return decode(line) or {level="info",source="raw",message=line,time=""}
end

local function readTail()
  local rows = {}
  local function push(line)
    rows[#rows + 1] = line
    if #rows > MAX_RECORDS then table.remove(rows, 1) end
  end
  for _, path in ipairs({LOG_PATH .. ".2", LOG_PATH .. ".1", LOG_PATH}) do
    if fs.exists(path) then
      withFile(path, "r", function(handle)
        local pending
        while true do
          local line = handle.readLine()
          if not line then break end
          if pending then
            pending = pending .. "\n" .. line
            local row = decode(pending)
            if row then push(encode(row)) pending = nil
            elseif line:match("^%s*}%s*$") or #pending > MAX_BYTES then
              push(pending:sub(1, MAX_BYTES):gsub("\n", " ")) pending = nil
            end
          elseif line:match("^%s*{%s*$") then pending = line
          else push(line) end
        end
        if pending then push(pending:gsub("\n", " ")) end
      end)
    end
  end
  return rows
end

function M.tail(limit)
  limit = tonumber(limit) or 20
  if limit ~= limit then limit = 20 end
  limit = math.max(0, math.min(MAX_RECORDS, math.floor(limit)))
  if cachedRevision ~= revision then
    local ok, rows = pcall(readTail)
    if ok then cached = rows end
    cachedRevision = revision
  end
  local out = {}
  for i = math.max(1, #cached - limit + 1), #cached do out[#out + 1] = cached[i] end
  return out
end

return M
