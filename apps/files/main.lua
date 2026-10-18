local renderer = require("system.gui.renderer")
local keyboard = require("system.gui.keyboard")
local config = require("system.libraries.config")
local ui = require("system.gui.components")
local fileNames = require("system.libraries.file_names")
local safeWrite = require("system.libraries.safe_write")
local theme = require("system.gui.theme")

local M = {}
local trash = "/home/user/.trash"
local metadata = trash .. "/.mintcraft-metadata"

local function sortedList(path)
  local rows = {}
  local directories = {}
  if fs.exists(path) and fs.isDir(path) then
    for _, name in ipairs(fs.list(path)) do
      if path ~= trash or name ~= ".mintcraft-metadata" then
        table.insert(rows, name)
        directories[name] = fs.isDir(fs.combine(path, name))
      end
    end
  end
  table.sort(rows, function(a, b)
    local ad = directories[a]
    local bd = directories[b]
    if ad ~= bd then return ad end
    return a:lower() < b:lower()
  end)
  return rows, directories
end

local function parent(path)
  local dir = fs.getDir(path)
  if dir == "" then return "/" end
  return fileNames.absolute(dir)
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
  local name = fs.getName(path)
  local candidate = fs.combine(trash, name)
  local i = 1
  while fs.exists(candidate) or fs.exists(fs.combine(metadata, fs.getName(candidate))) do
    candidate = fs.combine(trash, name .. "." .. tostring(i))
    i = i + 1
  end
  return candidate
end

