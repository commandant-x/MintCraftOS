local renderer = require("system.gui.renderer")
local updated = require("system.services.updated")

local M = {}

local function buttonAt(x, y, bx, by, bw)
  return y == by and x >= bx and x < bx + bw
end

function M.run(ctx)
  local app = {
    status = updated.status,
    message = "Ready",
  }

  function app:refresh()
    local ok, status = pcall(updated.check)
    if ok then
      self.status = status
      self.message = status.message
    else
      self.message = tostring(status)
    end
  end

  function app:apply()
    local allowed, denied = ctx.security.require("system.update", "apply")
    if not allowed then self.message = denied return end
    ctx.security.audit("update apply", "GitHub installer")
    self.message = "Downloading installer..."
    local ok, message = updated.apply()
    self.message = tostring(message)
    if ctx.notifications then
      ctx.notifications:push(ok and "success" or "error", "Update", self.message, 6)
    end
  end

  function app:draw(w, h)
    self.lastH = h
    renderer.writeAt(1, 1, renderer.crop("MintCraft Update", w), colors.black, colors.lightGray)
    renderer.writeAt(2, 3, renderer.crop("Local : " .. tostring(self.status.localVersion), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(2, 4, renderer.crop("GitHub: " .. tostring(self.status.remoteVersion), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(2, 5, renderer.crop("State : " .. tostring(self.message), w - 2), colors.black, colors.lightGray)
    renderer.button(2, h - 1, 10, "Check", false)
    renderer.button(14, h - 1, 10, "Apply", false)
  end

  function app:handle(event)
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    if buttonAt(x, y, 2, self.lastH - 1, 10) then
      self:refresh()
      return true
    elseif buttonAt(x, y, 14, self.lastH - 1, 10) then
      self:apply()
      return true
    end
    return false
  end

  local sw, sh = term.getSize()
  app.lastH = math.min(12, sh - 3)
  local win = ctx.windowManager:create({ title = "Update", w = math.min(44, sw - 4), h = app.lastH, x = 7, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
