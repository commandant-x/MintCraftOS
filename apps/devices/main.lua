local renderer = require("system.gui.renderer")
local deviced = require("system.services.deviced")
local sabled = require("system.services.sabled")
local avionicsd = require("system.services.avionicsd")

local M = {}

function M.run(ctx)
  local app = {}

  function app:draw(w, h)
    renderer.writeAt(1, 1, renderer.crop("[Rescan] [Use monitor]", w), colors.white, colors.gray)
    local display = deviced.getDisplay()
    local sable = sabled.status()
    local avionics = avionicsd.status()
    local counts = avionics.counts or {}
    renderer.writeAt(1, 2, renderer.crop("Target: " .. tostring(display.target) .. " " .. tostring(display.width) .. "x" .. tostring(display.height), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 3, renderer.crop("Monitor: " .. tostring(display.monitorSide or "none") .. " scale " .. tostring(display.scale or "-"), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 4, renderer.crop("Sable: " .. tostring(sable.available and "available" or "missing") .. "  Sublevel: " .. tostring(sable.inSublevel and "ready" or "none"), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 5, renderer.crop("Avionics: " .. tostring(avionics.available and "ready" or "missing") .. " alt=" .. tostring(counts.altitude or 0) .. " gimbal=" .. tostring(counts.gimbal or 0) .. " prop=" .. tostring(counts.propeller or 0) .. " throttle=" .. tostring(counts.throttle or 0), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 6, renderer.crop("APIs: " .. table.concat(sable.apiNames or {}, ",") .. "  Recommended: 4x3 monitor scale 0.5", w), colors.gray, colors.lightGray)
    renderer.writeAt(1, 8, renderer.crop("DEVICE          TYPE          ROLE", w), colors.black, colors.lightGray)
    local rows = deviced.list()
    if #rows == 0 then
      renderer.writeAt(1, 10, renderer.crop("No peripheral detected", w), colors.gray, colors.lightGray)
    end
    for i = 1, math.min(#rows, h - 8) do
      local d = rows[i]
      local role = tostring(d.type) == "modem" and "rednet"
        or tostring(d.type) == "monitor" and "display"
        or tostring(d.type):lower():find("altitude", 1, true) and "avionics"
        or tostring(d.type):lower():find("gimbal", 1, true) and "avionics"
        or tostring(d.type):lower():find("propeller", 1, true) and "avionics"
        or tostring(d.type):lower():find("throttle", 1, true) and "avionics"
        or tostring(d.type):find("redstone", 1, true) and "assist"
        or "-"
      renderer.writeAt(1, i + 8, renderer.crop(d.name .. "          " .. tostring(d.type) .. "          " .. role, w), colors.black, colors.lightGray)
    end
  end

  function app:handle(event)
    if event.name == "mouse_click" then
      local _, x, y = table.unpack(event.args)
      if y == 1 and x <= 8 then
        deviced.refreshDisplay()
        ctx.notifications:push("success", "Devices", "Rescan complete", 3)
        return true
      elseif y == 1 and x >= 10 and x <= 22 then
        if deviced.refreshDisplay() then
          ctx.notifications:push("success", "Devices", "Monitor selected", 3)
        else
          ctx.notifications:push("warn", "Devices", "No monitor found", 3)
        end
        return true
      end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Devices", w = math.min(60, sw - 4), h = math.min(18, sh - 3), x = 4, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
