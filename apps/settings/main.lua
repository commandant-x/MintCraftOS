local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")
local config = require("system.libraries.config")
local deviced = require("system.services.deviced")

local M = {}

function M.run(ctx)
  local app = { page = "system" }

  local pages = { "system", "display", "network", "dev", "theme" }

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
    return http and "available" or "missing"
  end

  local function rednetStatus()
    if not peripheral or not peripheral.find then return "no peripheral API" end
    local modem = peripheral.find("modem")
    if not modem then return "no modem" end
    return "modem ready"
  end

  function app:draw(w, h)
    local x = 1
    for _, page in ipairs(pages) do
      renderer.button(x, 1, #page + 2, page, self.page == page)
      x = x + #page + 3
    end

    if self.page == "system" then
      renderer.writeAt(1, 3, "Computer ID: " .. tostring(computerId()), colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Label: " .. tostring(os.getComputerLabel and (os.getComputerLabel() or "-") or "-"), colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "MintCraft: " .. tostring(config.load("/system/config/system.cfg", {}).version or "?"), colors.black, colors.lightGray)
      renderer.writeAt(1, 7, "Pseudo IP: " .. pseudoIp(), colors.black, colors.lightGray)
    elseif self.page == "display" then
      local d = deviced.getDisplay()
      renderer.writeAt(1, 3, "Target: " .. tostring(d.target), colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Resolution: " .. tostring(d.width) .. "x" .. tostring(d.height), colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "Monitor side: " .. tostring(d.monitorSide or "-"), colors.black, colors.lightGray)
      renderer.writeAt(1, 6, "Scale: " .. tostring(d.scale or "-"), colors.black, colors.lightGray)
      renderer.writeAt(1, 7, "Monitor grade: " .. monitorGrade(d), colors.black, colors.lightGray)
      renderer.button(1, 9, 18, "Refresh display", false)
    elseif self.page == "network" then
      renderer.writeAt(1, 3, "HTTP: " .. httpStatus(), colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Rednet: " .. rednetStatus(), colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "Pseudo IP: " .. pseudoIp(), colors.black, colors.lightGray)
      renderer.writeAt(1, 7, "Real IP is not exposed by CC:Tweaked.", colors.gray, colors.lightGray)
      renderer.writeAt(1, 8, "Use pseudo IP / rednet ID inside Minecraft.", colors.gray, colors.lightGray)
    elseif self.page == "dev" then
      renderer.writeAt(1, 3, "Editor: compile Lua with loadfile()", colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Autocomplete: Tab accepts suggestion", colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "Keyboard: AZERTY touch layout", colors.black, colors.lightGray)
      renderer.button(1, 7, 14, "Open Editor", false)
    elseif self.page == "theme" then
      renderer.writeAt(1, 3, "Theme: " .. theme.currentId, colors.black, colors.lightGray)
      renderer.button(1, 5, 14, "Mint", theme.currentId == "mint")
      renderer.button(16, 5, 14, "Dark", theme.currentId == "dark")
    end
    renderer.writeAt(1, h, "Settings", colors.gray, colors.lightGray)
  end

  function app:handle(event)
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    if y == 1 then
      local cursor = 1
      for _, page in ipairs(pages) do
        local width = #page + 2
        if x >= cursor and x < cursor + width then
          self.page = page
          return true
        end
        cursor = cursor + width + 1
      end
    end

    if self.page == "theme" and y == 5 and x <= 14 then
      theme.set("mint")
      ctx.notifications:push("success", "Settings", "Mint theme applied", 3)
      return true
    elseif self.page == "theme" and y == 5 and x >= 16 and x <= 29 then
      theme.set("dark")
      ctx.notifications:push("success", "Settings", "Dark theme applied", 3)
      return true
    elseif self.page == "display" and y == 9 and x <= 18 then
      deviced.refreshDisplay()
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
