local candidates = {
  "/boot.lua",
  "boot.lua",
}

if type(arg) == "table" and type(arg[0]) == "string" then
  table.insert(candidates, fs.combine(fs.getDir(arg[0]), "boot.lua"))
end

local lastErr
for _, path in ipairs(candidates) do
  if fs.exists(path) then
    local boot, err = loadfile(path)
    if boot then return boot() end
    lastErr = err
  end
end

error(lastErr or "MintCraft OS boot.lua not found", 0)
