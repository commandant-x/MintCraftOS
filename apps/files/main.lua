local renderer = require("system.gui.renderer")
local keyboard = require("system.gui.keyboard")
local config = require("system.libraries.config")
local ui = require("system.gui.components")
local fileNames = require("system.libraries.file_names")

local M = {}

local function sortedList(path)
  local rows = {}
  local directories = {}
  if fs.exists(path) and fs.isDir(path) then
    for _, name in ipairs(fs.list(path)) do
      table.insert(rows, name)
      directories[name] = fs.isDir(fs.combine(path, name))
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
    { label = "Refresh", id = "refresh" },
  }
  local toolbar = {}
  local toolbarState = {first = 1}

  local function refresh()
    local ok, rows, directories = pcall(sortedList, app.path)
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
    if fs.isDir(path) then
      navigate(path)
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
    local function target(name)
      local path, problem = fileNames.target(app.path, name)
      if not path then ctx.notifications:push("warn", "Files", problem, 3) end
      return path
    end
    if app.mode == "new_file" then
      local name = app.input ~= "" and app.input or basename(uniquePath(app.path, "new_file_", ".txt"))
      local path = target(name)
      if not path then return end
      local h = fs.open(path, "w")
      if not h then ctx.notifications:push("error", "Files", "Cannot create file", 3) return end
      h.close()
      app.selected = name
    elseif app.mode == "new_dir" then
      local name = app.input ~= "" and app.input or basename(uniquePath(app.path, "new_folder_", ""))
      local path = target(name)
      if not path then return end
      fs.makeDir(path)
      app.selected = name
    elseif app.mode == "rename" and app.selected then
      local old = fs.combine(app.path, app.selected)
      if isProtected(old) then ctx.notifications:push("error", "Files", "Protected path", 3) return end
      local new = target(app.input)
      if not new then return end
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
        local restoredName = app.selected:gsub("%.%d+$", "")
        local to = fs.combine("/home/user", restoredName)
        if fs.exists(from) and not fs.exists(to) then
          fs.move(from, to)
          ctx.notifications:push("success", "Files", "Restored to /home/user", 3)
          app.selected = nil
          refresh()
        else
          ctx.notifications:push("warn", "Files", "Cannot restore", 3)
        end
      end
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
  app.keyboard.onEnter = submitInput
  app.keyboard.onTab = submitInput

  function app:draw(w, h)
    if self.mode then
      toolbar = ui.toolbar(1, 1, w, {{id = "cancel", label = "Cancel"}})
    else
      toolbar = ui.toolbar(1, 1, w, actions, toolbarState)
    end
    renderer.writeAt(1, 2, renderer.crop("Path: " .. self.path, w), colors.black, colors.lightGray)
    local files = self.files
    local kbH = self.mode and keyboard.height() or 0
    local listTop = 3
    local listH = math.max(1, h - listTop - kbH)
    self.listBottom = listTop + listH - 1
    ui.list(1, listTop, w, listH, files, self.selected, self.scroll, function(name)
      local prefix = self.directories[name] and "[D] " or "[F] "
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
        if key == keys.escape then
          setMode(nil)
          return true
        elseif key == keys.backspace then
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
          refresh()
        end
        self.confirm = nil
        return true
      end
      if action == "cancel" then setMode(nil) return true end
      if action then perform(action) return true end
      if not self.mode and y >= 3 and y <= (self.listBottom or 2) then
        local files = self.files
        local name = files[self.scroll + y - 3]
        if name then
          if self.selected == name then openFile(fs.combine(self.path, name)) else self.selected = name end
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

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Files", w = math.min(72, sw - 4), h = math.min(24, sh - 3), x = 6, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
