local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")

local Notifd = {}
Notifd.__index = Notifd

function Notifd.new()
  return setmetatable({ queue = {}, nextId = 1 }, Notifd)
end

function Notifd:schedule()
  local deadline
  for _, item in ipairs(self.queue) do
    local expiry = item.created + item.ttl
    deadline = deadline and math.min(deadline, expiry) or expiry
  end
  if deadline == self.deadline and self.timer then return end
  if self.timer then os.cancelTimer(self.timer) end
  self.timer, self.deadline = nil, deadline
  if deadline then self.timer = os.startTimer(math.max(0, deadline - os.clock())) end
end

function Notifd:push(level, title, message, ttl)
  local ok, audiod = pcall(require, "system.services.audiod")
  if ok and audiod and audiod.notify then pcall(audiod.notify, level or "info") end
  table.insert(self.queue, {
    id = self.nextId,
    level = level or "info",
    title = title or "Notification",
    message = message or "",
    ttl = math.max(0.1, math.min(60, tonumber(ttl) or 5)),
    created = os.clock(),
  })
  self.nextId = self.nextId + 1
  if #self.queue > 32 then table.remove(self.queue, 1) end
  self:schedule()
end

function Notifd:handle(event)
  if event and event.name == "timer" and event.args[1] == self.timer then
    self.timer = nil
  end
  local now = os.clock()
  for i = #self.queue, 1, -1 do
    if now - self.queue[i].created >= self.queue[i].ttl then
      table.remove(self.queue, i)
    end
  end
  self:schedule()
end

function Notifd:draw()
  local w, h = term.getSize()
  local width = math.min(27, w)
  if width < 3 then return end
  local left = w - width + 1
  local count = w < 60 and 1 or 3
  local y = 2
  for i = #self.queue, math.max(1, #self.queue - count + 1), -1 do
    local n = self.queue[i]
    local bg = colors.blue
    if n.level == "error" then bg = theme.get("error") end
    if n.level == "warn" then bg = theme.get("warning") end
    if n.level == "success" then bg = theme.get("success") end
    if y + 2 >= h then break end
    renderer.fill(left, y, width, 3, bg)
    renderer.writeAt(left + 1, y, renderer.crop(n.title, width - 2), colors.white, bg)
    renderer.writeAt(left + 1, y + 1, renderer.crop(n.message, width - 2), colors.white, bg)
    y = y + 4
  end
end

return Notifd
