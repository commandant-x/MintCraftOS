local M = {}
local safeWrite = require("system.libraries.safe_write")

function M.load(path, fallback)
  local recovered, problem = safeWrite.recover(path)
  if not recovered then error(problem, 0) end
  if not fs.exists(path) then return fallback end
  local handle = fs.open(path, "r")
  if not handle then return fallback end
  local data = handle.readAll()
  handle.close()
  local ok, parsed = pcall(textutils.unserialize, data)
  if ok and parsed ~= nil then return parsed end
  return fallback
end

function M.save(path, value)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  return safeWrite.write(path, textutils.serialize(value))
end

function M.ensure(path, value)
  local recovered, problem = safeWrite.recover(path)
  if not recovered then return false, problem end
  if not fs.exists(path) then
    return M.save(path, value)
  end
  return true
end

return M
