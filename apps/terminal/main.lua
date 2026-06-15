local renderer = require("system.gui.renderer")
local log = require("system.libraries.log")

local M = {}

local function append(app, line)
  table.insert(app.lines, line)
  if #app.lines > 200 then table.remove(app.lines, 1) end
end

local function runCommand(app, ctx, input)
  append(app, "> " .. input)
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
  elseif cmd == "cat" then
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
    local ok, err = ctx.kill(pid)
    append(app, ok and "killed" or err)
  elseif cmd == "logs" then
    for _, line in ipairs(log.tail(10)) do append(app, line) end
  elseif cmd == "files" then
    ctx.apps.launch("files")
  elseif cmd == "settings" then
    ctx.apps.launch("settings")
  elseif cmd == "devices" then
    ctx.apps.launch("devices")
  elseif cmd == "reboot" then
    os.reboot()
  elseif cmd == "help" then
    append(app, "Commands: ls cd cat clear ps kill logs files settings devices reboot help")
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
  }

  local commands = { "ls", "cd", "cat", "clear", "ps", "kill", "logs", "files", "settings", "devices", "reboot", "help" }

  local quick = {
    { label = "ls", text = "ls" },
    { label = "cd home", text = "cd /home/user" },
    { label = "files", text = "files" },
    { label = "ps", text = "ps" },
    { label = "logs", text = "logs" },
    { label = "clear", text = "clear" },
  }

  local keysRows = {
    "1234567890",
    "azertyuiop",
    "qsdfghjklm",
    "wxcvbn",
  }

  local function currentWord()
    return app.input:match("([%w_%-/%.]+)$") or ""
  end

  local function updateSuggestion()
    local prefix = currentWord()
    app.suggestion = nil
    if prefix == "" then return end
    for _, cmd in ipairs(commands) do
      if cmd:sub(1, #prefix) == prefix then app.suggestion = cmd return end
    end
    local dir = app.cwd
    local part = prefix
    if prefix:find("/") then
      dir = fs.getDir(fs.combine(app.cwd, prefix))
      part = fs.getName(prefix)
    end
    if fs.exists(dir) and fs.isDir(dir) then
      for _, name in ipairs(fs.list(dir)) do
        if name:sub(1, #part) == part then app.suggestion = name return end
      end
    end
  end

  local function acceptSuggestion()
    updateSuggestion()
    if not app.suggestion then return false end
    local prefix = currentWord()
    app.input = app.input:sub(1, #app.input - #prefix) .. app.suggestion
    app.suggestion = nil
    return true
  end

  local function keyboardTop(h)
    return math.max(3, h - 6)
  end

  local function submit()
    local input = app.input
    app.input = ""
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

  local function hitKeyboard(x, y, h)
    local top = keyboardTop(h)
    local row = y - top + 1
    if row >= 1 and row <= #keysRows then
      local chars = keysRows[row]
      local index = math.floor((x + 1) / 2)
      local ch = chars:sub(index, index)
      if ch ~= "" then
        if app.caps or app.shift then ch = ch:upper() end
        app.shift = false
        app.input = app.input .. ch
        updateSuggestion()
        return true
      end
    elseif y == top + 4 then
      if x >= 1 and x <= 5 then
        app.caps = not app.caps
        return true
      elseif x >= 7 and x <= 12 then
        app.shift = true
        return true
      elseif x >= 14 and x <= 19 then
        return acceptSuggestion()
      elseif x >= 21 and x <= 28 then
        app.input = app.input .. " "
        return true
      elseif x >= 30 and x <= 37 then
        app.input = string.sub(app.input, 1, -2)
        updateSuggestion()
        return true
      elseif x >= 39 and x <= 47 then
        submit()
        return true
      end
    end
    return false
  end

  function app:draw(w, h)
    self.lastH = h
    updateSuggestion()
    local top = keyboardTop(h)
    local logHeight = math.max(1, top - 3)
    local cursor = 1
    for _, item in ipairs(quick) do
      local label = " " .. item.label .. " "
      renderer.writeAt(cursor, 1, renderer.crop(label, #label), colors.white, colors.gray)
      cursor = cursor + #label + 1
      if cursor > w then break end
    end

    local start = math.max(1, #self.lines - logHeight + 1)
    local y = 2
    for i = start, #self.lines do
      renderer.writeAt(1, y, renderer.crop(self.lines[i], w), colors.black, colors.lightGray)
      y = y + 1
      if y >= top - 1 then break end
    end
    local prompt = self.cwd .. "> " .. self.input
    if self.suggestion then prompt = prompt .. "  [tab " .. self.suggestion .. "]" end
    renderer.writeAt(1, top - 1, renderer.crop(prompt, w), colors.white, colors.gray)

    for row, chars in ipairs(keysRows) do
      local line = ""
      for i = 1, #chars do line = line .. chars:sub(i, i) .. " " end
      renderer.writeAt(1, top + row - 1, renderer.crop(line, w), colors.black, colors.lightGray)
    end
    renderer.writeAt(1, top + 4, renderer.crop("[maj] [shift] [tab] [space] [back] [enter]", w), colors.white, colors.gray)
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
      end
    elseif event.name == "mouse_click" and event.monitorTouch then
      local _, x, y = table.unpack(event.args)
      local h = self.lastH or 12
      if hitQuick(x, y) then return true end
      if hitKeyboard(x, y, h) then return true end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Terminal", w = math.min(72, sw - 4), h = math.min(24, sh - 3), x = 4, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
