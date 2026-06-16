local renderer = require("system.gui.renderer")
local keyboard = require("system.gui.keyboard")
local ui = require("system.gui.components")
local config = require("system.libraries.config")
local log = require("system.libraries.log")
local httpClient = require("system.network.http_client")

local M = {}

local ROOT = "/home/user/config/browser"
local CACHE = "/var/cache/browser"
local HISTORY = ROOT .. "/history.json"
local BOOKMARKS = ROOT .. "/bookmarks.json"
local SETTINGS = ROOT .. "/settings.db"
local DOWNLOADS = ROOT .. "/downloads.json"

local REDIRECTS = { [301] = true, [302] = true, [307] = true, [308] = true }

local ERROR_DEFS = {
  ["BRW-000"] = { title = "Unknown browser error", hint = "The browser received an unexpected failure." },
  ["BRW-001"] = { title = "HTTP API disabled", hint = "Enable HTTP in CC:Tweaked config, then reboot the world/client." },
  ["BRW-002"] = { title = "Request failed", hint = "The host rejected the request, TLS failed, DNS failed, or the server is unreachable from Minecraft." },
  ["BRW-003"] = { title = "Permission denied", hint = "MintCraft security blocked this network action." },
  ["BRW-004"] = { title = "Too many redirects", hint = "The page redirected too many times. Try Reload or open the final URL manually." },
  ["BRW-005"] = { title = "Invalid URL", hint = "Enter a full URL, a domain, or a search query." },
  ["BRW-006"] = { title = "YouTube routed", hint = "Use CraftTube. Browser does not run YouTube JavaScript or HTML5 video." },
  ["BRW-007"] = { title = "Cache read error", hint = "Clear /var/cache/browser or disable cache in Browser settings." },
  ["BRW-008"] = { title = "Download failed", hint = "The file could not be downloaded or written to /home/user/downloads." },
}

local function ensureDirs()
  for _, path in ipairs({ ROOT, CACHE, "/home/user/downloads" }) do
    if not fs.exists(path) then fs.makeDir(path) end
  end
end

local function now()
  if os.date then return os.date("%Y-%m-%dT%H:%M:%S") end
  return tostring(os.clock())
end

local function readFile(path)
  if not fs.exists(path) then return nil end
  local handle = fs.open(path, "r")
  if not handle then return nil end
  local data = handle.readAll()
  handle.close()
  return data
end

local function writeFile(path, data)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local handle = fs.open(path, "w")
  if not handle then return false end
  handle.write(data)
  handle.close()
  return true
end

local function loadData(path, fallback)
  local data = readFile(path)
  if not data then return fallback end
  if textutils.unserializeJSON then
    local ok, value = pcall(textutils.unserializeJSON, data)
    if ok and value ~= nil then return value end
  end
  local ok, value = pcall(textutils.unserialize, data)
  if ok and value ~= nil then return value end
  return fallback
end

local function saveData(path, value)
  if textutils.serializeJSON then
    local ok, data = pcall(textutils.serializeJSON, value)
    if ok and data then return writeFile(path, data) end
  end
  return writeFile(path, textutils.serialize(value))
end

local function urlDecode(text)
  return tostring(text or ""):gsub("+", " "):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

local function urlEncode(text)
  text = tostring(text or "")
  return text:gsub("([^%w%-%_%.%~ ])", function(ch)
    return string.format("%%%02X", string.byte(ch))
  end):gsub(" ", "+")
end

local function isYouTube(url)
  url = tostring(url or ""):lower()
  return url:find("youtube.com", 1, true)
    or url:find("youtu.be", 1, true)
    or url:find("m.youtube.com", 1, true)
    or url:find("www.youtube.com", 1, true)
end

local function youtubeQuery(url)
  url = tostring(url or "")
  local id = url:match("[?&]v=([%w%-_]+)") or url:match("youtu%.be/([%w%-_]+)")
  if id then return id end
  return urlDecode(url:match("[?&]search_query=([^&]+)") or url:match("[?&]q=([^&]+)") or "")
end

local function queryParam(url, name)
  local encoded = tostring(url or ""):match("[?&]" .. name .. "=([^&]+)")
  return encoded and urlDecode(encoded) or ""
end

