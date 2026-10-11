local M = {}

function M.current()
  local h = fs.open("/VERSION", "r")
  if not h then return "unknown" end
  local value = h.readAll()
  h.close()
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

function M.compare(a, b)
  local function parse(value)
    local x, y, z = tostring(value):match("^(%d+)%.(%d+)%.(%d+)$")
    if not x then return nil end
    return { tonumber(x), tonumber(y), tonumber(z) }
  end
  local left, right = parse(a), parse(b)
  if not left or not right then return nil, "Invalid release version" end
  for i = 1, 3 do
    if left[i] < right[i] then return -1 end
    if left[i] > right[i] then return 1 end
  end
  return 0
end

return M
