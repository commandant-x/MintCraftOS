local renderer = require("system.gui.renderer")
local keyboard = require("system.gui.keyboard")
local ui = require("system.gui.components")
local httpClient = require("system.network.http_client")

local M = {}

local function splitLines(text, width)
  local rows = {}
  width = math.max(8, width or 40)
  for raw in tostring(text or ""):gmatch("[^\r\n]+") do
    local line = raw:gsub("%s+", " ")
    while #line > width do
      table.insert(rows, line:sub(1, width))
      line = line:sub(width + 1)
    end
    table.insert(rows, line)
  end
  if #rows == 0 then table.insert(rows, "") end
  return rows
end

function M.run(ctx)
  local app = {
    url = (ctx.args and ctx.args.url and ctx.args.url ~= "") and ctx.args.url or "https://example.com",
    mode = "url",
    status = "Ready",
    lines = { "Enter a URL and tap Go." },
    scroll = 1,
    keyboard = {},
  }

  local actions = {
    { id = "go", label = "Go" },
    { id = "url", label = "URL" },
    { id = "clear", label = "Clear" },
  }

  local function load()
    app.status = "Loading..."
    local response, err = httpClient.get(app.url)
    if response then
      app.status = tostring(response.code) .. " " .. tostring(response.size) .. " bytes"
      app.lines = splitLines(response.body, app.lastW or 48)
      app.scroll = 1
    else
      app.status = tostring(err)
      app.lines = { "Network error:", tostring(err) }
    end
  end

  app.keyboard.onText = function(ch)
    if app.mode == "url" then app.url = app.url .. ch end
  end
  app.keyboard.onBackspace = function()
    if app.mode == "url" then app.url = app.url:sub(1, -2) end
  end
  app.keyboard.onEnter = load

  function app:draw(w, h)
    self.lastW = w
    self.toolbar = ui.toolbar(1, 1, w, actions)
    ui.input(1, 2, w, "URL", self.url, self.mode == "url")
    renderer.writeAt(1, 3, renderer.crop("Status: " .. self.status, w), colors.black, colors.lightGray)
    local kbH = self.mode == "url" and keyboard.height() or 0
    local listH = math.max(1, h - 4 - kbH)
    for i = 1, listH do
      local line = self.lines[self.scroll + i - 1] or ""
      renderer.writeAt(1, i + 3, renderer.crop(line, w), colors.black, colors.lightGray)
    end
    if self.mode == "url" then
      self.keyboard.x = 1
      self.keyboard.y = h - keyboard.height() + 1
      self.keyboard.hint = "URL"
      keyboard.draw(1, self.keyboard.y, w, self.keyboard)
    end
  end

  function app:handle(event)
    if event.name == "mouse_scroll" then
      self.scroll = math.max(1, self.scroll + event.args[1])
      return true
    elseif event.name == "char" and self.mode == "url" then
      self.url = self.url .. event.args[1]
      return true
    elseif event.name == "key" and self.mode == "url" then
      local key = event.args[1]
      if key == keys.backspace then self.url = self.url:sub(1, -2) return true end
      if key == keys.enter then load() return true end
    elseif event.name == "mouse_click" then
      local _, x, y = table.unpack(event.args)
      if self.mode == "url" and event.monitorTouch and keyboard.handle(event, self.keyboard) then return true end
      local action = ui.toolbarHit(self.toolbar, x, y)
      if action == "go" then load() return true end
      if action == "url" then self.mode = "url" return true end
      if action == "clear" then self.lines = { "" } self.status = "Cleared" return true end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Browser", w = math.min(78, sw - 4), h = math.min(24, sh - 3), x = 5, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
