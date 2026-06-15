local renderer = require("system.gui.renderer")
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
