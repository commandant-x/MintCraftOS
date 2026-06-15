local renderer = require("system.gui.renderer")
local keyboard = require("system.gui.keyboard")
local ui = require("system.gui.components")
local httpClient = require("system.network.http_client")

local M = {}

local function isYouTube(url)
  url = tostring(url or ""):lower()
  return url:find("youtube%.com", 1, true) or url:find("youtu%.be", 1, true)
end

local function youtubeQuery(url)
  url = tostring(url or "")
  local q = url:match("[?&]search_query=([^&]+)") or url:match("[?&]q=([^&]+)")
  if not q then return "" end
  q = q:gsub("+", " "):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
  return q
end

local function entity(text)
  text = tostring(text or "")
  local named = {
    amp = "&", lt = "<", gt = ">", quot = "\"", apos = "'",
    nbsp = " ", copy = "(c)", reg = "(r)",
  }
  text = text:gsub("&#(%d+);", function(n)
    n = tonumber(n)
    if n and n >= 32 and n <= 126 then return string.char(n) end
    return " "
  end)
  text = text:gsub("&([%a]+);", function(name) return named[name] or " " end)
  return text
end

local function clean(text)
  return entity(text):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function htmlToText(html, url)
  html = tostring(html or "")
  local rows = {}
  local lowerUrl = tostring(url or ""):lower()

  if isYouTube(lowerUrl) then
    table.insert(rows, "YouTube: video decode is not available inside CC:Tweaked.")
    table.insert(rows, "MintCraft Browser can show text metadata only.")
    table.insert(rows, "")
  end

  html = html:gsub("<script.-</script>", " "):gsub("<style.-</style>", " ")
  html = html:gsub("<!%-%-.-%-%->", " ")

  local title = clean(html:match("<title[^>]*>(.-)</title>"))
  if title ~= "" then
    table.insert(rows, "# " .. title)
    table.insert(rows, "")
  end

  html = html:gsub("<[hH]([1-6])[^>]*>", "\n# "):gsub("</[hH][1-6]>", "\n")
  html = html:gsub("<[pP][^>]*>", "\n"):gsub("</[pP]>", "\n")
  html = html:gsub("<br%s*/?>", "\n"):gsub("<br>", "\n")
  html = html:gsub("<li[^>]*>", "\n- "):gsub("</li>", "\n")
  html = html:gsub("<a[^>]-href=[\"']([^\"']+)[\"'][^>]*>(.-)</a>", function(href, label)
    label = clean(label)
    if label == "" then label = href end
    return label .. " <" .. href .. ">"
  end)
  html = html:gsub("<[^>]+>", " ")

  for line in html:gmatch("[^\r\n]+") do
    line = clean(line)
    if line ~= "" and line ~= title then table.insert(rows, line) end
  end
  if #rows == 0 then table.insert(rows, "(no readable text)") end
  return table.concat(rows, "\n")
end

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
    { id = "crafttube", label = "CraftTube" },
    { id = "url", label = "URL" },
    { id = "clear", label = "Clear" },
  }

  local function load()
    if isYouTube(app.url) then
      app.status = "Use CraftTube for YouTube"
      app.lines = {
        "YouTube is not a normal web page for CC:Tweaked.",
        "",
        "MintCraft Browser cannot run YouTube's JavaScript UI,",
        "decode video, render thumbnails, or play HTML5 streams.",
        "",
        "Use CraftTube instead:",
        "- search through a configured proxy/API",
        "- open metadata cards",
        "- keep favorites and history",
        "- optional audio later through DFPWM proxy",
        "",
        "Tap CraftTube in the toolbar.",
      }
      app.scroll = 1
      return
    end
    app.status = "Loading..."
    local allowed, denied = ctx.security.require("network.http", app.url)
    if not allowed then
      app.status = denied
      app.lines = { denied }
      return
    end
    local response, err = httpClient.get(app.url)
    if response then
      app.status = tostring(response.code) .. " " .. tostring(response.size) .. " bytes"
      app.lines = splitLines(htmlToText(response.body, response.url), app.lastW or 48)
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
      if action == "crafttube" then ctx.apps.launch("crafttube", { query = youtubeQuery(self.url) }) return true end
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
