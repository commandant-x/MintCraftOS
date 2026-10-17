local M = {}

local function recognizedStage(path)
  local stage = path .. ".mintcraft-save"
  if not fs.isDir(stage) then return false end
  if fs.exists(stage .. "/marker") then
    local h = fs.open(stage .. "/marker", "r")
    if not h then return false end
    local ok, data = pcall(h.readAll) pcall(h.close)
    if not ok or data ~= "MintCraft safe save 1" then return false end
    for _, name in ipairs(fs.list and fs.list(stage) or {"marker"}) do
      if (name ~= "marker" and name ~= "previous" and name ~= "next") or fs.isDir(stage .. "/" .. name) then return false end
    end
    return true
  end
  -- Older saves had no marker. Only accept their exact recovery layout.
  if not fs.exists(stage .. "/previous") or fs.isDir(stage .. "/previous") then return false end
  if fs.exists(stage .. "/next") and fs.isDir(stage .. "/next") then return false end
  if fs.list then
    for _, name in ipairs(fs.list(stage)) do if name ~= "previous" and name ~= "next" then return false end end
  end
  return not fs.exists(path) or fs.exists(stage .. "/next")
end

function M.recover(path)
  local stage = path .. ".mintcraft-save"
  if not fs.exists(stage) then return true end
  if not recognizedStage(path) then return false, "Unrecognized save directory retained: " .. stage end
  local old, nextFile = stage .. "/previous", stage .. "/next"
  local ok, err = pcall(function()
    assert(fs.isDir(stage), "Invalid save stage: " .. stage)
    assert(not fs.exists(path) or not fs.isDir(path), "Save target is a directory")
    if fs.exists(old) then
      assert(not fs.isDir(old), "Invalid previous save")
      if not fs.exists(path) then
        fs.move(old, path)
      else
        -- A target plus no next file means the final rename completed.
        assert(not fs.exists(nextFile), "Ambiguous save state; inspect " .. stage)
      end
    end
    fs.delete(stage)
  end)
  return ok, ok and "Recovered" or (tostring(err) .. "; recovery retained: " .. stage)
end

function M.recoverAll(root)
  root = root or "/"
  root = "/" .. fs.combine(root, ""):gsub("^/+", "")
  if not fs.exists(root) then return true end
  if fs.isReadOnly and fs.isReadOnly(root) then return true end
  if fs.getDrive and fs.getDrive(root) ~= fs.getDrive("/") then return true end
  for _, name in ipairs(fs.list(root)) do
    local path = "/" .. fs.combine(root, name):gsub("^/+", "")
    local writable = not fs.isReadOnly or not fs.isReadOnly(path)
    local internal = not fs.getDrive or fs.getDrive(path) == fs.getDrive("/")
    if (root == "/" and name ~= "system" and name ~= "home" and name ~= "packages" and name ~= "var")
      or (root == "/system" and name ~= "config")
      or (root == "/var" and name ~= "tmp" and name ~= "cache" and name ~= "logs") then
      -- Root-level arbitrary files are recovered lazily by their owning API.
    elseif writable and internal and name:sub(-15) == ".mintcraft-save" then
      local target = path:sub(1, -16)
      if recognizedStage(target) then
        local ok, err = M.recover(target)
        if not ok then return false, err end
      end
    elseif writable and internal and fs.isDir(path) and path ~= "/var/backups"
      and path ~= "/var/tmp/mintcraft-install" and path ~= "/var/tmp/mintcraft-package"
      and path ~= "/var/tmp/mintcraft-restore" then
      local ok, err = M.recoverAll(path)
      if not ok then return false, err end
    end
  end
  return true
end

function M.recoverRestore()
  local stage = "/var/tmp/mintcraft-restore"
  if not fs.exists(stage) then return true end
  local ok, err = pcall(function()
    local h = assert(fs.open(stage .. "/target.cfg", "r"), "Restore target missing; inspect " .. stage)
    local target = textutils.unserialize(h.readAll()) h.close()
    assert(target == "/VERSION" or target == "/boot.lua" or target == "/startup.lua"
      or target == "/system" or target == "/apps" or
      (type(target) == "string" and (target:match("^/system/") or target:match("^/apps/"))
      and not target:find("..", 1, true) and not target:find("//", 1, true)
      and not target:find("[%c:\\]") and target:sub(-1) ~= "/"), "Invalid restore target")
    for part in target:gmatch("[^/]+") do assert(part ~= "." and part ~= "..", "Non-canonical restore target") end
    assert(target ~= "/system/config" and not target:match("^/system/config/"), "Config restore target is protected")
    local old, nextPath = stage .. "/previous", stage .. "/next"
    if fs.exists(old) and not fs.exists(target) then fs.move(old, target)
    elseif fs.exists(old) and fs.exists(nextPath) then error("Ambiguous interrupted restore") end
    if fs.exists(nextPath) then
      local pending = assert(fs.open("/var/tmp/mintcraft-rollback.cfg", "r"), "Unverified restore copy retained")
      local info = textutils.unserialize(pending.readAll()) pending.close()
      assert(type(info) == "table" and type(info.id) == "string" and info.id:match("^%d+%-?%d*$")
        and fs.exists("/var/backups/update/" .. info.id .. target), "Sole restore copy retained")
    end
    fs.delete(stage)
  end)
  return ok, ok and "Recovered" or (tostring(err) .. "; restore data retained")
end

local function read(path)
  local h = assert(fs.open(path, "r"), "Cannot read " .. path)
  local ok, value = pcall(h.readAll)
  pcall(h.close)
  assert(ok, tostring(value))
  return value
end

