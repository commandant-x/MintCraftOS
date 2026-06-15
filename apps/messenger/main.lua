local renderer = require("system.gui.renderer")
local keyboard = require("system.gui.keyboard")
local ui = require("system.gui.components")
local messaged = require("system.services.messaged")

local M = {}

function M.run(ctx)
  local app = {
    input = "",
    status = "Connecting public chat...",
    scroll = 1,
    messages = {},
    seen = 0,
    keyboard = {},
  }

  local actions = {
    { id = "send", label = "Send" },
    { id = "clear", label = "Clear" },
    { id = "rescan", label = "Modem" },
  }

  local function push(line)
    table.insert(app.messages, line)
    if #app.messages > 80 then table.remove(app.messages, 1) end
  end

  local function rescan()
    local ok, msg = messaged.open()
    app.status = ok and ("Public chat ready on " .. tostring(msg)) or tostring(msg)
    return ok
  end

  local function syncInbox()
    local inbox = messaged.list()
    while app.seen < #inbox do
      app.seen = app.seen + 1
      local packet = inbox[app.seen]
      push(tostring(packet.from or packet.id or "?") .. ": " .. tostring(packet.text or ""))
    end
    if app.status == "Connecting public chat..." or app.status == "Opening modem..." then
      app.status = messaged.statusText()
    end
  end

  local function send()
    if app.input == "" then return end
    local ok, msg = messaged.send(app.input)
    if not ok then app.status = tostring(msg) return end
    push("me: " .. app.input)
    app.input = ""
    app.status = tostring(msg)
  end

  app.keyboard.onText = function(ch) app.input = app.input .. ch end
  app.keyboard.onBackspace = function() app.input = app.input:sub(1, -2) end
  app.keyboard.onEnter = send

  function app:draw(w, h)
    syncInbox()
    self.toolbar = ui.toolbar(1, 1, w, actions)
    renderer.writeAt(1, 2, renderer.crop("Status: " .. self.status, w), colors.black, colors.lightGray)
    local kbH = keyboard.height()
    local listH = math.max(1, h - kbH - 4)
    local first = math.max(1, #self.messages - listH + 1 - (self.scroll - 1))
    for i = 1, listH do
      local line = self.messages[first + i - 1] or ""
      renderer.writeAt(1, i + 2, renderer.crop(line, w), colors.black, colors.lightGray)
    end
    renderer.writeAt(1, h - kbH, renderer.crop("> " .. self.input, w), colors.white, colors.gray)
    self.keyboard.x = 1
    self.keyboard.y = h - kbH + 1
    self.keyboard.hint = "Message"
    keyboard.draw(1, self.keyboard.y, w, self.keyboard)
  end

  function app:handle(event)
    syncInbox()
    if event.name == "mouse_scroll" then
      self.scroll = math.max(1, self.scroll + event.args[1])
      return true
    elseif event.name == "char" then
      self.input = self.input .. event.args[1]
      return true
    elseif event.name == "key" then
      local key = event.args[1]
      if key == keys.backspace then self.input = self.input:sub(1, -2) return true end
      if key == keys.enter then send() return true end
    elseif event.name == "mouse_click" then
      local _, x, y = table.unpack(event.args)
      if event.monitorTouch and keyboard.handle(event, self.keyboard) then return true end
      local action = ui.toolbarHit(self.toolbar, x, y)
      if action == "send" then send() return true end
      if action == "clear" then self.messages = {} self.scroll = 1 return true end
      if action == "rescan" then rescan() return true end
    end
    return false
  end

  messaged.start(ctx.system)
  rescan()
  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Messenger", w = math.min(70, sw - 4), h = math.min(22, sh - 3), x = 7, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
