local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")
local keyboard = require("system.gui.keyboard")
local iconRenderer = require("system.gui.icon")

local M = {
  apps = nil,
  wm = nil,
  notifications = nil,
  menuOpen = false,
  contextMenu = nil,
  lastMonitorTap = nil,
  icons = {},
  search = "",
  searchFocused = false,
  searchBox = { x = 10, y = 1, w = 20 },
  keyboard = {},
}

function M.setApps(apps) M.apps = apps end
function M.setWindowManager(wm) M.wm = wm end
function M.setNotifications(notifications) M.notifications = notifications end

local function drawIcons()
  local w, h = term.getSize()
  local labels = {
    { app = "terminal" },
    { app = "browser" },
    { app = "files" },
    { app = "editor" },
    { app = "settings" },
    { app = "devices" },
    { app = "taskmanager" },
    { app = "store" },
    { app = "update" },
  }
  local icons = {}
  local x, y = 2, 2
  local cellW, cellH = 14, 8
  for _, item in ipairs(labels) do
    local meta = M.apps and M.apps.get(item.app) or nil
    table.insert(icons, {
      x = x,
      y = y,
      label = meta and meta.name or item.app,
      icon = meta and meta.icon or "[]",
      iconPath = meta and meta.iconPath,
      app = item.app,
    })
    y = y + cellH
    if y > h - 8 then
      y = 2
      x = x + cellW
    end
  end

  M.icons = icons
  for _, icon in ipairs(icons) do
    iconRenderer.draw(icon.iconPath, icon.x, icon.y, icon.icon, theme.get("desktopBg"))
    renderer.writeAt(icon.x, icon.y + 6, renderer.crop(icon.label, 12), colors.white, theme.get("desktopBg"))
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
  local searchW = math.min(24, math.max(10, w - 26))
  M.searchBox = { x = 10, y = h, w = searchW }
  local searchBg = M.searchFocused and colors.white or colors.lightGray
  local searchFg = colors.black
  renderer.writeAt(10, h, renderer.crop("?" .. M.search, searchW), searchFg, searchBg)
  local time = textutils.formatTime(os.time(), true)
  renderer.writeAt(w - #time, h, time, theme.get("taskbarFg"), theme.get("taskbarBg"))
end

local function drawSearchKeyboard()
  if not M.searchFocused then return end
  local w, h = term.getSize()
  M.keyboard.x = 1
  M.keyboard.y = math.max(1, h - keyboard.height())
  M.keyboard.hint = "Search: " .. M.search
  keyboard.draw(1, M.keyboard.y, w, M.keyboard)
end

local function drawMenu()
  if not M.menuOpen or not M.apps then return end
  local _, h = term.getSize()
  local appList = M.apps.list()
  if M.search ~= "" then
    local filtered = {}
    local query = M.search:lower()
    for _, app in ipairs(appList) do
      if app.name:lower():find(query, 1, true) or app.id:lower():find(query, 1, true) then
        table.insert(filtered, app)
      end
    end
    appList = filtered
  end
  local height = math.min(#appList + 3, h - 2)
  local menuW = math.min(32, w)
  renderer.fill(1, h - height, menuW, height, colors.lightGray)
  renderer.writeAt(2, h - height, renderer.crop("MintCraft OS", menuW - 2), colors.black, colors.lightGray)
  renderer.writeAt(2, h - height + 1, renderer.crop("Search: " .. M.search, menuW - 2), colors.gray, colors.lightGray)
  for i, app in ipairs(appList) do
    if i <= height - 2 then
      renderer.writeAt(2, h - height + i + 1, renderer.crop(app.icon .. " " .. app.name .. " [" .. app.category .. "]", menuW - 2), colors.black, colors.lightGray)
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
  drawSearchKeyboard()
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
      { label = "New Lua file", action = function()
        local path = nextFreePath("/home/user/desktop/new_script_", ".lua")
        local h = fs.open(path, "w")
        if h then h.write("print(\"hello\")\n") h.close() end
        launch("editor", { path = path })
      end },
      { label = "Terminal", action = function() launch("terminal") end },
      { label = "Settings", action = function() launch("settings") end },
      { label = "Devices", action = function() launch("devices") end },
    },
  }
end

M.keyboard.onText = function(ch)
  M.search = M.search .. ch
  M.menuOpen = true
end

M.keyboard.onBackspace = function()
  M.search = M.search:sub(1, -2)
  M.menuOpen = true
end

M.keyboard.onEnter = function()
  local appList = M.apps and M.apps.list() or {}
  local query = M.search:lower()
  for _, app in ipairs(appList) do
    if app.name:lower():find(query, 1, true) or app.id:lower():find(query, 1, true) then
      M.searchFocused = false
      M.search = ""
      M.menuOpen = false
      launch(app.id)
      return
    end
  end
end

M.keyboard.onTab = M.keyboard.onEnter

function M.handle(event)
  if event.name == "char" and M.searchFocused then
    M.search = M.search .. event.args[1]
    M.menuOpen = true
    return true
  elseif event.name == "key" and M.searchFocused then
    local key = event.args[1]
    if key == keys.backspace then
      M.search = string.sub(M.search, 1, -2)
      return true
    elseif key == keys.enter then
      local appList = M.apps and M.apps.list() or {}
      local query = M.search:lower()
      for _, app in ipairs(appList) do
        if app.name:lower():find(query, 1, true) or app.id:lower():find(query, 1, true) then
          M.searchFocused = false
          M.search = ""
          M.menuOpen = false
          launch(app.id)
          return true
        end
      end
    end
    return true
  end

  if event.name ~= "mouse_click" then return false end
  local button, x, y = table.unpack(event.args)
  local w, h = term.getSize()

  if M.searchFocused and event.monitorTouch and keyboard.handle(event, M.keyboard) then
    return true
  end

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
    M.searchFocused = false
    return true
  end

  if y == h and x >= M.searchBox.x and x < M.searchBox.x + M.searchBox.w then
    M.searchFocused = true
    M.menuOpen = true
    return true
  end

  if M.menuOpen then
    local appList = M.apps and M.apps.list() or {}
    if M.search ~= "" then
      local filtered = {}
      local query = M.search:lower()
      for _, app in ipairs(appList) do
        if app.name:lower():find(query, 1, true) or app.id:lower():find(query, 1, true) then
          table.insert(filtered, app)
        end
      end
      appList = filtered
    end
    local menuTop = h - math.min(#appList + 3, h - 2)
    local index = y - menuTop - 1
    if x <= 32 and index >= 1 and appList[index] then
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

  if button == 1 then
    for _, icon in ipairs(M.icons or {}) do
      if x >= icon.x and x <= icon.x + 12 and y >= icon.y and y <= icon.y + 6 then
        launch(icon.app)
        return true
      end
    end
  end

  return false
end

return M
