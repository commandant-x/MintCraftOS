local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")

local M = {
  apps = nil,
  wm = nil,
  notifications = nil,
  menuOpen = false,
}

function M.setApps(apps) M.apps = apps end
function M.setWindowManager(wm) M.wm = wm end
function M.setNotifications(notifications) M.notifications = notifications end

local function drawIcons()
  local icons = {
    { x = 2, y = 2, label = "Terminal", app = "terminal" },
    { x = 2, y = 5, label = "Files", app = "files" },
    { x = 2, y = 8, label = "Settings", app = "settings" },
  }

  for _, icon in ipairs(icons) do
    renderer.writeAt(icon.x, icon.y, "[ ]", colors.white, theme.get("desktopBg"))
    renderer.writeAt(icon.x, icon.y + 1, renderer.crop(icon.label, 10), colors.white, theme.get("desktopBg"))
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
end

local function launch(appId)
  if not M.apps then return end
  local ok, result = M.apps.launch(appId)
  if not ok and M.notifications then
    M.notifications:push("error", "Launch failed", result, 5)
  end
end

function M.handle(event)
  if event.name ~= "mouse_click" then return false end
  local button, x, y = table.unpack(event.args)
  local w, h = term.getSize()

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

  if button == 1 and x >= 2 and x <= 11 then
    if y >= 2 and y <= 3 then launch("terminal") return true end
    if y >= 5 and y <= 6 then launch("files") return true end
    if y >= 8 and y <= 9 then launch("settings") return true end
  end

  return false
end

return M
