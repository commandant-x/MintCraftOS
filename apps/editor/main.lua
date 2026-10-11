local renderer = require("system.gui.renderer")
local keyboard = require("system.gui.keyboard")
local autocomplete = require("system.dev.autocomplete")
local safeWrite = require("system.libraries.safe_write")

local M = {}

local function splitLines(text)
  local lines = {}
  text = text or ""
  for line in (text .. "\n"):gmatch("(.-)\n") do table.insert(lines, line) end
  if #lines == 0 then table.insert(lines, "") end
  return lines
end

local function readFile(path)
  if path and fs.exists(path) then
    local h = fs.open(path, "r")
    local text = h.readAll() or ""
    h.close()
    return splitLines(text)
  end
  return { "-- MintCraft Lua file", "" }
end

local function writeFile(path, lines)
  local h = fs.open(path, "w")
  if not h then return false end
  h.write(table.concat(lines, "\n"))
  h.close()
  return true
end

local function currentPrefix(line, col)
  return autocomplete.prefix(line, col, "([%w_%.]+)$")
end

local function insertText(app, text)
  app.revision = app.revision + 1
  local line = app.lines[app.cy]
  local before = line:sub(1, app.cx - 1)
  local after = line:sub(app.cx)
  local insertLines = splitLines(text)
  if #insertLines == 1 then
    app.lines[app.cy] = before .. insertLines[1] .. after
    app.cx = app.cx + #insertLines[1]
  else
    app.lines[app.cy] = before .. insertLines[1]
    for i = 2, #insertLines do
      table.insert(app.lines, app.cy + i - 1, insertLines[i])
    end
    app.cy = app.cy + #insertLines - 1
    app.cx = #insertLines[#insertLines] + 1
    app.lines[app.cy] = app.lines[app.cy] .. after
  end
end

local function compile(app)
  local tmp = "/var/tmp/editor_compile_" .. tostring(app.pid) .. ".lua"
  local ok, result = pcall(function()
    if not writeFile(tmp, app.lines) then return "Compile failed: cannot write temporary file" end
    local fn, err = loadfile(tmp)
    return fn and "Compile OK" or tostring(err)
  end)
  pcall(fs.delete, tmp)
  app.status = ok and result or ("Compile failed: " .. tostring(result))
end

