local renderer = require("system.gui.renderer")
local deviced = require("system.services.deviced")
local combat = require("system.services.combatd")
local avionics = require("system.services.avionicsd")
local sable = require("system.services.sabled")

local M = {}

function M.run(ctx)
  local app = {selected=nil}

  function app:draw(w, h)
    renderer.writeAt(1, 1, renderer.crop("[Rescan] [Use monitor] [Probe]", w), colors.white, colors.gray)
    local display = deviced.getDisplay()
    renderer.writeAt(1, 2, renderer.crop("Target: " .. tostring(display.target) .. " " .. tostring(display.width) .. "x" .. tostring(display.height), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 3, renderer.crop("Monitor: " .. tostring(display.monitorSide or "none") .. " scale " .. tostring(display.scale or "-"), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 4, renderer.crop("Sable: "..tostring(sable.status().inSublevel).." Avionics: "..tostring(avionics.status().available),w))
    renderer.writeAt(1, 5, renderer.crop("Selected: "..tostring(self.selected or "tap a device"),w))
    renderer.writeAt(1, 9, renderer.crop("DEVICE          TYPE          ROLE", w), colors.black, colors.lightGray)
    local rows = deviced.list()
    if #rows == 0 then
      renderer.writeAt(1, 11, renderer.crop("No peripheral detected", w), colors.gray, colors.lightGray)
    end
    for i = 1, math.min(#rows, h - 9) do
      local d = rows[i]
      local lowerType = tostring(d.type):lower()
      local role = tostring(d.type) == "modem" and "rednet"
        or (tostring(d.type) == "monitor" or tostring(d.type)=="terminal") and "display"
        or lowerType:find("altitude", 1, true) and "avionics"
        or lowerType:find("gimbal", 1, true) and "avionics"
        or lowerType:find("propeller", 1, true) and "avionics"
        or lowerType:find("throttle", 1, true) and "avionics"
        or lowerType:find("radar", 1, true) and "radar"
        or lowerType:find("cannon", 1, true) and "cbc"
        or lowerType:find("mount", 1, true) and "cbc"
        or lowerType:find("controller", 1, true) and "fire-control"
        or lowerType:find("redstone", 1, true) and "assist"
        or "-"
      renderer.writeAt(1, i + 9, renderer.crop(d.name .. "          " .. tostring(d.type) .. "          " .. role, w), colors.black, colors.lightGray)
    end
  end

  function app:handle(event)
    if event.name == "mouse_click" then
      local _, x, y = table.unpack(event.args)
      if y == 1 and x <= 8 then
        deviced.refreshDisplay()
        combat.rescan() avionics.rescan() sable.rescan()
        ctx.notifications:push("success", "Devices", "Rescan complete", 3)
        return true
      elseif y==1 and x>=24 and x<=30 then
        local ok,err=combat.requestProbe({pid=ctx.pid},self.selected)
        ctx.notifications:push(ok and "info" or "warn","Probe",ok and "Queued; result in Logs" or tostring(err),3)
        return true
      elseif y>=10 then
        local row=deviced.list()[y-9]
        if row then self.selected=row.name return true end
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
