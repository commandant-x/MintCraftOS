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
  register("terminal", "Terminal", "apps.terminal.main", { icon = ">_", iconPath = "/system/themes/icons/terminal.nfp", category = "System", version = "0.18.42", permissions = { "filesystem.read", "filesystem.write", "process.list", "process.kill", "packages.install", "system.reboot", "system.auth", "system.security.admin", "devices.list", "system.config" } })
  register("browser", "Browser", "apps.browser.main", { icon = "BR", iconPath = "/system/themes/icons/browser.nfp", category = "Internet", version = "0.18.42", permissions = { "network.http" } })
  register("crafttube", "CraftTube", "apps.crafttube.main", { icon = "CT", iconPath = "/system/themes/icons/crafttube.nfp", category = "Internet", version = "0.18.42", permissions = { "network.http", "filesystem.read", "filesystem.write" }, hidden = true })
  register("messenger", "Messenger", "apps.messenger.main", { icon = "MS", iconPath = "/system/themes/icons/messenger.nfp", category = "Network", version = "0.18.42", permissions = { "rednet.send", "rednet.receive" } })
  register("nexus", "NEXUS OVERMIND", "apps.nexus.main", { iconPath = "/system/themes/icons/nexus.nfp", category = "Network", version = "0.4.0", permissions = { "system.security.admin", "network.http" } })
  register("navigation", "Navigation", "apps.navigation.main", { icon = "NV", iconPath = "/system/themes/icons/navigation.nfp", category = "Control", version = "0.18.42", permissions = { "sable.read", "avionics.read", "redstone.output", "navigation.assist", "navigation.calibrate", "navigation.control", "peripheral.probe" } })
  register("combat", "Combat", "apps.combat.main", { icon = "CB", iconPath = "/system/themes/icons/combat.nfp", category = "Control", version = "0.18.42", permissions = { "combat.read", "combat.aim", "combat.fire", "combat.configure", "peripheral.probe" } })
  register("files", "Files", "apps.files.main", { icon = "[]", iconPath = "/system/themes/icons/files.nfp", category = "Files", version = "0.18.42", permissions = { "filesystem.read", "filesystem.write" } })
  register("settings", "Settings", "apps.settings.main", { icon = "##", iconPath = "/system/themes/icons/settings.nfp", category = "System", version = "0.18.42", permissions = { "system.config", "audio.control", "system.auth", "system.security.admin", "system.storage.manage" } })
  register("taskmanager", "Task Manager", "apps.taskmanager.main", { icon = "PS", iconPath = "/system/themes/icons/taskmanager.nfp", category = "System", version = "0.18.42", permissions = { "process.list", "process.kill" } })
  register("logs", "Logs", "apps.logs.main", { icon = "LG", iconPath = "/system/themes/icons/logs.nfp", category = "System", version = "0.18.42", permissions = { "logs.read" } })
  register("services", "Services", "apps.services.main", { icon = "SV", iconPath = "/system/themes/icons/services.nfp", category = "System", version = "0.18.42", permissions = { "services.list", "services.control" } })
  register("store", "Store", "apps.store.main", { icon = "ST", iconPath = "/system/themes/icons/store.nfp", category = "System", version = "0.18.42", permissions = { "packages.install", "filesystem.write" }, hidden = true })
  register("devices", "Devices", "apps.devices.main", { icon = "IO", iconPath = "/system/themes/icons/devices.nfp", category = "Hardware", version = "0.18.42", permissions = { "devices.list", "peripheral.probe" } })
  register("editor", "Editor", "apps.editor.main", { icon = "{}", iconPath = "/system/themes/icons/editor.nfp", category = "Dev", version = "0.18.42", permissions = { "filesystem.read", "filesystem.write", "dev.compile" }, hidden = true })
  register("update", "Update", "apps.update.main", { icon = "UP", iconPath = "/system/themes/icons/update.nfp", category = "System", version = "0.18.42", permissions = { "network.http", "system.update" } })
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
  ctx.services:register("nexusd", "system.services.nexusd", true)
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
  ctx.services:register("settingsd", "system.services.settingsd", true)
  ctx.services:startAutostart()
  bootApps(ctx)

  local graphicsConfig=require("system.libraries.config").load("/system/config/system.cfg",{})
  local workspace=require("system.graphics.workspace").new(ctx)
  ctx.pixelWorkspace=workspace
  local screen = compositor.new(devices.getTarget, devices.outputFailed,{
    mode=graphicsConfig.safeMode and "text" or graphicsConfig.graphicsMode=='pixel16' and 'pixel16' or "auto",
    beforeRender=function(backend) workspace:prepare(backend) end,
    pixelRender=function(backend) workspace:draw(backend) end,
    onGraphicsFailure=function(err) workspace:deactivate() log.error("graphics",tostring(err)) end,
  })
  ctx.setGraphicsMode=function(mode) workspace:deactivate() screen:configure(mode) ctx.wm:invalidate() end
  ctx.invalidateDisplay = function() screen:invalidate() ctx.wm:invalidate() end
  ctx.renderStats = function() return screen:stats() end
  ctx.graphicsCapabilities=function() return screen:capabilities() end
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
  local dragFrameTimer

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
      local display=devices.getDisplay()
      local graphics=screen:stats()
      if graphics.backend~="TEXT" then
        display.pixelWidth,display.pixelHeight=graphics.pixelWidth,graphics.pixelHeight
      end
      local event = input.normalize(raw, display)

      if event then
        if event.name=="timer" and event.args[1]==diagnosticTimer then
          diagnosticTimer=os.startTimer(1)
          for _,id in ipairs({"settings","devices","services","taskmanager","logs","messenger","nexus"}) do ctx.wm:invalidate(id) end
        elseif event.name=="peripheral" or event.name=="peripheral_detach" or event.name=="monitor_resize" or event.name=="term_resize" or event.name=="mintcraft_display_resize" then
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
          local pixelActive=screen:stats().backend~="TEXT"
          if pixelActive and workspace:handle(event) then
            -- Pixel shell consumed the event; never forward it to the grid behind.
          elseif pixelActive and event.name:match("^mouse_") then
            -- Pointer events are exclusively routed by the pixel workspace.
          elseif not pixelActive and (desktop.captures(event) or event.name=="key" and keys.f1 and event.args[1]==keys.f1) then
            desktop.handle(event)
          else
            local handled = ctx.wm:handle(event)
            if not handled then desktop.handle(event) end
          end
          ctx.notifications:handle(event)
        end

        if event.name=="timer" and event.args[1]==dragFrameTimer then
          dragFrameTimer=nil
          drawFrame()
        elseif workspace.drag and not workspace.drag.touch then
          -- Coalesce visual work only: acquisition and scheduler dispatch above
          -- still receive every event, including timers and peripheral replies.
          if not dragFrameTimer then dragFrameTimer=os.startTimer(0.05) end
        elseif not internal or ctx.notifications.nextId~=notificationVersion then
          if dragFrameTimer then os.cancelTimer(dragFrameTimer) dragFrameTimer=nil end
          drawFrame()
        end
      end
    end
  end
end

return M
