local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")
local keyboard = require("system.gui.keyboard")
local iconRenderer = require("system.gui.icon")
local ui = require("system.gui.components")

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
  local labels=M.apps and M.apps.list() or {}
  local compact=w<40 or h<18
  local iconW,iconH=compact and 4 or 7,compact and 3 or 6
  local cellH=iconH+2
  local columns=math.max(1,math.floor((w-2)/12))
  local rows=math.max(1,math.floor((h-3)/cellH))
  local cellW=math.max(1,math.floor((w-2)/columns))
  local capacity=columns*rows
  M.pageCount=math.max(1,math.ceil(#labels/capacity))
  M.page=math.max(1,math.min(M.page or 1,M.pageCount))
  local icons = {}
  for index=(M.page-1)*capacity+1,math.min(#labels,M.page*capacity) do
    local item=labels[index] local offset=index-(M.page-1)*capacity-1
    local x=2+math.floor(offset/rows)*cellW local y=2+(offset%rows)*cellH
    if x+iconW-1<=w and y+iconH<h-1 then
      icons[#icons+1]={x=x,y=y,w=cellW-1,h=cellH-1,label=item.name,icon=item.icon,iconPath=item.iconPath,app=item.id}
    end
  end

  M.icons = icons
  for _, icon in ipairs(icons) do
    iconRenderer.draw(icon.iconPath, icon.x, icon.y, icon.icon, theme.get("desktopBg"),iconW,iconH)
    renderer.writeAt(icon.x, icon.y + iconH, renderer.crop(icon.label, math.min(icon.w, w - icon.x + 1)), colors.white, theme.get("desktopBg"))
  end
  M.pageHits={}
  if w>=18 and h>=8 then
    if M.pageCount>1 then
      M.pageHits.previous=ui.button(1,h-1,3,"<",false)
      renderer.writeAt(5,h-1,tostring(M.page).."/"..M.pageCount,colors.white,theme.get("desktopBg"))
      M.pageHits.next=ui.button(11,h-1,3,">",false)
    end
    M.pageHits.apps=ui.button(w-6,h-1,7,"Apps",false)
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

function M.clockText()
  local minutes = math.floor(os.time() * 60 + 1e-7) % 1440
  return string.format("%02d:%02d", math.floor(minutes / 60), minutes % 60)
end

function M.drawClock(time)
  local w, h = term.getSize()
  time = time or M.clockText()
  renderer.writeAt(w - 5, h, time, theme.get("taskbarFg"), theme.get("taskbarBg"))
  M.displayedClock = time
end

local function drawTaskbar()
  local w, h = term.getSize()
  renderer.fill(1, h, w, 1, theme.get("taskbarBg"))
  renderer.button(1, h, 8, "Menu", M.menuOpen)
  local searchW = require("system.gui.taskbar").layout(w).searchWidth
  M.searchBox = { x = 10, y = h, w = searchW }
  local searchBg = M.searchFocused and colors.white or colors.lightGray
  local searchFg = colors.black
  renderer.writeAt(10, h, renderer.crop("?" .. M.search, searchW), searchFg, searchBg)
  M.drawClock()
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
  local w, h = term.getSize()
  if M.searchFocused then h = math.max(3, h - keyboard.height()) end
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
  local menuW = M.searchFocused and w or math.min(32, w)
  renderer.fill(1, h - height, menuW, height, colors.lightGray)
  renderer.writeAt(2, h - height, renderer.crop("MintCraft OS", menuW - 2), colors.black, colors.lightGray)
  renderer.writeAt(2, h - height + 1, renderer.crop("Search: " .. M.search, menuW - 2), colors.gray, colors.lightGray)
  local capacity=math.max(1,height-3)
  M.menuScroll=math.max(1,math.min(M.menuScroll or 1,math.max(1,#appList-capacity+1)))
  M.menuRows={} M.menuPager={}
  for i=1,capacity do
    local app=appList[M.menuScroll+i-1]
    if app then
      local y=h-height+i+1
      renderer.writeAt(2,y,renderer.crop(app.name,menuW-2),colors.black,colors.lightGray)
      M.menuRows[#M.menuRows+1]={app=app.id,x=1,y=y,w=menuW,h=1}
    end
  end
  if #appList>capacity then M.menuPager=ui.toolbar(1,h-1,menuW,{{id="up",label="^"},{id="down",label="v"}}) end
end

function M.draw()
  local w, h = term.getSize()
  renderer.fill(1, 1, w, h, theme.get("desktopBg"))
  drawIcons()
  drawTaskbar()
end

function M.drawOverlays()
  drawMenu()
  drawContextMenu()
  drawSearchKeyboard()
end

function M.captures(event)
  if event.name=="mouse_scroll" and M.menuOpen then return true end
  if M.searchFocused and (event.name == "char" or event.name == "key" or event.name == "paste") then return true end
  return event.name == "mouse_click" and (M.menuOpen or M.contextMenu ~= nil or M.searchFocused)
end

local function launch(appId,args)
  if not M.apps then return end
  local ok, result = M.apps.launch(appId,args)
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
      { label = "Refresh icons", action = function() iconRenderer.invalidate() end },
      { label = "New file", action = createTextFile },
      { label = "New folder", action = createFolder },
      { label = "Open Files", action = function() launch("files") end },
      { label = "New Lua file", action = function()
        local path = nextFreePath("/home/user/desktop/new_script_", ".lua")
        local h = fs.open(path, "w")
        if h then h.write("print(\"hello\")\n") h.close() end
        launch("files", { path = "/home/user/desktop" })
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
  if event.name=="key" and keys.f1 and event.args[1]==keys.f1 then
    M.menuOpen=not M.menuOpen M.searchFocused=M.menuOpen M.search="" return true
  end
  if event.name=="mouse_scroll" then
    if M.menuOpen then M.menuScroll=math.max(1,(M.menuScroll or 1)+event.args[1])
    else M.page=math.max(1,math.min(M.pageCount or 1,(M.page or 1)+event.args[1])) end
    return true
  end
  if event.name == "paste" and M.searchFocused then
    M.search = M.search .. event.args[1]
    M.menuOpen = true
    return true
  end
  if event.name == "char" and M.searchFocused then
    M.search = M.search .. event.args[1]
    M.menuOpen = true
    return true
  elseif event.name == "key" and M.searchFocused then
    local key = event.args[1]
    if key == keys.escape then
      M.searchFocused, M.menuOpen = false, false
      return true
    elseif key == keys.backspace then
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
    local action=ui.toolbarHit(M.menuPager,x,y)
    if action then M.menuScroll=math.max(1,(M.menuScroll or 1)+(action=="down" and 1 or -1)) return true end
    for _,box in ipairs(M.menuRows or {}) do if ui.hit(box,x,y) then
      M.menuOpen=false M.searchFocused=false launch(box.app) return true
    end end
    M.menuOpen = false
    M.searchFocused = false
    return true
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
    local pager=M.pageHits or {}
    if ui.hit(pager.apps,x,y) then launch("settings",{page="apps"}) return true end
    if ui.hit(pager.previous,x,y) then M.page=math.max(1,M.page-1) return true end
    if ui.hit(pager.next,x,y) then M.page=math.min(M.pageCount,M.page+1) return true end
    for _, icon in ipairs(M.icons or {}) do
      if ui.hit(icon,x,y) then
        launch(icon.app)
        return true
      end
    end
  end

  return false
end

return M
