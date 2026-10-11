-- Run in a normal CraftOS-PC window, with isolated storage and read-only /source.
local ok, err = pcall(function()
  shell.setDir("/")
  assert(shell.run("/source/install.lua"))
  http, _G.http = nil, nil
  local originalTime, hour = os.time, 6 + 59 / 60
  os.time = function(mode) if mode then return originalTime(mode) end return hour end
  local apps = require("system.libraries.apps")
  local originalCreate, root = window.create
  window.create = function(parent, x, y, w, h, visible)
    local surface = originalCreate(parent, x, y, w, h, visible)
    local sw, sh = term.native().getSize()
    if x == 1 and y == 1 and w == sw and h == sh then root = surface end
    return surface
  end
  parallel.waitForAny(function() require("system.boot.bootloader").start() end, function()
    for i = 1, 40 do if apps.ctx and apps.get("terminal") then break end sleep(0.1) end
    assert(apps.ctx and root, "boot failed")
    local launched, pid = apps.launch("terminal")
    assert(launched, tostring(pid))
    sleep(4)
    local app = apps.ctx.scheduler.processes[pid].window.app
    local draws, originalDraw = 0, app.draw
    app.draw = function(...) draws = draws + 1 return originalDraw(...) end
    local function expect(text)
      local w, h = root.getSize()
      assert(root.getLine(h):sub(w - 5, w - 1) == text, "stale clock: expected " .. text)
    end
    expect("06:59")
    local deadline = os.startTimer(8)
    local function waitClock(text)
      local w, h = root.getSize()
      repeat
        local _, timer = os.pullEvent("timer")
        assert(timer ~= deadline, "clock update timed out")
      until root.getLine(h):sub(w - 5, w - 1) == text
      expect(text)
    end
    hour = 7
    waitClock("07:00")
    hour = 7 + 1 / 60
    waitClock("07:01")
    hour = 24
    waitClock("00:00")
    os.cancelTimer(deadline)
    assert(draws == 0, "clock timer redrew the app")
    apps.ctx.scheduler:kill(pid)
    os.time = originalTime
  end)
end)
local result = assert(fs.open("/clock-result.txt", "w"))
result.write(ok and "PASS: idle hour/minute/midnight updates, no app redraw" or tostring(err))
result.close()
os.shutdown()
