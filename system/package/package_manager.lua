local config = require("system.libraries.config")
local manifest = require("system.package.manifest")
local log = require("system.libraries.log")

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
  return config.load(M.installedPath, {})
end

local function writeInstalled(data)
  ensure()
  return config.save(M.installedPath, data)
end

local function readSources()
  ensure()
  return config.load(M.sourcesPath, {})
end

local function writeFile(path, content)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local handle = fs.open(path, "w")
  if not handle then return false, "cannot write " .. path end
  handle.write(content)
  handle.close()
  return true
end

local function removeFile(path)
  if fs.exists(path) then fs.delete(path) end
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
  for _, pkg in pairs(readInstalled()) do
    if pkg.app then
      M.ctx.apps.register(pkg.app.id or pkg.id, pkg.app.name or pkg.name, pkg.app.module, {
        icon = pkg.app.icon or "PK",
        iconPath = pkg.app.iconPath,
        category = pkg.app.category or "Installed",
        version = pkg.version,
        permissions = pkg.app.permissions or pkg.permissions or {},
      })
    end
  end
end

function M.install(id)
  local pkg = M.find(id)
  if not pkg then return false, "package not found" end
  local ok, err = manifest.validate(pkg)
  if not ok then return false, err end

  for path, content in pairs(pkg.files) do
    local written, writeErr = writeFile("/" .. path, content)
    if not written then return false, writeErr end
  end

  local installed = readInstalled()
  installed[pkg.id] = {
    id = pkg.id,
    name = pkg.name,
    version = pkg.version,
    description = pkg.description,
    app = pkg.app,
    permissions = pkg.permissions,
    files = pkg.files,
    installedAt = os.clock(),
  }
  writeInstalled(installed)
  M.registerInstalledApps()
  log.info("package", "installed " .. pkg.id .. " " .. pkg.version)
  return true, "installed"
end

function M.remove(id)
  local installed = readInstalled()
  local pkg = installed[id]
  if not pkg then return false, "package not installed" end
  for path in pairs(pkg.files or {}) do removeFile("/" .. path) end
  installed[id] = nil
  writeInstalled(installed)
  log.warn("package", "removed " .. id)
  return true, "removed, reboot recommended"
end

return M
