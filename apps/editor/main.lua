local renderer = require("system.gui.renderer")
local keyboard = require("system.gui.keyboard")
local autocomplete = require("system.dev.autocomplete")
local safeWrite = require("system.libraries.safe_write")
local fileNames = require("system.libraries.file_names")
local theme = require("system.gui.theme")
local ui = require("system.gui.components")

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
    local h = assert(fs.open(path, "r"), "Cannot read " .. path)
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
  if app.persistDraft then app.persistDraft() end
end

local function compile(app, allowed)
  local prefix = "/var/tmp/editor_compile_" .. tostring(app.pid)
  local tmp, suffix = prefix .. ".lua", 0
  while fs.exists(tmp) do suffix = suffix + 1 tmp = prefix .. "_" .. tostring(suffix) .. ".lua" end
  allowed("filesystem.read", tmp)
  allowed("filesystem.write", tmp)
  local ok, result = pcall(function()
    if not writeFile(tmp, app.lines) then return "Compile failed: cannot write temporary file" end
    local fn, err = loadfile(tmp)
    return fn and "Compile OK" or tostring(err)
  end)
  pcall(fs.delete, tmp)
  app.status = ok and result or ("Compile failed: " .. tostring(result))
end

function M.run(ctx)
  local function allowed(permission, path)
    local ok, reason = ctx.security.require(permission, path)
    if not ok then error(reason or ("Permission denied: " .. permission), 0) end
  end
  local path = fileNames.absolute(ctx.args.path or "/home/user/documents/untitled.lua")
  local readOK, initial = pcall(function()
    allowed("filesystem.read", path)
    return readFile(ctx.args.path and path)
  end)
  local app = {
    pid = ctx.pid or 0,
    path = path,
    lines = readOK and initial or {""},
    cx = 1,
    cy = 1,
    scroll = 1,
    status = readOK and "Editor ready" or tostring(initial),
    caps = false,
    shift = false,
    keyboard = {},
    revision = 0,
    keyboardVisible = true,
  }
  local savedText = readOK and table.concat(app.lines, "\n") or nil
  local base
  if readOK then
    local ok, value = pcall(function()
      allowed("filesystem.read", path)
      return fs.exists(path) and table.concat(readFile(path), "\n") or false
    end)
    if ok then base = value end
  end
  local draftPath = "/home/user/.editor-drafts/" .. path:gsub(".", function(c) return string.format("%02x", c:byte()) end) .. ".draft"
  local draftBlocked = not readOK
  local draftSnapshot = false
  local function text() return table.concat(app.lines, "\n") end
  local function dirty() return savedText == nil or text() ~= savedText end
  local function draftAllowed()
    allowed("filesystem.read", draftPath)
    allowed("filesystem.write", draftPath)
  end
  local recovered, recoveryError = pcall(function()
    allowed("filesystem.read", draftPath)
    if not fs.exists(draftPath) then return end
    local h = assert(fs.open(draftPath, "r"), "Cannot read draft")
    local data = h.readAll()
    h.close()
    draftSnapshot = data
    local record = textutils.unserialize(data)
    if type(record) ~= "table" or record.path ~= path or type(record.text) ~= "string"
      or (type(record.base) ~= "string" and record.base ~= false) then error("Invalid recovery draft: " .. draftPath, 0) end
    if record.text ~= savedText then
      app.lines, base = splitLines(record.text), record.base
      app.status = "Recovered unsaved draft"
    end
  end)
  if not recovered then draftBlocked, app.status = true, tostring(recoveryError) end

  local function checkDraft()
    local current = false
    if fs.exists(draftPath) then
      local h = assert(fs.open(draftPath, "r"), "Cannot read draft")
      current = h.readAll()
      h.close()
    end
    if current ~= draftSnapshot then error("Recovery draft changed in another editor; retained", 0) end
  end

  app.persistDraft = function()
    if draftBlocked then return end
    local ok, problem = pcall(function()
      draftAllowed()
      checkDraft()
      if not dirty() then
        if fs.exists(draftPath) then fs.delete(draftPath) end
        draftSnapshot = false
        return
      end
      if base == nil then error("Original file unreadable; draft not replaced", 0) end
      local dir = fs.getDir(draftPath)
      if not fs.exists(dir) then fs.makeDir(dir) end
      local content = textutils.serialize({path=path, text=text(), base=base})
      local written, reason = safeWrite.write(draftPath, content)
      if not written then error(reason, 0) end
      draftSnapshot = content
    end)
    if not ok then app.status = "Draft recovery unavailable: " .. tostring(problem) end
  end

  local function clearDraft()
    if draftBlocked then return end
    draftAllowed()
    checkDraft()
    if fs.exists(draftPath) then fs.delete(draftPath) end
    draftSnapshot = false
  end

  local function keyboardHeight(h)
    return app.keyboardVisible and not app.closePrompt and h >= keyboard.height() + 5 and keyboard.height() or 0
  end

  local function visibleHeight(h)
    return math.max(0, h - keyboardHeight(h) - 3)
  end

  local function save()
    local ok, message = pcall(function()
      allowed("filesystem.read", path)
      allowed("filesystem.write", path)
      if fileNames.protected(path) then error("Protected path", 0) end
      local current = fs.exists(path) and table.concat(readFile(path), "\n") or false
      if base == nil or current ~= base then error("File changed on disk; original retained", 0) end
      local written, reason = safeWrite.write(path, text())
      if not written then error(reason, 0) end
      base, savedText = text(), text()
      local cleaned, problem = pcall(clearDraft)
      return cleaned and reason or (reason .. "; draft cleanup failed: " .. tostring(problem))
    end)
    app.status = ok and message or ("Save failed: " .. tostring(message))
    return ok
  end

  local closeWindow
  local closeBoxes, closeState = {}, {first=1}
  local toolbar, toolbarState = {}, {first=1}
  local actions = {{id="save",label="Save"},{id="compile",label="Compile"},{id="keyboard",label="Keyboard"}}
  local function closeChoice(choice)
    if choice == "cancel" then app.closePrompt, closeWindow = false, nil
    elseif choice == "save" then
      if save() then closeWindow.closed = true end
    elseif choice == "discard" then
      local ok, problem = pcall(clearDraft)
      if ok then closeWindow.closed = true else app.status = "Discard failed: " .. tostring(problem) end
    end
  end
  function app:canClose(win)
    if not dirty() then pcall(clearDraft) return true end
    self.persistDraft()
    self.closePrompt, closeWindow = true, win
    self.status = "Unsaved changes"
    if ctx.invalidate then ctx.invalidate() end
    return false
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
    app.persistDraft()
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
    app.persistDraft()
  end
  app.keyboard.onEnter = function() insertText(app, "\n") end
  app.keyboard.onTab = applySuggestion
  app.keyboard.onControl = function(ch)
    if ch == "s" then
      save()
    end
  end

  function app:draw(w, h)
    self.lastH = h
    if w < 1 or h < 1 then return end
    local sug = suggestion()
    if self.closePrompt then
      closeBoxes = ui.toolbar(1, 1, w, {{id="save",label="Save"},{id="discard",label="Discard"},{id="cancel",label="Cancel"}}, closeState)
    else
      toolbar = ui.toolbar(1, 1, w, actions, toolbarState)
    end
    local kbH = keyboardHeight(h)
    local maxLines = visibleHeight(h)
    if self.cy < self.scroll then self.scroll = self.cy end
    if maxLines > 0 and self.cy >= self.scroll + maxLines then self.scroll = self.cy - maxLines + 1 end
    for row = 1, maxLines do
      local lineNo = self.scroll + row - 1
      local text = self.lines[lineNo] or ""
      local marker = lineNo == self.cy and ">" or " "
      renderer.writeAt(1, row + 1, renderer.crop(marker .. tostring(lineNo) .. " " .. text, w), theme.get("windowFg"), theme.get("windowBg"))
    end
    if h - kbH - 1 >= 2 then renderer.writeAt(1, h - kbH - 1, renderer.crop(self.status .. (dirty() and " * " or " ") .. self.path, w), theme.get("buttonFg"), theme.get("buttonBg")) end
    if h - kbH >= 2 then renderer.writeAt(1, h - kbH, renderer.crop(sug and ("Tab: " .. sug.label .. " [" .. sug.kind .. "]") or "", w), theme.get("windowFg"), theme.get("warning")) end
    self.keyboard.x = 1
    self.keyboard.y = h - kbH + 1
    self.keyboard.hint = sug and ("Tab: " .. sug.label) or ""
    if kbH > 0 then keyboard.draw(1, self.keyboard.y, w, self.keyboard) else self.keyboard.boxes = {} end
  end

  function app:handle(event)
    if self.closePrompt then
      if event.name == "key" and event.args[1] == keys.escape then closeChoice("cancel") return true end
      if event.name == "mouse_click" and event.args[1] == 1 then
        for _, box in ipairs(closeBoxes) do
          if ui.hit(box, event.args[2], event.args[3]) then
            if box.delta then closeState.first = math.max(1, math.min(3, closeState.first + box.delta))
            else closeChoice(box.id) end
            break
          end
        end
      end
      return true
    end
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
      local action
      if y == 1 then
        for _, box in ipairs(toolbar) do
          if ui.hit(box, x, y) then
            if box.delta then toolbarState.first = math.max(1, math.min(#actions, toolbarState.first + box.delta)) return true end
            action = box.id
            break
          end
        end
      end
      if action == "save" then
        save()
        return true
      elseif action == "compile" then
        local ok, problem = pcall(function()
          allowed("dev.compile", path)
          allowed("filesystem.read", "/var/tmp")
          compile(self, allowed)
        end)
        if not ok then self.status = "Compile failed: " .. tostring(problem) end
        return true
      elseif action == "keyboard" then
        self.keyboardVisible = not self.keyboardVisible
        self.keyboard.boxes = {}
        return true
      elseif self.keyboardVisible and keyboardHeight(self.lastH or 18) > 0 and event.monitorTouch and keyboard.handle(event, self.keyboard) then
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
