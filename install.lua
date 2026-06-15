-- MintCraft OS V0.7.0 installer for CC:Tweaked
-- Install with: wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/main/install.lua
local files = {
  [".settings"] = [[{
  ["shell.allow_startup"] = true,
}
]],
  ["LICENSE"] = [[MIT License

Copyright (c) 2026 commandant-x

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]],
  ["README.md"] = [[# MintCraft OS

MintCraft OS is a CraftOS environment for CC:Tweaked 1.21.1 / NeoForge.

This repository currently contains the V0.7.0 base:

- bootloader, splash, recovery and panic handling
- persistent logs
- cooperative scheduler and process table
- event bus
- terminal renderer, themes and window manager
- desktop, taskbar, start menu, right-click context menu and stacked notifications
- monitor auto-display through `deviced`, tuned for a 4x3 block monitor minimum at text scale 0.5
- larger `.nfp` app icons with text fallback, searchable start menu and AZERTY touch keyboard
- shared GUI components for buttons, tabs, toolbars, lists, inputs and dialogs
- complete touch-first Files app with toolbar, open, create, rename and delete confirmation
- shared global AZERTY keyboard component reused by desktop search, Files, Terminal and Editor
- Editor app with Lua compile check and Tab autocomplete/snippets
- richer Settings pages for system, display, network and developer information
- GitHub Update app and boot-time update check through the `updated` service
- Task Manager with process list, disk usage, Lua memory usage and estimated CPU activity
- Terminal with file commands, process commands and touch autocomplete
- touch-first Files with trash support for user files
- Settings pages for system, display, desktop, network, storage, apps and developer information
- Services, Logs and Task Manager apps with touch controls
- HTTP/WebSocket network wrappers, `networkd` service and text Browser app

Not included yet: Store, CraftTube, users/permissions enforcement, audio and update rollback.

Install the repository contents at the root of a CC:Tweaked computer, then reboot or run:

```lua
shell.run("/boot.lua")
```

## Install From GitHub

On a CC:Tweaked computer with HTTP enabled:

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/main/install.lua
```

Then reboot:

```lua
reboot
```
]],
  ["VERSION"] = [[0.7.0
]],
  ["apps/browser/app.cfg"] = [[{
  id = "browser",
  name = "Browser",
  version = "0.7.0",
  main = "apps.browser.main",
  permissions = { "network.http" },
}
]],
  ["apps/browser/main.lua"] = [[local renderer = require("system.gui.renderer")
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
]],
  ["apps/devices/app.cfg"] = [[{
  id = "devices",
  name = "Devices",
  version = "0.7.0",
  main = "apps.devices.main",
  permissions = { "devices.list" },
}
]],
  ["apps/devices/main.lua"] = [[local renderer = require("system.gui.renderer")
local deviced = require("system.services.deviced")

local M = {}

function M.run(ctx)
  local app = {}

  function app:draw(w, h)
    renderer.writeAt(1, 1, renderer.crop("[Rescan] [Use monitor]", w), colors.white, colors.gray)
    local display = deviced.getDisplay()
    renderer.writeAt(1, 2, renderer.crop("Target: " .. tostring(display.target) .. " " .. tostring(display.width) .. "x" .. tostring(display.height), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 3, renderer.crop("Monitor: " .. tostring(display.monitorSide or "none") .. " scale " .. tostring(display.scale or "-"), w), colors.black, colors.lightGray)
    renderer.writeAt(1, 4, renderer.crop("Recommended: 4x3 blocks min, scale 0.5", w), colors.gray, colors.lightGray)
    renderer.writeAt(1, 6, renderer.crop("DEVICE          TYPE", w), colors.black, colors.lightGray)
    local rows = deviced.list()
    if #rows == 0 then
      renderer.writeAt(1, 8, renderer.crop("No peripheral detected", w), colors.gray, colors.lightGray)
    end
    for i = 1, math.min(#rows, h - 6) do
      local d = rows[i]
      renderer.writeAt(1, i + 6, renderer.crop(d.name .. "          " .. tostring(d.type), w), colors.black, colors.lightGray)
    end
  end

  function app:handle(event)
    if event.name == "mouse_click" then
      local _, x, y = table.unpack(event.args)
      if y == 1 and x <= 8 then
        deviced.refreshDisplay()
        ctx.notifications:push("success", "Devices", "Rescan complete", 3)
        return true
      elseif y == 1 and x >= 10 and x <= 22 then
        if deviced.refreshDisplay() then
          ctx.notifications:push("success", "Devices", "Monitor selected", 3)
        else
          ctx.notifications:push("warn", "Devices", "No monitor found", 3)
        end
        return true
      end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Devices", w = math.min(60, sw - 4), h = math.min(18, sh - 3), x = 4, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["apps/editor/app.cfg"] = [[{
  id = "editor",
  name = "Editor",
  version = "0.7.0",
  main = "apps.editor.main",
  permissions = { "filesystem.read", "filesystem.write", "dev.compile" },
}
]],
  ["apps/editor/main.lua"] = [[local renderer = require("system.gui.renderer")
local keyboard = require("system.gui.keyboard")
local autocomplete = require("system.dev.autocomplete")

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
    local sug = autocomplete.suggest({ mode = "editor", prefix = prefix, lines = app.lines })
    if not sug then return false end
    local replaced, cursor = autocomplete.apply(line, app.cx, sug, prefix)
    app.lines[app.cy] = replaced
    app.cx = cursor
    app.status = "Inserted " .. sug.label
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
    local sug = autocomplete.suggest({ mode = "editor", prefix = prefix, lines = self.lines })
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
    if sug then renderer.writeAt(1, h - keyboard.height(), renderer.crop("Tab: " .. sug.label .. " [" .. sug.kind .. "]", w), colors.black, colors.orange) end
    self.keyboard.x = 1
    self.keyboard.y = h - keyboard.height() + 1
    self.keyboard.hint = sug and ("Tab: " .. sug.label) or ""
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
]],
  ["apps/files/app.cfg"] = [[{
  id = "files",
  name = "Files",
  version = "0.7.0",
  main = "apps.files.main",
  permissions = { "filesystem.read", "filesystem.write" },
}
]],
  ["apps/files/main.lua"] = [[local renderer = require("system.gui.renderer")
local keyboard = require("system.gui.keyboard")
local config = require("system.libraries.config")
local ui = require("system.gui.components")

local M = {}

local function sortedList(path)
  local rows = {}
  if fs.exists(path) and fs.isDir(path) then
    for _, name in ipairs(fs.list(path)) do
      table.insert(rows, name)
    end
  end
  table.sort(rows, function(a, b)
    local ad = fs.isDir(fs.combine(path, a))
    local bd = fs.isDir(fs.combine(path, b))
    if ad ~= bd then return ad end
    return a:lower() < b:lower()
  end)
  return rows
end

local function parent(path)
  local dir = fs.getDir(path)
  if dir == "" then return "/" end
  return dir
end

local function basename(path)
  return fs.getName(path)
end

local function uniquePath(dir, prefix, ext)
  local i = 1
  local path
  repeat
    path = fs.combine(dir, prefix .. tostring(i) .. ext)
    i = i + 1
  until not fs.exists(path)
  return path
end

local function trashPath(path)
  local trash = "/home/user/.trash"
  if not fs.exists(trash) then fs.makeDir(trash) end
  local name = fs.getName(path)
  local candidate = fs.combine(trash, name)
  local i = 1
  while fs.exists(candidate) do
    candidate = fs.combine(trash, name .. "." .. tostring(i))
    i = i + 1
  end
  return candidate
end

local protected = {
  ["/system"] = true,
  ["/apps"] = true,
  ["/boot.lua"] = true,
  ["/startup.lua"] = true,
}

local function isProtected(path)
  if protected[path] then return true end
  return path:match("^/system/") or path:match("^/apps/")
end

local function extOf(path)
  return (path:match("%.([^%.]+)$") or ""):lower()
end

local function mimeApp(path)
  local db = config.load("/system/config/mime.db", {})
  return db[extOf(path)]
end

function M.run(ctx)
  local app = {
    path = ctx.args.path or "/home/user",
    selected = nil,
    scroll = 1,
    mode = nil,
    input = "",
    confirm = nil,
    keyboard = {},
  }

  local actions = {
    { label = "Back", id = "back" },
    { label = "Home", id = "home" },
    { label = "Up", id = "up" },
    { label = "New file", id = "new_file" },
    { label = "New dir", id = "new_dir" },
    { label = "Rename", id = "rename" },
    { label = "Delete", id = "delete" },
    { label = "Restore", id = "restore" },
    { label = "Refresh", id = "refresh" },
  }
  local toolbar = {}

  local function setMode(mode, default)
    app.mode = mode
    app.input = default or ""
    app.keyboard.hint = mode and (mode .. ": " .. app.input) or ""
  end

  local function selectedPath()
    if not app.selected then return nil end
    return fs.combine(app.path, app.selected)
  end

  local function openFile(path)
    if fs.isDir(path) then
      app.path = path
      app.selected = nil
      app.scroll = 1
      return
    end
    local target = mimeApp(path)
    if target then
      ctx.apps.launch(target, { path = path })
    else
      ctx.notifications:push("warn", "Files", "No app for ." .. extOf(path), 3)
    end
  end

  local function submitInput()
    if app.mode == "new_file" then
      local name = app.input ~= "" and app.input or basename(uniquePath(app.path, "new_file_", ".txt"))
      local path = fs.combine(app.path, name)
      local h = fs.open(path, "w")
      if h then h.write("") h.close() end
      app.selected = name
    elseif app.mode == "new_dir" then
      local name = app.input ~= "" and app.input or basename(uniquePath(app.path, "new_folder_", ""))
      fs.makeDir(fs.combine(app.path, name))
      app.selected = name
    elseif app.mode == "rename" and app.selected then
      local old = fs.combine(app.path, app.selected)
      local new = fs.combine(app.path, app.input)
      if app.input ~= "" and not fs.exists(new) then
        fs.move(old, new)
        app.selected = app.input
      else
        ctx.notifications:push("warn", "Files", "Invalid rename target", 3)
      end
    end
    setMode(nil)
  end

  local function toolbarHit(x)
    local cursor = 1
    for _, action in ipairs(actions) do
      local width = #action.label + 2
      if x >= cursor and x < cursor + width then return action.id end
      cursor = cursor + width + 1
    end
    return nil
  end

  local function perform(action)
    if action == "back" or action == "up" then
      app.path = parent(app.path)
      app.selected = nil
      app.scroll = 1
    elseif action == "home" then
      app.path = "/home/user"
      app.selected = nil
      app.scroll = 1
    elseif action == "new_file" then
      setMode("new_file", basename(uniquePath(app.path, "new_file_", ".txt")))
    elseif action == "new_dir" then
      setMode("new_dir", basename(uniquePath(app.path, "new_folder_", "")))
    elseif action == "rename" then
      if app.selected then setMode("rename", app.selected) end
    elseif action == "delete" then
      if app.selected then
        local full = selectedPath()
        if isProtected(full) then
          ctx.notifications:push("error", "Files", "Protected path", 3)
        else
          app.confirm = full and full:match("^/home/user/") and "trash" or "delete"
        end
      end
    elseif action == "restore" then
      if app.selected and app.path == "/home/user/.trash" then
        local from = selectedPath()
        local to = fs.combine("/home/user", app.selected:gsub("%.%d+$", ""))
        if fs.exists(from) and not fs.exists(to) then
          fs.move(from, to)
          ctx.notifications:push("success", "Files", "Restored to /home/user", 3)
          app.selected = nil
        else
          ctx.notifications:push("warn", "Files", "Cannot restore", 3)
        end
      end
    elseif action == "refresh" then
      app.scroll = 1
    end
  end

  app.keyboard.onText = function(ch)
    app.input = app.input .. ch
    app.keyboard.hint = tostring(app.mode or "input") .. ": " .. app.input
  end
  app.keyboard.onBackspace = function()
    app.input = app.input:sub(1, -2)
    app.keyboard.hint = tostring(app.mode or "input") .. ": " .. app.input
  end
  app.keyboard.onEnter = submitInput
  app.keyboard.onTab = submitInput

  function app:draw(w, h)
    toolbar = ui.toolbar(1, 1, w, actions)
    renderer.writeAt(1, 2, renderer.crop("Path: " .. self.path, w), colors.black, colors.lightGray)
    local files = sortedList(self.path)
    local kbH = self.mode and keyboard.height() or 0
    local listTop = 3
    local listH = math.max(1, h - listTop - kbH)
    ui.list(1, listTop, w, listH, files, self.selected, self.scroll, function(name)
      local full = fs.combine(self.path, name)
      local prefix = fs.isDir(full) and "[D] " or "[F] "
      return prefix .. name
    end)
    if self.confirm then
      local verb = self.confirm == "trash" and "Move to trash" or "Delete system file"
      renderer.writeAt(1, h, renderer.crop(verb .. " " .. tostring(self.selected) .. "? Tap Delete again.", w), colors.white, colors.red)
    elseif self.mode then
      self.keyboard.x = 1
      self.keyboard.y = h - keyboard.height() + 1
      keyboard.draw(1, self.keyboard.y, w, self.keyboard)
      renderer.writeAt(1, self.keyboard.y - 1, renderer.crop(tostring(self.mode) .. ": " .. self.input, w), colors.white, colors.gray)
    end
  end

  function app:handle(event)
    if event.name == "key" then
      local key = event.args[1]
      if self.mode then
        if key == keys.backspace then
          self.input = self.input:sub(1, -2)
          self.keyboard.hint = tostring(self.mode) .. ": " .. self.input
          return true
        elseif key == keys.enter or key == keys.tab then
          submitInput()
          return true
        end
      end
      if key == keys.backspace then perform("back") return true end
      if key == keys.enter and self.selected then openFile(selectedPath()) return true end
    elseif event.name == "char" and self.mode then
      self.input = self.input .. event.args[1]
      return true
    elseif event.name == "mouse_click" then
      local _, x, y = table.unpack(event.args)
      if self.mode and event.monitorTouch and keyboard.handle(event, self.keyboard) then return true end
      local action = y == 1 and (ui.toolbarHit(toolbar, x, y) or toolbarHit(x)) or nil
      if self.confirm then
        if action == "delete" and self.selected then
          local full = fs.combine(self.path, self.selected)
          if self.confirm == "trash" then
            fs.move(full, trashPath(full))
            ctx.notifications:push("success", "Files", "Moved to trash", 3)
          else
            fs.delete(full)
            ctx.notifications:push("warn", "Files", "Deleted", 3)
          end
          self.selected = nil
        end
        self.confirm = nil
        return true
      end
      if action then perform(action) return true end
      if y >= 3 then
        local files = sortedList(self.path)
        local name = files[self.scroll + y - 3]
        if name then
          if self.selected == name then openFile(fs.combine(self.path, name)) else self.selected = name end
          return true
        end
      end
    elseif event.name == "mouse_scroll" then
      local dir = event.args[1]
      self.scroll = math.max(1, self.scroll + dir)
      return true
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Files", w = math.min(72, sw - 4), h = math.min(24, sh - 3), x = 6, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["apps/logs/app.cfg"] = [[{
  id = "logs",
  name = "Logs",
  version = "0.7.0",
  main = "apps.logs.main",
  permissions = { "logs.read" },
}
]],
  ["apps/logs/main.lua"] = [[local renderer = require("system.gui.renderer")
local log = require("system.libraries.log")
local ui = require("system.gui.components")

local M = {}

function M.run(ctx)
  local app = { filter = "all" }
  local actions = {
    { id = "all", label = "All" },
    { id = "error", label = "Error" },
    { id = "warn", label = "Warn" },
    { id = "info", label = "Info" },
    { id = "debug", label = "Debug" },
    { id = "refresh", label = "Refresh" },
  }

  local function parse(line)
    local ok, row = pcall(textutils.unserialize, line)
    if ok and type(row) == "table" then return row end
    return { level = "info", source = "raw", message = line, time = "" }
  end

  local function format(row)
    return tostring(row.time or "") .. " " .. tostring(row.level or "?") .. " " .. tostring(row.source or "?") .. ": " .. tostring(row.message or "")
  end

  local function matches(row, filter)
    if filter == "all" then return true end
    return tostring(row.level or "") == filter
  end

  function app:draw(w, h)
    self.toolbar = ui.toolbar(1, 1, w, actions)
    renderer.writeAt(1, 2, renderer.crop("System Logs - " .. self.filter, w), colors.black, colors.lightGray)
    local raw = log.tail(120)
    local lines = {}
    for _, line in ipairs(raw) do
      local row = parse(line)
      if matches(row, self.filter) then table.insert(lines, format(row)) end
    end
    local start = math.max(1, #lines - h + 3)
    local y = 3
    for i = start, #lines do
      renderer.writeAt(1, y, renderer.crop(lines[i], w), colors.black, colors.lightGray)
      y = y + 1
      if y > h then break end
    end
  end

  function app:handle(event)
    if event.name == "mouse_click" then
      local _, x, y = table.unpack(event.args)
      local action = ui.toolbarHit(self.toolbar, x, y)
      if action then
        if action ~= "refresh" then self.filter = action end
        return true
      end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Logs", w = math.min(72, sw - 4), h = math.min(18, sh - 3), x = 5, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["apps/services/app.cfg"] = [[{
  id = "services",
  name = "Services",
  version = "0.7.0",
  main = "apps.services.main",
  permissions = { "services.list" },
}
]],
  ["apps/services/main.lua"] = [[local renderer = require("system.gui.renderer")
local ui = require("system.gui.components")

local M = {}

function M.run(ctx)
  local app = { selected = nil, scroll = 1 }
  local actions = {
    { id = "start", label = "Start" },
    { id = "stop", label = "Stop" },
    { id = "restart", label = "Restart" },
  }
  local protected = { deviced = true, notifd = true, logd = true }

  function app:draw(w, h)
    self.toolbar = ui.toolbar(1, 1, w, actions)
    renderer.writeAt(1, 2, renderer.crop("SERVICE       STATE      AUTO", w), colors.black, colors.gray)
    local rows = ctx.system.services:list()
    for i = 1, math.min(#rows, h - 4) do
      local s = rows[self.scroll + i - 1]
      if s then
        local bg = s.name == self.selected and colors.cyan or colors.lightGray
        local mark = protected[s.name] and " protected" or ""
        renderer.writeAt(1, i + 2, renderer.crop(s.name .. "       " .. s.state .. "      " .. tostring(s.autostart) .. mark, w), colors.black, bg)
      end
    end
    local selected
    for _, s in ipairs(rows) do if s.name == self.selected then selected = s end end
    if selected then
      renderer.writeAt(1, h, renderer.crop("Last error: " .. tostring(selected.error or "-"), w), colors.gray, colors.lightGray)
    end
  end

  function app:handle(event)
    if event.name == "mouse_scroll" then
      self.scroll = math.max(1, self.scroll + event.args[1])
      return true
    end
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    local action = ui.toolbarHit(self.toolbar, x, y)
    if action and self.selected then
      if protected[self.selected] and action ~= "start" then
        if ctx.notifications then ctx.notifications:push("warn", "Services", self.selected .. " is protected", 3) end
        return true
      end
      if action == "start" then
        ctx.system.services:start(self.selected)
      elseif action == "stop" then
        ctx.system.services:stop(self.selected)
      elseif action == "restart" then
        ctx.system.services:stop(self.selected)
        ctx.system.services:start(self.selected)
      end
      return true
    end
    if y >= 3 then
      local rows = ctx.system.services:list()
      local s = rows[self.scroll + y - 3]
      if s then self.selected = s.name return true end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Services", w = math.min(46, sw - 4), h = math.min(14, sh - 3), x = 10, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["apps/settings/app.cfg"] = [[{
  id = "settings",
  name = "Settings",
  version = "0.7.0",
  main = "apps.settings.main",
  permissions = { "system.config" },
}
]],
  ["apps/settings/main.lua"] = [[local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")
local config = require("system.libraries.config")
local deviced = require("system.services.deviced")
local networkd = require("system.services.networkd")
local ui = require("system.gui.components")
local keyboard = require("system.gui.keyboard")

local M = {}

function M.run(ctx)
  local app = { page = "system", scroll = 1, mode = nil, input = "", keyboard = {} }

  local pages = {
    { id = "system", label = "System" },
    { id = "display", label = "Display" },
    { id = "desktop", label = "Desktop" },
    { id = "network", label = "Network" },
    { id = "storage", label = "Storage" },
    { id = "apps", label = "Apps" },
    { id = "dev", label = "Dev" },
  }

  local function computerId()
    if os.getComputerID then return os.getComputerID() end
    if os.computerID then return os.computerID() end
    return 0
  end

  local function pseudoIp()
    local id = computerId()
    return "10.0." .. tostring(math.floor(id / 256) % 256) .. "." .. tostring(id % 256)
  end

  local function monitorGrade(display)
    local cells = (display.width or 0) * (display.height or 0)
    if display.target ~= "monitor" then return "computer" end
    if cells >= 4500 then return "A"
    elseif cells >= 2500 then return "B"
    elseif cells >= 1200 then return "C"
    else return "D"
    end
  end

  local function httpStatus()
    local status = networkd.getStatus()
    return status.http and "available" or "missing"
  end

  local function rednetStatus()
    if not peripheral or not peripheral.find then return "no peripheral API" end
    local modem = peripheral.find("modem")
    if not modem then return "no modem" end
    return "modem ready"
  end

  local function sizeLabel(bytes)
    bytes = tonumber(bytes) or 0
    if bytes >= 1024 * 1024 then return string.format("%.1f MB", bytes / 1024 / 1024) end
    if bytes >= 1024 then return string.format("%.1f KB", bytes / 1024) end
    return tostring(bytes) .. " B"
  end

  function app:draw(w, h)
    ui.tabs(1, 1, w, pages, self.page)

    if self.page == "system" then
      renderer.writeAt(1, 3, "Computer ID: " .. tostring(computerId()), colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Label: " .. tostring(os.getComputerLabel and (os.getComputerLabel() or "-") or "-"), colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "MintCraft: " .. tostring(config.load("/system/config/system.cfg", {}).version or "?"), colors.black, colors.lightGray)
      renderer.writeAt(1, 7, "Pseudo IP: " .. pseudoIp(), colors.black, colors.lightGray)
      renderer.writeAt(1, 8, "CraftOS over CC:Tweaked", colors.gray, colors.lightGray)
      renderer.button(1, 10, 16, "Set label", false)
    elseif self.page == "display" then
      local d = deviced.getDisplay()
      renderer.writeAt(1, 3, "Target: " .. tostring(d.target), colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Resolution: " .. tostring(d.width) .. "x" .. tostring(d.height), colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "Monitor side: " .. tostring(d.monitorSide or "-"), colors.black, colors.lightGray)
      renderer.writeAt(1, 6, "Scale: " .. tostring(d.scale or "-"), colors.black, colors.lightGray)
      renderer.writeAt(1, 7, "Monitor grade: " .. monitorGrade(d), colors.black, colors.lightGray)
      renderer.button(1, 9, 18, "Refresh display", false)
    elseif self.page == "desktop" then
      renderer.writeAt(1, 3, "Icons: NFP 7x6 with text fallback", colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Start search: touch AZERTY keyboard", colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "Context menu: desktop double tap on monitor", colors.black, colors.lightGray)
      renderer.writeAt(1, 6, "Windows: drag, minimize, maximize, close", colors.black, colors.lightGray)
    elseif self.page == "network" then
      local status = networkd.getStatus()
      renderer.writeAt(1, 3, "HTTP: " .. httpStatus(), colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "WebSocket: " .. tostring(status.websocket and "available" or "missing"), colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "Rednet: " .. rednetStatus(), colors.black, colors.lightGray)
      renderer.writeAt(1, 6, "Pseudo IP: " .. pseudoIp(), colors.black, colors.lightGray)
      renderer.writeAt(1, 7, "Real IP is not exposed by CC:Tweaked.", colors.gray, colors.lightGray)
      renderer.writeAt(1, 8, "Use pseudo IP / rednet ID inside Minecraft.", colors.gray, colors.lightGray)
      renderer.button(1, 10, 16, "Open Browser", false)
    elseif self.page == "storage" then
      local free = fs.getFreeSpace and fs.getFreeSpace("/") or nil
      local cap = fs.getCapacity and fs.getCapacity("/") or nil
      renderer.writeAt(1, 3, "Root: /", colors.black, colors.lightGray)
      if cap and free then
        renderer.writeAt(1, 4, "Used: " .. sizeLabel(cap - free) .. " / " .. sizeLabel(cap), colors.black, colors.lightGray)
        renderer.writeAt(1, 5, "Free: " .. sizeLabel(free), colors.black, colors.lightGray)
      elseif free then
        renderer.writeAt(1, 4, "Free: " .. sizeLabel(free), colors.black, colors.lightGray)
      else
        renderer.writeAt(1, 4, "Storage metrics unavailable", colors.black, colors.lightGray)
      end
      renderer.writeAt(1, 7, "Trash: /home/user/.trash", colors.gray, colors.lightGray)
    elseif self.page == "apps" then
      local rows = ctx.apps.list()
      renderer.writeAt(1, 3, renderer.crop("APP              VERSION   CATEGORY   PERMISSIONS", w), colors.black, colors.gray)
      for i = 1, math.min(#rows, h - 4) do
        local item = rows[self.scroll + i - 1]
        if item then
          renderer.writeAt(1, i + 3, renderer.crop(item.name .. "          " .. tostring(item.version) .. "   " .. item.category .. "   " .. table.concat(item.permissions or {}, ","), w), colors.black, colors.lightGray)
        end
      end
    elseif self.page == "dev" then
      renderer.writeAt(1, 3, "Editor: compile Lua with loadfile()", colors.black, colors.lightGray)
      renderer.writeAt(1, 4, "Autocomplete: Tab accepts suggestion", colors.black, colors.lightGray)
      renderer.writeAt(1, 5, "Keyboard: AZERTY touch layout", colors.black, colors.lightGray)
      renderer.writeAt(1, 6, "Theme: " .. theme.currentId, colors.black, colors.lightGray)
      renderer.button(1, 7, 14, "Mint", theme.currentId == "mint")
      renderer.button(16, 7, 14, "Dark", theme.currentId == "dark")
      renderer.button(1, 9, 14, "Open Editor", false)
    end
    if self.mode == "label" then
      self.keyboard.x = 1
      self.keyboard.y = math.max(1, h - keyboard.height() + 1)
      self.keyboard.hint = "Label: " .. self.input
      keyboard.draw(1, self.keyboard.y, w, self.keyboard)
    end
    renderer.writeAt(1, h, "Settings", colors.gray, colors.lightGray)
  end

  app.keyboard.onText = function(ch) app.input = app.input .. ch end
  app.keyboard.onBackspace = function() app.input = app.input:sub(1, -2) end
  app.keyboard.onEnter = function()
    if app.mode == "label" and os.setComputerLabel then os.setComputerLabel(app.input) end
    app.mode = nil
    app.input = ""
  end

  function app:handle(event)
    if self.mode == "label" then
      if event.name == "char" then self.input = self.input .. event.args[1] return true end
      if event.name == "key" and event.args[1] == keys.backspace then self.input = self.input:sub(1, -2) return true end
      if event.name == "key" and event.args[1] == keys.enter then self.keyboard.onEnter() return true end
      if event.name == "mouse_click" and event.monitorTouch and keyboard.handle(event, self.keyboard) then return true end
    end
    if event.name == "mouse_scroll" and self.page == "apps" then
      self.scroll = math.max(1, self.scroll + event.args[1])
      return true
    end
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    if y == 1 then
      for _, page in ipairs(pages) do
        if ui.hit(page, x, y) then
          self.page = page.id
          self.scroll = 1
          return true
        end
      end
    end

    if self.page == "dev" and y == 7 and x <= 14 then
      theme.set("mint")
      ctx.notifications:push("success", "Settings", "Mint theme applied", 3)
      return true
    elseif self.page == "dev" and y == 7 and x >= 16 and x <= 29 then
      theme.set("dark")
      ctx.notifications:push("success", "Settings", "Dark theme applied", 3)
      return true
    elseif self.page == "display" and y == 9 and x <= 18 then
      deviced.refreshDisplay()
      return true
    elseif self.page == "system" and y == 10 and x <= 16 then
      self.mode = "label"
      self.input = os.getComputerLabel and (os.getComputerLabel() or "") or ""
      return true
    elseif self.page == "network" and y == 10 and x <= 16 then
      ctx.apps.launch("browser")
      return true
    elseif self.page == "dev" and y == 9 and x <= 14 then
      ctx.apps.launch("editor")
      return true
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Settings", w = math.min(72, sw - 4), h = math.min(18, sh - 3), x = 8, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["apps/taskmanager/app.cfg"] = [[{
  id = "taskmanager",
  name = "Task Manager",
  version = "0.7.0",
  main = "apps.taskmanager.main",
  permissions = { "process.list", "process.kill" },
}
]],
  ["apps/taskmanager/main.lua"] = [[local renderer = require("system.gui.renderer")
local ui = require("system.gui.components")

local M = {}

local function sizeLabel(bytes)
  bytes = tonumber(bytes) or 0
  if bytes >= 1024 * 1024 then
    return string.format("%.1f MB", bytes / 1024 / 1024)
  elseif bytes >= 1024 then
    return string.format("%.1f KB", bytes / 1024)
  end
  return tostring(bytes) .. " B"
end

local function diskStats()
  if not fs.getFreeSpace then return "Disk: unavailable" end
  local free = fs.getFreeSpace("/")
  local capacity = fs.getCapacity and fs.getCapacity("/") or nil
  if capacity and capacity > 0 then
    local used = capacity - free
    local pct = math.floor((used / capacity) * 100 + 0.5)
    return "Disk: " .. sizeLabel(used) .. "/" .. sizeLabel(capacity) .. " " .. pct .. "%"
  end
  return "Disk free: " .. sizeLabel(free)
end

local function memoryStats()
  if not collectgarbage then return "RAM: unavailable" end
  local ok, kb = pcall(collectgarbage, "count")
  if not ok then return "RAM: unavailable" end
  return string.format("RAM Lua: %.1f KB", kb)
end

function M.run(ctx)
  local app = { selectedPid = nil, scroll = 1 }
  local actions = {
    { id = "kill", label = "Kill" },
    { id = "refresh", label = "Refresh" },
  }

  function app:draw(w, h)
    local rows = ctx.listProcesses()
    local total = #rows
    local ready = 0
    for _, p in ipairs(rows) do
      if p.state == "ready" then ready = ready + 1 end
    end
    local cpuEstimate = total > 0 and math.floor((ready / total) * 100 + 0.5) or 0

    self.toolbar = ui.toolbar(1, 1, w, actions)
    renderer.writeAt(1, 2, renderer.crop("MintCraft Task Manager", w), colors.black, colors.lightGray)
    renderer.writeAt(2, 3, renderer.crop("CPU est. CC: " .. cpuEstimate .. "%  Proc: " .. tostring(total), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(2, 4, renderer.crop(memoryStats(), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(2, 5, renderer.crop(diskStats(), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(1, 7, renderer.crop("PID STATE    APP        NAME", w), colors.black, colors.gray)

    for i = 1, math.min(#rows, h - 7) do
      local p = rows[self.scroll + i - 1]
      if p then
        local bg = p.pid == self.selectedPid and colors.cyan or colors.lightGray
        renderer.writeAt(1, i + 7, renderer.crop(tostring(p.pid) .. "   " .. p.state .. "   " .. tostring(p.appId or "-") .. "   " .. p.name, w), colors.black, bg)
      end
    end
    if self.selectedPid then
      for _, p in ipairs(rows) do
        if p.pid == self.selectedPid then
          local perms = table.concat(p.permissions or {}, ",")
          renderer.writeAt(1, h - 1, renderer.crop("Window: " .. tostring(p.windowId or "-") .. " Started: " .. tostring(p.startedAt or "-"), w), colors.gray, colors.lightGray)
          renderer.writeAt(1, h, renderer.crop("Perms: " .. (perms ~= "" and perms or "-") .. " Err: " .. tostring(p.error or "-"), w), colors.gray, colors.lightGray)
          break
        end
      end
    end
  end

  function app:handle(event)
    if event.name == "mouse_scroll" then
      self.scroll = math.max(1, self.scroll + event.args[1])
      return true
    end
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    local action = ui.toolbarHit(self.toolbar, x, y)
    if action == "kill" and self.selectedPid then
      local ok, err = ctx.kill(self.selectedPid)
      if ctx.notifications then ctx.notifications:push(ok and "success" or "error", "Task Manager", ok and "Killed" or tostring(err), 3) end
      return true
    elseif action then
      return true
    end
    if y >= 8 then
      local rows = ctx.listProcesses()
      local p = rows[self.scroll + y - 8]
      if p then self.selectedPid = p.pid return true end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Task Manager", w = math.min(58, sw - 4), h = math.min(16, sh - 3), x = 8, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["apps/terminal/app.cfg"] = [[{
  id = "terminal",
  name = "Terminal",
  version = "0.7.0",
  main = "apps.terminal.main",
  permissions = { "filesystem.read", "process.list", "process.kill", "system.reboot" },
}
]],
  ["apps/terminal/main.lua"] = [[local renderer = require("system.gui.renderer")
local log = require("system.libraries.log")
local keyboard = require("system.gui.keyboard")
local ui = require("system.gui.components")
local autocomplete = require("system.dev.autocomplete")

local M = {}

local function append(app, line)
  table.insert(app.lines, line)
  if #app.lines > 200 then table.remove(app.lines, 1) end
end

local help = {
  ls = "ls [dir] - list directory",
  cd = "cd <dir> - change directory",
  pwd = "pwd - print current directory",
  mkdir = "mkdir <dir> - create directory",
  cp = "cp <src> <dst> - copy file or directory",
  mv = "mv <src> <dst> - move or rename",
  rm = "rm <path> - delete after yes confirmation",
  trash = "trash - open user trash in Files",
  restore = "restore <name> - restore from /home/user/.trash",
  cat = "cat <file> - show file",
  type = "type <file> - alias of cat",
  edit = "edit <file> - open Editor",
  open = "open <path> - open Files or Editor",
  ps = "ps - list processes",
  kill = "kill <pid> - kill after yes confirmation",
  logs = "logs - show recent logs",
  browser = "browser [url] - open text browser",
}

local function trashPath(name)
  return fs.combine("/home/user/.trash", name)
end

local function runCommand(app, ctx, input)
  append(app, "> " .. input)
  if app.pending then
    if input == "yes" then
      local pending = app.pending
      app.pending = nil
      pending()
      return
    end
    append(app, "cancelled")
    app.pending = nil
    return
  end

  local cmd, rest = input:match("^(%S+)%s*(.*)$")
  if not cmd then return end

  if cmd == "clear" then
    app.lines = {}
  elseif cmd == "ls" then
    local path = rest ~= "" and fs.combine(app.cwd, rest) or app.cwd
    if fs.exists(path) and fs.isDir(path) then
      for _, name in ipairs(fs.list(path)) do append(app, name) end
    else
      append(app, "Not a directory: " .. path)
    end
  elseif cmd == "cd" then
    local path = rest ~= "" and fs.combine(app.cwd, rest) or "/"
    if fs.exists(path) and fs.isDir(path) then app.cwd = path else append(app, "No such directory") end
  elseif cmd == "pwd" then
    append(app, app.cwd)
  elseif cmd == "mkdir" then
    if rest == "" then append(app, "Usage: mkdir <dir>") else fs.makeDir(fs.combine(app.cwd, rest)) end
  elseif cmd == "cp" then
    local src, dst = rest:match("^(%S+)%s+(.+)$")
    if not src or not dst then
      append(app, "Usage: cp <src> <dst>")
    else
      local from, to = fs.combine(app.cwd, src), fs.combine(app.cwd, dst)
      if fs.exists(from) and not fs.exists(to) then fs.copy(from, to) else append(app, "Cannot copy") end
    end
  elseif cmd == "mv" then
    local src, dst = rest:match("^(%S+)%s+(.+)$")
    if not src or not dst then
      append(app, "Usage: mv <src> <dst>")
    else
      local from, to = fs.combine(app.cwd, src), fs.combine(app.cwd, dst)
      if fs.exists(from) and not fs.exists(to) then fs.move(from, to) else append(app, "Cannot move") end
    end
  elseif cmd == "rm" then
    if rest ~= "" then
      local path = fs.combine(app.cwd, rest)
      if fs.exists(path) then
        app.pending = function()
          fs.delete(path)
          append(app, "deleted")
        end
        append(app, "Type yes to delete " .. path)
      else
        append(app, "No such file")
      end
    else
      append(app, "Usage: rm <path>")
    end
  elseif cmd == "edit" then
    local path = rest ~= "" and fs.combine(app.cwd, rest) or app.cwd
    ctx.apps.launch("editor", { path = path })
  elseif cmd == "open" then
    local path = rest ~= "" and fs.combine(app.cwd, rest) or app.cwd
    if fs.isDir(path) then ctx.apps.launch("files", { path = path }) else ctx.apps.launch("editor", { path = path }) end
  elseif cmd == "trash" then
    ctx.apps.launch("files", { path = "/home/user/.trash" })
  elseif cmd == "restore" then
    if rest == "" then
      append(app, "Usage: restore <name>")
    else
      local from = trashPath(rest)
      local to = fs.combine(app.cwd, rest)
      if fs.exists(from) and not fs.exists(to) then fs.move(from, to) append(app, "restored") else append(app, "Cannot restore") end
    end
  elseif cmd == "cat" or cmd == "type" then
    local path = fs.combine(app.cwd, rest)
    if fs.exists(path) then
      local h = fs.open(path, "r")
      append(app, h.readAll() or "")
      h.close()
    else
      append(app, "No such file")
    end
  elseif cmd == "ps" then
    for _, p in ipairs(ctx.listProcesses()) do
      append(app, tostring(p.pid) .. " " .. p.state .. " " .. p.name)
    end
  elseif cmd == "kill" then
    local pid = tonumber(rest)
    if not pid then append(app, "Usage: kill <pid>") return end
    app.pending = function()
      local ok, err = ctx.kill(pid)
      append(app, ok and "killed" or tostring(err))
    end
    append(app, "Type yes to kill pid " .. tostring(pid))
  elseif cmd == "logs" then
    for _, line in ipairs(log.tail(10)) do append(app, line) end
  elseif cmd == "browser" then
    ctx.apps.launch("browser", { url = rest })
  elseif cmd == "files" then
    ctx.apps.launch("files")
  elseif cmd == "settings" then
    ctx.apps.launch("settings")
  elseif cmd == "devices" then
    ctx.apps.launch("devices")
  elseif cmd == "reboot" then
    os.reboot()
  elseif cmd == "help" then
    if rest ~= "" and help[rest] then
      append(app, help[rest])
    else
      append(app, "Commands: " .. table.concat(autocomplete.commands(), " "))
      append(app, "Use help <cmd> for details.")
    end
  else
    append(app, "Unknown command: " .. cmd)
  end
end

function M.run(ctx)
  local app = {
    lines = { "MintCraft Terminal", "Type help for commands." },
    input = "",
    cwd = "/home/user",
    caps = false,
    shift = false,
    suggestion = nil,
    history = {},
    historyIndex = nil,
    keyboard = {},
  }

  local quick = {
    { id = "ls", label = "ls", text = "ls" },
    { id = "home", label = "cd home", text = "cd /home/user" },
    { id = "files", label = "files", text = "files" },
    { id = "ps", label = "ps", text = "ps" },
    { id = "logs", label = "logs", text = "logs" },
    { id = "clear", label = "clear", text = "clear" },
  }

  local function currentWord()
    return autocomplete.prefix(app.input, #app.input + 1, "([%w_%-/%.]+)$")
  end

  local function updateSuggestion()
    local prefix = currentWord()
    app.suggestion = autocomplete.suggest({ mode = "terminal", prefix = prefix, cwd = app.cwd })
  end

  local function acceptSuggestion()
    updateSuggestion()
    if not app.suggestion then return false end
    local prefix = currentWord()
    local text = autocomplete.apply(app.input, #app.input + 1, app.suggestion, prefix)
    app.input = text
    app.suggestion = nil
    return true
  end

  local function submit()
    local input = app.input
    app.input = ""
    if input ~= "" then table.insert(app.history, input) app.historyIndex = nil end
    runCommand(app, ctx, input)
  end

  local function hitQuick(x, y)
    if y ~= 1 then return false end
    local cursor = 1
    for _, item in ipairs(quick) do
      local width = #item.label + 2
      if x >= cursor and x < cursor + width then
        app.input = item.text
        submit()
        return true
      end
      cursor = cursor + width + 1
    end
    return false
  end

  app.keyboard.onText = function(ch) app.input = app.input .. ch updateSuggestion() end
  app.keyboard.onBackspace = function() app.input = string.sub(app.input, 1, -2) updateSuggestion() end
  app.keyboard.onEnter = submit
  app.keyboard.onTab = acceptSuggestion

  function app:draw(w, h)
    self.lastH = h
    updateSuggestion()
    local top = math.max(3, h - keyboard.height())
    local logHeight = math.max(1, top - 3)
    self.quickBoxes = ui.toolbar(1, 1, w, quick)

    local start = math.max(1, #self.lines - logHeight + 1)
    local y = 2
    for i = start, #self.lines do
      renderer.writeAt(1, y, renderer.crop(self.lines[i], w), colors.black, colors.lightGray)
      y = y + 1
      if y >= top - 1 then break end
    end
    local prompt = self.cwd .. "> " .. self.input
    if self.suggestion then prompt = prompt .. "  [tab " .. self.suggestion.label .. "]" end
    renderer.writeAt(1, top - 1, renderer.crop(prompt, w), colors.white, colors.gray)

    self.keyboard.x = 1
    self.keyboard.y = top
    self.keyboard.hint = self.suggestion and ("Tab: " .. self.suggestion.label) or ""
    keyboard.draw(1, top, w, self.keyboard)
  end

  function app:handle(event)
    if event.name == "char" then
      self.input = self.input .. event.args[1]
      return true
    elseif event.name == "key" then
      local key = event.args[1]
      if key == keys.enter then
        local input = self.input
        self.input = ""
        runCommand(self, ctx, input)
        return true
      elseif key == keys.backspace then
        self.input = string.sub(self.input, 1, -2)
        updateSuggestion()
        return true
      elseif key == keys.tab then
        acceptSuggestion()
        return true
      elseif key == keys.up then
        if #self.history > 0 then
          self.historyIndex = self.historyIndex and math.max(1, self.historyIndex - 1) or #self.history
          self.input = self.history[self.historyIndex] or self.input
        end
        return true
      elseif key == keys.down then
        if self.historyIndex then
          self.historyIndex = self.historyIndex + 1
          if self.historyIndex > #self.history then self.historyIndex = nil self.input = "" else self.input = self.history[self.historyIndex] end
        end
        return true
      end
    elseif event.name == "mouse_click" and event.monitorTouch then
      local _, x, y = table.unpack(event.args)
      local quickId = ui.toolbarHit(self.quickBoxes, x, y)
      if quickId then
        for _, item in ipairs(quick) do
          if item.id == quickId then app.input = item.text submit() return true end
        end
      end
      if hitQuick(x, y) then return true end
      if keyboard.handle(event, self.keyboard) then return true end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Terminal", w = math.min(72, sw - 4), h = math.min(24, sh - 3), x = 4, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["apps/update/app.cfg"] = [[{
  id = "update",
  name = "Update",
  version = "0.7.0",
}
]],
  ["apps/update/main.lua"] = [[local renderer = require("system.gui.renderer")
local updated = require("system.services.updated")

local M = {}

local function buttonAt(x, y, bx, by, bw)
  return y == by and x >= bx and x < bx + bw
end

function M.run(ctx)
  local app = {
    status = updated.status,
    message = "Ready",
  }

  function app:refresh()
    local ok, status = pcall(updated.check)
    if ok then
      self.status = status
      self.message = status.message
    else
      self.message = tostring(status)
    end
  end

  function app:apply()
    self.message = "Downloading installer..."
    local ok, message = updated.apply()
    self.message = tostring(message)
    if ctx.notifications then
      ctx.notifications:push(ok and "success" or "error", "Update", self.message, 6)
    end
  end

  function app:draw(w, h)
    self.lastH = h
    renderer.writeAt(1, 1, renderer.crop("MintCraft Update", w), colors.black, colors.lightGray)
    renderer.writeAt(2, 3, renderer.crop("Local : " .. tostring(self.status.localVersion), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(2, 4, renderer.crop("GitHub: " .. tostring(self.status.remoteVersion), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(2, 5, renderer.crop("State : " .. tostring(self.message), w - 2), colors.black, colors.lightGray)
    renderer.button(2, h - 1, 10, "Check", false)
    renderer.button(14, h - 1, 10, "Apply", false)
  end

  function app:handle(event)
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    if buttonAt(x, y, 2, self.lastH - 1, 10) then
      self:refresh()
      return true
    elseif buttonAt(x, y, 14, self.lastH - 1, 10) then
      self:apply()
      return true
    end
    return false
  end

  local sw, sh = term.getSize()
  app.lastH = math.min(12, sh - 3)
  local win = ctx.windowManager:create({ title = "Update", w = math.min(44, sw - 4), h = app.lastH, x = 7, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
]],
  ["boot.lua"] = [[if not table.unpack and unpack then table.unpack = unpack end

if not require then
  local loaded = {}

  function require(name)
    if loaded[name] then return loaded[name] end

    local path = "/" .. name:gsub("%.", "/") .. ".lua"
    if not fs.exists(path) then
      error("module not found: " .. name .. " (" .. path .. ")", 2)
    end

    local chunk, err = loadfile(path)
    if not chunk then error(err, 2) end

    loaded[name] = true
    local result = chunk()
    if result ~= nil then loaded[name] = result end
    return loaded[name]
  end
end

local ok, err = pcall(function()
  local bootloader = require("system.boot.bootloader")
  bootloader.start()
end)

if not ok then
  if not fs.exists("/var") then fs.makeDir("/var") end
  if not fs.exists("/var/logs") then fs.makeDir("/var/logs") end
  local crash = fs.open("/var/logs/last_crash.log", "w")
  if crash then
    crash.writeLine(tostring(err))
    crash.close()
  end
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.red)
  term.clear()
  term.setCursorPos(1, 1)
  print("MintCraft OS boot error")
  print(tostring(err))

  if fs.exists("/system/boot/recovery.lua") then
    local recovery, loadErr = loadfile("/system/boot/recovery.lua")
    if recovery then
      recovery(tostring(err))
    else
      print(tostring(loadErr))
    end
  end
end
]],
  ["packages/installed.db"] = [[{}
]],
  ["packages/sources.db"] = [[{}
]],
  ["startup.lua"] = [[local candidates = {
  "/boot.lua",
  "boot.lua",
}

if type(arg) == "table" and type(arg[0]) == "string" then
  table.insert(candidates, fs.combine(fs.getDir(arg[0]), "boot.lua"))
end

local lastErr
for _, path in ipairs(candidates) do
  if fs.exists(path) then
    local boot, err = loadfile(path)
    if boot then return boot() end
    lastErr = err
  end
end

error(lastErr or "MintCraft OS boot.lua not found", 0)
]],
  ["system/boot/bootloader.lua"] = [[local splash = require("system.boot.splash")
local log = require("system.libraries.log")
local config = require("system.libraries.config")

local M = {}

local REQUIRED_DIRS = {
  "/system",
  "/system/boot",
  "/system/config",
  "/system/dev",
  "/system/gui",
  "/system/kernel",
  "/system/libraries",
  "/system/network",
  "/system/services",
  "/system/themes",
  "/system/wm",
  "/apps",
  "/home",
  "/home/user",
  "/home/user/config",
  "/home/user/desktop",
  "/home/user/documents",
  "/home/user/downloads",
  "/home/user/.trash",
  "/var",
  "/var/cache",
  "/var/logs",
  "/var/tmp",
  "/packages",
}

local function ensureDirs()
  for _, path in ipairs(REQUIRED_DIRS) do
    if not fs.exists(path) then
      fs.makeDir(path)
    end
  end
end

local function ensureDefaults()
  config.ensure("/system/config/system.cfg", {
    version = "0.7.0",
    theme = "mint",
    debug = true,
    safeMode = false,
  })
end

function M.start()
  ensureDirs()
  log.info("boot", "bootloader started")
  ensureDefaults()
  local cfg = config.load("/system/config/system.cfg", { version = "0.7.0" })
  splash.draw("MintCraft OS", "Version " .. tostring(cfg.version or "0.7.0"))

  local kernel = require("system.kernel.kernel")
  kernel.start()
end

return M
]],
  ["system/boot/recovery.lua"] = [[local reason = ...

term.setBackgroundColor(colors.black)
term.setTextColor(colors.yellow)
term.clear()
term.setCursorPos(1, 1)
print("MintCraft OS Recovery")
print("---------------------")
print("Reason: " .. tostring(reason or "manual"))
print("")
print("Commands:")
print("  shell  - open CraftOS shell")
print("  logs   - show last system log lines")
print("  crash  - show last crash log")
print("  reboot - reboot computer")
print("  exit   - return to caller")
print("")

while true do
  term.setTextColor(colors.lime)
  write("recovery> ")
  term.setTextColor(colors.white)
  local cmd = read()

  if cmd == "shell" then
    shell.run("shell")
  elseif cmd == "logs" then
    if fs.exists("/var/logs/system.log") then
      shell.run("type", "/var/logs/system.log")
    else
      print("No logs found.")
    end
  elseif cmd == "crash" then
    if fs.exists("/var/logs/last_crash.log") then
      shell.run("type", "/var/logs/last_crash.log")
    else
      print("No crash log found.")
    end
  elseif cmd == "reboot" then
    os.reboot()
  elseif cmd == "exit" then
    return
  elseif cmd ~= "" then
    print("Unknown command: " .. cmd)
  end
end
]],
  ["system/boot/splash.lua"] = [[local M = {}

function M.draw(title, subtitle)
  term.setBackgroundColor(colors.green)
  term.setTextColor(colors.white)
  term.clear()

  local w, h = term.getSize()
  local y = math.max(2, math.floor(h / 2) - 1)
  term.setCursorPos(math.max(1, math.floor((w - #title) / 2)), y)
  term.write(title)
  term.setCursorPos(math.max(1, math.floor((w - #subtitle) / 2)), y + 2)
  term.write(subtitle)
  sleep(0.35)
end

return M
]],
  ["system/config/mime.db"] = [[{
  txt = "editor",
  md = "editor",
  cfg = "editor",
  db = "editor",
  lua = "editor",
}
]],
  ["system/config/system.cfg"] = [[{
  version = "0.7.0",
  theme = "mint",
  debug = true,
  safeMode = false,
  display = {
    preferMonitor = true,
    monitorTextScale = 0.5,
    minMonitorBlocksWide = 4,
    minMonitorBlocksHigh = 3,
  },
}
]],
  ["system/config/update.cfg"] = [[{
  repo = "commandant-x/MintCraftOS",
  branch = "main",
  autoCheck = true,
  autoApply = false,
  lastStatus = "never checked",
}
]],
  ["system/dev/autocomplete.lua"] = [[local M = {}

local luaWords = {
  "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
  "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
  "true", "until", "while", "pairs", "ipairs", "pcall", "print", "require",
}

local ccWords = {
  "fs.open", "fs.exists", "fs.list", "fs.combine", "term.setCursorPos",
  "term.getSize", "textutils.serialize", "os.pullEvent", "os.reboot",
  "peripheral.find", "rednet.open", "http.get", "window.create",
  "table.insert", "table.remove", "string.sub", "string.match",
}

local terminalCommands = {
  "ls", "cd", "pwd", "mkdir", "cp", "mv", "rm", "trash", "restore", "cat", "type",
  "edit", "open", "clear", "ps", "kill", "logs", "browser", "files", "settings", "devices",
  "reboot", "help",
}

local snippets = {
  { label = "function", insert = "function name(args)\n  \nend", kind = "snippet" },
  { label = "if", insert = "if condition then\n  \nend", kind = "snippet" },
  { label = "for", insert = "for i = 1, n do\n  \nend", kind = "snippet" },
  { label = "while", insert = "while condition do\n  \nend", kind = "snippet" },
  { label = "repeat", insert = "repeat\n  \nuntil condition", kind = "snippet" },
  { label = "pcall", insert = "local ok, err = pcall(function()\n  \nend)", kind = "snippet" },
  { label = "require", insert = "local mod = require(\"module\")", kind = "snippet" },
}

local function add(rows, seen, label, insert, kind)
  if label and label ~= "" and not seen[label] then
    seen[label] = true
    table.insert(rows, { label = label, insert = insert or label, kind = kind or "word" })
  end
end

local function listModules()
  local rows = {}
  local function walk(path)
    if not fs.exists(path) then return end
    for _, name in ipairs(fs.list(path)) do
      local full = fs.combine(path, name)
      if fs.isDir(full) then
        walk(full)
      elseif name:match("%.lua$") then
        table.insert(rows, full:gsub("^/", ""):gsub("%.lua$", ""):gsub("/", "."))
      end
    end
  end
  walk("/system")
  walk("/apps")
  table.sort(rows)
  return rows
end

local function localSymbols(lines)
  local found = {}
  for _, line in ipairs(lines or {}) do
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

function M.prefix(text, cursor, pattern)
  local left = tostring(text or ""):sub(1, (cursor or 1) - 1)
  return left:match(pattern or "([%w_%.%-/]+)$") or ""
end

function M.suggest(ctx)
  ctx = ctx or {}
  local prefix = ctx.prefix or M.prefix(ctx.text or "", ctx.cursor or 1, ctx.pattern)
  if prefix == "" then return nil end

  local rows, seen = {}, {}
  if ctx.mode == "terminal" then
    for _, cmd in ipairs(terminalCommands) do
      if cmd:sub(1, #prefix) == prefix then add(rows, seen, cmd, cmd, "command") end
    end
    local dir = ctx.cwd or "/"
    local part = prefix
    if prefix:find("/") then
      dir = fs.getDir(fs.combine(ctx.cwd or "/", prefix))
      part = fs.getName(prefix)
    end
    if fs.exists(dir) and fs.isDir(dir) then
      for _, name in ipairs(fs.list(dir)) do
        if name:sub(1, #part) == part then add(rows, seen, name, name, "path") end
      end
    end
  else
    for _, item in ipairs(snippets) do
      if item.label:sub(1, #prefix) == prefix then add(rows, seen, item.label, item.insert, item.kind) end
    end
    for _, word in ipairs(luaWords) do
      if word:sub(1, #prefix) == prefix then add(rows, seen, word, word, "lua") end
    end
    for _, word in ipairs(ccWords) do
      if word:sub(1, #prefix) == prefix then add(rows, seen, word, word, "cc") end
    end
    for _, word in ipairs(localSymbols(ctx.lines or {})) do
      if word:sub(1, #prefix) == prefix and word ~= prefix then add(rows, seen, word, word, "local") end
    end
    if #rows == 0 then
      for _, mod in ipairs(listModules()) do
        if mod:sub(1, #prefix) == prefix then add(rows, seen, mod, mod, "module") end
      end
    end
  end

  return rows[1]
end

function M.apply(text, cursor, suggestion, prefix)
  text = tostring(text or "")
  cursor = cursor or 1
  if not suggestion then return text, cursor end
  prefix = prefix or M.prefix(text, cursor)
  local before = text:sub(1, cursor - #prefix - 1)
  local after = text:sub(cursor)
  local insert = suggestion.insert or suggestion.label or ""
  return before .. insert .. after, #before + #insert + 1
end

function M.commands()
  return terminalCommands
end

return M
]],
  ["system/gui/components.lua"] = [[local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")

local M = {}

function M.button(x, y, w, label, active)
  renderer.button(x, y, w, label, active)
  return { x = x, y = y, w = w, h = 1, label = label }
end

function M.hit(box, x, y)
  return box and x >= box.x and x < box.x + box.w and y >= box.y and y < box.y + (box.h or 1)
end

function M.toolbar(x, y, w, actions)
  local boxes = {}
  local cursor = x
  for _, action in ipairs(actions) do
    local width = math.min(#action.label + 2, math.max(4, w - cursor + x))
    if cursor + width - x > w then break end
    renderer.button(cursor, y, width, action.label, action.active)
    action.x, action.y, action.w, action.h = cursor, y, width, 1
    table.insert(boxes, action)
    cursor = cursor + width + 1
  end
  return boxes
end

function M.toolbarHit(actions, x, y)
  for _, action in ipairs(actions or {}) do
    if M.hit(action, x, y) then return action.id end
  end
  return nil
end

function M.tabs(x, y, w, tabs, selected)
  local boxes = {}
  local cursor = x
  for _, tab in ipairs(tabs) do
    local width = math.min(#tab.label + 2, math.max(5, w - cursor + x))
    if cursor + width - x > w then break end
    renderer.button(cursor, y, width, tab.label, tab.id == selected)
    tab.x, tab.y, tab.w, tab.h = cursor, y, width, 1
    table.insert(boxes, tab)
    cursor = cursor + width + 1
  end
  return boxes
end

function M.list(x, y, w, h, rows, selected, scroll, render)
  scroll = scroll or 1
  for i = 1, h do
    local index = scroll + i - 1
    local row = rows[index]
    local bg = row == selected and colors.cyan or theme.get("windowBg")
    local text = row and render(row, index) or ""
    renderer.writeAt(x, y + i - 1, renderer.crop(text, w), colors.black, bg)
  end
end

function M.input(x, y, w, label, value, focused)
  local bg = focused and colors.white or colors.lightGray
  renderer.writeAt(x, y, renderer.crop(label .. ": " .. tostring(value or ""), w), colors.black, bg)
end

function M.dialog(x, y, w, title, message, confirmLabel)
  renderer.fill(x, y, w, 5, colors.gray)
  renderer.writeAt(x + 1, y, renderer.crop(title, w - 2), colors.white, colors.gray)
  renderer.writeAt(x + 1, y + 2, renderer.crop(message, w - 2), colors.white, colors.gray)
  renderer.button(x + 1, y + 4, math.min(12, w - 2), confirmLabel or "Confirm", false)
end

return M
]],
  ["system/gui/desktop.lua"] = [[local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")
local keyboard = require("system.gui.keyboard")
local iconRenderer = require("system.gui.icon")

local M = {
  apps = nil,
  wm = nil,
  notifications = nil,
  menuOpen = false,
  contextMenu = nil,
  lastMonitorTap = nil,
  icons = {},
  search = "",
  searchFocused = false,
  searchBox = { x = 10, y = 1, w = 20 },
  keyboard = {},
}

function M.setApps(apps) M.apps = apps end
function M.setWindowManager(wm) M.wm = wm end
function M.setNotifications(notifications) M.notifications = notifications end

local function drawIcons()
  local w, h = term.getSize()
  local labels = {
    { app = "terminal" },
    { app = "browser" },
    { app = "files" },
    { app = "editor" },
    { app = "settings" },
    { app = "devices" },
    { app = "taskmanager" },
    { app = "update" },
  }
  local icons = {}
  local x, y = 2, 2
  local cellW, cellH = 14, 8
  for _, item in ipairs(labels) do
    local meta = M.apps and M.apps.get(item.app) or nil
    table.insert(icons, {
      x = x,
      y = y,
      label = meta and meta.name or item.app,
      icon = meta and meta.icon or "[]",
      iconPath = meta and meta.iconPath,
      app = item.app,
    })
    y = y + cellH
    if y > h - 8 then
      y = 2
      x = x + cellW
    end
  end

  M.icons = icons
  for _, icon in ipairs(icons) do
    iconRenderer.draw(icon.iconPath, icon.x, icon.y, icon.icon, theme.get("desktopBg"))
    renderer.writeAt(icon.x, icon.y + 6, renderer.crop(icon.label, 12), colors.white, theme.get("desktopBg"))
  end
end

local function drawContextMenu()
  if not M.contextMenu then return end
  local w, h = term.getSize()
  local items = M.contextMenu.items
  local menuW = 18
  local menuH = #items + 2
  local x = math.min(M.contextMenu.x, math.max(1, w - menuW + 1))
  local y = math.min(M.contextMenu.y, math.max(1, h - menuH))
  M.contextMenu.x, M.contextMenu.y = x, y
  renderer.fill(x, y, menuW, menuH, colors.lightGray)
  renderer.writeAt(x + 1, y, "Desktop", colors.black, colors.lightGray)
  for i, item in ipairs(items) do
    renderer.writeAt(x + 1, y + i, renderer.crop(item.label, menuW - 2), colors.black, colors.lightGray)
  end
end

local function drawTaskbar()
  local w, h = term.getSize()
  renderer.fill(1, h, w, 1, theme.get("taskbarBg"))
  renderer.button(1, h, 8, "Menu", M.menuOpen)
  local searchW = math.min(24, math.max(10, w - 26))
  M.searchBox = { x = 10, y = h, w = searchW }
  local searchBg = M.searchFocused and colors.white or colors.lightGray
  local searchFg = colors.black
  renderer.writeAt(10, h, renderer.crop("?" .. M.search, searchW), searchFg, searchBg)
  local time = textutils.formatTime(os.time(), true)
  renderer.writeAt(w - #time, h, time, theme.get("taskbarFg"), theme.get("taskbarBg"))
end

local function drawSearchKeyboard()
  if not M.searchFocused then return end
  local w, h = term.getSize()
  M.keyboard.x = 1
  M.keyboard.y = math.max(1, h - keyboard.height())
  M.keyboard.hint = "Search: " .. M.search
  keyboard.draw(1, M.keyboard.y, w, M.keyboard)
end

local function drawMenu()
  if not M.menuOpen or not M.apps then return end
  local _, h = term.getSize()
  local appList = M.apps.list()
  if M.search ~= "" then
    local filtered = {}
    local query = M.search:lower()
    for _, app in ipairs(appList) do
      if app.name:lower():find(query, 1, true) or app.id:lower():find(query, 1, true) then
        table.insert(filtered, app)
      end
    end
    appList = filtered
  end
  local height = math.min(#appList + 3, h - 2)
  local menuW = math.min(32, w)
  renderer.fill(1, h - height, menuW, height, colors.lightGray)
  renderer.writeAt(2, h - height, renderer.crop("MintCraft OS", menuW - 2), colors.black, colors.lightGray)
  renderer.writeAt(2, h - height + 1, renderer.crop("Search: " .. M.search, menuW - 2), colors.gray, colors.lightGray)
  for i, app in ipairs(appList) do
    if i <= height - 2 then
      renderer.writeAt(2, h - height + i + 1, renderer.crop(app.icon .. " " .. app.name .. " [" .. app.category .. "]", menuW - 2), colors.black, colors.lightGray)
    end
  end
end

function M.draw()
  local w, h = term.getSize()
  renderer.fill(1, 1, w, h, theme.get("desktopBg"))
  drawIcons()
  drawTaskbar()
  drawMenu()
  drawContextMenu()
  drawSearchKeyboard()
end

local function launch(appId)
  if not M.apps then return end
  local ok, result = M.apps.launch(appId)
  if not ok and M.notifications then
    M.notifications:push("error", "Launch failed", result, 5)
  end
end

local function nextFreePath(base, ext)
  local index = 1
  local path
  repeat
    path = base .. tostring(index) .. ext
    index = index + 1
  until not fs.exists(path)
  return path
end

local function createTextFile()
  local path = nextFreePath("/home/user/desktop/new_file_", ".txt")
  local h = fs.open(path, "w")
  if h then
    h.write("")
    h.close()
    if M.notifications then M.notifications:push("success", "Desktop", fs.getName(path) .. " created", 3) end
  end
end

local function createFolder()
  local path = nextFreePath("/home/user/desktop/new_folder_", "")
  fs.makeDir(path)
  if M.notifications then M.notifications:push("success", "Desktop", fs.getName(path) .. " created", 3) end
end

local function openContextMenu(x, y)
  M.menuOpen = false
  M.contextMenu = {
    x = x,
    y = y,
    items = {
      { label = "New file", action = createTextFile },
      { label = "New folder", action = createFolder },
      { label = "Open Files", action = function() launch("files") end },
      { label = "New Lua file", action = function()
        local path = nextFreePath("/home/user/desktop/new_script_", ".lua")
        local h = fs.open(path, "w")
        if h then h.write("print(\"hello\")\n") h.close() end
        launch("editor", { path = path })
      end },
      { label = "Terminal", action = function() launch("terminal") end },
      { label = "Settings", action = function() launch("settings") end },
      { label = "Devices", action = function() launch("devices") end },
    },
  }
end

M.keyboard.onText = function(ch)
  M.search = M.search .. ch
  M.menuOpen = true
end

M.keyboard.onBackspace = function()
  M.search = M.search:sub(1, -2)
  M.menuOpen = true
end

M.keyboard.onEnter = function()
  local appList = M.apps and M.apps.list() or {}
  local query = M.search:lower()
  for _, app in ipairs(appList) do
    if app.name:lower():find(query, 1, true) or app.id:lower():find(query, 1, true) then
      M.searchFocused = false
      M.search = ""
      M.menuOpen = false
      launch(app.id)
      return
    end
  end
end

M.keyboard.onTab = M.keyboard.onEnter

function M.handle(event)
  if event.name == "char" and M.searchFocused then
    M.search = M.search .. event.args[1]
    M.menuOpen = true
    return true
  elseif event.name == "key" and M.searchFocused then
    local key = event.args[1]
    if key == keys.backspace then
      M.search = string.sub(M.search, 1, -2)
      return true
    elseif key == keys.enter then
      local appList = M.apps and M.apps.list() or {}
      local query = M.search:lower()
      for _, app in ipairs(appList) do
        if app.name:lower():find(query, 1, true) or app.id:lower():find(query, 1, true) then
          M.searchFocused = false
          M.search = ""
          M.menuOpen = false
          launch(app.id)
          return true
        end
      end
    end
    return true
  end

  if event.name ~= "mouse_click" then return false end
  local button, x, y = table.unpack(event.args)
  local w, h = term.getSize()

  if M.searchFocused and event.monitorTouch and keyboard.handle(event, M.keyboard) then
    return true
  end

  if M.contextMenu then
    local menu = M.contextMenu
    local index = y - menu.y
    if button == 1 and x >= menu.x and x < menu.x + 18 and index >= 1 and menu.items[index] then
      local action = menu.items[index].action
      M.contextMenu = nil
      action()
      return true
    end
    M.contextMenu = nil
    return true
  end

  if y == h and x <= 8 then
    M.menuOpen = not M.menuOpen
    M.searchFocused = false
    return true
  end

  if y == h and x >= M.searchBox.x and x < M.searchBox.x + M.searchBox.w then
    M.searchFocused = true
    M.menuOpen = true
    return true
  end

  if M.menuOpen then
    local appList = M.apps and M.apps.list() or {}
    if M.search ~= "" then
      local filtered = {}
      local query = M.search:lower()
      for _, app in ipairs(appList) do
        if app.name:lower():find(query, 1, true) or app.id:lower():find(query, 1, true) then
          table.insert(filtered, app)
        end
      end
      appList = filtered
    end
    local menuTop = h - math.min(#appList + 3, h - 2)
    local index = y - menuTop - 1
    if x <= 32 and index >= 1 and appList[index] then
      M.menuOpen = false
      launch(appList[index].id)
      return true
    end
    M.menuOpen = false
  end

  if button == 2 then
    openContextMenu(x, y)
    return true
  end

  if event.monitorTouch then
    local now = os.clock()
    local last = M.lastMonitorTap
    M.lastMonitorTap = { x = x, y = y, time = now }
    if last and last.x == x and last.y == y and now - last.time < 0.5 then
      openContextMenu(x, y)
      return true
    end
  end

  if button == 1 then
    for _, icon in ipairs(M.icons or {}) do
      if x >= icon.x and x <= icon.x + 12 and y >= icon.y and y <= icon.y + 6 then
        launch(icon.app)
        return true
      end
    end
  end

  return false
end

return M
]],
  ["system/gui/icon.lua"] = [[local renderer = require("system.gui.renderer")

local M = {}

local function fallback(x, y, label, bg)
  renderer.writeAt(x, y, "[" .. renderer.crop(label or "?", 2) .. "]", colors.white, bg or colors.black)
end

function M.draw(path, x, y, fallbackLabel, bg)
  if path and fs.exists(path) and paintutils and paintutils.loadImage and paintutils.drawImage then
    local ok, image = pcall(paintutils.loadImage, path)
    if ok and image then
      local drawn = pcall(paintutils.drawImage, image, x, y)
      if drawn then return true end
    end
  end

  fallback(x, y, fallbackLabel, bg)
  return false
end

return M
]],
  ["system/gui/keyboard.lua"] = [[local renderer = require("system.gui.renderer")

local M = {}

local rows = {
  "1234567890",
  "azertyuiop",
  "qsdfghjklm",
  "wxcvbn",
}

local function ensure(state)
  state.caps = state.caps or false
  state.shift = state.shift or false
  return state
end

function M.height()
  return 6
end

function M.draw(x, y, w, state)
  state = ensure(state or {})
  renderer.fill(x, y, w, M.height(), colors.lightGray)
  for row, chars in ipairs(rows) do
    local line = ""
    for i = 1, #chars do
      local ch = chars:sub(i, i)
      if state.caps or state.shift then ch = ch:upper() end
      line = line .. ch .. " "
    end
    renderer.writeAt(x, y + row - 1, renderer.crop(line, w), colors.black, colors.lightGray)
  end
  local control = w < 48 and "[M] [S] [C] [Tab] [Space] [<] [Enter]" or "[maj] [shift] [ctrl] [tab] [space] [back] [enter]"
  local flags = (state.caps and "CAPS " or "") .. (state.shift and "SHIFT " or "") .. (state.ctrl and "CTRL " or "")
  renderer.writeAt(x, y + 4, renderer.crop(control, w), colors.white, colors.gray)
  renderer.writeAt(x, y + 5, renderer.crop(flags .. (state.hint or ""), w), colors.black, colors.orange)
end

function M.handle(event, state)
  state = ensure(state or {})
  if event.name ~= "mouse_click" then return false end
  local _, x, y = table.unpack(event.args)
  local relY = y - (state.y or 1) + 1
  local relX = x - (state.x or 1) + 1

  if relY >= 1 and relY <= #rows then
    local chars = rows[relY]
    local index = math.floor((relX + 1) / 2)
    local ch = chars:sub(index, index)
    if ch ~= "" then
      if state.caps or state.shift then ch = ch:upper() end
      state.shift = false
      if state.onText then state.onText(ch) end
      return true
    end
  elseif relY == 5 then
    if relX >= 1 and relX <= 5 then
      state.caps = not state.caps
      return true
    elseif relX >= 7 and relX <= 13 then
      state.shift = true
      return true
    elseif relX >= 15 and relX <= 20 then
      state.ctrl = not state.ctrl
      return true
    elseif relX >= 22 and relX <= 27 then
      if state.onTab then state.onTab() end
      return true
    elseif relX >= 29 and relX <= 36 then
      if state.onText then state.onText(" ") end
      return true
    elseif relX >= 38 and relX <= 45 then
      if state.onBackspace then state.onBackspace() end
      return true
    elseif relX >= 47 and relX <= 55 then
      if state.onEnter then state.onEnter() end
      return true
    end
  end
  return false
end

return M
]],
  ["system/gui/renderer.lua"] = [[local theme = require("system.gui.theme")

local M = {}

function M.clear(bg)
  term.setBackgroundColor(bg or theme.get("windowBg"))
  term.clear()
end

function M.writeAt(x, y, text, fg, bg)
  term.setCursorPos(x, y)
  term.setTextColor(fg or theme.get("windowFg"))
  term.setBackgroundColor(bg or theme.get("windowBg"))
  term.write(tostring(text))
end

function M.fill(x, y, w, h, bg)
  term.setBackgroundColor(bg or theme.get("windowBg"))
  for row = y, y + h - 1 do
    term.setCursorPos(x, row)
    term.write(string.rep(" ", w))
  end
end

function M.crop(text, width)
  text = tostring(text or "")
  if #text <= width then return text .. string.rep(" ", width - #text) end
  if width <= 1 then return string.sub(text, 1, width) end
  return string.sub(text, 1, width - 1) .. ">"
end

function M.button(x, y, w, label, active)
  local bg = active and theme.get("accent") or theme.get("buttonBg")
  local fg = active and colors.black or theme.get("buttonFg")
  M.writeAt(x, y, M.crop(" " .. label .. " ", w), fg, bg)
end

return M
]],
  ["system/gui/theme.lua"] = [[local config = require("system.libraries.config")

local M = {}

local themes = {
  mint = {
    desktopBg = colors.green,
    taskbarBg = colors.gray,
    taskbarFg = colors.white,
    windowBg = colors.lightGray,
    windowFg = colors.black,
    titleBg = colors.lime,
    titleFg = colors.black,
    accent = colors.lime,
    buttonBg = colors.gray,
    buttonFg = colors.white,
    error = colors.red,
    warning = colors.orange,
    success = colors.green,
    shadow = colors.black,
  },
  dark = {
    desktopBg = colors.black,
    taskbarBg = colors.gray,
    taskbarFg = colors.white,
    windowBg = colors.gray,
    windowFg = colors.white,
    titleBg = colors.blue,
    titleFg = colors.white,
    accent = colors.cyan,
    buttonBg = colors.lightGray,
    buttonFg = colors.black,
    error = colors.red,
    warning = colors.orange,
    success = colors.lime,
    shadow = colors.black,
  },
}

M.currentId = "mint"
M.current = themes.mint

function M.load()
  local cfg = config.load("/system/config/system.cfg", {})
  M.currentId = cfg.theme or "mint"
  M.current = themes[M.currentId] or themes.mint
end

function M.set(id)
  M.currentId = themes[id] and id or "mint"
  M.current = themes[M.currentId]
  local cfg = config.load("/system/config/system.cfg", {})
  cfg.theme = M.currentId
  config.save("/system/config/system.cfg", cfg)
end

function M.get(name)
  return M.current[name] or themes.mint[name] or colors.white
end

return M
]],
  ["system/kernel/event_bus.lua"] = [[local log = require("system.libraries.log")

local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
  return setmetatable({ listeners = {}, nextId = 1 }, EventBus)
end

function EventBus:on(name, callback)
  self.listeners[name] = self.listeners[name] or {}
  local id = self.nextId
  self.nextId = self.nextId + 1
  table.insert(self.listeners[name], { id = id, callback = callback })
  return id
end

function EventBus:off(id)
  for name, listeners in pairs(self.listeners) do
    for i = #listeners, 1, -1 do
      if listeners[i].id == id then
        table.remove(listeners, i)
        return true
      end
    end
  end
  return false
end

function EventBus:emit(name, ...)
  local listeners = self.listeners[name] or {}
  for _, listener in ipairs(listeners) do
    local ok, err = pcall(listener.callback, ...)
    if not ok then
      log.error("event_bus", tostring(err))
    end
  end
end

return EventBus
]],
  ["system/kernel/kernel.lua"] = [[local EventBus = require("system.kernel.event_bus")
local Scheduler = require("system.kernel.scheduler")
local log = require("system.libraries.log")
local apps = require("system.libraries.apps")
local theme = require("system.gui.theme")
local desktop = require("system.gui.desktop")
local WindowManager = require("system.wm.window_manager")
local ServiceManager = require("system.services.service_manager")
local notifd = require("system.services.notifd")

local M = {}

local function normalize(raw)
  if raw[1] == "monitor_touch" then
    return {
      name = "mouse_click",
      args = { 1, raw[3], raw[4] },
      raw = raw,
      monitorTouch = true,
      monitorSide = raw[2],
    }
  end

  return {
    name = raw[1],
    args = { select(2, table.unpack(raw)) },
    raw = raw,
  }
end

local function bootApps(ctx)
  apps.register("terminal", "Terminal", "apps.terminal.main", { icon = ">_", iconPath = "/system/themes/icons/terminal.nfp", category = "System", version = "0.7.0", permissions = { "filesystem.read", "filesystem.write", "process.list", "process.kill", "system.reboot" } })
  apps.register("browser", "Browser", "apps.browser.main", { icon = "BR", iconPath = "/system/themes/icons/browser.nfp", category = "Internet", version = "0.7.0", permissions = { "network.http" } })
  apps.register("files", "Files", "apps.files.main", { icon = "[]", iconPath = "/system/themes/icons/files.nfp", category = "Files", version = "0.7.0", permissions = { "filesystem.read", "filesystem.write" } })
  apps.register("settings", "Settings", "apps.settings.main", { icon = "##", iconPath = "/system/themes/icons/settings.nfp", category = "System", version = "0.7.0", permissions = { "system.config" } })
  apps.register("taskmanager", "Task Manager", "apps.taskmanager.main", { icon = "PS", iconPath = "/system/themes/icons/taskmanager.nfp", category = "System", version = "0.7.0", permissions = { "process.list", "process.kill" } })
  apps.register("logs", "Logs", "apps.logs.main", { icon = "LG", iconPath = "/system/themes/icons/logs.nfp", category = "System", version = "0.7.0", permissions = { "logs.read" } })
  apps.register("services", "Services", "apps.services.main", { icon = "SV", iconPath = "/system/themes/icons/services.nfp", category = "System", version = "0.7.0", permissions = { "services.list", "services.control" } })
  apps.register("devices", "Devices", "apps.devices.main", { icon = "IO", iconPath = "/system/themes/icons/devices.nfp", category = "Hardware", version = "0.7.0", permissions = { "devices.list" } })
  apps.register("editor", "Editor", "apps.editor.main", { icon = "{}", iconPath = "/system/themes/icons/editor.nfp", category = "Dev", version = "0.7.0", permissions = { "filesystem.read", "filesystem.write", "dev.compile" } })
  apps.register("update", "Update", "apps.update.main", { icon = "UP", iconPath = "/system/themes/icons/update.nfp", category = "System", version = "0.7.0", permissions = { "network.http", "system.update" } })

  desktop.setApps(apps)
  desktop.setWindowManager(ctx.wm)
  desktop.setNotifications(ctx.notifications)
end

function M.start()
  log.info("kernel", "kernel starting")
  theme.load()

  local ctx = {
    eventBus = EventBus.new(),
    scheduler = Scheduler.new(),
    wm = WindowManager.new(),
    notifications = notifd.new(),
  }
  ctx.scheduler.ctx = ctx
  ctx.services = ServiceManager.new(ctx)

  ctx.apps = apps
  ctx.apps.setContext(ctx)
  ctx.services:register("logd", "system.services.logd", true)
  ctx.services:register("networkd", "system.services.networkd", true)
  ctx.services:register("deviced", "system.services.deviced", true)
  ctx.services:register("notifd", "system.services.notifd", true)
  ctx.services:register("updated", "system.services.updated", true)
  ctx.services:startAutostart()
  bootApps(ctx)

  ctx.notifications:push("success", "MintCraft OS", "System ready", 3)
  desktop.draw()
  ctx.wm:draw()
  ctx.notifications:draw()

  while true do
    local raw = { os.pullEventRaw() }
    local event = normalize(raw)

    if event.name == "terminate" then
      ctx.notifications:push("warn", "Terminate", "Use Recovery or reboot from Terminal", 4)
    else
      ctx.eventBus:emit(event.name, table.unpack(event.args))
      if event.name == "peripheral" or event.name == "peripheral_detach" then
        ctx.notifications:push("info", "Devices", "Display refreshed", 2)
      end
      ctx.scheduler:dispatch(event)
      local handled = ctx.wm:handle(event)
      if not handled then desktop.handle(event) end
      ctx.notifications:handle(event)
    end

    desktop.draw()
    ctx.wm:draw()
    ctx.notifications:draw()
  end
end

return M
]],
  ["system/kernel/scheduler.lua"] = [[local log = require("system.libraries.log")

local Scheduler = {}
Scheduler.__index = Scheduler

local function eventMatches(filter, event)
  return filter == nil or filter == event.name
end

function Scheduler.new()
  return setmetatable({ processes = {}, nextPid = 1, ctx = nil }, Scheduler)
end

function Scheduler:spawn(name, fn, meta)
  local pid = self.nextPid
  self.nextPid = self.nextPid + 1

  local process = {
    pid = pid,
    name = name,
    co = coroutine.create(fn),
    state = "ready",
    filter = nil,
    meta = meta or {},
    permissions = (meta and meta.permissions) or {},
    startedAt = os.epoch("utc"),
    window = nil,
  }

  self.processes[pid] = process
  return pid
end

function Scheduler:start(pid)
  local process = self.processes[pid]
  if not process then return false, "No such process" end
  self:resume(process, { name = "mintcraft_start", args = {} })
  return true
end

function Scheduler:resume(process, event)
  if process.state ~= "ready" then return end

  local ok, filterOrErr = coroutine.resume(process.co, event)
  if not ok then
    process.state = "crashed"
    process.error = tostring(filterOrErr)
    log.error("process", process.name .. ": " .. tostring(filterOrErr))
    if process.window then process.window.closed = true end
    if self.ctx and self.ctx.notifications then
      self.ctx.notifications:push("error", "App crashed", process.name, 5)
    end
    return
  end

  if coroutine.status(process.co) == "dead" then
    process.state = "stopped"
  else
    process.filter = filterOrErr
  end
end

function Scheduler:dispatch(event)
  for _, process in pairs(self.processes) do
    if process.state == "ready" and eventMatches(process.filter, event) then
      self:resume(process, event)
    end
  end
end

function Scheduler:kill(pid)
  local process = self.processes[pid]
  if not process then return false, "No such process" end
  process.state = "killed"
  if process.window then process.window.closed = true end
  log.warn("process", "killed " .. process.name .. " #" .. tostring(pid))
  return true
end

function Scheduler:attachWindow(pid, win)
  local process = self.processes[pid]
  if process then process.window = win end
end

function Scheduler:list()
  local rows = {}
  for _, process in pairs(self.processes) do
    table.insert(rows, {
      pid = process.pid,
      name = process.name,
      state = process.state,
      appId = process.meta and process.meta.appId or nil,
      filter = process.filter,
      error = process.error,
      permissions = process.permissions,
      windowId = process.window and process.window.id or nil,
      startedAt = process.startedAt,
    })
  end
  table.sort(rows, function(a, b) return a.pid < b.pid end)
  return rows
end

function Scheduler:makeContext(pid)
  local scheduler = self
  return {
    pid = pid,
    pullEvent = function(filter)
      while true do
        local event = coroutine.yield(filter)
        if not filter or event.name == filter then return event end
      end
    end,
    listProcesses = function()
      return scheduler:list()
    end,
    kill = function(targetPid)
      return scheduler:kill(targetPid)
    end,
  }
end

return Scheduler
]],
  ["system/libraries/apps.lua"] = [[local log = require("system.libraries.log")

local M = {
  registry = {},
  ctx = nil,
}

function M.setContext(ctx)
  M.ctx = ctx
end

function M.register(id, name, module, meta)
  meta = meta or {}
  M.registry[id] = {
    id = id,
    name = name,
    module = module,
    icon = meta.icon or "[]",
    iconPath = meta.iconPath,
    category = meta.category or "System",
    version = meta.version or "0.7.0",
    permissions = meta.permissions or {},
  }
end

function M.get(id)
  return M.registry[id]
end

function M.list()
  local rows = {}
  for _, app in pairs(M.registry) do table.insert(rows, app) end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

function M.launch(id, args)
  local app = M.registry[id]
  if not app then return false, "Unknown app: " .. tostring(id) end
  if not M.ctx then return false, "App context not ready" end

  local ok, mod = pcall(require, app.module)
  if not ok then
    log.error("apps", tostring(mod))
    return false, tostring(mod)
  end

  local scheduler = M.ctx.scheduler
  local pid
  pid = scheduler:spawn(app.name, function(startEvent)
    local procCtx = scheduler:makeContext(pid)
    procCtx.appId = id
    procCtx.args = args or {}
    procCtx.windowManager = {
      create = function(_, opts)
        opts.ownerPid = pid
        local win = M.ctx.wm:create(opts)
        scheduler:attachWindow(pid, win)
        return win
      end,
    }
    procCtx.notifications = M.ctx.notifications
    procCtx.apps = M
    procCtx.system = M.ctx
    mod.run(procCtx, startEvent)
  end, { appId = id, permissions = app.permissions })
  scheduler:start(pid)

  return true, pid
end

return M
]],
  ["system/libraries/config.lua"] = [[local M = {}

function M.load(path, fallback)
  if not fs.exists(path) then return fallback end
  local handle = fs.open(path, "r")
  if not handle then return fallback end
  local data = handle.readAll()
  handle.close()
  local ok, parsed = pcall(textutils.unserialize, data)
  if ok and parsed ~= nil then return parsed end
  return fallback
end

function M.save(path, value)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local handle = fs.open(path, "w")
  if not handle then return false, "Cannot write " .. path end
  handle.write(textutils.serialize(value))
  handle.close()
  return true
end

function M.ensure(path, value)
  if not fs.exists(path) then
    return M.save(path, value)
  end
  return true
end

return M
]],
  ["system/libraries/log.lua"] = [[local M = {}

local LOG_PATH = "/var/logs/system.log"

local function ensure()
  if not fs.exists("/var") then fs.makeDir("/var") end
  if not fs.exists("/var/logs") then fs.makeDir("/var/logs") end
end

function M.write(level, source, message)
  ensure()
  local handle = fs.open(LOG_PATH, "a")
  if handle then
    handle.writeLine(textutils.serialize({
      time = os.date(),
      level = level,
      source = source,
      message = tostring(message),
    }))
    handle.close()
  end
end

function M.info(source, message) M.write("info", source, message) end
function M.warn(source, message) M.write("warn", source, message) end
function M.error(source, message) M.write("error", source, message) end
function M.debug(source, message) M.write("debug", source, message) end

function M.tail(limit)
  limit = limit or 20
  if not fs.exists(LOG_PATH) then return {} end
  local lines = {}
  local handle = fs.open(LOG_PATH, "r")
  while true do
    local line = handle.readLine()
    if not line then break end
    table.insert(lines, line)
    if #lines > limit then table.remove(lines, 1) end
  end
  handle.close()
  return lines
end

return M
]],
  ["system/network/http_client.lua"] = [[local log = require("system.libraries.log")

local M = {
  lastStatus = {
    available = false,
    message = "not checked",
  },
}

local function trim(text)
  return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function M.available()
  return http ~= nil and type(http.get) == "function"
end

function M.check()
  M.lastStatus = {
    available = M.available(),
    message = M.available() and "HTTP available" or "HTTP API disabled",
  }
  return M.lastStatus
end

function M.get(url, opts)
  opts = opts or {}
  url = trim(url)
  if url == "" then return nil, "empty URL" end
  if not url:match("^https?://") then url = "https://" .. url end
  if not M.available() then return nil, "HTTP API disabled" end

  log.info("http", "GET " .. url)
  local ok, handle = pcall(http.get, url, opts.headers)
  if not ok then
    log.error("http", tostring(handle))
    return nil, tostring(handle)
  end
  if not handle then
    log.warn("http", "request failed: " .. url)
    return nil, "request failed"
  end

  local body = handle.readAll() or ""
  local code = handle.getResponseCode and handle.getResponseCode() or 200
  handle.close()
  return {
    url = url,
    code = code,
    body = body,
    size = #body,
  }
end

function M.json(url, opts)
  local response, err = M.get(url, opts)
  if not response then return nil, err end
  if not textutils.unserializeJSON then return nil, "JSON unavailable" end
  local ok, parsed = pcall(textutils.unserializeJSON, response.body)
  if not ok then return nil, tostring(parsed) end
  response.json = parsed
  return response
end

return M
]],
  ["system/network/websocket.lua"] = [[local M = {}

function M.available()
  return http ~= nil and type(http.websocket) == "function"
end

function M.connect(url, headers)
  if not M.available() then return nil, "WebSocket API disabled" end
  if not url:match("^wss?://") then url = "wss://" .. url end
  local ok, socket = pcall(http.websocket, url, headers)
  if not ok then return nil, tostring(socket) end
  return socket
end

return M
]],
  ["system/services/deviced.lua"] = [[local log = require("system.libraries.log")

local M = {
  devices = {},
  redirected = false,
  nativeTerm = nil,
  display = {
    target = "computer",
    scale = nil,
    width = 0,
    height = 0,
    monitorSide = nil,
  },
  ctx = nil,
}

function M.scan()
  local devices = {}
  if peripheral and peripheral.getNames then
    for _, name in ipairs(peripheral.getNames()) do
      devices[name] = {
        name = name,
        type = peripheral.getType(name),
      }
    end
  end
  M.devices = devices
  return devices
end

function M.useMonitor()
  if not peripheral or not peripheral.find then return false end
  local monitor, side = peripheral.find("monitor")
  if not monitor then return false end

  if monitor.setTextScale then monitor.setTextScale(0.5) end
  if monitor.setBackgroundColor then monitor.setBackgroundColor(colors.black) end
  if monitor.clear then monitor.clear() end

  if not M.nativeTerm then M.nativeTerm = term.current() end
  term.redirect(monitor)
  M.redirected = true
  local w, h = term.getSize()
  M.display = {
    target = "monitor",
    scale = 0.5,
    width = w,
    height = h,
    monitorSide = side or "unknown",
  }
  log.info("deviced", "using monitor " .. tostring(M.display.monitorSide) .. " at " .. tostring(w) .. "x" .. tostring(h) .. " scale 0.5")
  return true
end

function M.refreshDisplay()
  M.scan()
  local oldW, oldH = M.display.width, M.display.height
  local ok = M.useMonitor()
  if not ok then
    if M.redirected and M.nativeTerm then
      term.redirect(M.nativeTerm)
    end
    M.redirected = false
    M.getDisplay()
  end

  local d = M.getDisplay()
  if M.ctx and M.ctx.notifications and (d.width ~= oldW or d.height ~= oldH) then
    M.ctx.notifications:push("success", "Display", tostring(d.width) .. "x" .. tostring(d.height), 3)
  end
  return ok
end

function M.isRedirected()
  return M.redirected
end

function M.getDisplay()
  if not M.redirected then
    local w, h = term.getSize()
    M.display = {
      target = "computer",
      scale = nil,
      width = w,
      height = h,
      monitorSide = nil,
    }
  end
  return M.display
end

function M.start(ctx)
  M.ctx = ctx
  M.refreshDisplay()
  if ctx and ctx.eventBus then
    ctx.eventBus:on("peripheral", function()
      M.refreshDisplay()
    end)
    ctx.eventBus:on("peripheral_detach", function()
      M.refreshDisplay()
    end)
  end
  log.info("deviced", "device service ready")
end

function M.stop()
  if M.redirected and M.nativeTerm then
    term.redirect(M.nativeTerm)
    M.redirected = false
    M.getDisplay()
  end
end

function M.list()
  M.scan()
  local rows = {}
  for _, device in pairs(M.devices) do table.insert(rows, device) end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

return M
]],
  ["system/services/logd.lua"] = [[local log = require("system.libraries.log")

local M = {}

function M.start()
  log.info("logd", "log service ready")
end

function M.stop()
  log.info("logd", "log service stopped")
end

return M
]],
  ["system/services/networkd.lua"] = [[local log = require("system.libraries.log")
local httpClient = require("system.network.http_client")
local websocket = require("system.network.websocket")

local M = {
  status = {
    http = false,
    websocket = false,
    message = "not started",
  },
}

function M.refresh()
  local httpStatus = httpClient.check()
  M.status = {
    http = httpStatus.available,
    websocket = websocket.available(),
    message = httpStatus.message,
  }
  return M.status
end

function M.start(ctx)
  local status = M.refresh()
  log.info("networkd", "http=" .. tostring(status.http) .. " websocket=" .. tostring(status.websocket))
  if ctx and ctx.notifications then
    ctx.notifications:push(status.http and "success" or "warn", "Network", status.message, 3)
  end
end

function M.getStatus()
  return M.status
end

return M
]],
  ["system/services/notifd.lua"] = [[local renderer = require("system.gui.renderer")
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
  local w, h = term.getSize()
  local y = 2
  for i = #self.queue, math.max(1, #self.queue - 3), -1 do
    local n = self.queue[i]
    local bg = colors.blue
    if n.level == "error" then bg = theme.get("error") end
    if n.level == "warn" then bg = theme.get("warning") end
    if n.level == "success" then bg = theme.get("success") end
    if y + 2 >= h then break end
    renderer.fill(math.max(1, w - 27), y, 27, 3, bg)
    renderer.writeAt(math.max(1, w - 26), y, renderer.crop(n.title, 25), colors.white, bg)
    renderer.writeAt(math.max(1, w - 26), y + 1, renderer.crop(n.message, 25), colors.white, bg)
    y = y + 4
  end
end

return Notifd
]],
  ["system/services/service_manager.lua"] = [[local log = require("system.libraries.log")

local ServiceManager = {}
ServiceManager.__index = ServiceManager

function ServiceManager.new(ctx)
  return setmetatable({ ctx = ctx, services = {} }, ServiceManager)
end

function ServiceManager:register(name, moduleName, autostart)
  self.services[name] = {
    name = name,
    moduleName = moduleName,
    state = "stopped",
    autostart = autostart ~= false,
  }
end

function ServiceManager:start(name)
  local service = self.services[name]
  if not service then return false, "No such service" end
  if service.state == "running" then return true end

  local ok, mod = pcall(require, service.moduleName)
  if not ok then
    service.state = "crashed"
    service.error = tostring(mod)
    log.error("service", name .. ": " .. tostring(mod))
    return false, tostring(mod)
  end

  service.module = mod
  if mod.start then
    local started, err = pcall(mod.start, self.ctx)
    if not started then
      service.state = "crashed"
      service.error = tostring(err)
      log.error("service", name .. ": " .. tostring(err))
      return false, tostring(err)
    end
  end

  service.state = "running"
  service.error = nil
  log.info("service", name .. " running")
  return true
end

function ServiceManager:stop(name)
  local service = self.services[name]
  if not service then return false, "No such service" end
  if service.module and service.module.stop then pcall(service.module.stop, self.ctx) end
  service.state = "stopped"
  log.info("service", name .. " stopped")
  return true
end

function ServiceManager:startAutostart()
  for name, service in pairs(self.services) do
    if service.autostart then self:start(name) end
  end
end

function ServiceManager:list()
  local rows = {}
  for _, service in pairs(self.services) do
    table.insert(rows, {
      name = service.name,
      state = service.state,
      autostart = service.autostart,
      error = service.error,
    })
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

return ServiceManager
]],
  ["system/services/updated.lua"] = [[local config = require("system.libraries.config")

local M = {
  cfgPath = "/system/config/update.cfg",
  status = {
    localVersion = "unknown",
    remoteVersion = "unknown",
    updateAvailable = false,
    message = "never checked",
  },
}

local function trim(value)
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function readFile(path)
  if not fs.exists(path) then return nil end
  local handle = fs.open(path, "r")
  if not handle then return nil end
  local data = handle.readAll()
  handle.close()
  return data
end

local function httpGet(url)
  if not http or not http.get then return nil, "HTTP API disabled" end
  local ok, handle = pcall(http.get, url)
  if not ok then return nil, tostring(handle) end
  if not handle then return nil, "request failed" end
  local data = handle.readAll()
  handle.close()
  return data
end

function M.loadConfig()
  return config.load(M.cfgPath, {
    repo = "commandant-x/MintCraftOS",
    branch = "main",
    autoCheck = true,
    autoApply = false,
  })
end

function M.localVersion()
  return trim(readFile("/VERSION") or "0.0.0")
end

function M.remoteVersion()
  local cfg = M.loadConfig()
  local url = "https://raw.githubusercontent.com/" .. cfg.repo .. "/" .. cfg.branch .. "/VERSION"
  local data, err = httpGet(url)
  if not data then return nil, err end
  return trim(data)
end

function M.check()
  local cfg = M.loadConfig()
  local localVersion = M.localVersion()
  local remoteVersion, err = M.remoteVersion()

  if not remoteVersion then
    M.status = {
      localVersion = localVersion,
      remoteVersion = "unknown",
      updateAvailable = false,
      message = err or "check failed",
    }
  else
    M.status = {
      localVersion = localVersion,
      remoteVersion = remoteVersion,
      updateAvailable = remoteVersion ~= localVersion,
      message = remoteVersion ~= localVersion and "update available" or "up to date",
    }
  end

  cfg.lastStatus = M.status.message
  cfg.lastLocalVersion = M.status.localVersion
  cfg.lastRemoteVersion = M.status.remoteVersion
  cfg.lastCheckedUptime = os.clock()
  config.save(M.cfgPath, cfg)
  return M.status
end

function M.downloadInstaller()
  local cfg = M.loadConfig()
  local url = "https://raw.githubusercontent.com/" .. cfg.repo .. "/" .. cfg.branch .. "/install.lua"
  local data, err = httpGet(url)
  if not data then return nil, err end

  local path = "/var/tmp/mintcraft_update.lua"
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local handle = fs.open(path, "w")
  if not handle then return nil, "cannot write update installer" end
  handle.write(data)
  handle.close()
  return path
end

function M.apply()
  local path, err = M.downloadInstaller()
  if not path then return false, err end
  local fn, loadErr = loadfile(path)
  if not fn then return false, loadErr end
  local ok, runErr = pcall(fn)
  if not ok then return false, tostring(runErr) end
  return true, "installer finished, reboot required"
end

function M.start(ctx)
  local cfg = M.loadConfig()
  if not cfg.autoCheck then return end

  local ok, status = pcall(M.check)
  if ok and status.updateAvailable and ctx.notifications then
    ctx.notifications:push("info", "Update", "Version " .. status.remoteVersion .. " available", 6)
  elseif not ok and ctx.notifications then
    ctx.notifications:push("warn", "Update", tostring(status), 5)
  end

  if ok and status.updateAvailable and cfg.autoApply then
    local applied, message = M.apply()
    if ctx.notifications then
      ctx.notifications:push(applied and "success" or "error", "Update", tostring(message), 6)
    end
  end
end

return M
]],
  ["system/themes/icons/browser.nfp"] = [[6666666
6fffff6
6f666f6
6fffff6
6f6f6f6
6666666
]],
  ["system/themes/icons/devices.nfp"] = [[3333333
3fffff3
3f333f3
3fffff3
3030303
3333333
]],
  ["system/themes/icons/editor.nfp"] = [[ddddddd
dfffffd
df000fd
dfffffd
df000fd
ddddddd
]],
  ["system/themes/icons/files.nfp"] = [[4440000
4eeee00
4e44440
4eeeee0
4eeeee0
4444440
]],
  ["system/themes/icons/logs.nfp"] = [[1111110
1ffff10
1f11110
1ffff10
1f11110
1111110
]],
  ["system/themes/icons/services.nfp"] = [[bbbbbbb
bff0ffb
b0fff0b
bff0ffb
b0fff0b
bbbbbbb
]],
  ["system/themes/icons/settings.nfp"] = [[7777777
77f7f77
7fffff7
77fff77
7fffff7
77f7f77
]],
  ["system/themes/icons/taskmanager.nfp"] = [[5555555
5f0f0f5
5fffff5
5f0f0f5
5fffff5
5555555
]],
  ["system/themes/icons/terminal.nfp"] = [[8888888
8fffff8
8f000f8
8f0ff08
8fffff8
8888888
]],
  ["system/themes/icons/update.nfp"] = [[2222222
22fff22
2ff0ff2
2200f22
2ff0ff2
22fff22
]],
  ["system/wm/window.lua"] = [[local theme = require("system.gui.theme")
local renderer = require("system.gui.renderer")

local Window = {}
Window.__index = Window

function Window.new(opts)
  local w, h = term.getSize()
  local width = opts.w or math.min(38, w - 8)
  local height = opts.h or math.min(12, h - 5)
  width = math.max(12, math.min(width, w))
  height = math.max(5, math.min(height, h - 1))
  return setmetatable({
    id = opts.id,
    title = opts.title or "Window",
    x = opts.x or 6,
    y = opts.y or 3,
    w = width,
    h = height,
    minimized = false,
    maximized = false,
    closed = false,
    dragging = false,
    movePending = false,
    minimizeBox = nil,
    maximizeBox = nil,
    closeBox = nil,
    previousBounds = nil,
    app = opts.app,
    ownerPid = opts.ownerPid,
  }, Window)
end

function Window:clamp()
  local sw, sh = term.getSize()
  local maxX = math.max(1, sw - self.w + 1)
  local maxY = math.max(1, sh - self.h)
  self.x = math.max(1, math.min(self.x, maxX))
  self.y = math.max(1, math.min(self.y, maxY))
end

function Window:contains(x, y)
  return x >= self.x and x < self.x + self.w and y >= self.y and y < self.y + self.h
end

function Window:titleContains(x, y)
  return y == self.y and x >= self.x and x < self.x + self.w
end

function Window:boxHit(box, x, y)
  return box and x >= box.x and x < box.x + box.w and y == box.y
end

function Window:updateControls()
  local y = self.y
  self.minimizeBox = { x = self.x + self.w - 6, y = y, w = 2 }
  self.maximizeBox = { x = self.x + self.w - 4, y = y, w = 2 }
  self.closeBox = { x = self.x + self.w - 2, y = y, w = 2 }
end

function Window:toggleMaximize()
  if self.maximized and self.previousBounds then
    self.x = self.previousBounds.x
    self.y = self.previousBounds.y
    self.w = self.previousBounds.w
    self.h = self.previousBounds.h
    self.maximized = false
    self.previousBounds = nil
  else
    self.previousBounds = { x = self.x, y = self.y, w = self.w, h = self.h }
    local sw, sh = term.getSize()
    self.x, self.y = 1, 1
    self.w, self.h = sw, math.max(5, sh - 1)
    self.maximized = true
  end
  self:clamp()
end

function Window:draw()
  if self.closed or self.minimized then return end
  self:clamp()
  renderer.fill(self.x + 1, self.y + 1, self.w, self.h, theme.get("shadow"))
  renderer.fill(self.x, self.y, self.w, self.h, theme.get("windowBg"))
  self:updateControls()
  local title = self.movePending and " Tap destination" or (" " .. self.title)
  renderer.writeAt(self.x, self.y, renderer.crop(title, self.w - 7), theme.get("titleFg"), theme.get("titleBg"))
  renderer.writeAt(self.minimizeBox.x, self.y, " -", theme.get("titleFg"), theme.get("titleBg"))
  renderer.writeAt(self.maximizeBox.x, self.y, self.maximized and "[]" or "[]", theme.get("titleFg"), theme.get("titleBg"))
  renderer.writeAt(self.closeBox.x, self.y, " X", theme.get("titleFg"), theme.get("titleBg"))

  if self.app and self.app.draw then
    local target = window.create(term.current(), self.x + 1, self.y + 1, self.w - 2, self.h - 2, false)
    local previous = term.redirect(target)
    term.setBackgroundColor(theme.get("windowBg"))
    term.setTextColor(theme.get("windowFg"))
    term.clear()
    local ok, err = pcall(self.app.draw, self.app, self.w - 2, self.h - 2)
    term.redirect(previous)
    if ok then
      target.setVisible(true)
    else
      renderer.writeAt(self.x + 1, self.y + 1, "Draw error: " .. tostring(err), theme.get("error"), theme.get("windowBg"))
    end
  end
end

function Window:handle(event)
  if self.closed or self.minimized then return false end
  if event.name == "mouse_click" then
    local button, x, y = table.unpack(event.args)
    if self.movePending then
      self.x = x - math.floor(self.w / 2)
      self.y = y
      self.movePending = false
      self:clamp()
      return true
    end
    self:updateControls()
    if button == 1 and self:boxHit(self.closeBox, x, y) then
      self.closed = true
      return true
    elseif button == 1 and self:boxHit(self.minimizeBox, x, y) then
      self.minimized = true
      return true
    elseif button == 1 and self:boxHit(self.maximizeBox, x, y) then
      self:toggleMaximize()
      return true
    elseif button == 1 and self:titleContains(x, y) then
      if event.monitorTouch then
        self.movePending = true
        return true
      end
      self.dragging = { dx = x - self.x, dy = y - self.y }
      return true
    end
  elseif event.name == "mouse_drag" and self.dragging then
    local _, x, y = table.unpack(event.args)
    self.x = x - self.dragging.dx
    self.y = y - self.dragging.dy
    self:clamp()
    return true
  elseif event.name == "mouse_up" then
    self.dragging = false
  end

  if self.app and self.app.handle then
    local localEvent = event
    if event.name:match("^mouse_") then
      local args = { table.unpack(event.args) }
      args[2] = args[2] - self.x
      args[3] = args[3] - self.y
      localEvent = {
        name = event.name,
        args = args,
        raw = event.raw,
        monitorTouch = event.monitorTouch,
        monitorSide = event.monitorSide,
      }
    end
    return self.app:handle(localEvent, self)
  end
  return false
end

return Window
]],
  ["system/wm/window_manager.lua"] = [[local Window = require("system.wm.window")
local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")

local WindowManager = {}
WindowManager.__index = WindowManager

function WindowManager.new()
  return setmetatable({ windows = {}, nextId = 1, taskButtons = {} }, WindowManager)
end

function WindowManager:create(opts)
  opts.id = self.nextId
  self.nextId = self.nextId + 1
  local win = Window.new(opts)
  table.insert(self.windows, win)
  return win
end

function WindowManager:focus(win)
  for i, item in ipairs(self.windows) do
    if item == win then
      table.remove(self.windows, i)
      break
    end
  end
  table.insert(self.windows, win)
end

function WindowManager:draw()
  for i = #self.windows, 1, -1 do
    if self.windows[i].closed then table.remove(self.windows, i) end
  end

  for _, win in ipairs(self.windows) do
    win:draw()
  end

  local w, h = term.getSize()
  local x = 10
  local maxRight = math.max(x, w - 8)
  self.taskButtons = {}
  for _, win in ipairs(self.windows) do
    if not win.closed then
      local label = "[" .. win.title .. "]"
      local width = math.min(#label, 14, maxRight - x)
      if width < 4 then break end
      local bg = win.minimized and theme.get("buttonBg") or theme.get("accent")
      renderer.writeAt(x, h, renderer.crop(label, width), theme.get("taskbarFg"), bg)
      table.insert(self.taskButtons, { x = x, w = width, win = win })
      x = x + width + 1
      if x > maxRight then break end
    end
  end
end

function WindowManager:handle(event)
  if event.name == "mouse_click" then
    local _, x, y = table.unpack(event.args)
    if y == ({ term.getSize() })[2] then
      for _, box in ipairs(self.taskButtons or {}) do
        if x >= box.x and x < box.x + box.w then
          box.win.minimized = false
          self:focus(box.win)
          return true
        end
      end
      return false
    end
    local active = self.windows[#self.windows]
    if active and active.movePending then
      return active:handle(event)
    end
    for i = #self.windows, 1, -1 do
      local win = self.windows[i]
      if win:contains(x, y) then
        self:focus(win)
        return win:handle(event)
      end
    end
  else
    local win = self.windows[#self.windows]
    if win then return win:handle(event) end
  end
  return false
end

return WindowManager
]],
}

local function writeFile(path, content)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local handle = fs.open(path, "w")
  if not handle then error("Cannot write " .. path) end
  handle.write(content)
  handle.close()
end

for path, content in pairs(files) do
  writeFile(path, content)
end

if not fs.exists("home/user/desktop") then fs.makeDir("home/user/desktop") end
if not fs.exists("home/user/.trash") then fs.makeDir("home/user/.trash") end
print("MintCraft OS 0.7.0 installed.")
print("Run reboot() to start MintCraft OS.")
