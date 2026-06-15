-- MintCraft OS V0.4 installer for CC:Tweaked
-- Install with: wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/main/install.lua
local files = {
  [".settings"] = [[{
  ["shell.allow_startup"] = true,
}
]],
  ["apps/devices/app.cfg"] = [[{
  id = "devices",
  name = "Devices",
  version = "0.4.0",
  main = "apps.devices.main",
  permissions = { "devices.list" },
}
]],
  ["apps/devices/main.lua"] = [[local renderer = require("system.gui.renderer")
local deviced = require("system.services.deviced")

local M = {}

function M.run(ctx)
  local app = {}

  function app:draw(w, h)
    renderer.writeAt(1, 1, renderer.crop("DEVICE          TYPE", w), colors.black, colors.lightGray)
    local rows = deviced.list()
    if #rows == 0 then
      renderer.writeAt(1, 3, renderer.crop("No peripheral detected", w), colors.gray, colors.lightGray)
    end
    for i = 1, math.min(#rows, h - 1) do
      local d = rows[i]
      renderer.writeAt(1, i + 1, renderer.crop(d.name .. "          " .. tostring(d.type), w), colors.black, colors.lightGray)
    end
  end

  function app:handle()
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Devices", w = math.min(44, sw - 4), h = math.min(12, sh - 3), x = 4, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["apps/files/app.cfg"] = [[{
  id = "files",
  name = "Files",
  version = "0.4.0",
  main = "apps.files.main",
  permissions = { "filesystem.read" },
}
]],
  ["apps/files/main.lua"] = [[local renderer = require("system.gui.renderer")

local M = {}

function M.run(ctx)
  local app = { path = ctx.args.path or "/home/user" }

  function app:draw(w, h)
    renderer.writeAt(1, 1, renderer.crop("Path: " .. self.path, w), colors.black, colors.lightGray)
    local files = {}
    if fs.exists(self.path) and fs.isDir(self.path) then files = fs.list(self.path) end
    for i = 1, math.min(#files, h - 2) do
      local name = files[i]
      local full = fs.combine(self.path, name)
      local prefix = fs.isDir(full) and "[D] " or "    "
      renderer.writeAt(1, i + 1, renderer.crop(prefix .. name, w), colors.black, colors.lightGray)
    end
  end

  function app:handle(event)
    if event.name == "mouse_click" then
      local _, _, y = table.unpack(event.args)
      local files = fs.list(self.path)
      local name = files[y - 1]
      if name then
        local full = fs.combine(self.path, name)
        if fs.isDir(full) then self.path = full end
      end
      return true
    elseif event.name == "key" and event.args[1] == keys.backspace then
      self.path = fs.getDir(self.path)
      if self.path == "" then self.path = "/" end
      return true
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Files", w = math.min(58, sw - 4), h = math.min(18, sh - 3), x = 6, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["apps/logs/app.cfg"] = [[{
  id = "logs",
  name = "Logs",
  version = "0.4.0",
  main = "apps.logs.main",
  permissions = { "logs.read" },
}
]],
  ["apps/logs/main.lua"] = [[local renderer = require("system.gui.renderer")
local log = require("system.libraries.log")

local M = {}

function M.run(ctx)
  local app = {}

  function app:draw(w, h)
    renderer.writeAt(1, 1, "System Logs", colors.black, colors.lightGray)
    local lines = log.tail(h - 1)
    for i, line in ipairs(lines) do
      renderer.writeAt(1, i + 1, renderer.crop(line, w), colors.black, colors.lightGray)
    end
  end

  function app:handle()
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Logs", w = math.min(72, sw - 4), h = math.min(18, sh - 3), x = 5, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["apps/services/app.cfg"] = [[{
  id = "services",
  name = "Services",
  version = "0.4.0",
  main = "apps.services.main",
  permissions = { "services.list" },
}
]],
  ["apps/services/main.lua"] = [[local renderer = require("system.gui.renderer")

local M = {}

function M.run(ctx)
  local app = {}

  function app:draw(w, h)
    renderer.writeAt(1, 1, renderer.crop("SERVICE       STATE", w), colors.black, colors.lightGray)
    local rows = ctx.system.services:list()
    for i = 1, math.min(#rows, h - 1) do
      local s = rows[i]
      renderer.writeAt(1, i + 1, renderer.crop(s.name .. "       " .. s.state, w), colors.black, colors.lightGray)
    end
  end

  function app:handle()
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Services", w = math.min(46, sw - 4), h = math.min(14, sh - 3), x = 10, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["apps/settings/app.cfg"] = [[{
  id = "settings",
  name = "Settings",
  version = "0.4.0",
  main = "apps.settings.main",
  permissions = { "system.config" },
}
]],
  ["apps/settings/main.lua"] = [[local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")

local M = {}

function M.run(ctx)
  local app = {}

  function app:draw(w, h)
    renderer.writeAt(1, 1, "Settings", colors.black, colors.lightGray)
    renderer.writeAt(1, 3, "Theme: " .. theme.currentId, colors.black, colors.lightGray)
    renderer.button(1, 5, 14, "Mint", theme.currentId == "mint")
    renderer.button(16, 5, 14, "Dark", theme.currentId == "dark")
    renderer.writeAt(1, h, "Click a theme to apply", colors.gray, colors.lightGray)
  end

  function app:handle(event)
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    if y == 5 and x <= 14 then
      theme.set("mint")
      ctx.notifications:push("success", "Settings", "Mint theme applied", 3)
      return true
    elseif y == 5 and x >= 16 and x <= 29 then
      theme.set("dark")
      ctx.notifications:push("success", "Settings", "Dark theme applied", 3)
      return true
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Settings", w = math.min(46, sw - 4), h = math.min(12, sh - 3), x = 8, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["apps/taskmanager/app.cfg"] = [[{
  id = "taskmanager",
  name = "Task Manager",
  version = "0.4.0",
  main = "apps.taskmanager.main",
  permissions = { "process.list", "process.kill" },
}
]],
  ["apps/taskmanager/main.lua"] = [[local renderer = require("system.gui.renderer")

local M = {}

function M.run(ctx)
  local app = {}

  function app:draw(w, h)
    renderer.writeAt(1, 1, renderer.crop("PID STATE    NAME", w), colors.black, colors.lightGray)
    local rows = ctx.listProcesses()
    for i = 1, math.min(#rows, h - 1) do
      local p = rows[i]
      renderer.writeAt(1, i + 1, renderer.crop(tostring(p.pid) .. "   " .. p.state .. "   " .. p.name, w), colors.black, colors.lightGray)
    end
  end

  function app:handle()
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Task Manager", w = math.min(58, sw - 4), h = math.min(16, sh - 3), x = 8, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["apps/terminal/app.cfg"] = [[{
  id = "terminal",
  name = "Terminal",
  version = "0.4.0",
  main = "apps.terminal.main",
  permissions = { "filesystem.read", "process.list", "process.kill", "system.reboot" },
}
]],
  ["apps/terminal/main.lua"] = [[local renderer = require("system.gui.renderer")
local log = require("system.libraries.log")

local M = {}

local function append(app, line)
  table.insert(app.lines, line)
  if #app.lines > 200 then table.remove(app.lines, 1) end
end

local function runCommand(app, ctx, input)
  append(app, "> " .. input)
  local cmd, rest = input:match("^(%S+)%s*(.*)$")
  if not cmd then return end

  if cmd == "clear" then
    app.lines = {}
  elseif cmd == "ls" then
    local path = rest ~= "" and fs.combine(app.cwd, rest) or app.cwd
    if fs.exists(path) and fs.isDir(path) then
      for _, name in ipairs(fs.list(path)) do append(app, name) end
    else
      append(app, "Not a directory: " .. path)
    end
  elseif cmd == "cd" then
    local path = rest ~= "" and fs.combine(app.cwd, rest) or "/"
    if fs.exists(path) and fs.isDir(path) then app.cwd = path else append(app, "No such directory") end
  elseif cmd == "cat" then
    local path = fs.combine(app.cwd, rest)
    if fs.exists(path) then
      local h = fs.open(path, "r")
      append(app, h.readAll() or "")
      h.close()
    else
      append(app, "No such file")
    end
  elseif cmd == "ps" then
    for _, p in ipairs(ctx.listProcesses()) do
      append(app, tostring(p.pid) .. " " .. p.state .. " " .. p.name)
    end
  elseif cmd == "kill" then
    local pid = tonumber(rest)
    local ok, err = ctx.kill(pid)
    append(app, ok and "killed" or err)
  elseif cmd == "logs" then
    for _, line in ipairs(log.tail(10)) do append(app, line) end
  elseif cmd == "reboot" then
    os.reboot()
  elseif cmd == "help" then
    append(app, "Commands: ls cd cat clear ps kill logs reboot help")
  else
    append(app, "Unknown command: " .. cmd)
  end
end

function M.run(ctx)
  local app = {
    lines = { "MintCraft Terminal", "Type help for commands." },
    input = "",
    cwd = "/home/user",
  }

  function app:draw(w, h)
    local start = math.max(1, #self.lines - h + 2)
    local y = 1
    for i = start, #self.lines do
      renderer.writeAt(1, y, renderer.crop(self.lines[i], w), colors.black, colors.lightGray)
      y = y + 1
      if y >= h then break end
    end
    renderer.writeAt(1, h, renderer.crop(self.cwd .. "> " .. self.input, w), colors.white, colors.gray)
  end

  function app:handle(event)
    if event.name == "char" then
      self.input = self.input .. event.args[1]
      return true
    elseif event.name == "key" then
      local key = event.args[1]
      if key == keys.enter then
        local input = self.input
        self.input = ""
        runCommand(self, ctx, input)
        return true
      elseif key == keys.backspace then
        self.input = string.sub(self.input, 1, -2)
        return true
      end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Terminal", w = math.min(68, sw - 4), h = math.min(20, sh - 3), x = 4, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["boot.lua"] = [[if not table.unpack and unpack then table.unpack = unpack end

if not require then
  local loaded = {}

  function require(name)
    if loaded[name] then return loaded[name] end

    local path = "/" .. name:gsub("%.", "/") .. ".lua"
    if not fs.exists(path) then
      error("module not found: " .. name .. " (" .. path .. ")", 2)
    end

    local chunk, err = loadfile(path)
    if not chunk then error(err, 2) end

    loaded[name] = true
    local result = chunk()
    if result ~= nil then loaded[name] = result end
    return loaded[name]
  end
end

local ok, err = pcall(function()
  local bootloader = require("system.boot.bootloader")
  bootloader.start()
end)

if not ok then
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.red)
  term.clear()
  term.setCursorPos(1, 1)
  print("MintCraft OS boot error")
  print(tostring(err))

  if fs.exists("/system/boot/recovery.lua") then
    local recovery, loadErr = loadfile("/system/boot/recovery.lua")
    if recovery then
      recovery(tostring(err))
    else
      print(tostring(loadErr))
    end
  end
end
]],
  ["packages/installed.db"] = [[{}
]],
  ["packages/sources.db"] = [[{}
]],
  ["README.md"] = [[# MintCraft OS

MintCraft OS is a CraftOS environment for CC:Tweaked 1.21.1 / NeoForge.

This repository currently contains the V0.4 base:

- bootloader, splash, recovery and panic handling
- persistent logs
- cooperative scheduler and process table
- event bus
- terminal renderer, themes and window manager
- desktop, taskbar, start menu, right-click context menu and notifications
- monitor auto-display through `deviced`
- minimal Terminal, Files, Settings, Task Manager, Services, Devices and Logs apps

Install the repository contents at the root of a CC:Tweaked computer, then reboot or run:

```lua
shell.run("/boot.lua")
```

## Install From GitHub

On a CC:Tweaked computer with HTTP enabled:

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/main/install.lua
```

Then reboot:

```lua
reboot
```
]],
  ["startup.lua"] = [[local candidates = {
  "/boot.lua",
  "boot.lua",
}

if type(arg) == "table" and type(arg[0]) == "string" then
  table.insert(candidates, fs.combine(fs.getDir(arg[0]), "boot.lua"))
end

local lastErr
for _, path in ipairs(candidates) do
  if fs.exists(path) then
    local boot, err = loadfile(path)
    if boot then return boot() end
    lastErr = err
  end
end

error(lastErr or "MintCraft OS boot.lua not found", 0)
]],
  ["system/boot/bootloader.lua"] = [[local splash = require("system.boot.splash")
local log = require("system.libraries.log")
local config = require("system.libraries.config")

local M = {}

local REQUIRED_DIRS = {
  "/system",
  "/system/boot",
  "/system/config",
  "/system/gui",
  "/system/kernel",
  "/system/libraries",
  "/system/services",
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
    version = "0.4.0",
    theme = "mint",
    debug = true,
    safeMode = false,
  })
end

function M.start()
  ensureDirs()
  log.info("boot", "bootloader started")
  ensureDefaults()
  splash.draw("MintCraft OS", "Version 0.4")

  local kernel = require("system.kernel.kernel")
  kernel.start()
end

return M
]],
  ["system/boot/recovery.lua"] = [[local reason = ...

term.setBackgroundColor(colors.black)
term.setTextColor(colors.yellow)
term.clear()
term.setCursorPos(1, 1)
print("MintCraft OS Recovery")
print("---------------------")
print("Reason: " .. tostring(reason or "manual"))
print("")
print("Commands:")
print("  shell  - open CraftOS shell")
print("  logs   - show last system log lines")
print("  reboot - reboot computer")
print("  exit   - return to caller")
print("")

while true do
  term.setTextColor(colors.lime)
  write("recovery> ")
  term.setTextColor(colors.white)
  local cmd = read()

  if cmd == "shell" then
    shell.run("shell")
  elseif cmd == "logs" then
    if fs.exists("/var/logs/system.log") then
      shell.run("type", "/var/logs/system.log")
    else
      print("No logs found.")
    end
  elseif cmd == "reboot" then
    os.reboot()
  elseif cmd == "exit" then
    return
  elseif cmd ~= "" then
    print("Unknown command: " .. cmd)
  end
end
]],
  ["system/boot/splash.lua"] = [[local M = {}

function M.draw(title, subtitle)
  term.setBackgroundColor(colors.green)
  term.setTextColor(colors.white)
  term.clear()

  local w, h = term.getSize()
  local y = math.max(2, math.floor(h / 2) - 1)
  term.setCursorPos(math.max(1, math.floor((w - #title) / 2)), y)
  term.write(title)
  term.setCursorPos(math.max(1, math.floor((w - #subtitle) / 2)), y + 2)
  term.write(subtitle)
  sleep(0.35)
end

return M
]],
  ["system/config/system.cfg"] = [[{
  version = "0.4.0",
  theme = "mint",
  debug = true,
  safeMode = false,
}
]],
  ["system/gui/desktop.lua"] = [[local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")

local M = {
  apps = nil,
  wm = nil,
  notifications = nil,
  menuOpen = false,
  contextMenu = nil,
  lastMonitorTap = nil,
}

function M.setApps(apps) M.apps = apps end
function M.setWindowManager(wm) M.wm = wm end
function M.setNotifications(notifications) M.notifications = notifications end

local function drawIcons()
  local _, h = term.getSize()
  local labels = {
    { label = "Terminal", app = "terminal" },
    { label = "Files", app = "files" },
    { label = "Settings", app = "settings" },
    { label = "Devices", app = "devices" },
  }
  local icons = {}
  local x, y = 2, 2
  for _, item in ipairs(labels) do
    table.insert(icons, { x = x, y = y, label = item.label, app = item.app })
    y = y + 3
    if y > h - 5 then
      y = 2
      x = x + 13
    end
  end

  for _, icon in ipairs(icons) do
    renderer.writeAt(icon.x, icon.y, "[ ]", colors.white, theme.get("desktopBg"))
    renderer.writeAt(icon.x, icon.y + 1, renderer.crop(icon.label, 10), colors.white, theme.get("desktopBg"))
  end
end

local function drawContextMenu()
  if not M.contextMenu then return end
  local w, h = term.getSize()
  local items = M.contextMenu.items
  local menuW = 18
  local menuH = #items + 2
  local x = math.min(M.contextMenu.x, math.max(1, w - menuW + 1))
  local y = math.min(M.contextMenu.y, math.max(1, h - menuH))
  M.contextMenu.x, M.contextMenu.y = x, y
  renderer.fill(x, y, menuW, menuH, colors.lightGray)
  renderer.writeAt(x + 1, y, "Desktop", colors.black, colors.lightGray)
  for i, item in ipairs(items) do
    renderer.writeAt(x + 1, y + i, renderer.crop(item.label, menuW - 2), colors.black, colors.lightGray)
  end
end

local function drawTaskbar()
  local w, h = term.getSize()
  renderer.fill(1, h, w, 1, theme.get("taskbarBg"))
  renderer.button(1, h, 8, "Menu", M.menuOpen)
  local time = textutils.formatTime(os.time(), true)
  renderer.writeAt(w - #time, h, time, theme.get("taskbarFg"), theme.get("taskbarBg"))
end

local function drawMenu()
  if not M.menuOpen or not M.apps then return end
  local _, h = term.getSize()
  local appList = M.apps.list()
  local height = math.min(#appList + 2, h - 2)
  renderer.fill(1, h - height, 24, height, colors.lightGray)
  renderer.writeAt(2, h - height, "MintCraft OS", colors.black, colors.lightGray)
  for i, app in ipairs(appList) do
    if i <= height - 1 then
      renderer.writeAt(2, h - height + i, tostring(i) .. ". " .. renderer.crop(app.name, 18), colors.black, colors.lightGray)
    end
  end
end

function M.draw()
  local w, h = term.getSize()
  renderer.fill(1, 1, w, h, theme.get("desktopBg"))
  drawIcons()
  drawTaskbar()
  drawMenu()
  drawContextMenu()
end

local function launch(appId)
  if not M.apps then return end
  local ok, result = M.apps.launch(appId)
  if not ok and M.notifications then
    M.notifications:push("error", "Launch failed", result, 5)
  end
end

local function nextFreePath(base, ext)
  local index = 1
  local path
  repeat
    path = base .. tostring(index) .. ext
    index = index + 1
  until not fs.exists(path)
  return path
end

local function createTextFile()
  local path = nextFreePath("/home/user/desktop/new_file_", ".txt")
  local h = fs.open(path, "w")
  if h then
    h.write("")
    h.close()
    if M.notifications then M.notifications:push("success", "Desktop", fs.getName(path) .. " created", 3) end
  end
end

local function createFolder()
  local path = nextFreePath("/home/user/desktop/new_folder_", "")
  fs.makeDir(path)
  if M.notifications then M.notifications:push("success", "Desktop", fs.getName(path) .. " created", 3) end
end

local function openContextMenu(x, y)
  M.menuOpen = false
  M.contextMenu = {
    x = x,
    y = y,
    items = {
      { label = "New file", action = createTextFile },
      { label = "New folder", action = createFolder },
      { label = "Open Files", action = function() launch("files") end },
      { label = "Terminal", action = function() launch("terminal") end },
      { label = "Settings", action = function() launch("settings") end },
    },
  }
end

function M.handle(event)
  if event.name ~= "mouse_click" then return false end
  local button, x, y = table.unpack(event.args)
  local w, h = term.getSize()

  if M.contextMenu then
    local menu = M.contextMenu
    local index = y - menu.y
    if button == 1 and x >= menu.x and x < menu.x + 18 and index >= 1 and menu.items[index] then
      local action = menu.items[index].action
      M.contextMenu = nil
      action()
      return true
    end
    M.contextMenu = nil
    return true
  end

  if y == h and x <= 8 then
    M.menuOpen = not M.menuOpen
    return true
  end

  if M.menuOpen then
    local appList = M.apps and M.apps.list() or {}
    local menuTop = h - math.min(#appList + 2, h - 2)
    local index = y - menuTop
    if x <= 24 and index >= 1 and appList[index] then
      M.menuOpen = false
      launch(appList[index].id)
      return true
    end
    M.menuOpen = false
  end

  if button == 2 then
    openContextMenu(x, y)
    return true
  end

  if event.monitorTouch then
    local now = os.clock()
    local last = M.lastMonitorTap
    M.lastMonitorTap = { x = x, y = y, time = now }
    if last and last.x == x and last.y == y and now - last.time < 0.5 then
      openContextMenu(x, y)
      return true
    end
  end

  if button == 1 and x >= 2 and x <= 11 then
    if y >= 2 and y <= 3 then launch("terminal") return true end
    if y >= 5 and y <= 6 then launch("files") return true end
    if y >= 8 and y <= 9 then launch("settings") return true end
  end

  return false
end

return M
]],
  ["system/gui/renderer.lua"] = [[local theme = require("system.gui.theme")

local M = {}

function M.clear(bg)
  term.setBackgroundColor(bg or theme.get("windowBg"))
  term.clear()
end

function M.writeAt(x, y, text, fg, bg)
  term.setCursorPos(x, y)
  term.setTextColor(fg or theme.get("windowFg"))
  term.setBackgroundColor(bg or theme.get("windowBg"))
  term.write(tostring(text))
end

function M.fill(x, y, w, h, bg)
  term.setBackgroundColor(bg or theme.get("windowBg"))
  for row = y, y + h - 1 do
    term.setCursorPos(x, row)
    term.write(string.rep(" ", w))
  end
end

function M.crop(text, width)
  text = tostring(text or "")
  if #text <= width then return text .. string.rep(" ", width - #text) end
  if width <= 1 then return string.sub(text, 1, width) end
  return string.sub(text, 1, width - 1) .. ">"
end

function M.button(x, y, w, label, active)
  local bg = active and theme.get("accent") or theme.get("buttonBg")
  local fg = active and colors.black or theme.get("buttonFg")
  M.writeAt(x, y, M.crop(" " .. label .. " ", w), fg, bg)
end

return M
]],
  ["system/gui/theme.lua"] = [[local config = require("system.libraries.config")

local M = {}

local themes = {
  mint = {
    desktopBg = colors.green,
    taskbarBg = colors.gray,
    taskbarFg = colors.white,
    windowBg = colors.lightGray,
    windowFg = colors.black,
    titleBg = colors.lime,
    titleFg = colors.black,
    accent = colors.lime,
    buttonBg = colors.gray,
    buttonFg = colors.white,
    error = colors.red,
    warning = colors.orange,
    success = colors.green,
    shadow = colors.black,
  },
  dark = {
    desktopBg = colors.black,
    taskbarBg = colors.gray,
    taskbarFg = colors.white,
    windowBg = colors.gray,
    windowFg = colors.white,
    titleBg = colors.blue,
    titleFg = colors.white,
    accent = colors.cyan,
    buttonBg = colors.lightGray,
    buttonFg = colors.black,
    error = colors.red,
    warning = colors.orange,
    success = colors.lime,
    shadow = colors.black,
  },
}

M.currentId = "mint"
M.current = themes.mint

function M.load()
  local cfg = config.load("/system/config/system.cfg", {})
  M.currentId = cfg.theme or "mint"
  M.current = themes[M.currentId] or themes.mint
end

function M.set(id)
  M.currentId = themes[id] and id or "mint"
  M.current = themes[M.currentId]
  local cfg = config.load("/system/config/system.cfg", {})
  cfg.theme = M.currentId
  config.save("/system/config/system.cfg", cfg)
end

function M.get(name)
  return M.current[name] or themes.mint[name] or colors.white
end

return M
]],
  ["system/kernel/event_bus.lua"] = [[local log = require("system.libraries.log")

local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
  return setmetatable({ listeners = {}, nextId = 1 }, EventBus)
end

function EventBus:on(name, callback)
  self.listeners[name] = self.listeners[name] or {}
  local id = self.nextId
  self.nextId = self.nextId + 1
  table.insert(self.listeners[name], { id = id, callback = callback })
  return id
end

function EventBus:off(id)
  for name, listeners in pairs(self.listeners) do
    for i = #listeners, 1, -1 do
      if listeners[i].id == id then
        table.remove(listeners, i)
        return true
      end
    end
  end
  return false
end

function EventBus:emit(name, ...)
  local listeners = self.listeners[name] or {}
  for _, listener in ipairs(listeners) do
    local ok, err = pcall(listener.callback, ...)
    if not ok then
      log.error("event_bus", tostring(err))
    end
  end
end

return EventBus
]],
  ["system/kernel/kernel.lua"] = [[local EventBus = require("system.kernel.event_bus")
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
  apps.register("terminal", "Terminal", "apps.terminal.main")
  apps.register("files", "Files", "apps.files.main")
  apps.register("settings", "Settings", "apps.settings.main")
  apps.register("taskmanager", "Task Manager", "apps.taskmanager.main")
  apps.register("logs", "Logs", "apps.logs.main")
  apps.register("services", "Services", "apps.services.main")
  apps.register("devices", "Devices", "apps.devices.main")

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
]],
  ["system/kernel/scheduler.lua"] = [[local log = require("system.libraries.log")

local Scheduler = {}
Scheduler.__index = Scheduler

local function eventMatches(filter, event)
  return filter == nil or filter == event.name
end

function Scheduler.new()
  return setmetatable({ processes = {}, nextPid = 1 }, Scheduler)
end

function Scheduler:spawn(name, fn, meta)
  local pid = self.nextPid
  self.nextPid = self.nextPid + 1

  local process = {
    pid = pid,
    name = name,
    co = coroutine.create(fn),
    state = "ready",
    filter = nil,
    meta = meta or {},
    startedAt = os.epoch("utc"),
  }

  self.processes[pid] = process
  return pid
end

function Scheduler:start(pid)
  local process = self.processes[pid]
  if not process then return false, "No such process" end
  self:resume(process, { name = "mintcraft_start", args = {} })
  return true
end

function Scheduler:resume(process, event)
  if process.state ~= "ready" then return end

  local ok, filterOrErr = coroutine.resume(process.co, event)
  if not ok then
    process.state = "crashed"
    process.error = tostring(filterOrErr)
    log.error("process", process.name .. ": " .. tostring(filterOrErr))
    return
  end

  if coroutine.status(process.co) == "dead" then
    process.state = "stopped"
  else
    process.filter = filterOrErr
  end
end

function Scheduler:dispatch(event)
  for _, process in pairs(self.processes) do
    if process.state == "ready" and eventMatches(process.filter, event) then
      self:resume(process, event)
    end
  end
end

function Scheduler:kill(pid)
  local process = self.processes[pid]
  if not process then return false, "No such process" end
  process.state = "killed"
  log.warn("process", "killed " .. process.name .. " #" .. tostring(pid))
  return true
end

function Scheduler:list()
  local rows = {}
  for _, process in pairs(self.processes) do
    table.insert(rows, {
      pid = process.pid,
      name = process.name,
      state = process.state,
      filter = process.filter,
      error = process.error,
    })
  end
  table.sort(rows, function(a, b) return a.pid < b.pid end)
  return rows
end

function Scheduler:makeContext(pid)
  local scheduler = self
  return {
    pid = pid,
    pullEvent = function(filter)
      while true do
        local event = coroutine.yield(filter)
        if not filter or event.name == filter then return event end
      end
    end,
    listProcesses = function()
      return scheduler:list()
    end,
    kill = function(targetPid)
      return scheduler:kill(targetPid)
    end,
  }
end

return Scheduler
]],
  ["system/libraries/apps.lua"] = [[local log = require("system.libraries.log")

local M = {
  registry = {},
  ctx = nil,
}

function M.setContext(ctx)
  M.ctx = ctx
end

function M.register(id, name, module)
  M.registry[id] = { id = id, name = name, module = module }
end

function M.list()
  local rows = {}
  for _, app in pairs(M.registry) do table.insert(rows, app) end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

function M.launch(id, args)
  local app = M.registry[id]
  if not app then return false, "Unknown app: " .. tostring(id) end
  if not M.ctx then return false, "App context not ready" end

  local ok, mod = pcall(require, app.module)
  if not ok then
    log.error("apps", tostring(mod))
    return false, tostring(mod)
  end

  local scheduler = M.ctx.scheduler
  local pid
  pid = scheduler:spawn(app.name, function(startEvent)
    local procCtx = scheduler:makeContext(pid)
    procCtx.appId = id
    procCtx.args = args or {}
    procCtx.windowManager = M.ctx.wm
    procCtx.notifications = M.ctx.notifications
    procCtx.apps = M
    procCtx.system = M.ctx
    mod.run(procCtx, startEvent)
  end, { appId = id })
  scheduler:start(pid)

  return true, pid
end

return M
]],
  ["system/libraries/config.lua"] = [[local M = {}

function M.load(path, fallback)
  if not fs.exists(path) then return fallback end
  local handle = fs.open(path, "r")
  if not handle then return fallback end
  local data = handle.readAll()
  handle.close()
  local ok, parsed = pcall(textutils.unserialize, data)
  if ok and parsed ~= nil then return parsed end
  return fallback
end

function M.save(path, value)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local handle = fs.open(path, "w")
  if not handle then return false, "Cannot write " .. path end
  handle.write(textutils.serialize(value))
  handle.close()
  return true
end

function M.ensure(path, value)
  if not fs.exists(path) then
    return M.save(path, value)
  end
  return true
end

return M
]],
  ["system/libraries/log.lua"] = [[local M = {}

local LOG_PATH = "/var/logs/system.log"

local function ensure()
  if not fs.exists("/var") then fs.makeDir("/var") end
  if not fs.exists("/var/logs") then fs.makeDir("/var/logs") end
end

function M.write(level, source, message)
  ensure()
  local handle = fs.open(LOG_PATH, "a")
  if handle then
    handle.writeLine(textutils.serialize({
      time = os.date(),
      level = level,
      source = source,
      message = tostring(message),
    }))
    handle.close()
  end
end

function M.info(source, message) M.write("info", source, message) end
function M.warn(source, message) M.write("warn", source, message) end
function M.error(source, message) M.write("error", source, message) end
function M.debug(source, message) M.write("debug", source, message) end

function M.tail(limit)
  limit = limit or 20
  if not fs.exists(LOG_PATH) then return {} end
  local lines = {}
  local handle = fs.open(LOG_PATH, "r")
  while true do
    local line = handle.readLine()
    if not line then break end
    table.insert(lines, line)
    if #lines > limit then table.remove(lines, 1) end
  end
  handle.close()
  return lines
end

return M
]],
  ["system/services/deviced.lua"] = [[local log = require("system.libraries.log")

local M = {
  devices = {},
  redirected = false,
  nativeTerm = nil,
}

local function scan()
  local devices = {}
  if peripheral and peripheral.getNames then
    for _, name in ipairs(peripheral.getNames()) do
      devices[name] = {
        name = name,
        type = peripheral.getType(name),
      }
    end
  end
  M.devices = devices
  return devices
end

local function useMonitorIfPresent()
  if not peripheral or not peripheral.find then return false end
  local monitor = peripheral.find("monitor")
  if not monitor then return false end

  if monitor.setTextScale then monitor.setTextScale(0.5) end
  if monitor.setBackgroundColor then monitor.setBackgroundColor(colors.black) end
  if monitor.clear then monitor.clear() end

  M.nativeTerm = term.current()
  term.redirect(monitor)
  M.redirected = true
  log.info("deviced", "using attached monitor as display")
  return true
end

function M.start(ctx)
  scan()
  useMonitorIfPresent()
  if ctx and ctx.eventBus then
    ctx.eventBus:on("peripheral", function()
      scan()
      if not M.redirected then useMonitorIfPresent() end
    end)
    ctx.eventBus:on("peripheral_detach", function()
      scan()
    end)
  end
  log.info("deviced", "device service ready")
end

function M.stop()
  if M.redirected and M.nativeTerm then
    term.redirect(M.nativeTerm)
    M.redirected = false
  end
end

function M.list()
  scan()
  local rows = {}
  for _, device in pairs(M.devices) do table.insert(rows, device) end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

return M
]],
  ["system/services/logd.lua"] = [[local log = require("system.libraries.log")

local M = {}

function M.start()
  log.info("logd", "log service ready")
end

function M.stop()
  log.info("logd", "log service stopped")
end

return M
]],
  ["system/services/notifd.lua"] = [[local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")

local Notifd = {}
Notifd.__index = Notifd

function Notifd.new()
  return setmetatable({ queue = {}, nextId = 1 }, Notifd)
end

function Notifd:push(level, title, message, ttl)
  table.insert(self.queue, {
    id = self.nextId,
    level = level or "info",
    title = title or "Notification",
    message = message or "",
    ttl = ttl or 5,
    created = os.clock(),
  })
  self.nextId = self.nextId + 1
end

function Notifd:handle()
  local now = os.clock()
  for i = #self.queue, 1, -1 do
    if now - self.queue[i].created > self.queue[i].ttl then
      table.remove(self.queue, i)
    end
  end
end

function Notifd:draw()
  local w = term.getSize()
  local y = 2
  for i = #self.queue, math.max(1, #self.queue - 2), -1 do
    local n = self.queue[i]
    local bg = colors.gray
    if n.level == "error" then bg = theme.get("error") end
    if n.level == "warn" then bg = theme.get("warning") end
    if n.level == "success" then bg = theme.get("success") end
    renderer.fill(math.max(1, w - 27), y, 27, 3, bg)
    renderer.writeAt(math.max(1, w - 26), y, renderer.crop(n.title, 25), colors.white, bg)
    renderer.writeAt(math.max(1, w - 26), y + 1, renderer.crop(n.message, 25), colors.white, bg)
    y = y + 4
  end
end

return Notifd
]],
  ["system/services/service_manager.lua"] = [[local log = require("system.libraries.log")

local ServiceManager = {}
ServiceManager.__index = ServiceManager

function ServiceManager.new(ctx)
  return setmetatable({ ctx = ctx, services = {} }, ServiceManager)
end

function ServiceManager:register(name, moduleName, autostart)
  self.services[name] = {
    name = name,
    moduleName = moduleName,
    state = "stopped",
    autostart = autostart ~= false,
  }
end

function ServiceManager:start(name)
  local service = self.services[name]
  if not service then return false, "No such service" end
  if service.state == "running" then return true end

  local ok, mod = pcall(require, service.moduleName)
  if not ok then
    service.state = "crashed"
    service.error = tostring(mod)
    log.error("service", name .. ": " .. tostring(mod))
    return false, tostring(mod)
  end

  service.module = mod
  if mod.start then
    local started, err = pcall(mod.start, self.ctx)
    if not started then
      service.state = "crashed"
      service.error = tostring(err)
      log.error("service", name .. ": " .. tostring(err))
      return false, tostring(err)
    end
  end

  service.state = "running"
  service.error = nil
  log.info("service", name .. " running")
  return true
end

function ServiceManager:stop(name)
  local service = self.services[name]
  if not service then return false, "No such service" end
  if service.module and service.module.stop then pcall(service.module.stop, self.ctx) end
  service.state = "stopped"
  log.info("service", name .. " stopped")
  return true
end

function ServiceManager:startAutostart()
  for name, service in pairs(self.services) do
    if service.autostart then self:start(name) end
  end
end

function ServiceManager:list()
  local rows = {}
  for _, service in pairs(self.services) do
    table.insert(rows, {
      name = service.name,
      state = service.state,
      autostart = service.autostart,
      error = service.error,
    })
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

return ServiceManager
]],
  ["system/wm/window.lua"] = [[local theme = require("system.gui.theme")
local renderer = require("system.gui.renderer")

local Window = {}
Window.__index = Window

function Window.new(opts)
  local w, h = term.getSize()
  local width = opts.w or math.min(38, w - 8)
  local height = opts.h or math.min(12, h - 5)
  width = math.max(12, math.min(width, w))
  height = math.max(5, math.min(height, h - 1))
  return setmetatable({
    id = opts.id,
    title = opts.title or "Window",
    x = opts.x or 6,
    y = opts.y or 3,
    w = width,
    h = height,
    minimized = false,
    closed = false,
    dragging = false,
    app = opts.app,
  }, Window)
end

function Window:clamp()
  local sw, sh = term.getSize()
  local maxX = math.max(1, sw - self.w + 1)
  local maxY = math.max(1, sh - self.h)
  self.x = math.max(1, math.min(self.x, maxX))
  self.y = math.max(1, math.min(self.y, maxY))
end

function Window:contains(x, y)
  return x >= self.x and x < self.x + self.w and y >= self.y and y < self.y + self.h
end

function Window:titleContains(x, y)
  return y == self.y and x >= self.x and x < self.x + self.w
end

function Window:draw()
  if self.closed or self.minimized then return end
  self:clamp()
  renderer.fill(self.x + 1, self.y + 1, self.w, self.h, theme.get("shadow"))
  renderer.fill(self.x, self.y, self.w, self.h, theme.get("windowBg"))
  renderer.writeAt(self.x, self.y, renderer.crop(" " .. self.title, self.w - 6), theme.get("titleFg"), theme.get("titleBg"))
  renderer.writeAt(self.x + self.w - 5, self.y, " _ X ", theme.get("titleFg"), theme.get("titleBg"))

  if self.app and self.app.draw then
    local target = window.create(term.current(), self.x + 1, self.y + 1, self.w - 2, self.h - 2, false)
    local previous = term.redirect(target)
    term.setBackgroundColor(theme.get("windowBg"))
    term.setTextColor(theme.get("windowFg"))
    term.clear()
    local ok, err = pcall(self.app.draw, self.app, self.w - 2, self.h - 2)
    term.redirect(previous)
    if ok then
      target.setVisible(true)
    else
      renderer.writeAt(self.x + 1, self.y + 1, "Draw error: " .. tostring(err), theme.get("error"), theme.get("windowBg"))
    end
  end
end

function Window:handle(event)
  if self.closed or self.minimized then return false end
  if event.name == "mouse_click" then
    local button, x, y = table.unpack(event.args)
    if button == 1 and y == self.y and x >= self.x + self.w - 2 then
      self.closed = true
      return true
    elseif button == 1 and y == self.y and x >= self.x + self.w - 5 then
      self.minimized = true
      return true
    elseif button == 1 and self:titleContains(x, y) then
      self.dragging = { dx = x - self.x, dy = y - self.y }
      return true
    end
  elseif event.name == "mouse_drag" and self.dragging then
    local _, x, y = table.unpack(event.args)
    self.x = x - self.dragging.dx
    self.y = y - self.dragging.dy
    self:clamp()
    return true
  elseif event.name == "mouse_up" then
    self.dragging = false
  end

  if self.app and self.app.handle then
    local localEvent = event
    if event.name:match("^mouse_") then
      local args = { table.unpack(event.args) }
      args[2] = args[2] - self.x
      args[3] = args[3] - self.y
      localEvent = { name = event.name, args = args, raw = event.raw }
    end
    return self.app:handle(localEvent, self)
  end
  return false
end

return Window
]],
  ["system/wm/window_manager.lua"] = [[local Window = require("system.wm.window")
local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")

local WindowManager = {}
WindowManager.__index = WindowManager

function WindowManager.new()
  return setmetatable({ windows = {}, nextId = 1 }, WindowManager)
end

function WindowManager:create(opts)
  opts.id = self.nextId
  self.nextId = self.nextId + 1
  local win = Window.new(opts)
  table.insert(self.windows, win)
  return win
end

function WindowManager:focus(win)
  for i, item in ipairs(self.windows) do
    if item == win then
      table.remove(self.windows, i)
      break
    end
  end
  table.insert(self.windows, win)
end

function WindowManager:draw()
  for i = #self.windows, 1, -1 do
    if self.windows[i].closed then table.remove(self.windows, i) end
  end

  for _, win in ipairs(self.windows) do
    win:draw()
  end

  local w, h = term.getSize()
  local x = 10
  for _, win in ipairs(self.windows) do
    if win.minimized then
      local label = "[" .. win.title .. "]"
      renderer.writeAt(x, h, renderer.crop(label, math.min(#label, 14)), theme.get("taskbarFg"), theme.get("taskbarBg"))
      x = x + math.min(#label, 14) + 1
    end
  end
end

function WindowManager:handle(event)
  if event.name == "mouse_click" then
    local _, x, y = table.unpack(event.args)
    for i = #self.windows, 1, -1 do
      local win = self.windows[i]
      if win.minimized and y == ({ term.getSize() })[2] then
        win.minimized = false
        self:focus(win)
        return true
      end
      if win:contains(x, y) then
        self:focus(win)
        return win:handle(event)
      end
    end
  else
    local win = self.windows[#self.windows]
    if win then return win:handle(event) end
  end
  return false
end

return WindowManager
]],
  ["VERSION"] = [[0.4.0
]],
}

local function ensureDir(path)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
end

term.clear()
term.setCursorPos(1, 1)
print("MintCraft OS V0.4 installer")
print("Writing files...")

for path, content in pairs(files) do
  ensureDir(path)
  local h = fs.open(path, "w")
  if not h then error("Cannot write " .. path) end
  h.write(content)
  h.close()
  print("+ " .. path)
end

print("")
print("Install complete.")
print("Run: reboot")
