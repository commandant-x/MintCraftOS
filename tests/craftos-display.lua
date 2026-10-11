-- Disposable normal-window CraftOS-PC run, source mounted read-only at /source.
local function result(message)
  local h = assert(fs.open('/display-result.txt', 'w'))
  h.write(message)
  h.close()
end
local ok, err = pcall(function()
  shell.setDir('/')
  assert(shell.run('/source/install.lua'))
  http = nil
  local native = term.native()
  local monitor = window.create(native, 1, 1, 80, 30, false)
  monitor.setTextScale = function() end
  local attached = false
  peripheral.getNames = function() return attached and {'right'} or {} end
  peripheral.getType = function(name) if attached and name == 'right' then return 'monitor' end end
  peripheral.getMethods = function() return {'getSize', 'setTextScale'} end
  peripheral.wrap = function(name) if attached and name == 'right' then return monitor end end
  local apps = require('system.libraries.apps')
  local devices = require('system.services.deviced')
  parallel.waitForAny(function() require('system.boot.bootloader').start() end, function()
    for _ = 1, 50 do
      if apps.ctx and apps.get('settings') then break end
      sleep(0.1)
    end
    assert(apps.ctx and apps.get('settings'), 'boot failed')
    assert(devices.getDisplay().target == 'computer')
    local launched, pid = apps.launch('settings')
    assert(launched, tostring(pid))
    attached = true
    os.queueEvent('peripheral', 'right')
    sleep(0.4)
    assert(devices.getTarget() == monitor, 'hotplug target not selected')
    assert(term.current() == monitor, 'render restored wrong screen')
    local painted = false
    for y = 1, 30 do
      local text = monitor.getLine(y)
      if text:find('%S') then painted = true end
    end
    assert(painted, 'monitor blank after hotplug')
    monitor.reposition(1, 1, 60, 22)
    os.queueEvent('monitor_resize', 'right')
    sleep(0.4)
    assert(devices.getDisplay().width == 60)
    assert(not apps.ctx.scheduler.processes[pid].window.closed, 'resize closed app')
    attached = false
    os.queueEvent('peripheral_detach', 'right')
    sleep(0.4)
    assert(devices.getDisplay().target == 'computer' and term.current() == native)
    result('PASS: full boot, monitor hotplug redraw, resize preserves app, detach restores computer')
  end)
end)
if not ok then result('FAIL: ' .. tostring(err)) end
os.shutdown()
