-- Normal GUI only, disposable data directory and read-only /source mount.
local ok, err = pcall(function()
  shell.setDir("/")
  assert(shell.run("/source/install.lua"))
  local compositor = require("system.gui.compositor").new()
  local renderer = require("system.gui.renderer")
  local native = term.current()
  local count, original = 0, native.blit
  native.blit = function(...) count = count + 1 return original(...) end
  local w, h = term.getSize()
  local function frame() renderer.fill(1, 1, w, h, colors.black) end
  compositor:draw(frame)
  assert(count == h, "first frame missing rows")
  for i = 1, 100 do compositor:draw(frame) end
  assert(count == h, "unchanged frames still written")
  compositor:draw(function() frame() renderer.writeAt(2, 4, "change", colors.white, colors.black) end)
  assert(count == h + 1, "one changed row not batched")
  native.blit = original
  local results = assert(fs.open("/render-metrics.txt", "w"))
  results.writeLine("100 unchanged frames: 0 output blits")
  results.writeLine("One changed row: 1 output blit")
  results.writeLine("Graphics resolution: " .. (w * 2) .. "x" .. (h * 3))
  results.close()
  http, _G.http = nil, nil
  local apps = require("system.libraries.apps")
  local boot = require("system.boot.bootloader")
  parallel.waitForAny(function() boot.start() end, function()
    for i = 1, 40 do if apps.ctx then break end sleep(0.1) end
    assert(apps.ctx, "boot failed")
    sleep(3.5)
    os.queueEvent("mintcraft_render_test")
    sleep(0.5)
    if term.screenshot then term.screenshot() sleep(1.1) end
    local launched, pid = apps.launch("terminal")
    assert(launched, tostring(pid))
    os.queueEvent("mintcraft_render_test")
    sleep(0.3)
    local win = apps.ctx.scheduler.processes[pid].window
    assert(win and not win.closed, "terminal failed to draw")
    win:toggleMaximize()
    os.queueEvent("mintcraft_render_test")
    sleep(0.3)
    assert(not win.closed, "maximize crashed app")
    apps.ctx.scheduler:kill(pid)
  end)
end)
local result = assert(fs.open("/render-result.txt", "w"))
result.write(ok and "PASS" or tostring(err))
result.close()
os.shutdown()
