local splash = require("system.boot.splash")
local log = require("system.libraries.log")
local config = require("system.libraries.config")

local M = {}

local REQUIRED_DIRS = {
  "/system",
  "/system/boot",
  "/system/config",
  "/system/dev",
  "/system/drivers",
  "/system/gui",
  "/system/kernel",
  "/system/libraries",
  "/system/network",
  "/system/package",
  "/system/security",
  "/system/services",
  "/system/themes",
  "/system/wm",
  "/apps",
  "/home",
  "/home/user",
  "/home/user/config",
  "/home/user/desktop",
  "/home/user/documents",
  "/home/user/downloads",
  "/home/user/.trash",
  "/var",
  "/var/backups",
  "/var/backups/update",
  "/var/cache",
  "/var/logs",
  "/var/tmp",
  "/packages",
}

local function ensureDirs()
  for _, path in ipairs(REQUIRED_DIRS) do
    if not fs.exists(path) then
      fs.makeDir(path)
    end
  end
end

local function ensureDefaults()
  config.ensure("/system/config/system.cfg", {
    version = "0.12.0",
    theme = "mint",
    displayScale = 0.5,
    debug = true,
    safeMode = false,
  })
  config.ensure("/system/config/security.cfg", {
    enabled = true,
    mode = "single-user",
    currentUser = "admin",
    logDenied = true,
    logSensitive = true,
  })
  config.ensure("/system/config/audio.cfg", {
    enabled = true,
    volume = 1,
    notificationVolume = 0.6,
    defaultSide = nil,
    notifyOnSystemReady = true,
  })
end

function M.start()
  ensureDirs()
  log.info("boot", "bootloader started")
  ensureDefaults()
  local cfg = config.load("/system/config/system.cfg", { version = "0.12.0" })
  splash.draw("MintCraft OS", "Version " .. tostring(cfg.version or "0.12.0"))

  local kernel = require("system.kernel.kernel")
  kernel.start()
end

return M