function M.run(ctx)
  local app = {
    pid = ctx.pid or 0,
    path = ctx.args.path or "/home/user/documents/untitled.lua",
    lines = readFile(ctx.args.path),
    cx = 1,
    cy = 1,
    scroll = 1,
    status = "Editor ready",
    caps = false,
    shift = false,
    keyboard = {},
    revision = 0,
  }

  local function visibleHeight(h)
    return math.max(0, h - keyboard.height() - 3)
  end

  local function save()
    local ok, message = safeWrite.write(app.path, table.concat(app.lines, "\n"))
    app.status = ok and message or ("Save failed: " .. tostring(message))
  end

  local completionCache
  local function suggestion()
    local prefix = currentPrefix(app.lines[app.cy] or "", app.cx)
    local now = os.clock()
    if not completionCache or completionCache.lines ~= app.lines or completionCache.prefix ~= prefix
      or completionCache.revision ~= app.revision or now - completionCache.time >= 5 then
      completionCache = { lines = app.lines, prefix = prefix, revision = app.revision, time = now,
        value = autocomplete.suggest({ mode = "editor", prefix = prefix, lines = app.lines, revision = app.revision }) }
    end
    return completionCache.value, prefix
  end

  local function applySuggestion()
    local line = app.lines[app.cy]
    local sug, prefix = suggestion()
    if not sug then return false end
    local replaced, cursor = autocomplete.apply(line, app.cx, sug, prefix)
    local row = app.cy
    local replacement = splitLines(replaced)
    app.lines[row] = replacement[1]
    for i = 2, #replacement do table.insert(app.lines, row + i - 1, replacement[i]) end
    local beforeCursor = splitLines(replaced:sub(1, cursor - 1))
    app.cy = row + #beforeCursor - 1
    app.cx = #beforeCursor[#beforeCursor] + 1
    app.status = "Inserted " .. sug.label
    app.revision = app.revision + 1
    return true
  end

  app.keyboard.onText = function(ch) insertText(app, ch) end
  app.keyboard.onBackspace = function()
    app.revision = app.revision + 1
    local line = app.lines[app.cy]
    if app.cx > 1 then
      app.lines[app.cy] = line:sub(1, app.cx - 2) .. line:sub(app.cx)
      app.cx = app.cx - 1
    elseif app.cy > 1 then
      local previous = app.lines[app.cy - 1]
      app.lines[app.cy - 1] = previous .. line
      table.remove(app.lines, app.cy)
      app.cy, app.cx = app.cy - 1, #previous + 1
    end
  end
  app.keyboard.onEnter = function() insertText(app, "\n") end
  app.keyboard.onTab = applySuggestion
  app.keyboard.onControl = function(ch)
    if ch == "s" then
      save()
    end
  end

  function app:draw(w, h)
    local sug = suggestion()
    renderer.writeAt(1, 1, renderer.crop("[Save] [Compile] " .. self.path, w), colors.white, colors.gray)
    local maxLines = math.max(0, h - keyboard.height() - 3)
    if self.cy < self.scroll then self.scroll = self.cy end
    if self.cy >= self.scroll + maxLines then self.scroll = self.cy - maxLines + 1 end
    for row = 1, maxLines do
      local lineNo = self.scroll + row - 1
      local text = self.lines[lineNo] or ""
      local marker = lineNo == self.cy and ">" or " "
      renderer.writeAt(1, row + 1, renderer.crop(marker .. tostring(lineNo) .. " " .. text, w), colors.black, colors.lightGray)
    end
    renderer.writeAt(1, h - keyboard.height() - 1, renderer.crop(self.status, w), colors.white, colors.gray)
    renderer.writeAt(1, h - keyboard.height(), renderer.crop(sug and ("Tab: " .. sug.label .. " [" .. sug.kind .. "]") or "", w), colors.black, colors.orange)
    self.keyboard.x = 1
    self.keyboard.y = h - keyboard.height() + 1
    self.keyboard.hint = sug and ("Tab: " .. sug.label) or ""
    keyboard.draw(1, self.keyboard.y, w, self.keyboard)
  end

  function app:handle(event)
    if event.name == "char" or event.name == "paste" then
      insertText(self, event.args[1])
      return true
    elseif event.name == "key" then
      local key = event.args[1]
      if key == keys.tab then return applySuggestion()
      elseif key == keys.enter then insertText(self, "\n") return true
      elseif key == keys.backspace then
        self.keyboard.onBackspace()
        return true
      elseif key == keys.up then
        self.cy = math.max(1, self.cy - 1)
        self.cx = math.min(self.cx, #self.lines[self.cy] + 1)
        return true
      elseif key == keys.down then
        self.cy = math.min(#self.lines, self.cy + 1)
        self.cx = math.min(self.cx, #self.lines[self.cy] + 1)
        return true
      elseif key == keys.left then self.cx = math.max(1, self.cx - 1) return true
      elseif key == keys.right then self.cx = math.min(#self.lines[self.cy] + 1, self.cx + 1) return true
      end
    elseif event.name == "mouse_click" then
      local _, x, y = table.unpack(event.args)
      if y == 1 and x <= 6 then
        save()
        return true
      elseif y == 1 and x >= 8 and x <= 16 then
        compile(self)
        return true
      elseif event.monitorTouch and keyboard.handle(event, self.keyboard) then
        return true
      else
        local vh = visibleHeight(self.lastH or 18)
        if y >= 2 and y < 2 + vh then
          self.cy = math.min(#self.lines, self.scroll + y - 2)
          self.cx = #(self.lines[self.cy] or "") + 1
          return true
        end
      end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Editor", w = math.min(78, sw - 4), h = math.min(26, sh - 3), x = 5, y = 3, app = app })
  local originalDraw = app.draw
  app.draw = function(self, w, h) self.lastH = h return originalDraw(self, w, h) end
  while not win.closed do ctx.pullEvent() end
end

return M
