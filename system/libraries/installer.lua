local M = {}
local root = "/var/tmp/mintcraft-install"

local function write(path, content)
  local dir = fs.getDir(path)
  if not fs.exists(dir) then fs.makeDir(dir) end
  local h = assert(fs.open(path, "w"), "Cannot write " .. path)
  local ok, err = pcall(h.write, content)
  h.close()
  if not ok then error(err) end
end

local function validPath(path)
  if type(path) ~= "string" or path:sub(1, 1) == "/" or path:find("\\", 1, true) then return false end
  for part in path:gmatch("[^/]+") do if part == "." or part == ".." then return false end end
  return path == "VERSION" or path == "boot.lua" or path == "startup.lua"
    or path:match("^system/") or path:match("^apps/")
    or path:match("^home/") or path:match("^packages/")
end

local function preserved(path)
  return path:match("^system/config/") or path:match("^home/") or path:match("^packages/")
end

function M.install(files)
  -- A retained transaction may contain the only backup after an interrupted write.
  if fs.exists(root) then error("Unfinished installation: recover " .. root .. " before retrying") end
  local paths = {}
  for path, content in pairs(files) do
    assert(validPath(path), "Invalid install path: " .. tostring(path))
    assert(type(content) == "string", "Invalid file content")
    table.insert(paths, path)
  end
  table.sort(paths)
  local changed, touched = {}, {}
  local ok, err = pcall(function()
    fs.makeDir(root)
    for _, path in ipairs(paths) do
      if not (preserved(path) and fs.exists("/" .. path)) then
        write(root .. "/stage/" .. path, files[path])
        if path:match("%.lua$") then
          local fn, problem = loadfile(root .. "/stage/" .. path)
          assert(fn, tostring(problem))
        end
        table.insert(changed, path)
      end
    end
    local entries = {}
    for _, path in ipairs(changed) do
      local exists = fs.exists("/" .. path)
      assert(not exists or not fs.isDir("/" .. path), "Destination is a directory: " .. path)
      if exists then
        local backup = root .. "/backup/" .. path
        fs.makeDir(fs.getDir(backup))
        fs.copy("/" .. path, backup)
      end
      table.insert(entries, { path = path, existed = exists })
    end
    write(root .. "/journal.cfg", textutils.serialize(entries))
    for _, entry in ipairs(entries) do
      table.insert(touched, entry)
      write("/" .. entry.path, files[entry.path])
    end
  end)
  if not ok then
    local rollbackErrors = {}
    for i = #touched, 1, -1 do
      local entry = touched[i]
      local restored, problem = pcall(function()
        local path = "/" .. entry.path
        if fs.exists(path) then fs.delete(path) end
        if entry.existed then fs.copy(root .. "/backup/" .. entry.path, path) end
      end)
      if not restored then table.insert(rollbackErrors, tostring(problem)) end
    end
    if #rollbackErrors == 0 then
      if fs.exists(root) then fs.delete(root) end
    else
      error(tostring(err) .. "; recovery required: " .. table.concat(rollbackErrors, "; "))
    end
    error(err)
  end
  fs.delete(root)
  return true
end

function M.recover()
  local h = fs.open(root .. "/journal.cfg", "r")
  if not h then return false, "No recovery journal; inspect " .. root end
  local entries = textutils.unserialize(h.readAll())
  h.close()
  if type(entries) ~= "table" then return false, "Invalid recovery journal" end
  for _, entry in ipairs(entries) do
    if type(entry) ~= "table" or not validPath(entry.path) or type(entry.existed) ~= "boolean" then
      return false, "Invalid recovery entry"
    end
    if entry.existed and not fs.exists(root .. "/backup/" .. entry.path) then
      return false, "Missing backup: " .. entry.path
    end
  end
  local ok, err = pcall(function()
    for _, entry in ipairs(entries) do
      local target = "/" .. entry.path
      if fs.exists(target) then fs.delete(target) end
      if entry.existed then fs.copy(root .. "/backup/" .. entry.path, target) end
    end
    fs.delete(root)
  end)
  return ok, ok and "Previous files restored; reboot required" or tostring(err)
end

return M
