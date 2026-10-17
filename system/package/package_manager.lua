local config = require("system.libraries.config")
local manifest = require("system.package.manifest")
local log = require("system.libraries.log")
local safeWrite = require("system.libraries.safe_write")
local transactionRoot = "/var/tmp/mintcraft-package"
local busy = false

local function allowed(path)
  return path == "packages/installed.db" or manifest.ownedPath(path)
end

local M = {
  installedPath = "/packages/installed.db",
  sourcesPath = "/packages/sources.db",
  ctx = nil,
}

local function ensure()
  if not fs.exists("/packages") then fs.makeDir("/packages") end
end

local function readInstalled()
  ensure()
  local recovered, problem = safeWrite.recoverTransaction(transactionRoot, allowed)
  assert(recovered, problem)
  local data = config.load(M.installedPath, nil)
  if data == nil and not fs.exists(M.installedPath) then data = {} end
  M.quarantined = {}
  if type(data) ~= "table" then
    M.quarantined[1] = {id="database", reason="Invalid installed package database; retained for inspection"}
    return {}
  end
  local valid = {}
  local owners, migrated = {}, false
  for id, pkg in pairs(data) do
    local ok, problem = pcall(function()
      assert(manifest.validId(id) and type(pkg) == "table" and pkg.id == id and type(pkg.files) == "table",
        "Invalid installed package record")
      for path in pairs(pkg.files) do
        assert(manifest.ownedPath(path, id) and not owners[path], "Invalid package ownership")
      end
      if pkg.app then
        assert(type(pkg.app) == "table" and (pkg.app.id == nil or pkg.app.id == id)
          and type(pkg.app.module) == "string" and manifest.ownedPath(pkg.app.module:gsub("%.", "/") .. ".lua", id),
          "Invalid installed application identity")
      end
    end)
    if ok then
      valid[id] = pkg
      for path in pairs(pkg.files) do
        owners[path] = id
        if pkg.files[path] ~= true then pkg.files[path], migrated = true, true end
      end
    else
      M.quarantined[#M.quarantined+1] = {id=tostring(id), reason=tostring(problem)}
    end
  end
  if migrated then
    local saved, err = config.save(M.installedPath, data)
    assert(saved, err)
  end
  return valid
end

local function readSources()
  ensure()
  return config.load(M.sourcesPath, {})
end

function M.setContext(ctx)
  M.ctx = ctx
end

function M.available()
  local rows = {}
  for _, pkg in ipairs(readSources().packages or {}) do
    table.insert(rows, pkg)
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

function M.installed()
  local rows = {}
  for _, pkg in pairs(readInstalled()) do table.insert(rows, pkg) end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

function M.find(id)
  for _, pkg in ipairs(M.available()) do
    if pkg.id == id then return pkg end
  end
  return nil
end

function M.isInstalled(id)
  return readInstalled()[id] ~= nil
end

function M.registerInstalledApps()
  if not M.ctx or not M.ctx.apps then return end
  local ok, installed = pcall(readInstalled)
  if not ok then return false, tostring(installed) end
  for _, pkg in pairs(installed) do
    if pkg.app then
      M.ctx.apps.register(pkg.app.id or pkg.id, pkg.app.name or pkg.name, pkg.app.module, {
        builtin = false,
        icon = pkg.app.icon or "PK",
        iconPath = pkg.app.iconPath,
        category = pkg.app.category or "Installed",
        version = pkg.version,
        permissions = pkg.app.permissions or pkg.permissions or {},
      })
    end
  end
end

local function install(id)
  local pkg = M.find(id)
  if not pkg then return false, "package not found" end
  local ok, err = manifest.validate(pkg)
  if not ok then return false, err end

  local installed = readInstalled()
  if #M.quarantined > 0 then return false, "Quarantined package records require inspection; database retained" end
  local registered = M.ctx and M.ctx.apps and M.ctx.apps.get and M.ctx.apps.get(id)
  if registered and registered.builtin then return false, "Built-in application identity is protected" end
  local previous = installed[id]
  local changes, paths = {}, {}
  for path, content in pairs(pkg.files) do
    if fs.exists("/" .. path) and not (previous and previous.files[path]) then
      return false, "Refusing to overwrite unowned file: " .. path
    end
    changes[path], paths[path] = content, true
  end
  for path in pairs(previous and previous.files or {}) do
    if not paths[path] then changes[path] = false end
  end
  installed[pkg.id] = {
    id = pkg.id,
    name = pkg.name,
    version = pkg.version,
    description = pkg.description,
    app = pkg.app,
    permissions = pkg.permissions,
    files = paths,
    installedAt = os.clock(),
  }
  -- Normalize legacy records too; installed.db contains ownership, never payloads.
  for _, record in pairs(installed) do
    for path in pairs(record.files) do record.files[path] = true end
  end
  changes["packages/installed.db"] = textutils.serialize(installed)
  local saved, problem = safeWrite.transaction(transactionRoot, changes, allowed)
  if not saved then return false, problem end
  M.registerInstalledApps()
  log.info("package", "installed " .. pkg.id .. " " .. pkg.version)
  return true, "installed"
end

local function remove(id)
  local installed = readInstalled()
  if #M.quarantined > 0 then return false, "Quarantined package records require inspection; database retained" end
  local pkg = installed[id]
  if not pkg then return false, "package not installed" end
  local changes = {}
  for path in pairs(pkg.files or {}) do
    if not manifest.ownedPath(path, id) then return false, "Invalid package ownership" end
    changes[path] = false
  end
  installed[id] = nil
  for _, record in pairs(installed) do
    for path in pairs(record.files) do record.files[path] = true end
  end
  changes["packages/installed.db"] = textutils.serialize(installed)
  local saved, problem = safeWrite.transaction(transactionRoot, changes, allowed)
  if not saved then return false, problem end
  log.warn("package", "removed " .. id)
  return true, "removed, reboot recommended"
end

local function exclusive(fn, id)
  if busy or _G.mintcraftStorageOperation then return false, "Package/storage operation already in progress" end
  if fs.exists("/var/tmp/mintcraft-install") or fs.exists("/var/tmp/mintcraft-rollback.cfg")
    or fs.exists("/var/tmp/mintcraft-restore") then return false, "System recovery pending" end
  busy = true
  _G.mintcraftStorageOperation = "Package"
  local ok, result, detail = pcall(fn, id)
  busy = false
  _G.mintcraftStorageOperation = nil
  if not ok then return false, tostring(result) end
  return result, detail
end

function M.install(id) return exclusive(install, id) end
function M.remove(id) return exclusive(remove, id) end

return M
