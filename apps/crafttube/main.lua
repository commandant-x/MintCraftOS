local renderer = require("system.gui.renderer")
local keyboard = require("system.gui.keyboard")
local ui = require("system.gui.components")
local config = require("system.libraries.config")
local httpClient = require("system.network.http_client")
local audiod = require("system.services.audiod")

local M = {}

local cfgPath = "/system/config/crafttube.cfg"
local dataPath = "/home/user/config/crafttube.db"

local defaultCfg = {
  provider = "invidious",
  proxy = "https://inv.thepixora.com",
  searchPath = "/api/v1/search?type=video&q=",
  detailsPath = "/api/v1/videos/",
  audioProxy = "",
  audioPath = "/crafttube/audio?id=",
  fallbackProxies = {
    "https://yt.chocolatemoo53.com",
    "https://invidious.f5.si",
  },
}

local function urlEncode(text)
  text = tostring(text or "")
  text = text:gsub("\n", "\r\n")
  text = text:gsub("([^%w%-%_%.%~ ])", function(ch)
    return string.format("%%%02X", string.byte(ch))
  end)
  return text:gsub(" ", "+")
end

local function loadCfg()
  local cfg = config.load(cfgPath, {})
  for key, value in pairs(defaultCfg) do
    if cfg[key] == nil or cfg[key] == "" then cfg[key] = value end
  end
  return cfg
end

local function saveCfg(cfg)
  return config.save(cfgPath, cfg)
end

local function loadData()
  return config.load(dataPath, { favorites = {}, history = {} })
end

local function saveData(data)
  return config.save(dataPath, data)
end

local function normalizeVideo(raw)
  if type(raw) ~= "table" then return nil end
  local id = raw.id
  if type(id) == "table" then id = id.videoId or id.id end
  id = raw.videoId or raw.video_id or id
  local title = raw.title or raw.name or (raw.snippet and raw.snippet.title)
  if not id and raw.url then id = tostring(raw.url):match("[?&]v=([%w%-_]+)") or tostring(raw.url):match("youtu%.be/([%w%-_]+)") end
  if not title or title == "" then title = id or "Untitled" end
  local duration = raw.duration or raw.length or raw.lengthText
  if not duration and raw.lengthSeconds then
    local seconds = tonumber(raw.lengthSeconds) or 0
    duration = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
  end
  return {
    id = tostring(id or title),
    title = tostring(title),
    channel = tostring(raw.channel or raw.channelTitle or raw.author or (raw.snippet and raw.snippet.channelTitle) or "-"),
    description = tostring(raw.description or (raw.snippet and raw.snippet.description) or ""),
    duration = tostring(duration or "-"),
    views = tostring(raw.viewCountText or raw.views or raw.viewCount or "-"),
    published = tostring(raw.publishedText or raw.published or ""),
    url = tostring(raw.url or ("https://www.youtube.com/watch?v=" .. tostring(id or ""))),
  }
end

local function listFromJson(json)
  local source = json and (json.items or json.results or json.videos or json)
  local out = {}
  if type(source) == "table" then
    for _, item in ipairs(source) do
      local video = normalizeVideo(item)
      if video then table.insert(out, video) end
    end
  end
  return out
end

local function findById(rows, id)
  for _, item in ipairs(rows or {}) do
    if item.id == id then return item end
  end
  return nil
end

