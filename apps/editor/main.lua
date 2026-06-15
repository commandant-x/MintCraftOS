local renderer = require("system.gui.renderer")
local keyboard = require("system.gui.keyboard")

local M = {}

local snippets = {
  ["for"] = "for i = 1, n do\n  \nend",
  ["if"] = "if condition then\n  \nend",
  ["function"] = "function name(args)\n  \nend",
  ["local"] = "local name = value",
  ["while"] = "while condition do\n  \nend",
  ["repeat"] = "repeat\n  \n until condition",
  ["print"] = "print(\"\")",
  ["require"] = "local mod = require(\"module\")",
}

local words = {
  "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
  "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
  "true", "until", "while", "pairs", "ipairs", "pcall", "print", "require",
  "table.insert", "string.sub", "term.setCursorPos", "fs.open", "fs.exists",
  "os.pullEvent", "peripheral.find", "rednet.open", "http.get", "window.create",
}

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
  local left = line:sub(1, col - 1)
  return left:match("([%w_%.]+)$") or ""
end

local function suggestion(prefix)
  if prefix == "" then return nil end
  for key in pairs(snippets) do
    if key:sub(1, #prefix) == prefix then return key, snippets[key] end
  end
  for _, word in ipairs(words) do
    if word:sub(1, #prefix) == prefix then return word, word end
  end
  return nil
end

local function collectModules()
  local roots = { "/system", "/apps" }
  local rows = {}
  local function walk(path)
    if not fs.exists(path) then return end
    for _, name in ipairs(fs.list(path)) do
      local full = fs.combine(path, name)
      if fs.isDir(full) then
        walk(full)
      elseif name:match("%.lua$") then
        local mod = full:gsub("^/", ""):gsub("%.lua$", ""):gsub("/", ".")
        table.insert(rows, mod)
      end
    end
  end
  for _, root in ipairs(roots) do walk(root) end
  table.sort(rows)
  return rows
end

local function collectLocalWords(lines)
  local found = {}
  for _, line in ipairs(lines) do
    local name = line:match("^%s*local%s+function%s+([%w_]+)")
    if name then found[name] = true end
    name = line:match("^%s*function%s+([%w_%.]+)")
    if name then found[name] = true end
    for localName in line:gmatch("local%s+([%w_]+)") do found[localName] = true end
  end
  local rows = {}
  for name in pairs(found) do table.insert(rows, name) end
  table.sort(rows)
  return rows
end

local function insertText(app, text)
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
  local tmp = "/var/tmp/editor_compile.lua"
  writeFile(tmp, app.lines)
  local fn, err = loadfile(tmp)
  if fn then app.status = "Compile OK" else app.status = tostring(err) end
end

function M.run(ctx)
  local app = {
    path = ctx.args.path or "/home/user/documents/untitled.lua",
    lines = readFile(ctx.args.path),
    cx = 1,
    cy = 1,
    scroll = 1,
    status = "Editor ready",
    caps = false,
    shift = false,
    keyboard = {},
  }

  local function visibleHeight(h)
    return math.max(4, h - 8)
  end

  local function applySuggestion()
    local line = app.lines[app.cy]
    local prefix = currentPrefix(line, app.cx)
    local label, text = suggestion(prefix)
    if not text then
      for _, word in ipairs(collectLocalWords(app.lines)) do
        if word:sub(1, #prefix) == prefix and word ~= prefix then
          label, text = word, word
          break
        end
      end
    end
    if not text then
      for _, mod in ipairs(collectModules()) do
        if mod:sub(1, #prefix) == prefix then label, text = mod, mod break end
      end
    end
    if not text then return false end
    app.lines[app.cy] = line:sub(1, app.cx - #prefix - 1) .. line:sub(app.cx)
    app.cx = app.cx - #prefix
    insertText(app, text)
    app.status = "Inserted " .. label
    return true
  end

  app.keyboard.onText = function(ch) insertText(app, ch) end
  app.keyboard.onBackspace = function()
    local line = app.lines[app.cy]
    if app.cx > 1 then
      app.lines[app.cy] = line:sub(1, app.cx - 2) .. line:sub(app.cx)
      app.cx = app.cx - 1
    end
  end
  app.keyboard.onEnter = function() insertText(app, "\n") end
  app.keyboard.onTab = applySuggestion

  function app:draw(w, h)
    local prefix = currentPrefix(self.lines[self.cy] or "", self.cx)
    local sug = suggestion(prefix)
    renderer.writeAt(1, 1, renderer.crop("[Save] [Compile] " .. self.path, w), colors.white, colors.gray)
    local maxLines = math.max(4, h - keyboard.height() - 3)
    if self.cy < self.scroll then self.scroll = self.cy end
    if self.cy >= self.scroll + maxLines then self.scroll = self.cy - maxLines + 1 end
    for row = 1, maxLines do
      local lineNo = self.scroll + row - 1
      local text = self.lines[lineNo] or ""
      local marker = lineNo == self.cy and ">" or " "
      renderer.writeAt(1, row + 1, renderer.crop(marker .. tostring(lineNo) .. " " .. text, w), colors.black, colors.lightGray)
    end
    renderer.writeAt(1, h - 5, renderer.crop(self.status, w), colors.white, colors.gray)
    local locals = collectLocalWords(self.lines)
    if not sug then
      local prefix2 = currentPrefix(self.lines[self.cy] or "", self.cx)
      for _, word in ipairs(locals) do if word:sub(1, #prefix2) == prefix2 and word ~= prefix2 then sug = word break end end
      if not sug then
        for _, mod in ipairs(collectModules()) do if mod:sub(1, #prefix2) == prefix2 then sug = mod break end end
      end
    end
    if sug then renderer.writeAt(1, h - keyboard.height(), renderer.crop("Tab: " .. sug, w), colors.black, colors.orange) end
    self.keyboard.x = 1
    self.keyboard.y = h - keyboard.height() + 1
    self.keyboard.hint = sug and ("Tab: " .. sug) or ""
    keyboard.draw(1, self.keyboard.y, w, self.keyboard)
  end

  function app:handle(event)
    if event.name == "char" then
      insertText(self, event.args[1])
      return true
    elseif event.name == "key" then
      local key = event.args[1]
      if key == keys.tab then return applySuggestion()
      elseif key == keys.enter then insertText(self, "\n") return true
      elseif key == keys.backspace then
        local line = self.lines[self.cy]
        if self.cx > 1 then
          self.lines[self.cy] = line:sub(1, self.cx - 2) .. line:sub(self.cx)
          self.cx = self.cx - 1
        end
        return true
      elseif key == keys.up then self.cy = math.max(1, self.cy - 1) return true
      elseif key == keys.down then self.cy = math.min(#self.lines, self.cy + 1) return true
      elseif key == keys.left then self.cx = math.max(1, self.cx - 1) return true
      elseif key == keys.right then self.cx = self.cx + 1 return true
      end
    elseif event.name == "mouse_click" then
      local _, x, y = table.unpack(event.args)
      if y == 1 and x <= 6 then
        if writeFile(self.path, self.lines) then self.status = "Saved" else self.status = "Save failed" end
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
