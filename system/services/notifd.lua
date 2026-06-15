local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")

local Notifd = {}
Notifd.__index = Notifd

function Notifd.new()
  return setmetatable({ queue = {}, nextId = 1 }, Notifd)
end

function Notifd:push(level, title, message, ttl)
  table.insert(self.queue, {
    id = self.nextId,
    level = level or "info",
    title = title or "Notification",
    message = message or "",
    ttl = ttl or 5,
    created = os.clock(),
  })
  self.nextId = self.nextId + 1
end

function Notifd:handle()
  local now = os.clock()
  for i = #self.queue, 1, -1 do
    if now - self.queue[i].created > self.queue[i].ttl then
      table.remove(self.queue, i)
    end
  end
end

function Notifd:draw()
  local w = term.getSize()
  local y = 2
  for i = #self.queue, math.max(1, #self.queue - 2), -1 do
    local n = self.queue[i]
    local bg = colors.gray
    if n.level == "error" then bg = theme.get("error") end
    if n.level == "warn" then bg = theme.get("warning") end
    if n.level == "success" then bg = theme.get("success") end
    renderer.fill(math.max(1, w - 27), y, 27, 3, bg)
    renderer.writeAt(math.max(1, w - 26), y, renderer.crop(n.title, 25), colors.white, bg)
    renderer.writeAt(math.max(1, w - 26), y + 1, renderer.crop(n.message, 25), colors.white, bg)
    y = y + 4
  end
end

return Notifd