local function addUnique(list, item)
  for i = #list, 1, -1 do
    if list[i].id == item.id then table.remove(list, i) end
  end
  table.insert(list, 1, item)
  while #list > 30 do table.remove(list) end
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
    cfg = loadCfg(),
    data = loadData(),
    mode = "search",
    input = (ctx.args and ctx.args.query) or "",
    status = "Configure proxy in Settings or paste it here.",
    selected = nil,
    rows = {},
    scroll = 1,
    keyboard = {},
  }

  local actions = {
    { id = "search", label = "Search" },
    { id = "play", label = "Play" },
    { id = "proxy", label = "Proxy" },
    { id = "audio", label = "Audio" },
    { id = "fav", label = "Fav" },
    { id = "history", label = "History" },
    { id = "details", label = "Details" },
  }

  local function selectedVideo()
    return findById(app.rows, app.selected)
  end

  local function replaceSelected(video)
    for i, item in ipairs(app.rows) do
      if item.id == video.id then
        app.rows[i] = video
        return
      end
    end
  end

  local function showRows(rows, status)
    app.rows = rows or {}
    app.scroll = 1
    app.selected = app.rows[1] and app.rows[1].id or nil
    app.status = status or tostring(#app.rows) .. " results"
  end

  local function searchWithProxy(proxy)
    local url = proxy .. app.cfg.searchPath .. urlEncode(app.input)
    local allowed, denied = ctx.security.require("network.http", url)
    if not allowed then return nil, denied end
    local response, err = httpClient.json(url)
    if not response then return nil, err end
    return listFromJson(response.json)
  end

  local function search()
    app.mode = "search"
    if app.input == "" then app.status = "Enter search text" return end
    if not app.cfg.proxy or app.cfg.proxy == "" then
      app.cfg.proxy = defaultCfg.proxy
      saveCfg(app.cfg)
    end
    local proxies = { app.cfg.proxy }
    for _, proxy in ipairs(app.cfg.fallbackProxies or {}) do table.insert(proxies, proxy) end
    app.status = "Searching..."
    local lastErr
    for _, proxy in ipairs(proxies) do
      local rows, err = searchWithProxy(proxy)
      if rows and #rows > 0 then
        app.cfg.proxy = proxy
        saveCfg(app.cfg)
        showRows(rows, "Search complete via " .. proxy)
        return
      end
      lastErr = err or "no results"
    end
    app.status = tostring(lastErr or "no results")
  end

  local function toggleFavorite()
    local video = selectedVideo()
    if not video then app.status = "No video selected" return end
    addUnique(app.data.favorites, video)
    saveData(app.data)
    app.status = "Favorite saved"
  end

  local function openVideo()
    local video = selectedVideo()
    if not video then app.status = "No video selected" return end
    if app.cfg.proxy and app.cfg.proxy ~= "" and app.cfg.detailsPath and app.cfg.detailsPath ~= "" then
      local detailsUrl = app.cfg.proxy .. app.cfg.detailsPath .. urlEncode(video.id)
      local allowed = ctx.security.require("network.http", detailsUrl)
      if not allowed then return end
      local response = httpClient.json(detailsUrl)
      if response and response.json then
        local detail = normalizeVideo(response.json.video or response.json.item or response.json)
        if detail then
          video = detail
          replaceSelected(video)
        end
      end
    end
    addUnique(app.data.history, video)
    saveData(app.data)
    app.status = "Opened details"
  end

  local function playSelected()
    local video = selectedVideo()
    if not video then app.status = "No video selected" return end
    if not app.cfg.audioProxy or app.cfg.audioProxy == "" then
      app.status = "Audio needs a DFPWM proxy in Audio mode"
      return
    end
    local base = app.cfg.audioProxy:gsub("/+$", "")
    local audioPath = app.cfg.audioPath or defaultCfg.audioPath
    local url = base .. audioPath .. urlEncode(video.id)
    local allowed, denied = ctx.security.require("network.http", url)
    if not allowed then app.status = denied return end
    app.status = "Downloading DFPWM audio..."
    local response, err = httpClient.get(url, { binary = true })
    if not response then app.status = tostring(err) return end
    if not fs.exists("/var/tmp") then fs.makeDir("/var/tmp") end
    local path = "/var/tmp/crafttube_audio.dfpwm"
    local handle = fs.open(path, "wb")
    if not handle then app.status = "Cannot write audio temp file" return end
    handle.write(response.body)
    handle.close()
    local ok, playErr = audiod.playDfPWM(path)
    app.status = ok and ("Playing " .. video.title) or tostring(playErr)
  end

  local function saveProxy()
    if app.input ~= "" then
      if app.mode == "audio" then
        app.cfg.audioProxy = app.input:gsub("/+$", "")
        app.cfg.audioPath = app.cfg.audioPath or defaultCfg.audioPath
      else
        app.cfg.proxy = app.input:gsub("/+$", "")
        app.cfg.searchPath = app.cfg.searchPath or defaultCfg.searchPath
        app.cfg.detailsPath = app.cfg.detailsPath or defaultCfg.detailsPath
      end
      saveCfg(app.cfg)
      app.status = app.mode == "audio" and "Audio proxy saved" or "Proxy saved"
    end
  end

  app.keyboard.onText = function(ch) app.input = app.input .. ch end
  app.keyboard.onBackspace = function() app.input = app.input:sub(1, -2) end
  app.keyboard.onEnter = function()
    if app.mode == "proxy" or app.mode == "audio" then saveProxy() else search() end
  end

  function app:draw(w, h)
    self.toolbar = ui.toolbar(1, 1, w, actions)
    local kbH = keyboard.height()
    local selected = selectedVideo()
    local inputLabel = self.mode == "proxy" and "Proxy" or (self.mode == "audio" and "Audio proxy" or "Search")
    ui.input(1, 2, w, inputLabel, self.input, true)
    renderer.writeAt(1, 3, renderer.crop("Status: " .. self.status, w), colors.black, colors.lightGray)
    local cardH = 3
    local listH = math.max(1, h - kbH - 10)
    local visible = math.max(1, math.floor(listH / cardH))
    for i = 1, visible do
      local item = self.rows[self.scroll + i - 1]
      local y = 4 + (i - 1) * cardH
      if item then
        local bg = item.id == self.selected and colors.cyan or colors.lightGray
        renderer.writeAt(1, y, renderer.crop("[" .. tostring(self.scroll + i - 1) .. "] " .. item.title, w), colors.black, bg)
        renderer.writeAt(1, y + 1, renderer.crop("    " .. item.channel .. "   " .. item.duration .. "   " .. item.views, w), colors.gray, colors.lightGray)
        renderer.writeAt(1, y + 2, renderer.crop("    " .. item.url, w), colors.gray, colors.lightGray)
      else
        renderer.writeAt(1, y, renderer.crop("No result. Set a proxy, then search.", w), colors.gray, colors.lightGray)
      end
    end
    local detailY = 4 + visible * cardH
    if selected then
      renderer.writeAt(1, detailY, renderer.crop("Selected: " .. selected.title, w), colors.white, colors.gray)
      renderer.writeAt(1, detailY + 1, renderer.crop(selected.channel .. "  " .. selected.duration .. "  " .. selected.views .. "  " .. selected.published, w), colors.black, colors.lightGray)
      local lines = splitLines(selected.description, w)
      renderer.writeAt(1, detailY + 2, renderer.crop(lines[1] or "", w), colors.gray, colors.lightGray)
      renderer.writeAt(1, detailY + 3, renderer.crop("Play requires DFPWM proxy: " .. tostring(self.cfg.audioProxy or "-"), w), colors.gray, colors.lightGray)
    else
      renderer.writeAt(1, detailY, renderer.crop("CraftTube is the YouTube app for MintCraft OS.", w), colors.white, colors.gray)
      renderer.writeAt(1, detailY + 1, renderer.crop("It needs a proxy/API because CC:Tweaked cannot run YouTube web UI.", w), colors.gray, colors.lightGray)
      renderer.writeAt(1, detailY + 2, renderer.crop("Default API: " .. tostring(self.cfg.proxy), w), colors.gray, colors.lightGray)
    end
    self.keyboard.x = 1
    self.keyboard.y = h - kbH + 1
    self.keyboard.hint = self.mode == "proxy" and "Proxy URL" or (self.mode == "audio" and "DFPWM audio proxy URL" or "Search")
    keyboard.draw(1, self.keyboard.y, w, self.keyboard)
  end

  function app:handle(event)
    if event.name == "mouse_scroll" then
      self.scroll = math.max(1, self.scroll + event.args[1])
      return true
    elseif event.name == "char" then
      self.input = self.input .. event.args[1]
      return true
    elseif event.name == "key" then
      local key = event.args[1]
      if key == keys.backspace then self.input = self.input:sub(1, -2) return true end
      if key == keys.enter then self.keyboard.onEnter() return true end
    elseif event.name == "mouse_click" then
      local _, x, y = table.unpack(event.args)
      if event.monitorTouch and keyboard.handle(event, self.keyboard) then return true end
      local action = ui.toolbarHit(self.toolbar, x, y)
      if action == "search" then self.mode = "search" search() return true end
      if action == "play" then playSelected() return true end
      if action == "proxy" then self.mode = "proxy" self.input = self.cfg.proxy or "" return true end
      if action == "audio" then self.mode = "audio" self.input = self.cfg.audioProxy or "" return true end
      if action == "fav" then toggleFavorite() return true end
      if action == "history" then showRows(self.data.history, "History") return true end
      if action == "details" then
        local video = selectedVideo()
        if video then openVideo() end
        return true
      end
      if y >= 4 then
        local item = self.rows[self.scroll + math.floor((y - 4) / 3)]
        if item then self.selected = item.id openVideo() return true end
      end
    end
    return false
  end

  showRows(app.data.favorites, "Favorites")
  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "CraftTube", w = math.min(78, sw - 4), h = math.min(24, sh - 3), x = 4, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
