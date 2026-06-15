local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")
local config = require("system.libraries.config")
local deviced = require("system.services.deviced")
local networkd = require("system.services.networkd")
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
    elseif self.page == "desktop" then
      renderer.writeAt(1, 3, "Icons: NFP 7x6 with text fallback", colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Start search: touch AZERTY keyboard", colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "Context menu: desktop double tap on monitor", colors.black, colors.lightGray)
      renderer.writeAt(1, 6, "Windows: drag, minimize, maximize, close", colors.black, colors.lightGray)
    elseif self.page == "network" then
      local status = networkd.getStatus()
      renderer.writeAt(1, 3, "HTTP: " .. httpStatus(), colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "WebSocket: " .. tostring(status.websocket and "available" or "missing"), colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "Rednet: " .. rednetStatus(), colors.black, colors.lightGray)
      renderer.writeAt(1, 6, "Pseudo IP: " .. pseudoIp(), colors.black, colors.lightGray)
      renderer.writeAt(1, 7, "Real IP is not exposed by CC:Tweaked.", colors.gray, colors.lightGray)
      renderer.writeAt(1, 8, "Use pseudo IP / rednet ID inside Minecraft.", colors.gray, colors.lightGray)
      renderer.button(1, 10, 16, "Open Browser", false)
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
      renderer.writeAt(1, 6, "Theme: " .. theme.currentId, colors.black, colors.lightGray)
      renderer.button(1, 7, 14, "Mint", theme.currentId == "mint")
      renderer.button(16, 7, 14, "Dark", theme.currentId == "dark")
      renderer.button(1, 9, 14, "Open Editor", false)
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

    if self.page == "dev" and y == 7 and x <= 14 then
      theme.set("mint")
      ctx.notifications:push("success", "Settings", "Mint theme applied", 3)
      return true
    elseif self.page == "dev" and y == 7 and x >= 16 and x <= 29 then
      theme.set("dark")
      ctx.notifications:push("success", "Settings", "Dark theme applied", 3)
      return true
    elseif self.page == "display" and y == 9 and x <= 18 then
      deviced.refreshDisplay()
      return true
    elseif self.page == "system" and y == 10 and x <= 16 then
      self.mode = "label"
      self.input = os.getComputerLabel and (os.getComputerLabel() or "") or ""
      return true
    elseif self.page == "network" and y == 10 and x <= 16 then
      ctx.apps.launch("browser")
      return true
    elseif self.page == "dev" and y == 9 and x <= 14 then
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
