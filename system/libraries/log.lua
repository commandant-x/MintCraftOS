local M = {}

local LOG_PATH = "/var/logs/system.log"

local function ensure()
  if not fs.exists("/var") then fs.makeDir("/var") end
  if not fs.exists("/var/logs") then fs.makeDir("/var/logs") end
end

function M.write(level, source, message)
  ensure()
  local handle = fs.open(LOG_PATH, "a")
  if handle then
    handle.writeLine(textutils.serialize({
      time = os.date(),
      level = level,
      source = source,
      message = tostring(message),
    }))
    handle.close()
  end
end

function M.info(source, message) M.write("info", source, message) end
function M.warn(source, message) M.write("warn", source, message) end
function M.error(source, message) M.write("error", source, message) end
function M.debug(source, message) M.write("debug", source, message) end

function M.tail(limit)
  limit = limit or 20
  if not fs.exists(LOG_PATH) then return {} end
  local lines = {}
  local handle = fs.open(LOG_PATH, "r")
  while true do
    local line = handle.readLine()
    if not line then break end
    table.insert(lines, line)
    if #lines > limit then table.remove(lines, 1) end
  end
  handle.close()
  return lines
end

return M
