local M = {}

function M.load(path, fallback)
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
  local handle = fs.open(path, "w")
  if not handle then return false, "Cannot write " .. path end
  handle.write(textutils.serialize(value))
  handle.close()
  return true
end

function M.ensure(path, value)
  if not fs.exists(path) then
    return M.save(path, value)
  end
  return true
end

return M