local function isProtected(path)
  return fileNames.protected(path)
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
    path = fileNames.absolute(ctx.args.path or "/home/user"),
    selected = nil,
    scroll = 1,
    mode = nil,
    input = "",
    confirm = nil,
    keyboard = {},
    history = {},
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
    { label = "Delete forever", id = "delete_forever" },
    { label = "Empty trash", id = "empty_trash" },
    { label = "Refresh", id = "refresh" },
  }
  local toolbar = {}
  local toolbarState = {first = 1}

  local function allowed(permission, path)
    local ok, reason = ctx.security.require("filesystem." .. permission, path)
    if not ok then error(reason or ("Permission denied: " .. permission), 0) end
  end

  local function writable(path)
    path = fileNames.absolute(path)
    allowed("read", path)
    allowed("write", path)
    if isProtected(path) or path == trash or path == metadata or path:sub(1, #metadata + 1) == metadata .. "/" then
      error("Protected path", 0)
    end
    return path
  end

  local function attempt(fn, ...)
    local ok, problem = pcall(fn, ...)
    if not ok then ctx.notifications:push("error", "Files", tostring(problem), 4) end
    return ok
  end

  -- Persist the original path before the move; interrupted moves retain recovery metadata.
  local function moveToTrash(from)
    writable(from)
    if from:sub(1, #trash + 1) == trash .. "/" then error("Use Delete forever inside trash", 0) end
    allowed("write", trash)
    allowed("read", trash)
    allowed("read", metadata)
    allowed("write", metadata)
    if not fs.exists(metadata) then fs.makeDir(metadata) end
    local to = trashPath(from)
    local info = fs.combine(metadata, fs.getName(to))
    allowed("write", to)
    allowed("write", info)
    local ok, reason = safeWrite.write(info, textutils.serialize({original = from, name = fs.getName(from)}))
    if not ok then error("Cannot record trash location: " .. tostring(reason), 0) end
    fs.move(from, to)
  end

  local function restore(from)
    writable(from)
    local info = fs.combine(metadata, fs.getName(from))
    allowed("read", info)
    local to
    if fs.exists(info) then
      local h = assert(fs.open(info, "r"), "Cannot read trash metadata")
      local content = h.readAll()
      h.close()
      local data = textutils.unserialize(content)
      if type(data) ~= "table" or type(data.original) ~= "string" or type(data.name) ~= "string"
        or fs.getName(data.original) ~= data.name or fileNames.absolute(data.original) ~= data.original then
        error("Invalid trash metadata; item retained", 0)
      end
      to = data.original
    else
      -- Legacy trash entries have no original location. Preserve their exact names.
      to = fs.combine("/home/user", fs.getName(from))
    end
    to = writable(to)
    if to:sub(1, #trash + 1) == trash .. "/" then error("Invalid restore location", 0) end
    if fs.exists(to) then error("Restore target already exists; item retained", 0) end
    local dir = fs.getDir(to)
    allowed("write", dir)
    if not fs.exists(dir) then fs.makeDir(dir) end
    allowed("write", info)
    fs.move(from, to)
    if fs.exists(info) then fs.delete(info) end
    ctx.notifications:push("success", "Files", "Restored to " .. to, 3)
  end

  local function deleteForever(path)
    writable(path)
    local info = fs.combine(metadata, fs.getName(path))
    local trashed = parent(path) == trash
    if trashed then allowed("read", info) allowed("write", info) end
    fs.delete(path)
    if trashed and fs.exists(info) then fs.delete(info) end
  end

  local function refresh()
    local ok, rows, directories = pcall(function()
      allowed("read", app.path)
      return sortedList(app.path)
    end)
    if not ok then
      ctx.notifications:push("error", "Files", "Cannot read folder: " .. tostring(rows), 4)
      app.files, app.directories = {}, {}
      return false
    end
    app.files, app.directories = rows, directories
    app.scroll = math.max(1, math.min(app.scroll, math.max(1, #rows)))
    return true
  end
  refresh()

  local function setMode(mode, default)
    app.mode = mode
    app.input = default or ""
    app.keyboard.hint = mode and (mode .. ": " .. app.input) or ""
  end

  local function selectedPath()
    if not app.selected then return nil end
    return fileNames.absolute(fs.combine(app.path, app.selected))
  end

  local function navigate(path, backwards)
    path = fileNames.absolute(path)
    allowed("read", path)
    if not fs.exists(path) or not fs.isDir(path) then
      ctx.notifications:push("warn", "Files", "Folder is no longer available", 3)
      return false
    end
    if path ~= app.path and not backwards then
      table.insert(app.history, app.path)
      if #app.history > 100 then table.remove(app.history, 1) end
    end
    app.path, app.selected, app.scroll = path, nil, 1
    app.mode, app.confirm = nil, nil
    refresh()
    return true
  end

  local function openFile(path)
    path = fileNames.absolute(path)
    allowed("read", path)
    if fs.isDir(path) then
      navigate(path)
      return
    end
    allowed("read", "/system/config/mime.db")
    local target = mimeApp(path)
    if target then
      ctx.apps.launch(target, { path = path })
    else
      ctx.notifications:push("warn", "Files", "No app for ." .. extOf(path), 3)
    end
  end

  local function submitInput()
    if not app.mode then return end
    local function target(name)
      allowed("read", app.path)
      local path, problem = fileNames.target(app.path, name)
      if not path then ctx.notifications:push("warn", "Files", problem, 3) end
      return path
    end
    if app.mode == "new_file" then
      local name = app.input ~= "" and app.input or basename(uniquePath(app.path, "new_file_", ".txt"))
      local path = target(name)
      if not path then return end
      writable(path)
      local h = fs.open(path, "w")
      if not h then ctx.notifications:push("error", "Files", "Cannot create file", 3) return end
      h.close()
      app.selected = name
    elseif app.mode == "new_dir" then
      local name = app.input ~= "" and app.input or basename(uniquePath(app.path, "new_folder_", ""))
      local path = target(name)
      if not path then return end
      writable(path)
      fs.makeDir(path)
      app.selected = name
    elseif app.mode == "rename" and app.selected then
      local old = fs.combine(app.path, app.selected)
      writable(old)
      if app.path == trash then error("Restore trash items before renaming", 0) end
      local new = target(app.input)
      if not new then return end
      writable(new)
      if app.input ~= "" and not fs.exists(new) then
        fs.move(old, new)
        app.selected = app.input
      else
        ctx.notifications:push("warn", "Files", "Invalid rename target", 3)
      end
    end
    setMode(nil)
    refresh()
  end

  local function perform(action)
    if action == "back" then
      local path = app.history[#app.history]
      if path and navigate(path, true) then table.remove(app.history) end
    elseif action == "up" then
      navigate(parent(app.path))
    elseif action == "home" then
      navigate("/home/user")
    elseif action == "new_file" then
      allowed("read", app.path)
      setMode("new_file", basename(uniquePath(app.path, "new_file_", ".txt")))
    elseif action == "new_dir" then
      allowed("read", app.path)
      setMode("new_dir", basename(uniquePath(app.path, "new_folder_", "")))
    elseif action == "rename" then
      if app.selected then setMode("rename", app.selected) end
    elseif action == "delete" then
      if app.selected then
        local full = selectedPath()
        if isProtected(full) or full == trash then
          ctx.notifications:push("error", "Files", "Protected path", 3)
        else
          writable(full)
          app.confirm = (app.path == trash or app.path:sub(1,#trash+1) == trash .. "/") and "delete_forever" or "trash"
          app.confirmPath = full
        end
      end
    elseif action == "restore" then
      if app.selected and app.path == "/home/user/.trash" then
        local from = selectedPath()
        restore(from)
        app.selected = nil
        refresh()
      end
    elseif action == "delete_forever" and app.selected then
      app.confirmPath = writable(selectedPath())
      app.confirm = "delete_forever"
    elseif action == "empty_trash" then
      allowed("read", trash)
      allowed("write", trash)
      app.confirm, app.confirmPath = "empty_trash", trash
    elseif action == "refresh" then
      app.scroll = 1
      refresh()
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
  app.keyboard.onEnter = function() attempt(submitInput) end
  app.keyboard.onTab = app.keyboard.onEnter

  function app:draw(w, h)
    if w < 1 or h < 1 then return end
    if self.confirm then
      toolbar = ui.toolbar(1, 1, w, {{id="confirm",label="Confirm"},{id="cancel",label="Cancel"}})
    elseif self.mode then
      toolbar = ui.toolbar(1, 1, w, {{id = "cancel", label = "Cancel"}})
    else
      toolbar = ui.toolbar(1, 1, w, actions, toolbarState)
    end
    if h >= 2 then renderer.writeAt(1, 2, renderer.crop("Path: " .. self.path, w), theme.get("windowFg"), theme.get("windowBg")) end
    local files = self.files
    local kbH = self.mode and h >= keyboard.height() + 5 and keyboard.height() or 0
    local listTop = 3
    local listH = math.max(0, h - listTop - kbH)
    self.listBottom = listTop + listH - 1
    ui.list(1, listTop, w, listH, files, self.selected, self.scroll, function(name)
      local prefix = self.directories[name] and "[D] " or "[F] "
      return prefix .. name
    end)
    if self.confirm then
      local verb = self.confirm == "trash" and "Move to trash" or self.confirm == "empty_trash" and "Empty trash forever" or "Delete forever"
      if h >= 2 then renderer.writeAt(1, h, renderer.crop(verb .. " " .. tostring(self.confirmPath) .. "?", w), theme.get("buttonFg"), theme.get("error")) end
    elseif self.mode then
      self.keyboard.x = 1
      self.keyboard.y = h - kbH + 1
      if kbH > 0 then keyboard.draw(1, self.keyboard.y, w, self.keyboard) else self.keyboard.boxes = {} end
      if h >= 3 then renderer.writeAt(1, h - kbH, renderer.crop(tostring(self.mode) .. ": " .. self.input, w), theme.get("buttonFg"), theme.get("buttonBg")) end
    end
  end

  function app:handle(event)
    if self.confirm and event.name == "key" and event.args[1] == keys.escape then self.confirm = nil return true end
    if self.confirm and event.name ~= "mouse_click" then return true end
    if event.name == "key" then
      local key = event.args[1]
      if self.mode then
        if key == keys.escape then
          setMode(nil)
          return true
        elseif key == keys.backspace then
          self.input = self.input:sub(1, -2)
          self.keyboard.hint = tostring(self.mode) .. ": " .. self.input
          return true
        elseif key == keys.enter or key == keys.tab then
          attempt(submitInput)
          return true
        end
      end
      if key == keys.backspace then attempt(perform, "back") return true end
      if key == keys.enter and self.selected then attempt(openFile, selectedPath()) return true end
    elseif event.name == "char" and self.mode then
      self.input = self.input .. event.args[1]
      return true
    elseif event.name == "mouse_click" then
      local _, x, y = table.unpack(event.args)
      if self.mode and event.monitorTouch and keyboard.handle(event, self.keyboard) then return true end
      local action
      if y == 1 then
        for _, box in ipairs(toolbar) do
          if ui.hit(box, x, y) then
            if box.delta then
              toolbarState.first = math.max(1, math.min(#actions, toolbarState.first + box.delta))
              return true
            end
            action = box.id
            break
          end
        end
      end
      if self.confirm then
        if action == "confirm" then
          local succeeded = attempt(function()
            if self.confirm == "trash" then moveToTrash(self.confirmPath)
            elseif self.confirm == "empty_trash" then
              allowed("read", trash)
              allowed("write", trash)
              local names = sortedList(trash)
              -- Preflight the entire batch before deleting any item.
              for _, name in ipairs(names) do
                writable(fs.combine(trash, name))
                allowed("read", fs.combine(metadata, name))
                allowed("write", fs.combine(metadata, name))
              end
              for _, name in ipairs(names) do
                local path = fs.combine(trash, name)
                fs.delete(path)
                local info = fs.combine(metadata, name)
                if fs.exists(info) then fs.delete(info) end
              end
            else deleteForever(self.confirmPath) end
          end)
          if succeeded then self.selected, self.confirm = nil, nil end
          refresh()
        elseif action == "cancel" then self.confirm = nil end
        return true
      end
      if action == "cancel" then setMode(nil) return true end
      if action then attempt(perform, action) return true end
      if not self.mode and y >= 3 and y <= (self.listBottom or 2) then
        local files = self.files
        local name = files[self.scroll + y - 3]
        if name then
          if self.selected == name then attempt(openFile, fs.combine(self.path, name)) else self.selected = name end
          return true
        end
      end
    elseif event.name == "mouse_scroll" then
      local dir = event.args[1]
      local visible = math.max(1, (self.listBottom or 3) - 2)
      self.scroll = math.max(1, math.min(math.max(1, #self.files - visible + 1), self.scroll + dir))
      return true
    end
    return false
  end

  if ctx.args.action=="new_file" or ctx.args.action=="new_dir" then attempt(perform,ctx.args.action)
  elseif ctx.args.action=="new_lua" then attempt(function()
    allowed("read",app.path)
    setMode("new_file",basename(uniquePath(app.path,"new_script_",".lua")))
  end) end
  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Files", w = math.min(72, sw - 4), h = math.min(24, sh - 3), x = 6, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
