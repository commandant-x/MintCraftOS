local EventBus = require("system.kernel.event_bus")
local Scheduler = require("system.kernel.scheduler")
local log = require("system.libraries.log")
local apps = require("system.libraries.apps")
local theme = require("system.gui.theme")
local desktop = require("system.gui.desktop")
local WindowManager = require("system.wm.window_manager")
local ServiceManager = require("system.services.service_manager")
local notifd = require("system.services.notifd")

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
  apps.register("terminal", "Terminal", "apps.terminal.main", { icon = ">_", iconPath = "/system/themes/icons/terminal.nfp", category = "System" })
  apps.register("files", "Files", "apps.files.main", { icon = "[]", iconPath = "/system/themes/icons/files.nfp", category = "Files" })
  apps.register("settings", "Settings", "apps.settings.main", { icon = "##", iconPath = "/system/themes/icons/settings.nfp", category = "System" })
  apps.register("taskmanager", "Task Manager", "apps.taskmanager.main", { icon = "PS", iconPath = "/system/themes/icons/taskmanager.nfp", category = "System" })
  apps.register("logs", "Logs", "apps.logs.main", { icon = "LG", iconPath = "/system/themes/icons/logs.nfp", category = "System" })
  apps.register("services", "Services", "apps.services.main", { icon = "SV", iconPath = "/system/themes/icons/services.nfp", category = "System" })
  apps.register("devices", "Devices", "apps.devices.main", { icon = "IO", iconPath = "/system/themes/icons/devices.nfp", category = "Hardware" })
  apps.register("editor", "Editor", "apps.editor.main", { icon = "{}", iconPath = "/system/themes/icons/editor.nfp", category = "Dev" })
  apps.register("update", "Update", "apps.update.main", { icon = "UP", iconPath = "/system/themes/icons/update.nfp", category = "System" })

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
  ctx.services = ServiceManager.new(ctx)

  ctx.apps = apps
  ctx.apps.setContext(ctx)
  ctx.services:register("logd", "system.services.logd", true)
  ctx.services:register("deviced", "system.services.deviced", true)
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
      ctx.wm:handle(event)
      desktop.handle(event)
      ctx.notifications:handle(event)
    end

    desktop.draw()
    ctx.wm:draw()
    ctx.notifications:draw()
  end
end

return M
