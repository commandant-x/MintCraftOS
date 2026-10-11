-- Run only in a disposable CraftOS-PC directory with /source mounted read-only.
local function result(message)
  local h = assert(fs.open("/launcher-result.txt", "w"))
  h.write(message)
  h.close()
end
local ok, err = pcall(function()
  shell.setDir("/")
  assert(shell.run("/source/install.lua"))
  http, _G.http = nil, nil
  local apps = require("system.libraries.apps")
  local desktop = require("system.gui.desktop")
  local boot = require("system.boot.bootloader")
  local originalCreate = window.create
  local rootSurface
  window.create = function(parent, x, y, w, h, visible)
    local surface = originalCreate(parent, x, y, w, h, visible)
    local sw, sh = term.native().getSize()
    if x == 1 and y == 1 and w == sw and h == sh then rootSurface = surface end
    return surface
  end
  local function send(name, ...)
    os.queueEvent(name, ...)
    sleep(0.2)
  end
  parallel.waitForAny(function() boot.start() end, function()
    for i = 1, 30 do
      if apps.ctx and apps.get("terminal") then break end
      sleep(0.1)
    end
    assert(apps.ctx and apps.get("terminal"), "boot failed")
    local launched, pid = apps.launch("terminal")
    assert(launched, tostring(pid))
    send("mintcraft_test")
    local terminal = apps.ctx.scheduler.processes[pid].window.app
    local _, height = term.getSize()
    send("mouse_click", 1, 11, height)
    assert(desktop.searchFocused and desktop.menuOpen, "search did not open over terminal")
    send("char", "f")
    send("paste", "iles")
    assert(desktop.search == "files", "search input lost")
    assert(terminal.input == "", "search leaked to terminal")
    if rootSurface then
      local bar = rootSurface.getLine(height)
      assert(bar:find("Menu", 1, true) and bar:find("?files", 1, true), "taskbar covered by window shadow")
      local menuRow = rootSurface.getLine(height - 9)
      assert(menuRow:sub(33):match("^ *$"), "underlying app keyboard visible beside search")
      local dump = assert(fs.open("/launcher-frame.txt", "w"))
      for row = 1, height do
        local text, fg, bg = rootSurface.getLine(row)
        dump.writeLine(text)
        dump.writeLine(bg)
      end
      dump.close()
    end
    if term.screenshot then term.screenshot() sleep(1.1) end
    send("key", keys.enter)
    assert(not desktop.searchFocused and not desktop.menuOpen, "launcher stayed open")
    local files
    for _, proc in pairs(apps.ctx.scheduler.processes) do
      if proc.meta.appId == "files" then files = proc end
    end
    assert(files and files.state == "ready" and files.window and not files.window.closed, "Files did not launch")
    apps.ctx.scheduler:kill(files.pid)
    send("mintcraft_test")
    send("mouse_click", 1, 11, height)
    send("key", keys.escape)
    send("char", "x")
    assert(terminal.input == "x", "Escape did not restore terminal input")
    result("PASS: launcher over active terminal, search isolation, Files launch, Escape restores input")
  end)
end)
if not ok then result("FAIL: " .. tostring(err)) end
os.shutdown()
