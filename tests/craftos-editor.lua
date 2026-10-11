-- Run only in a disposable CraftOS-PC directory.
local function write(path, content)
  local h = assert(fs.open(path, "w"))
  h.write(content)
  h.close()
end
local function read(path)
  local h = assert(fs.open(path, "r"))
  local data = h.readAll()
  h.close()
  return data
end
local ok, err = pcall(function()
  shell.setDir("/")
  assert(shell.run("/source/install.lua"))
  local path = "/home/user/editor-test.lua"
  write(path, "original")
  local app
  local ctx = {pid = 91, args = {path = path},
    windowManager = {create = function(_, opts) app = opts.app return {closed = false} end},
    pullEvent = function() coroutine.yield() end,
  }
  local co = coroutine.create(function() require("apps.editor.main").run(ctx) end)
  local started, problem = coroutine.resume(co)
  assert(started, tostring(problem))
  app.lines = {"error('compile must not execute')"}
  app:handle({name = "mouse_click", args = {1, 9, 1}})
  assert(app.status == "Compile OK", app.status)
  assert(read(path) == "original", "compile changed source file")
  assert(not fs.exists("/var/tmp/editor_compile_91.lua"))
  app:handle({name = "mouse_click", args = {1, 2, 1}})
  assert(app.status == "Saved", app.status)
  assert(read(path) == app.lines[1])
  assert(not fs.exists(path .. ".mintcraft-save"))
  app.lines = {"local ="}
  app:handle({name = "mouse_click", args = {1, 9, 1}})
  assert(app.status ~= "Compile OK" and app.status:find("expected", 1, true), app.status)
  fs.makeDir(path .. ".mintcraft-save")
  app.lines = {"unsaved text"}
  app:handle({name = "mouse_click", args = {1, 2, 1}})
  assert(app.status:find("Save failed", 1, true), app.status)
  assert(app.lines[1] == "unsaved text")
  assert(read(path) == "error('compile must not execute')")
  assert(fs.exists(path .. ".mintcraft-save"))
  write("/editor-result.txt", "PASS: save and readback, compile without execution, invalid Lua error, interrupted save preserves disk and buffer")
end)
if not ok then write("/editor-result.txt", "FAIL: " .. tostring(err)) end
os.shutdown()
