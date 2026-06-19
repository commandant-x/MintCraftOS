local EventBus = require("system.kernel.event_bus")
local Scheduler = require("system.kernel.scheduler")
local log = require("system.libraries.log")
local apps = require("system.libraries.apps")
local theme = require("system.gui.theme")
local desktop = require("system.gui.desktop")
local WindowManager = require("system.wm.window_manager")
local ServiceManager = require("system.services.service_manager")
local notifd = require("system.services.notifd")
local packageManager = require("system.package.package_manager")
local permissions = require("system.security.permissions")

local M = {}

local function normalize(raw)
  if raw[1] == "monitor_touch" then
    return {
      name = "mouse_click",
      args = { 1, raw[3], raw[4] },
      raw = raw,
      monitorTouch = true,
      monitorSide = raw[2],
    }
  end

  return {
    name = raw[1],
    args = { select(2, table.unpack(raw)) },
    raw = raw,
  }
end

local function bootApps(ctx)
  apps.register("terminal", "Terminal", "apps.terminal.main", { icon = ">_", iconPath = "/system/themes/icons/terminal.nfp", category = "System", version = "0.17.2", permissions = { "filesystem.read", "filesystem.write", "process.list", "process.kill", "packages.install", "system.reboot", "system.auth" } })
  apps.register("browser", "Browser", "apps.browser.main", { icon = "BR", iconPath = "/system/themes/icons/browser.nfp", category = "Internet", version = "0.17.2", permissions = { "network.http" } })
  apps.register("crafttube", "CraftTube", "apps.crafttube.main", { icon = "CT", iconPath = "/system/themes/icons/crafttube.nfp", category = "Internet", version = "0.17.2", permissions = { "network.http", "filesystem.read", "filesystem.write" }, hidden = true })
  apps.register("messenger", "Messenger", "apps.messenger.main", { icon = "MS", iconPath = "/system/themes/icons/messenger.nfp", category = "Network", version = "0.17.2", permissions = { "rednet.send", "rednet.receive" } })
  apps.register("navigation", "Navigation", "apps.navigation.main", { icon = "NV", iconPath = "/system/themes/icons/navigation.nfp", category = "Control", version = "0.17.2", permissions = { "sable.read", "avionics.read", "redstone.output", "navigation.assist" } })
  apps.register("combat", "Combat", "apps.combat.main", { icon = "CB", iconPath = "/system/themes/icons/combat.nfp", category = "Control", version = "0.17.2", permissions = { "combat.read", "combat.aim", "combat.fire", "peripheral.probe" } })
  apps.register("files", "Files", "apps.files.main", { icon = "[]", iconPath = "/system/themes/icons/files.nfp", category = "Files", version = "0.17.2", permissions = { "filesystem.read", "filesystem.write" } })
  apps.register("settings", "Settings", "apps.settings.main", { icon = "##", iconPath = "/system/themes/icons/settings.nfp", category = "System", version = "0.17.2", permissions = { "system.config", "audio.control", "system.auth" } })
  apps.register("taskmanager", "Task Manager", "apps.taskmanager.main", { icon = "PS", iconPath = "/system/themes/icons/taskmanager.nfp", category = "System", version = "0.17.2", permissions = { "process.list", "process.kill" } })
  apps.register("logs", "Logs", "apps.logs.main", { icon = "LG", iconPath = "/system/themes/icons/logs.nfp", category = "System", version = "0.17.2", permissions = { "logs.read" } })
  apps.register("services", "Services", "apps.services.main", { icon = "SV", iconPath = "/system/themes/icons/services.nfp", category = "System", version = "0.17.2", permissions = { "services.list", "services.control" } })
  apps.register("store", "Store", "apps.store.main", { icon = "ST", iconPath = "/system/themes/icons/store.nfp", category = "System", version = "0.17.2", permissions = { "packages.install", "filesystem.write" }, hidden = true })
  apps.register("devices", "Devices", "apps.devices.main", { icon = "IO", iconPath = "/system/themes/icons/devices.nfp", category = "Hardware", version = "0.17.2", permissions = { "devices.list" } })
  apps.register("editor", "Editor", "apps.editor.main", { icon = "{}", iconPath = "/system/themes/icons/editor.nfp", category = "Dev", version = "0.17.2", permissions = { "filesystem.read", "filesystem.write", "dev.compile" }, hidden = true })
  apps.register("update", "Update", "apps.update.main", { icon = "UP", iconPath = "/system/themes/icons/update.nfp", category = "System", version = "0.17.2", permissions = { "network.http", "system.update" } })
  packageManager.setContext(ctx)
  packageManager.registerInstalledApps()

  desktop.setApps(apps)
  desktop.setWindowManager(ctx.wm)
  desktop.setNotifications(ctx.notifications)
end

function M.start()
  log.info("kernel", "kernel starting")
  theme.load()

  local ctx = {
    eventBus = EventBus.new(),
    scheduler = Scheduler.new(),
    wm = WindowManager.new(),
    notifications = notifd.new(),
  }
  ctx.scheduler.ctx = ctx
  ctx.services = ServiceManager.new(ctx)

  ctx.apps = apps
  ctx.apps.setContext(ctx)
  ctx.packages = packageManager
  ctx.permissions = permissions
  ctx.services:register("logd", "system.services.logd", true)
  ctx.services:register("securityd", "system.services.securityd", true)
  ctx.services:register("networkd", "system.services.networkd", true)
  ctx.services:register("messaged", "system.services.messaged", true)
  ctx.services:register("audiod", "system.services.audiod", true)
  ctx.services:register("deviced", "system.services.deviced", true)
  ctx.services:register("sabled", "system.services.sabled", true)
  ctx.services:register("avionicsd", "system.services.avionicsd", true)
  ctx.services:register("combatd", "system.services.combatd", true)
  ctx.services:register("notifd", "system.services.notifd", true)
  ctx.services:register("updated", "system.services.updated", true)
  ctx.services:startAutostart()
  bootApps(ctx)

  ctx.notifications:push("success", "MintCraft OS", "System ready", 3)
  desktop.draw()
  ctx.wm:draw()
  ctx.notifications:draw()

  while true do
    local raw = { os.pullEventRaw() }
    local event = normalize(raw)

    if event.name == "terminate" then
      ctx.notifications:push("warn", "Terminate", "Use Recovery or reboot from Terminal", 4)
    else
      ctx.eventBus:emit(event.name, table.unpack(event.args))
      if event.name == "peripheral" or event.name == "peripheral_detach" then
        ctx.notifications:push("info", "Devices", "Display refreshed", 2)
      end
      ctx.scheduler:dispatch(event)
      local handled = ctx.wm:handle(event)
      if not handled then desktop.handle(event) end
      ctx.notifications:handle(event)
    end

    desktop.draw()
    ctx.wm:draw()
    ctx.notifications:draw()
  end
end

return M
