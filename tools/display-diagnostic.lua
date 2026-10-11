-- Read-only diagnosis: no redirect, scale change, actuator call or file write.
local function readFile(path)
  local h = fs.open(path, 'r')
  if not h then return nil end
  local text = h.readAll()
  h.close()
  return text
end
print('MintCraft display diagnostic')
print('Computer ID: ' .. tostring(os.getComputerID()))
local version = readFile('/VERSION')
print('Version: ' .. tostring(version and version:gsub('%s+$', '') or 'missing'))
local service = readFile('/system/services/deviced.lua')
print('Latest display fix: ' .. tostring(service and service:find('function M.getTarget()', 1, true) ~= nil or false))
if type(peripheral) ~= 'table' then print('DISPLAY-001: peripheral API absent') return end
local names, seen = {}, {}
local function add(name)
  if not seen[name] then seen[name] = true names[#names + 1] = name end
end
for _, side in ipairs({'top', 'bottom', 'left', 'right', 'front', 'back'}) do add(side) end
local ok, list = pcall(peripheral.getNames)
if ok and type(list) == 'table' then
  print('getNames: ' .. (#list > 0 and table.concat(list, ', ') or '(empty)'))
  for _, name in ipairs(list) do add(name) end
else
  print('DISPLAY-002: getNames failed: ' .. tostring(list))
end
local monitors = 0
for _, name in ipairs(names) do
  local types = table.pack(pcall(peripheral.getType, name))
  if not types[1] then
    print(name .. ': TYPE ERROR ' .. tostring(types[2]))
  elseif types[2] ~= nil then
    local labels, monitor = {}, false
    for i = 2, types.n do
      labels[#labels + 1] = tostring(types[i])
      if types[i] == 'monitor' then monitor = true end
    end
    print(name .. ': ' .. table.concat(labels, ', '))
    if monitor then
      monitors = monitors + 1
      local success, detail = pcall(function()
        local device = assert(peripheral.wrap(name), 'wrap returned nil')
        local w, h = device.getSize()
        local scale = device.getTextScale()
        return tostring(w) .. 'x' .. tostring(h) .. ' scale=' .. tostring(scale)
      end)
      print(success and ('READ OK: ' .. detail) or ('DISPLAY-004: monitor read failed: ' .. tostring(detail)))
    end
  else
    print(name .. ': no peripheral')
  end
end
if monitors == 0 then
  print('DISPLAY-003: no CC monitor exposed')
  print('Check block adjacency or wired modem network.')
else
  print('Monitors exposed: ' .. tostring(monitors))
end