local function normalizeAddress(input, search)
  input = tostring(input or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if input == "" then return "mint://home" end
  if isYouTube(input) and not input:match("^https?://") then return "https://" .. input end
  if input:match("^mint://") or input:match("^https?://") then return input end
  if input:match("^[%w%-_%.]+%.[%a][%a]+[/]?.*$") then return "https://" .. input end
  return (search or "https://duckduckgo.com/html/?q=") .. urlEncode(input)
end

local function hostOf(url)
  return tostring(url or ""):match("^https?://([^/%?#]+)") or ""
end

local function baseOf(url)
  local proto, host, path = tostring(url or ""):match("^(https?://)([^/]+)(.-)$")
  if not proto then return url end
  path = path:gsub("[^/]*$", "")
  return proto .. host .. path
end

local function resolveUrl(base, href)
  href = tostring(href or "")
  if href:match("^https?://") or href:match("^mint://") then return href end
  if href:sub(1, 2) == "//" then return "https:" .. href end
  local protoHost = tostring(base or ""):match("^(https?://[^/]+)")
  if href:sub(1, 1) == "/" then return (protoHost or "") .. href end
  return baseOf(base) .. href
end

local function entity(text)
  text = tostring(text or "")
  local named = { amp = "&", lt = "<", gt = ">", quot = "\"", apos = "'", nbsp = " " }
  text = text:gsub("&#(%d+);", function(n)
    n = tonumber(n)
    if n and n >= 32 and n <= 126 then return string.char(n) end
    return " "
  end)
  return text:gsub("&([%a]+);", function(name) return named[name] or " " end)
end

local function clean(text)
  return entity(text):gsub("<[^>]+>", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function wrap(text, width, prefix)
  local lines = {}
  width = math.max(10, width or 60)
  prefix = prefix or ""
  local line = prefix
  for word in tostring(text or ""):gmatch("%S+") do
    if #line + #word + 1 > width then
      table.insert(lines, line)
      line = prefix .. word
    else
      line = line == prefix and (line .. word) or (line .. " " .. word)
    end
  end
  if line ~= prefix or #lines == 0 then table.insert(lines, line) end
  return lines
end

local function parseHtml(html, url, width)
  html = tostring(html or "")
  local title = clean(html:match("<title[^>]*>(.-)</title>"))
  if title == "" then title = url end
  local links = {}
  local lines = {}

  html = html:gsub("<script.-</script>", " "):gsub("<style.-</style>", " "):gsub("<!%-%-.-%-%->", " ")
  html = html:gsub("<a[^>]-href=[\"']([^\"']+)[\"'][^>]*>(.-)</a>", function(href, label)
    local n = #links + 1
    local text = clean(label)
    if text == "" then text = href end
    table.insert(links, { index = n, text = text, url = resolveUrl(url, href) })
    return " [" .. tostring(n) .. "] " .. text .. " "
  end)

  html = html:gsub("<[hH]1[^>]*>", "\n# "):gsub("</[hH]1>", "\n")
  html = html:gsub("<[hH]2[^>]*>", "\n## "):gsub("</[hH]2>", "\n")
  html = html:gsub("<[hH]3[^>]*>", "\n### "):gsub("</[hH]3>", "\n")
  html = html:gsub("<[pP][^>]*>", "\n"):gsub("</[pP]>", "\n")
  html = html:gsub("<br%s*/?>", "\n"):gsub("<br>", "\n")
  html = html:gsub("<li[^>]*>", "\n- "):gsub("</li>", "\n")
  html = html:gsub("<tr[^>]*>", "\n"):gsub("</tr>", "\n")
  html = html:gsub("<t[dh][^>]*>", " | "):gsub("</t[dh]>", " ")
  html = html:gsub("<pre[^>]*>", "\n``` "):gsub("</pre>", " ```\n")
  html = html:gsub("<blockquote[^>]*>", "\n> "):gsub("</blockquote>", "\n")
  html = html:gsub("<hr[^>]*>", "\n----------------\n")
  html = html:gsub("<[^>]+>", " ")

  if title ~= "" then
    table.insert(lines, "# " .. title)
    table.insert(lines, "")
  end
  for raw in html:gmatch("[^\r\n]+") do
    local line = clean(raw)
    if line ~= "" and line ~= title then
      for _, item in ipairs(wrap(line, width)) do table.insert(lines, item) end
    end
  end
  if #lines == 0 then table.insert(lines, "(empty page)") end
  return { title = title, lines = lines, links = links, status = 200 }
end

local function cacheKey(url)
  return tostring(url or ""):gsub("[^%w%-_%.]", "_"):sub(1, 80)
end

local function filenameFromUrl(url)
  local name = tostring(url or ""):match("/([^/%?#]+)[%?#]?$") or "download.txt"
  name = name:gsub("[^%w%._%-]", "_")
  if name == "" then name = "download.txt" end
  return name
end

local function defaultSettings()
  return {
    home = "mint://home",
    search = "https://duckduckgo.com/html/?q=",
    showBookmarks = true,
    cookies = true,
    cache = true,
    maxRedirects = 5,
    userAgent = "MintCraft Browser/1.0",
    downloadDir = "/home/user/downloads",
    autoCraftTube = false,
  }
end

local function newTab(url)
  return {
    id = tostring(os.clock()) .. "-" .. tostring(math.random(1000, 9999)),
    title = "New Tab",
    url = url or "mint://home",
    history = {},
    historyIndex = 0,
    scroll = 1,
    page = nil,
    loading = false,
    private = false,
  }
end

local function classifyError(err)
  local text = tostring(err or ""):lower()
  if text:find("http api disabled", 1, true) then return "BRW-001" end
  if text:find("permission", 1, true) or text:find("blocked", 1, true) then return "BRW-003" end
  if text:find("redirect", 1, true) then return "BRW-004" end
  if text:find("empty url", 1, true) or text:find("invalid", 1, true) then return "BRW-005" end
  if text:find("cache", 1, true) then return "BRW-007" end
  if text:find("download", 1, true) or text:find("write", 1, true) then return "BRW-008" end
  if text:find("request failed", 1, true) or text:find("ssl", 1, true) or text:find("dns", 1, true) or text:find("timed", 1, true) or text:find("closed", 1, true) then return "BRW-002" end
  return "BRW-000"
end

function M.run(ctx)
  ensureDirs()
  local settings = config.load(SETTINGS, defaultSettings())
  for k, v in pairs(defaultSettings()) do if settings[k] == nil then settings[k] = v end end

  local app = {
    tabs = { newTab((ctx.args and ctx.args.url and ctx.args.url ~= "") and ctx.args.url or settings.home) },
    active = 1,
    address = "",
    focusAddress = false,
    status = "Ready",
    keyboard = {},
    history = loadData(HISTORY, {}),
    bookmarks = loadData(BOOKMARKS, {
      { title = "GitHub", url = "https://github.com" },
      { title = "CraftTube", url = "mint://crafttube?q=" },
      { title = "YouTube", url = "https://youtube.com" },
      { title = "Docs", url = "https://tweaked.cc" },
    }),
    downloads = loadData(DOWNLOADS, {}),
    linkBoxes = {},
  }

  local function tab() return app.tabs[app.active] end

  local function saveAll()
    saveData(HISTORY, app.history)
    saveData(BOOKMARKS, app.bookmarks)
    saveData(DOWNLOADS, app.downloads)
    config.save(SETTINGS, settings)
  end

  local function errorPage(code, detail, url)
    code = code or classifyError(detail)
    local def = ERROR_DEFS[code] or ERROR_DEFS["BRW-000"]
    local lines = {
      "# " .. code .. " - " .. def.title,
      "",
      "What happened:",
      tostring(detail or def.title),
      "",
      "Meaning:",
      def.hint,
      "",
      "URL:",
      tostring(url or tab().url or "-"),
      "",
      "[1] Reload",
      "[2] Home",
      "[3] Open Network Settings",
    }
    return {
      title = code,
      lines = lines,
      links = {
        { index = 1, text = "Reload", url = tostring(url or tab().url or settings.home) },
        { index = 2, text = "Home", url = settings.home },
        { index = 3, text = "Settings", url = "mint://settings?network" },
      },
      status = 0,
      error = true,
      errorCode = code,
    }
  end

  local function homePage()
    local lines = {
      "# MintCraft Browser",
      "",
      "Search or enter address in the bar above.",
      "",
      "Quick links:",
    }
    local links = {}
    for i, b in ipairs(app.bookmarks) do
      table.insert(lines, "[" .. i .. "] " .. b.title .. "  " .. b.url)
      table.insert(links, { index = i, text = b.title, url = b.url })
    end
    table.insert(lines, "")
    table.insert(lines, "Recent:")
    for i = 1, math.min(5, #app.history) do
      local idx = #links + 1
      table.insert(lines, "[" .. idx .. "] " .. app.history[i].title .. "  " .. app.history[i].url)
      table.insert(links, { index = idx, text = app.history[i].title, url = app.history[i].url })
    end
    table.insert(lines, "")
    table.insert(lines, "Downloads:")
    for i = 1, math.min(3, #app.downloads) do table.insert(lines, "- " .. app.downloads[i].filename .. "  " .. app.downloads[i].status) end
    return { title = "New Tab", lines = lines, links = links, status = 200 }
  end

  local function addHistory(t, page)
    if t.private or not page then return end
    table.insert(app.history, 1, { url = t.url, title = page.title or t.url, timestamp = now(), status = page.status or 0 })
    while #app.history > 80 do table.remove(app.history) end
    saveData(HISTORY, app.history)
  end

  local function headersFor(url, previous)
    return {
      ["User-Agent"] = settings.userAgent,
      ["Accept"] = "text/html,application/json,text/plain,*/*",
      ["Accept-Language"] = "fr-FR,fr;q=0.9,en;q=0.8",
      ["Referer"] = previous or "",
    }
  end

  local function openCraftTube(query)
    query = tostring(query or "")
    if query == "" then query = youtubeQuery(tab().url) end
    if query == "" and app.address ~= "" then query = app.address end
    local ok, err = ctx.apps.launch("crafttube", { query = query })
    if ok then
      app.status = query ~= "" and ("CraftTube search: " .. query) or "CraftTube opened"
    else
      app.status = tostring(err)
    end
  end

  local function loadUrl(url, addToHistory)
    local t = tab()
    url = normalizeAddress(url, settings.search)
    if url:match("^mint://crafttube") then
      local query = queryParam(url, "q")
      t.url = url
      t.title = "CraftTube"
      t.page = {
        title = "CraftTube",
        lines = {
          "# CraftTube",
          "",
          "YouTube runs inside MintCraft Browser through CraftTube.",
          "Search and audio playback use the configured CraftTube proxies.",
          "",
          "[1] Open CraftTube",
        },
        links = { { index = 1, text = "Open CraftTube", url = url } },
        status = 200,
      }
      openCraftTube(query)
      return
    end
    if isYouTube(url) then
      t.url = url
      t.title = "YouTube"
      t.page = {
        title = "BRW-006",
        lines = {
          "# BRW-006 - YouTube routed",
          "",
          ERROR_DEFS["BRW-006"].hint,
          "",
          "Reason:",
          "YouTube requires JavaScript and media codecs that CC:Tweaked does not provide.",
          "",
          "[1] Open in CraftTube",
        },
        links = { { index = 1, text = "Open in CraftTube", url = "mint://crafttube?q=" .. youtubeQuery(url) } },
        status = 200,
      }
      openCraftTube(youtubeQuery(url))
      return
    end
    if url == "mint://home" then
      t.url = url
      t.page = homePage()
      t.title = t.page.title
      return
    end
    if url == "mint://history" then
      local lines = { "# History", "" }
      for i, h in ipairs(app.history) do table.insert(lines, "[" .. i .. "] " .. h.title .. "  " .. h.url) end
      t.url = url
      t.page = { title = "History", lines = lines, links = {}, status = 200 }
      t.title = "History"
      return
    end

    local allowed, denied = ctx.security.require("network.http", url)
    if not allowed then
      t.page = errorPage("BRW-003", denied, url)
      t.title = t.page.title
      app.status = "BRW-003 " .. tostring(denied)
      return
    end

    local previous = t.url
    local current = url
    local response, err
    for redirects = 0, settings.maxRedirects do
      app.status = "Loading " .. current
      local cachePath = CACHE .. "/" .. cacheKey(current) .. ".html"
      if settings.cache and fs.exists(cachePath) then
        response = { url = current, code = 200, body = readFile(cachePath) or "", headers = {}, size = fs.getSize(cachePath) }
      else
        response, err = httpClient.get(current, { headers = headersFor(current, previous) })
      end
      if not response then
        local code = classifyError(err)
        t.page = errorPage(code, tostring(err), current)
        t.title = t.page.title
        app.status = code .. " " .. tostring(err)
        log.warn("browser", code .. " " .. tostring(err) .. " url=" .. tostring(current))
        return
      end
      local location = response.headers and (response.headers.Location or response.headers.location)
      if REDIRECTS[response.code] and location then
        current = resolveUrl(current, location)
      else
        break
      end
      if redirects == settings.maxRedirects then
        t.page = errorPage("BRW-004", "Redirect limit reached", current)
        t.title = t.page.title
        app.status = "BRW-004 redirect limit"
        return
      end
    end

    if settings.cache and response and response.code == 200 then
      writeFile(CACHE .. "/" .. cacheKey(current) .. ".html", response.body)
    end
    local page = parseHtml(response.body, response.url or current, app.lastW or 60)
    page.status = response.code
    t.url = response.url or current
    t.page = page
    t.title = page.title
    t.scroll = 1
    app.status = tostring(response.code) .. " " .. tostring(response.size) .. " bytes"
    if addToHistory ~= false then
      while #t.history > t.historyIndex do table.remove(t.history) end
      table.insert(t.history, t.url)
      t.historyIndex = #t.history
      addHistory(t, page)
    end
  end

  local function submitAddress()
    loadUrl(app.address ~= "" and app.address or tab().url, true)
    app.focusAddress = false
  end

  local function goHistory(delta)
    local t = tab()
    local nextIndex = t.historyIndex + delta
    if nextIndex >= 1 and nextIndex <= #t.history then
      t.historyIndex = nextIndex
      loadUrl(t.history[t.historyIndex], false)
    end
  end

  local function addBookmark()
    local t = tab()
    table.insert(app.bookmarks, { title = t.title or t.url, url = t.url, folder = "Bar", createdAt = now() })
    saveData(BOOKMARKS, app.bookmarks)
    app.status = "Bookmark added"
  end

  local function download(url)
    url = url or tab().url
    local allowed, denied = ctx.security.require("network.http", url)
    if not allowed then app.status = "BRW-003 " .. tostring(denied) return end
    local response, err = httpClient.get(url, { headers = headersFor(url, tab().url) })
    if not response then app.status = classifyError(err) .. " " .. tostring(err) return end
    local filename = filenameFromUrl(url)
    local path = fs.combine(settings.downloadDir, filename)
    writeFile(path, response.body)
    table.insert(app.downloads, 1, { url = url, filename = filename, path = path, status = "done", received = response.size, startedAt = now() })
    saveData(DOWNLOADS, app.downloads)
    app.status = "Downloaded " .. filename
  end

  local function openLink(link)
    if not link then return end
    if tostring(link.url):match("^mint://crafttube") then
      openCraftTube(queryParam(link.url, "q"))
    elseif tostring(link.url):match("^mint://settings") then
      ctx.apps.launch("settings")
    else
      loadUrl(link.url, true)
    end
  end

  app.keyboard.onText = function(ch) app.address = app.address .. ch end
  app.keyboard.onBackspace = function() app.address = app.address:sub(1, -2) end
  app.keyboard.onEnter = submitAddress

  function app:draw(w, h)
    self.lastW = w
    local t = tab()
    self.linkBoxes = {}
    renderer.fill(1, 1, w, 1, colors.gray)
    local x = 1
    for i, item in ipairs(self.tabs) do
      local label = (i == self.active and "[" or " ") .. renderer.crop(item.title or "Tab", 10):gsub("%s+$", "") .. (i == self.active and "]" or " ")
      renderer.writeAt(x, 1, renderer.crop(label, math.min(12, w - x + 1)), colors.white, i == self.active and colors.blue or colors.gray)
      item.tabX, item.tabW = x, math.min(12, #label)
      x = x + item.tabW + 1
      if x > w - 3 then break end
    end
    renderer.writeAt(math.max(1, w - 2), 1, "+", colors.black, colors.lime)

    renderer.fill(1, 2, w, 1, colors.lightGray)
    renderer.writeAt(1, 2, "<", colors.black, colors.lightGray)
    renderer.writeAt(3, 2, ">", colors.black, colors.lightGray)
    renderer.writeAt(5, 2, "R", colors.black, colors.lightGray)
    renderer.writeAt(7, 2, "H", colors.black, colors.lightGray)
    renderer.writeAt(9, 2, "*", colors.black, colors.lightGray)
    renderer.writeAt(11, 2, "D", colors.black, colors.lightGray)
    renderer.writeAt(13, 2, "YT", colors.white, colors.red)
    local addr = self.focusAddress and self.address or t.url
    renderer.writeAt(16, 2, renderer.crop(addr, math.max(1, w - 15)), colors.black, colors.white)

    local y = 3
    if settings.showBookmarks then
      renderer.fill(1, y, w, 1, colors.gray)
      local bx = 1
      for i, b in ipairs(self.bookmarks) do
        local label = renderer.crop(b.title, 10):gsub("%s+$", "")
        renderer.writeAt(bx, y, "[" .. label .. "]", colors.white, colors.gray)
        b.x, b.y, b.w = bx, y, #label + 2
        bx = bx + b.w + 1
        if bx > w - 8 then break end
      end
      y = y + 1
    end

    local page = t.page or homePage()
    local kbH = self.focusAddress and keyboard.height() or 0
    local pageH = math.max(1, h - y - 1 - kbH)
    for i = 1, pageH do
      local lineIndex = t.scroll + i - 1
      local line = page.lines[lineIndex] or ""
      local fg = line:match("^#") and colors.blue or colors.black
      if line:match("%[%d+%]") then fg = colors.blue end
      renderer.writeAt(1, y + i - 1, renderer.crop(line, w), fg, colors.lightGray)
      for _, link in ipairs(page.links or {}) do
        if line:find("%[" .. tostring(link.index) .. "%]", 1, false) then
          table.insert(self.linkBoxes, { x = 1, y = y + i - 1, w = w, link = link })
        end
      end
    end
    renderer.writeAt(1, h - kbH, renderer.crop("Status: " .. self.status, w), colors.white, colors.gray)
    if self.focusAddress then
      self.keyboard.x = 1
      self.keyboard.y = h - kbH + 1
      self.keyboard.hint = "Address/Search"
      keyboard.draw(1, self.keyboard.y, w, self.keyboard)
    end
  end

  function app:handle(event)
    local t = tab()
    if event.name == "mouse_scroll" then
      t.scroll = math.max(1, t.scroll + event.args[1])
      return true
    elseif event.name == "char" and self.focusAddress then
      self.address = self.address .. event.args[1]
      return true
    elseif event.name == "key" and self.focusAddress then
      local key = event.args[1]
      if key == keys.backspace then self.address = self.address:sub(1, -2) return true end
      if key == keys.enter then submitAddress() return true end
    elseif event.name == "mouse_click" then
      local _, x, y = table.unpack(event.args)
      if self.focusAddress and event.monitorTouch and keyboard.handle(event, self.keyboard) then return true end
      if y == 1 then
        if x >= self.lastW - 2 then table.insert(self.tabs, newTab(settings.home)) self.active = #self.tabs loadUrl(settings.home, false) return true end
        for i, item in ipairs(self.tabs) do
          if item.tabX and x >= item.tabX and x < item.tabX + item.tabW then self.active = i return true end
        end
      elseif y == 2 then
        if x == 1 then goHistory(-1) return true end
        if x == 3 then goHistory(1) return true end
        if x == 5 then loadUrl(t.url, false) return true end
        if x == 7 then loadUrl(settings.home, true) return true end
        if x == 9 then addBookmark() return true end
        if x == 11 then download(t.url) return true end
        if x == 13 or x == 14 then openCraftTube(youtubeQuery(t.url)) return true end
        if x >= 16 then self.focusAddress = true self.address = t.url return true end
      elseif settings.showBookmarks and y == 3 then
        for _, b in ipairs(self.bookmarks) do
          if b.x and x >= b.x and x < b.x + b.w then loadUrl(b.url, true) return true end
        end
      end
      for _, box in ipairs(self.linkBoxes or {}) do
        if y == box.y and x >= box.x and x < box.x + box.w then openLink(box.link) return true end
      end
    end
    return false
  end

  loadUrl(tab().url, false)
  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Browser", w = math.min(82, sw - 4), h = math.min(26, sh - 3), x = 5, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
