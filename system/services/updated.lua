local config = require("system.libraries.config")

local M = {
  cfgPath = "/system/config/update.cfg",
  rollbackRoot = "/var/backups/update",
  status = {
    localVersion = "unknown",
    remoteVersion = "unknown",
    updateAvailable = false,
    message = "never checked",
  },
}

local function trim(value)
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function readFile(path)
  if not fs.exists(path) then return nil end
  local handle = fs.open(path, "r")
  if not handle then return nil end
  local data = handle.readAll()
  handle.close()
  return data
end

local function copyTree(from, to)
  if not fs.exists(from) then return true end
  if fs.exists(to) then fs.delete(to) end
  local dir = fs.getDir(to)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  fs.copy(from, to)
  return true
end

local function restoreTree(from, to)
  if not fs.exists(from) then return false, "missing backup " .. tostring(from) end
  if fs.exists(to) then fs.delete(to) end
  local dir = fs.getDir(to)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  fs.copy(from, to)
  return true
end

local function httpGet(url)
  if not http or not http.get then return nil, "HTTP API disabled" end
  local ok, handle = pcall(http.get, url)
  if not ok then return nil, tostring(handle) end
  if not handle then return nil, "request failed" end
  local data = handle.readAll()
  handle.close()
  return data
end

function M.loadConfig()
  return config.load(M.cfgPath, {
    repo = "commandant-x/MintCraftOS",
    branch = "main",
    autoCheck = true,
    autoApply = false,
  })
end

local ROLLBACK_PATHS = {
  "/VERSION",
  "/boot.lua",
  "/startup.lua",
  "/system",
  "/apps",
  "/packages",
}

function M.localVersion()
  return trim(readFile("/VERSION") or "0.0.0")
end

function M.remoteVersion()
  local cfg = M.loadConfig()
  local url = "https://raw.githubusercontent.com/" .. cfg.repo .. "/" .. cfg.branch .. "/VERSION"
  local data, err = httpGet(url)
  if not data then return nil, err end
  return trim(data)
end

function M.check()
  local cfg = M.loadConfig()
  local localVersion = M.localVersion()
  local remoteVersion, err = M.remoteVersion()

  if not remoteVersion then
    M.status = {
      localVersion = localVersion,
      remoteVersion = "unknown",
      updateAvailable = false,
      message = err or "check failed",
    }
  else
    M.status = {
      localVersion = localVersion,
      remoteVersion = remoteVersion,
      updateAvailable = remoteVersion ~= localVersion,
      message = remoteVersion ~= localVersion and "update available" or "up to date",
    }
  end

  cfg.lastStatus = M.status.message
  cfg.lastLocalVersion = M.status.localVersion
  cfg.lastRemoteVersion = M.status.remoteVersion
  cfg.lastCheckedUptime = os.clock()
  config.save(M.cfgPath, cfg)
  return M.status
end

function M.downloadInstaller()
  local cfg = M.loadConfig()
  local url = "https://raw.githubusercontent.com/" .. cfg.repo .. "/" .. cfg.branch .. "/install.lua"
  local data, err = httpGet(url)
  if not data then return nil, err end

  local path = "/var/tmp/mintcraft_update.lua"
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local handle = fs.open(path, "w")
  if not handle then return nil, "cannot write update installer" end
  handle.write(data)
  handle.close()
  return path
end

function M.rollbackInfo()
  local latestPath = M.rollbackRoot .. "/latest.cfg"
  if not fs.exists(latestPath) then return nil end
  local data = config.load(latestPath, nil)
  if not data or not data.id then return nil end
  data.path = M.rollbackRoot .. "/" .. data.id
  return data
end

function M.createRollback(reason)
  if fs.exists(M.rollbackRoot) then fs.delete(M.rollbackRoot) end
  fs.makeDir(M.rollbackRoot)

  local id = tostring(math.floor(os.epoch and os.epoch("utc") or (os.clock() * 1000)))
  local backupDir = M.rollbackRoot .. "/" .. id
  fs.makeDir(backupDir)
  local manifest = {
    id = id,
    reason = reason or "update",
    fromVersion = M.localVersion(),
    createdUptime = os.clock(),
    paths = {},
  }

  for _, path in ipairs(ROLLBACK_PATHS) do
    if fs.exists(path) then
      local target = backupDir .. path
      copyTree(path, target)
      table.insert(manifest.paths, path)
    end
  end

  config.save(backupDir .. "/manifest.cfg", manifest)
  config.save(M.rollbackRoot .. "/latest.cfg", manifest)
  return true, manifest
end

function M.rollback()
  local info = M.rollbackInfo()
  if not info then return false, "no rollback backup" end
  local backupDir = M.rollbackRoot .. "/" .. info.id
  local manifest = config.load(backupDir .. "/manifest.cfg", info)
  if not manifest or type(manifest.paths) ~= "table" then return false, "invalid rollback manifest" end

  for _, path in ipairs(manifest.paths) do
    local ok, err = restoreTree(backupDir .. path, path)
    if not ok then return false, err end
  end
  return true, "rollback restored " .. tostring(manifest.fromVersion or "previous") .. ", reboot required"
end

function M.apply()
  local backedUp, backup = M.createRollback("before update")
  if not backedUp then return false, tostring(backup) end
  local path, err = M.downloadInstaller()
  if not path then return false, err end
  local fn, loadErr = loadfile(path)
  if not fn then return false, loadErr end
  local ok, runErr = pcall(fn)
  if not ok then return false, tostring(runErr) end
  return true, "installer finished, reboot required"
end

function M.start(ctx)
  local cfg = M.loadConfig()
  if not cfg.autoCheck then return end

  local ok, status = pcall(M.check)
  if ok and status.updateAvailable and ctx.notifications then
    ctx.notifications:push("info", "Update", "Version " .. status.remoteVersion .. " available", 6)
  elseif not ok and ctx.notifications then
    ctx.notifications:push("warn", "Update", tostring(status), 5)
  end

  if ok and status.updateAvailable and cfg.autoApply then
    local applied, message = M.apply()
    if ctx.notifications then
      ctx.notifications:push(applied and "success" or "error", "Update", tostring(message), 6)
    end
  end
end

return M
