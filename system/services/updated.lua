local config = require("system.libraries.config")
local version = require("system.libraries.version")
local source = require("system.libraries.update_source")

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
  local stage = "/var/tmp/mintcraft-restore"
  if fs.exists(stage) then return false, "Interrupted restore at " .. stage .. "; inspection required" end
  fs.makeDir(stage)
  local nextPath, oldPath = stage .. "/next", stage .. "/previous"
  local copied, err = pcall(fs.copy, from, nextPath)
  if not copied then
    pcall(fs.delete, stage)
    return false, "Restore staging failed: " .. tostring(err) .. "; backup retained"
  end
  local hadPrevious = fs.exists(to)
  local moved, moveErr = pcall(function()
    if hadPrevious then fs.move(to, oldPath) end
    fs.move(nextPath, to)
  end)
  if not moved then
    if fs.exists(oldPath) and not fs.exists(to) then
      local recovered = pcall(fs.move, oldPath, to)
      if not recovered then return false, "Restore interrupted; previous data at " .. oldPath end
    end
    pcall(fs.delete, stage)
    return false, "Restore replacement failed: " .. tostring(moveErr)
  end
  fs.delete(stage)
  return true
end

local function httpGet(url)
  if not http or not http.get then return nil, "HTTP API disabled" end
  local ok, handle, problem = pcall(http.get, url, { ["User-Agent"] = "MintCraftOS" })
  if not ok then return nil, tostring(handle) end
  if not handle then return nil, tostring(problem or "request failed") end
  local readOk, data = pcall(handle.readAll)
  pcall(handle.close)
  if not readOk then return nil, tostring(data) end
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
    local comparison, problem = version.compare(remoteVersion, localVersion)
    M.status = {
      localVersion = localVersion,
      remoteVersion = remoteVersion,
      updateAvailable = comparison == 1,
      message = problem or (comparison == 1 and "update available" or (comparison == -1 and "local version is newer" or "up to date")),
    }
  end

  cfg.lastStatus = M.status.message
  cfg.lastLocalVersion = M.status.localVersion
  cfg.lastRemoteVersion = M.status.remoteVersion
  cfg.lastCheckedUptime = os.clock()
  config.save(M.cfgPath, cfg)
  return M.status
end

function M.downloadInstaller(pinned)
  if not pinned then
    local err
    pinned, err = source.resolve(M.loadConfig(), httpGet)
    if not pinned then return nil, err end
  end
  local url = source.url(pinned, "install.lua")
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
  if not fs.exists(latestPath) then latestPath = M.rollbackRoot .. "/previous.cfg" end
  if not fs.exists(latestPath) then return nil end
  local data = config.load(latestPath, nil)
  if type(data) ~= "table" or type(data.id) ~= "string" or not data.id:match("^%d+%-?%d*$") then return nil end
  data.path = M.rollbackRoot .. "/" .. data.id
  return data
end

local function createRollback(reason)
  fs.makeDir(M.rollbackRoot)

  local base = tostring(math.floor(os.epoch and os.epoch("utc") or (os.clock() * 1000)))
  local id, suffix = base, 0
  while fs.exists(M.rollbackRoot .. "/" .. id) do
    suffix = suffix + 1
    id = base .. "-" .. suffix
  end
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

  assert(config.save(backupDir .. "/manifest.cfg", manifest))
  local latest = M.rollbackRoot .. "/latest.cfg"
  local previous = M.rollbackRoot .. "/previous.cfg"
  local pending = backupDir .. "/latest.cfg"
  assert(config.save(pending, manifest))
  if fs.exists(latest) then
    if fs.exists(previous) then fs.delete(previous) end
    fs.move(latest, previous)
  end
  fs.move(pending, latest)
  return true, manifest
end

function M.createRollback(reason)
  local ok, result, detail = pcall(createRollback, reason)
  if not ok then return false, tostring(result) end
  return result, detail
end