local function write(path, value)
  local dir = fs.getDir(path)
  if dir ~= "" then fs.makeDir(dir) end
  local h = assert(fs.open(path, "w"), "Cannot write " .. path)
  local ok, err = pcall(h.write, value)
  local closed, closeErr = pcall(h.close)
  assert(ok and closed, tostring(ok and closeErr or err))
end

-- The entire journal and every backup are validated before the first live mutation.
function M.recoverTransaction(root, allowed)
  if not fs.exists(root) then return true end
  local ok, err = pcall(function()
    local journal = root .. "/journal.cfg"
    if not fs.exists(journal) then
      assert(fs.exists(root .. "/protocol") and read(root .. "/protocol") == "MintCraft transaction 1", "Unrecognized transaction retained")
      local function checkBackups(path, relative)
        if not fs.exists(path) then return end
        for _, name in ipairs(fs.list(path)) do
          local backup, key = path .. "/" .. name, relative == "" and name or relative .. "/" .. name
          if fs.isDir(backup) then checkBackups(backup, key)
          else
            assert(allowed(key) and fs.exists("/" .. key) and not fs.isDir("/" .. key)
              and read(backup) == read("/" .. key), "Sole or changed backup retained: " .. key)
          end
        end
      end
      checkBackups(root .. "/backup", "")
      fs.delete(root) return
    end
    local entries = textutils.unserialize(read(journal))
    assert(type(entries) == "table", "Invalid transaction journal")
    local seen, count = {}, 0
    for index, entry in pairs(entries) do
      assert(type(index) == "number" and index % 1 == 0 and index >= 1 and index <= #entries,
        "Invalid transaction sequence")
      assert(type(entry) == "table" and allowed(entry.path) and not seen[entry.path]
        and type(entry.existed) == "boolean", "Invalid transaction entry")
      seen[entry.path], count = true, count + 1
      local target, backup = "/" .. entry.path, root .. "/backup/" .. entry.path
      assert(not fs.exists(target) or not fs.isDir(target), "Unexpected directory: " .. target)
      if entry.existed then
        assert(fs.exists(backup) and not fs.isDir(backup), "Missing backup: " .. backup)
      end
    end
    assert(count == #entries, "Incomplete transaction journal")
    local committed = fs.exists(root .. "/committed") and not fs.isDir(root .. "/committed") and read(root .. "/committed") == "committed"
    if not committed then
      for i = #entries, 1, -1 do
        local entry = entries[i]
        local target = "/" .. entry.path
        if entry.existed then
          write(target, read(root .. "/backup/" .. entry.path))
        elseif fs.exists(target) then fs.delete(target) end
      end
    end
    fs.delete(root)
  end)
  return ok, ok and "Recovered" or (tostring(err) .. "; recovery retained: " .. root)
end

function M.transaction(root, changes, allowed)
  if fs.exists(root) then return false, "Pending transaction: " .. root end
  local entries, paths = {}, {}
  local ok, err = pcall(function()
    for path, value in pairs(changes) do
      assert(allowed(path) and (type(value) == "string" or value == false), "Invalid transaction path")
      assert(not fs.exists("/" .. path) or not fs.isDir("/" .. path), "Destination is a directory")
      paths[#paths + 1] = path
    end
    table.sort(paths)
    fs.makeDir(root)
    write(root .. "/protocol", "MintCraft transaction 1")
    for _, path in ipairs(paths) do
      local target = "/" .. path
      assert(M.recover(target))
      local existed = fs.exists(target)
      if existed then
        fs.makeDir(fs.getDir(root .. "/backup/" .. path))
        fs.copy(target, root .. "/backup/" .. path)
      end
      if changes[path] ~= false then write(root .. "/stage/" .. path, changes[path]) end
      entries[#entries + 1] = {path = path, existed = existed}
    end
    write(root .. "/journal.cfg", textutils.serialize(entries))
    for _, entry in ipairs(entries) do
      local target, value = "/" .. entry.path, changes[entry.path]
      if value == false then
        if fs.exists(target) then fs.delete(target) end
      else
        write(target, read(root .. "/stage/" .. entry.path))
      end
    end
    write(root .. "/committed", "committed")
  end)
  if not ok then
    local recovered, problem = M.recoverTransaction(root, allowed)
    return false, tostring(err) .. (recovered and "" or ("; " .. tostring(problem)))
  end
  local cleaned = pcall(fs.delete, root)
  return true, cleaned and "Committed" or ("Committed; cleanup pending: " .. root)
end

function M.write(path, content)
  local stage = path .. ".mintcraft-save"
  local old, nextFile = stage .. "/previous", stage .. "/next"
  local handle, owned
  local ok, err = pcall(function()
    if fs.exists(stage) then error("Unfinished save: " .. stage, 0) end
    if fs.exists(path) and fs.isDir(path) then error("Target is a directory", 0) end
    fs.makeDir(stage)
    owned = true
    handle = assert(fs.open(stage .. "/marker", "w"), "Cannot open save marker")
    handle.write("MintCraft safe save 1")
    handle.close()
    handle = nil
    handle = assert(fs.open(nextFile, "w"), "Cannot open staging file")
    handle.write(content)
    handle.close()
    handle = nil
    if fs.exists(path) then fs.move(path, old) end
    fs.move(nextFile, path)
  end)
  if handle then pcall(handle.close) end
  if not ok then
    if owned then
      local restored, restoreErr = pcall(function()
        if fs.exists(old) then
          if fs.exists(path) then error("Target changed during save", 0) end
          fs.move(old, path)
        end
      end)
      if not restored then return false, tostring(err) .. "; recovery data: " .. stage .. " (" .. tostring(restoreErr) .. ")" end
      pcall(fs.delete, stage)
    end
    return false, tostring(err)
  end
  local cleaned = pcall(fs.delete, stage)
  return true, cleaned and "Saved" or ("Saved; cleanup needed: " .. stage)
end

return M
