-- Run in a disposable CraftOS-PC directory with /source mounted read-only.
local function write(path, value)
  local h = assert(fs.open(path, "w"))
  h.write(value)
  h.close()
end
local function read(path)
  local h = assert(fs.open(path, "r"))
  local value = h.readAll()
  h.close()
  return value
end
local ok, err = pcall(function()
  shell.setDir("/")
  assert(shell.run("/source/install.lua"))
  fs.makeDir("/home/user/files-test")
  local ui = require("system.gui.components")
  local originalToolbar = ui.toolbar
  local boxes
  ui.toolbar = function(...)
    boxes = originalToolbar(...)
    return boxes
  end
  local app
  local surface = window.create(term.current(), 1, 1, 47, 16, false)
  local notices = {}
  local ctx = {
    args = {path = "home/user/files-test"},
    notifications = {push = function(_, kind, title, message) notices[#notices + 1] = message end},
    apps = {launch = function() return true end},
    pullEvent = function() coroutine.yield() end,
    windowManager = {create = function(_, opts) app = opts.app return {closed = false} end},
  }
  local co = coroutine.create(function() require("apps.files.main").run(ctx) end)
  assert(coroutine.resume(co))
  local function draw()
    local previous = term.redirect(surface)
    local originalList, originalIsDir = fs.list, fs.isDir
    fs.list = function() error("directory listing during draw") end
    fs.isDir = function() error("directory stat during draw") end
    local drawn, problem = pcall(app.draw, app, 47, 16)
    fs.list, fs.isDir = originalList, originalIsDir
    term.redirect(previous)
    assert(drawn, tostring(problem))
  end
  local function click(box)
    assert(app:handle({name = "mouse_click", args = {1, box.x, box.y}, monitorTouch = true}))
  end
  local function action(id)
    for attempt = 1, 12 do
      draw()
      local nextBox
      for _, box in ipairs(boxes) do
        if box.id == id then click(box) return end
        if box.delta == 1 then nextBox = box end
      end
      assert(nextBox, "missing action " .. id)
      click(nextBox)
    end
    error("action not reachable: " .. id)
  end
  local function resetToolbar()
    for i = 1, 12 do
      draw()
      for _, box in ipairs(boxes) do if box.delta == -1 then click(box) break end end
    end
  end
  local function typeName(value)
    local function tap(id, text)
      draw()
      for _, box in ipairs(app.keyboard.boxes) do
        if box.id == id and (not text or box.text == text) then click(box) return end
      end
      error("missing keyboard key " .. tostring(text or id))
    end
    while #app.input > 0 do tap("back") end
    for i = 1, #value do tap("text", value:sub(i, i)) end
    tap("enter")
  end
  action("home")
  assert(app.path == "/home/user")
  action("back")
  assert(app.path == "/home/user/files-test", "Back did not restore previous location")
  action("up")
  assert(app.path == "/home/user")
  action("back")
  assert(app.path == "/home/user/files-test", "Up was not added to navigation history")
  action("new_file")
  typeName("sample.txt")
  assert(fs.exists("/home/user/files-test/sample.txt"))
  write("/home/user/files-test/sample.txt", "keep this content")
  resetToolbar()
  action("new_file")
  typeName("sample.txt")
  assert(read("/home/user/files-test/sample.txt") == "keep this content", "creation overwrote existing file")
  assert(app.mode == "new_file", "invalid input dialog was dismissed")
  action("cancel")
  assert(app.mode == nil, "Cancel failed")
  action("rename")
  typeName("renamed.txt")
  assert(read("/home/user/files-test/renamed.txt") == "keep this content")
  action("delete")
  assert(app.confirm == "trash", "user file classified as permanent deletion")
  action("delete")
  assert(not fs.exists("/home/user/files-test/renamed.txt"))
  assert(read("/home/user/.trash/renamed.txt") == "keep this content")
  app.path, app.selected = "/home/user/.trash", "renamed.txt"
  action("restore")
  assert(read("/home/user/renamed.txt") == "keep this content")
  app.path, app.selected = "/", "system"
  resetToolbar()
  action("delete")
  assert(not app.confirm and fs.exists("/system"), "system path accepted for deletion")
  write("/files-result.txt", "PASS: paged actions, create, overwrite refused, rename, trash, restore, protected system")
end)
if not ok then write("/files-result.txt", "FAIL: " .. tostring(err)) end
os.shutdown()