local function rollback()
  local info = M.rollbackInfo()
  if not info then return false, "no rollback backup" end
  local backupDir = M.rollbackRoot .. "/" .. info.id
  local manifest = config.load(backupDir .. "/manifest.cfg", nil)
  if type(manifest) ~= "table" or type(manifest.paths) ~= "table" or manifest.id ~= info.id then
    return false, "invalid rollback manifest"
  end
  local allowed, seen, count = {}, {}, 0
  for _, path in ipairs(ROLLBACK_PATHS) do allowed[path] = true end
  for index, path in pairs(manifest.paths) do
    if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #manifest.paths
      or type(path) ~= "string" or not allowed[path] or seen[path] then
      return false, "invalid rollback path list"
    end
    seen[path], count = true, count + 1
    if not fs.exists(backupDir .. path) then return false, "missing backup " .. path end
  end
  if count == 0 or count ~= #manifest.paths then return false, "empty or incomplete rollback manifest" end

  for _, path in ipairs(manifest.paths) do
    local ok, err = restoreTree(backupDir .. path, path)
    if not ok then return false, err end
  end
  return true, "rollback restored " .. tostring(manifest.fromVersion or "previous") .. ", reboot required"
end

function M.rollback()
  local ok, result, detail = pcall(rollback)
  if not ok then return false, "Rollback failed: " .. tostring(result) .. "; backup retained" end
  return result, detail
end

function M.apply()
  local pinned, err = source.resolve(M.loadConfig(), httpGet)
  if not pinned then return false, err end
  local remote, problem = httpGet(source.url(pinned, "VERSION"))
  if not remote then return false, problem end
  local comparison, invalid = version.compare(trim(remote), M.localVersion())
  if comparison ~= 1 then return false, invalid or "Pinned release is not newer than installed version" end
  local path, err = M.downloadInstaller(pinned)
  if not path then return false, err end
  local fn, loadErr = loadfile(path)
  if not fn then return false, loadErr end
  local backedUp, backup = M.createRollback("before update")
  if not backedUp then return false, tostring(backup) end
  local ok, runErr = pcall(fn)
  if not ok then return false, tostring(runErr) end
  return true, "installer finished, reboot required"
end

function M.start(ctx)
  M.stop()
  local cfg = M.loadConfig()
  if not cfg.autoCheck then return end
  if not ctx or not ctx.eventBus or not http or not http.request then
    M.status.message = "Automatic check unavailable"
    return
  end
  M.ctx, M.listeners = ctx, {}
  local url = "https://raw.githubusercontent.com/" .. cfg.repo .. "/" .. cfg.branch .. "/VERSION"
  local function finish(remote, problem)
    local localVersion = M.localVersion()
    local comparison, invalid = version.compare(remote, localVersion)
    M.status = {
      localVersion = localVersion, remoteVersion = remote or "unknown",
      updateAvailable = comparison == 1,
      message = problem or invalid or (comparison == 1 and "update available" or "no newer release"),
    }
    if M.status.updateAvailable and ctx.notifications then
      ctx.notifications:push("info", "Update", "Version " .. remote .. " available; open Update to install", 6)
    end
    M.stop()
  end
  table.insert(M.listeners, ctx.eventBus:on("http_success", function(address, handle)
    if address ~= url then return end
    local ok, data = pcall(handle.readAll)
    pcall(handle.close)
    finish(ok and trim(data) or nil, not ok and tostring(data) or nil)
  end))
  table.insert(M.listeners, ctx.eventBus:on("http_failure", function(address, problem, handle)
    if address ~= url then return end
    if handle then pcall(handle.close) end
    finish(nil, tostring(problem))
  end))
  table.insert(M.listeners, ctx.eventBus:on("timer", function(id)
    if id == M.timer then finish(nil, "Update check timed out") end
  end))
  M.timer = os.startTimer(15)
  local ok, accepted, err = pcall(http.request, url)
  if not ok or not accepted then finish(nil, tostring(err or accepted)) end
end

function M.stop()
  if M.ctx and M.ctx.eventBus then
    for _, id in ipairs(M.listeners or {}) do M.ctx.eventBus:off(id) end
  end
  if M.timer and os.cancelTimer then os.cancelTimer(M.timer) end
  M.ctx, M.listeners, M.timer = nil, {}, nil
end

return M
