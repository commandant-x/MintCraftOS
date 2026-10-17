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
local input = require("system.kernel.input")
local devices = require("system.services.deviced")
local compositor = require("system.gui.compositor")

local M = {}

local function bootApps(ctx)
  local register=apps.registerBuiltin
  register("terminal", "Terminal", "apps.terminal.main", { icon = ">_", iconPath = "/system/themes/icons/terminal.nfp", category = "System", version = "0.18.15", permissions = { "filesystem.read", "filesystem.write", "process.list", "process.kill", "packages.install", "system.reboot", "system.auth", "system.security.admin" } })
  register("browser", "Browser", "apps.browser.main", { icon = "BR", iconPath = "/system/themes/icons/browser.nfp", category = "Internet", version = "0.18.15", permissions = { "network.http" } })
  register("crafttube", "CraftTube", "apps.crafttube.main", { icon = "CT", iconPath = "/system/themes/icons/crafttube.nfp", category = "Internet", version = "0.18.15", permissions = { "network.http", "filesystem.read", "filesystem.write" }, hidden = true })
  register("messenger", "Messenger", "apps.messenger.main", { icon = "MS", iconPath = "/system/themes/icons/messenger.nfp", category = "Network", version = "0.18.15", permissions = { "rednet.send", "rednet.receive" } })
  register("navigation", "Navigation", "apps.navigation.main", { icon = "NV", iconPath = "/system/themes/icons/navigation.nfp", category = "Control", version = "0.18.15", permissions = { "sable.read", "avionics.read", "redstone.output", "navigation.assist", "navigation.calibrate", "navigation.control", "peripheral.probe" } })
  register("combat", "Combat", "apps.combat.main", { icon = "CB", iconPath = "/system/themes/icons/combat.nfp", category = "Control", version = "0.18.15", permissions = { "combat.read", "combat.aim", "combat.fire", "combat.configure", "peripheral.probe" } })
  register("files", "Files", "apps.files.main", { icon = "[]", iconPath = "/system/themes/icons/files.nfp", category = "Files", version = "0.18.15", permissions = { "filesystem.read", "filesystem.write" } })
  register("settings", "Settings", "apps.settings.main", { icon = "##", iconPath = "/system/themes/icons/settings.nfp", category = "System", version = "0.18.15", permissions = { "system.config", "audio.control", "system.auth", "system.security.admin", "system.storage.manage" } })
  register("taskmanager", "Task Manager", "apps.taskmanager.main", { icon = "PS", iconPath = "/system/themes/icons/taskmanager.nfp", category = "System", version = "0.18.15", permissions = { "process.list", "process.kill" } })
  register("logs", "Logs", "apps.logs.main", { icon = "LG", iconPath = "/system/themes/icons/logs.nfp", category = "System", version = "0.18.15", permissions = { "logs.read" } })
  register("services", "Services", "apps.services.main", { icon = "SV", iconPath = "/system/themes/icons/services.nfp", category = "System", version = "0.18.15", permissions = { "services.list", "services.control" } })
  register("store", "Store", "apps.store.main", { icon = "ST", iconPath = "/system/themes/icons/store.nfp", category = "System", version = "0.18.15", permissions = { "packages.install", "filesystem.write" }, hidden = true })
  register("devices", "Devices", "apps.devices.main", { icon = "IO", iconPath = "/system/themes/icons/devices.nfp", category = "Hardware", version = "0.18.15", permissions = { "devices.list", "peripheral.probe" } })
  register("editor", "Editor", "apps.editor.main", { icon = "{}", iconPath = "/system/themes/icons/editor.nfp", category = "Dev", version = "0.18.15", permissions = { "filesystem.read", "filesystem.write", "dev.compile" }, hidden = true })
  register("update", "Update", "apps.update.main", { icon = "UP", iconPath = "/system/themes/icons/update.nfp", category = "System", version = "0.18.15", permissions = { "network.http", "system.update" } })
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
  ctx.services:register("vehiclebridged", "system.services.vehiclebridged", true)
  ctx.services:register("flightd", "system.services.flightd", true)
  ctx.services:register("combatd", "system.services.combatd", true)
  ctx.services:register("radarnetd", "system.services.radarnetd", true)
  ctx.services:register("notifd", "system.services.notifd", true)
  ctx.services:register("updated", "system.services.updated", true)
  ctx.services:startAutostart()
  bootApps(ctx)

  local screen = compositor.new(devices.getTarget, devices.outputFailed)
  ctx.invalidateDisplay = function() screen:invalidate() ctx.wm:invalidate() end
  ctx.renderStats = function() return screen:stats() end
  local lastClock
  local function drawFrame()
    screen:draw(function()
      desktop.draw()
      ctx.wm:draw()
      desktop.drawOverlays()
      ctx.notifications:draw()
    end)
    lastClock = desktop.displayedClock
  end
  ctx.notifications:push("success", "MintCraft OS", "System ready", 3)
  drawFrame()
  local clockTimer = os.startTimer(0.5)
  local diagnosticTimer=os.startTimer(1)

  while true do
    local raw = table.pack(os.pullEventRaw())
    if raw[1] == "timer" and raw[2] == clockTimer then
      clockTimer = os.startTimer(0.5)
      local time = desktop.clockText()
      if time ~= lastClock then
        screen:draw(function() desktop.drawClock(time) end)
        lastClock = time
      end
    else
      local internal=(raw[1]=="timer" and ctx.workerTimers and ctx.workerTimers[raw[2]]) or raw[1]=="task_complete" or raw[1]=="mintcraft_radar_verify"
      local notificationVersion=ctx.notifications.nextId
      local event = input.normalize(raw, devices.getDisplay())

      if event then
        if event.name=="timer" and event.args[1]==diagnosticTimer then
          diagnosticTimer=os.startTimer(1)
          for _,id in ipairs({"settings","devices","services","taskmanager","logs","messenger"}) do ctx.wm:invalidate(id) end
        elseif event.name=="peripheral" or event.name=="peripheral_detach" or event.name=="monitor_resize" or event.name=="term_resize" then
          ctx.wm:invalidate()
        end
        if event.name == "terminate" then
          ctx.notifications:push("warn", "Terminate", "Use Recovery or reboot from Terminal", 4)
        else
          ctx.eventBus:emit(event.name, table.unpack(event.args))
          if event.name == "peripheral" or event.name == "peripheral_detach" then
            ctx.notifications:push("info", "Devices", "Display refreshed", 2)
          end
          ctx.scheduler:dispatch(event)
          if desktop.captures(event) then
            desktop.handle(event)
          else
            local handled = ctx.wm:handle(event)
            if not handled then desktop.handle(event) end
          end
          ctx.notifications:handle(event)
        end

        if not internal or ctx.notifications.nextId~=notificationVersion then drawFrame() end
      end
    end
  end
end

return M
