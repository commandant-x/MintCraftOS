local renderer = require("system.gui.renderer")
local keyboard = require("system.gui.keyboard")
local config = require("system.libraries.config")

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
    { label = "Refresh", id = "refresh" },
  }

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
      if app.selected then app.confirm = "delete" end
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
    local cursor = 1
    for _, action in ipairs(actions) do
      local label = " " .. action.label .. " "
      renderer.writeAt(cursor, 1, renderer.crop(label, #label), colors.white, colors.gray)
      cursor = cursor + #label + 1
      if cursor > w then break end
    end
    renderer.writeAt(1, 2, renderer.crop("Path: " .. self.path, w), colors.black, colors.lightGray)
    local files = sortedList(self.path)
    local kbH = self.mode and keyboard.height() or 0
    local listTop = 3
    local listH = math.max(1, h - listTop - kbH)
    for i = 1, listH do
      local index = self.scroll + i - 1
      local name = files[index]
      if name then
        local full = fs.combine(self.path, name)
        local prefix = fs.isDir(full) and "[D] " or "[F] "
        local bg = name == self.selected and colors.cyan or colors.lightGray
        renderer.writeAt(1, listTop + i - 1, renderer.crop(prefix .. name, w), colors.black, bg)
      end
    end
    if self.confirm == "delete" then
      renderer.writeAt(1, h, renderer.crop("Confirm delete " .. tostring(self.selected) .. "? [Delete] again / any other tap cancels", w), colors.white, colors.red)
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
      local action = y == 1 and toolbarHit(x) or nil
      if self.confirm then
        if action == "delete" and self.selected then
          fs.delete(fs.combine(self.path, self.selected))
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
