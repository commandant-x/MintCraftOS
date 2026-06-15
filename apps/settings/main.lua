local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")
local config = require("system.libraries.config")
local deviced = require("system.services.deviced")
local networkd = require("system.services.networkd")
local securityd = require("system.services.securityd")
local audiod = require("system.services.audiod")
local ui = require("system.gui.components")
local keyboard = require("system.gui.keyboard")

local M = {}

function M.run(ctx)
  local app = { page = "system", scroll = 1, mode = nil, input = "", keyboard = {} }

  local pages = {
    { id = "system", label = "System" },
    { id = "display", label = "Display" },
    { id = "desktop", label = "Desktop" },
    { id = "network", label = "Network" },
    { id = "storage", label = "Storage" },
    { id = "sound", label = "Sound" },
    { id = "security", label = "Security" },
    { id = "apps", label = "Apps" },
    { id = "packages", label = "Packages" },
    { id = "dev", label = "Dev" },
  }

  local function computerId()
    if os.getComputerID then return os.getComputerID() end
    if os.computerID then return os.computerID() end
    return 0
  end

  local function pseudoIp()
    local id = computerId()
    return "10.0." .. tostring(math.floor(id / 256) % 256) .. "." .. tostring(id % 256)
  end

  local function monitorGrade(display)
    local cells = (display.width or 0) * (display.height or 0)
    if display.target ~= "monitor" then return "computer" end
    if cells >= 4500 then return "A"
    elseif cells >= 2500 then return "B"
    elseif cells >= 1200 then return "C"
    else return "D"
    end
  end

  local function httpStatus()
    local status = networkd.getStatus()
    return status.http and "available" or "missing"
  end

  local function rednetStatus()
    if not peripheral or not peripheral.find then return "no peripheral API" end
    local modem = peripheral.find("modem")
    if not modem then return "no modem" end
    return "modem ready"
  end

  local function sizeLabel(bytes)
    bytes = tonumber(bytes) or 0
    if bytes >= 1024 * 1024 then return string.format("%.1f MB", bytes / 1024 / 1024) end
    if bytes >= 1024 then return string.format("%.1f KB", bytes / 1024) end
    return tostring(bytes) .. " B"
  end

  function app:draw(w, h)
    ui.tabs(1, 1, w, pages, self.page)

    if self.page == "system" then
      renderer.writeAt(1, 3, "Computer ID: " .. tostring(computerId()), colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Label: " .. tostring(os.getComputerLabel and (os.getComputerLabel() or "-") or "-"), colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "MintCraft: " .. tostring(config.load("/system/config/system.cfg", {}).version or "?"), colors.black, colors.lightGray)
      renderer.writeAt(1, 7, "Pseudo IP: " .. pseudoIp(), colors.black, colors.lightGray)
      renderer.writeAt(1, 8, "CraftOS over CC:Tweaked", colors.gray, colors.lightGray)
      renderer.button(1, 10, 16, "Set label", false)
    elseif self.page == "display" then
      local d = deviced.getDisplay()
      renderer.writeAt(1, 3, "Target: " .. tostring(d.target), colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Resolution: " .. tostring(d.width) .. "x" .. tostring(d.height), colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "Monitor side: " .. tostring(d.monitorSide or "-"), colors.black, colors.lightGray)
      renderer.writeAt(1, 6, "Scale: " .. tostring(d.scale or "-"), colors.black, colors.lightGray)
      renderer.writeAt(1, 7, "Monitor grade: " .. monitorGrade(d), colors.black, colors.lightGray)
      renderer.button(1, 9, 18, "Refresh display", false)
      renderer.writeAt(1, 11, "Set scale:", colors.black, colors.lightGray)
      renderer.button(1, 12, 8, "0.5", d.scale == 0.5)
      renderer.button(10, 12, 8, "1.0", d.scale == 1)
      renderer.button(19, 12, 8, "1.5", d.scale == 1.5)
      renderer.button(28, 12, 8, "2.0", d.scale == 2)
    elseif self.page == "desktop" then
      renderer.writeAt(1, 3, "Icons: NFP 7x6 with text fallback", colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Start search: touch AZERTY keyboard", colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "Context menu: desktop double tap on monitor", colors.black, colors.lightGray)
      renderer.writeAt(1, 6, "Windows: drag, minimize, maximize, close", colors.black, colors.lightGray)
      renderer.writeAt(1, 8, "Theme: " .. theme.currentId, colors.black, colors.lightGray)
      renderer.button(1, 9, 14, "Mint", theme.currentId == "mint")
      renderer.button(16, 9, 14, "Dark", theme.currentId == "dark")
    elseif self.page == "network" then
      local status = networkd.getStatus()
      local crafttube = config.load("/system/config/crafttube.cfg", {})
      renderer.writeAt(1, 3, "HTTP: " .. httpStatus(), colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "WebSocket: " .. tostring(status.websocket and "available" or "missing"), colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "Rednet: " .. rednetStatus(), colors.black, colors.lightGray)
      renderer.writeAt(1, 6, "Pseudo IP: " .. pseudoIp(), colors.black, colors.lightGray)
      renderer.writeAt(1, 7, renderer.crop("CraftTube " .. tostring(crafttube.provider or "proxy") .. ": " .. tostring(crafttube.proxy or ""), w), colors.black, colors.lightGray)
      renderer.writeAt(1, 8, "Use pseudo IP / rednet ID inside Minecraft.", colors.gray, colors.lightGray)
      renderer.button(1, 10, 16, "Open Browser", false)
      renderer.button(18, 10, 18, "Messenger", false)
      renderer.button(38, 10, 18, "CraftTube", false)
    elseif self.page == "storage" then
      local free = fs.getFreeSpace and fs.getFreeSpace("/") or nil
      local cap = fs.getCapacity and fs.getCapacity("/") or nil
      renderer.writeAt(1, 3, "Root: /", colors.black, colors.lightGray)
      if cap and free then
        renderer.writeAt(1, 4, "Used: " .. sizeLabel(cap - free) .. " / " .. sizeLabel(cap), colors.black, colors.lightGray)
        renderer.writeAt(1, 5, "Free: " .. sizeLabel(free), colors.black, colors.lightGray)
      elseif free then
        renderer.writeAt(1, 4, "Free: " .. sizeLabel(free), colors.black, colors.lightGray)
      else
        renderer.writeAt(1, 4, "Storage metrics unavailable", colors.black, colors.lightGray)
      end
      renderer.writeAt(1, 7, "Trash: /home/user/.trash", colors.gray, colors.lightGray)
    elseif self.page == "sound" then
      local st = audiod.status()
      renderer.writeAt(1, 3, "Audio service: " .. tostring(st.ready and "ready" or "stopped"), colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Enabled: " .. tostring(st.enabled and "yes" or "no"), colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "Speakers: " .. tostring(st.count or 0), colors.black, colors.lightGray)
      renderer.writeAt(1, 6, "Default side: " .. tostring(st.defaultSide or "-"), colors.black, colors.lightGray)
      renderer.writeAt(1, 7, "Volume: " .. tostring(st.volume) .. "  Notify: " .. tostring(st.notificationVolume), colors.black, colors.lightGray)
      renderer.button(1, 9, 12, st.enabled and "Disable" or "Enable", false)
      renderer.button(15, 9, 12, "Test", false)
      renderer.writeAt(1, 11, "Volume:", colors.black, colors.lightGray)
      renderer.button(1, 12, 8, "0.5", st.volume == 0.5)
      renderer.button(10, 12, 8, "1.0", st.volume == 1)
      renderer.button(19, 12, 8, "1.5", st.volume == 1.5)
      renderer.button(28, 12, 8, "2.0", st.volume == 2)
      local speakers = st.speakers or {}
      renderer.writeAt(1, 14, "Detected speakers:", colors.black, colors.lightGray)
      for i = 1, math.min(#speakers, h - 15) do
        renderer.writeAt(1, 14 + i, renderer.crop(tostring(speakers[i].side) .. "  tap to use", w), colors.black, colors.lightGray)
      end
    elseif self.page == "security" then
      local cfg = config.load("/system/config/security.cfg", {})
      renderer.writeAt(1, 3, "Security: " .. tostring(cfg.enabled ~= false and "enabled" or "disabled"), colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Mode: " .. tostring(cfg.mode or "single-user"), colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "User: " .. tostring(cfg.currentUser or "admin"), colors.black, colors.lightGray)
      renderer.writeAt(1, 6, "Service: " .. securityd.statusText(), colors.black, colors.lightGray)
      renderer.writeAt(1, 8, "Apps carry declared permissions.", colors.gray, colors.lightGray)
      renderer.writeAt(1, 9, "Denied actions are logged in system.log.", colors.gray, colors.lightGray)
      renderer.writeAt(1, 10, "Users/enforcement are simulated in V0.10.", colors.gray, colors.lightGray)
    elseif self.page == "apps" then
      local rows = ctx.apps.list()
      renderer.writeAt(1, 3, renderer.crop("APP              VERSION   CATEGORY   PERMISSIONS", w), colors.black, colors.gray)
      for i = 1, math.min(#rows, h - 4) do
        local item = rows[self.scroll + i - 1]
        if item then
          renderer.writeAt(1, i + 3, renderer.crop(item.name .. "          " .. tostring(item.version) .. "   " .. item.category .. "   " .. table.concat(item.permissions or {}, ","), w), colors.black, colors.lightGray)
        end
      end
    elseif self.page == "packages" then
      local rows = ctx.system.packages.installed()
      renderer.writeAt(1, 3, renderer.crop("PACKAGE          VERSION", w), colors.black, colors.gray)
      if #rows == 0 then renderer.writeAt(1, 4, "No package installed", colors.gray, colors.lightGray) end
      for i = 1, math.min(#rows, h - 4) do
        local item = rows[self.scroll + i - 1]
        if item then renderer.writeAt(1, i + 3, renderer.crop(item.name .. "          " .. item.version, w), colors.black, colors.lightGray) end
      end
    elseif self.page == "dev" then
      renderer.writeAt(1, 3, "Editor: compile Lua with loadfile()", colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Autocomplete: Tab accepts suggestion", colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "Keyboard: AZERTY touch layout", colors.black, colors.lightGray)
      renderer.button(1, 7, 14, "Open Editor", false)
    end
    if self.mode == "label" then
      self.keyboard.x = 1
      self.keyboard.y = math.max(1, h - keyboard.height() + 1)
      self.keyboard.hint = "Label: " .. self.input
      keyboard.draw(1, self.keyboard.y, w, self.keyboard)
    end
    renderer.writeAt(1, h, "Settings", colors.gray, colors.lightGray)
  end

  app.keyboard.onText = function(ch) app.input = app.input .. ch end
  app.keyboard.onBackspace = function() app.input = app.input:sub(1, -2) end
  app.keyboard.onEnter = function()
    if app.mode == "label" and os.setComputerLabel then os.setComputerLabel(app.input) end
    app.mode = nil
    app.input = ""
  end

  function app:handle(event)
    if self.mode == "label" then
      if event.name == "char" then self.input = self.input .. event.args[1] return true end
      if event.name == "key" and event.args[1] == keys.backspace then self.input = self.input:sub(1, -2) return true end
      if event.name == "key" and event.args[1] == keys.enter then self.keyboard.onEnter() return true end
      if event.name == "mouse_click" and event.monitorTouch and keyboard.handle(event, self.keyboard) then return true end
    end
    if event.name == "mouse_scroll" and (self.page == "apps" or self.page == "packages") then
      self.scroll = math.max(1, self.scroll + event.args[1])
      return true
    end
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    if y == 1 then
      for _, page in ipairs(pages) do
        if ui.hit(page, x, y) then
          self.page = page.id
          self.scroll = 1
          return true
        end
      end
    end

    if self.page == "desktop" and y == 9 and x <= 14 then
      theme.set("mint")
      ctx.notifications:push("success", "Settings", "Mint theme applied", 3)
      return true
    elseif self.page == "desktop" and y == 9 and x >= 16 and x <= 29 then
      theme.set("dark")
      ctx.notifications:push("success", "Settings", "Dark theme applied", 3)
      return true
    elseif self.page == "display" and y == 9 and x <= 18 then
      deviced.refreshDisplay()
      return true
    elseif self.page == "display" and y == 12 then
      if x <= 8 then deviced.setScale(0.5) return true end
      if x >= 10 and x <= 17 then deviced.setScale(1) return true end
      if x >= 19 and x <= 26 then deviced.setScale(1.5) return true end
      if x >= 28 and x <= 35 then deviced.setScale(2) return true end
    elseif self.page == "sound" and y == 9 and x <= 12 then
      local st = audiod.status()
      audiod.setEnabled(not st.enabled)
      ctx.notifications:push("success", "Audio", "Audio " .. tostring(not st.enabled and "enabled" or "disabled"), 2)
      return true
    elseif self.page == "sound" and y == 9 and x >= 15 and x <= 26 then
      local ok, err = audiod.test()
      ctx.notifications:push(ok and "success" or "warn", "Audio", ok and "Test note sent" or tostring(err), 3)
      return true
    elseif self.page == "sound" and y == 12 then
      if x <= 8 then audiod.setVolume(0.5) return true end
      if x >= 10 and x <= 17 then audiod.setVolume(1) return true end
      if x >= 19 and x <= 26 then audiod.setVolume(1.5) return true end
      if x >= 28 and x <= 35 then audiod.setVolume(2) return true end
    elseif self.page == "sound" and y >= 15 then
      local st = audiod.status()
      local item = (st.speakers or {})[y - 14]
      if item then
        local ok, err = audiod.use(item.side)
        ctx.notifications:push(ok and "success" or "warn", "Audio", ok and ("Using " .. item.side) or tostring(err), 3)
        return true
      end
    elseif self.page == "system" and y == 10 and x <= 16 then
      self.mode = "label"
      self.input = os.getComputerLabel and (os.getComputerLabel() or "") or ""
      return true
    elseif self.page == "network" and y == 10 and x <= 16 then
      ctx.apps.launch("browser")
      return true
    elseif self.page == "network" and y == 10 and x >= 18 and x <= 35 then
      ctx.apps.launch("messenger")
      return true
    elseif self.page == "network" and y == 10 and x >= 38 and x <= 55 then
      ctx.apps.launch("crafttube")
      return true
    elseif self.page == "dev" and y == 7 and x <= 14 then
      ctx.apps.launch("editor")
      return true
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Settings", w = math.min(72, sw - 4), h = math.min(18, sh - 3), x = 8, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
