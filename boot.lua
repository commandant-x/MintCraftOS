if not table.unpack and unpack then table.unpack = unpack end

if not require then
  local loaded = {}

  function require(name)
    if loaded[name] then return loaded[name] end

    local path = "/" .. name:gsub("%.", "/") .. ".lua"
    if not fs.exists(path) then
      error("module not found: " .. name .. " (" .. path .. ")", 2)
    end

    local chunk, err = loadfile(path)
    if not chunk then error(err, 2) end

    loaded[name] = true
    local result = chunk()
    if result ~= nil then loaded[name] = result end
    return loaded[name]
  end
end

local ok, err = pcall(function()
  local bootloader = require("system.boot.bootloader")
  bootloader.start()
end)

if not ok then
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.red)
  term.clear()
  term.setCursorPos(1, 1)
  print("MintCraft OS boot error")
  print(tostring(err))

  if fs.exists("/system/boot/recovery.lua") then
    local recovery, loadErr = loadfile("/system/boot/recovery.lua")
    if recovery then
      recovery(tostring(err))
    else
      print(tostring(loadErr))
    end
  end
end
