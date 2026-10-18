-- Normal visible CraftOS-PC, isolated storage and read-only /source mount.
local function result(message)
  local f=assert(fs.open("/graphics-result.txt","w")) f.write(message) f.close()
end
local ok,err=pcall(function()
  shell.setDir("/")
  assert(shell.run("/source/install.lua"))
  local cfg=require("system.libraries.config")
  local settings=cfg.load("/system/config/system.cfg",{})
  settings.graphicsMode="auto" cfg.save("/system/config/system.cfg",settings)
  local apps=require("system.libraries.apps")
  parallel.waitForAny(function() require("system.boot.bootloader").start() end,function()
    for _=1,80 do if apps.ctx and apps.get("settings") and apps.ctx.renderStats then break end sleep(0.1) end
    assert(apps.ctx and apps.ctx.renderStats,"kernel not ready")
    sleep(0.5)
    local stats=apps.ctx.renderStats()
    assert(stats.backend=="PIXEL256","pixel backend inactive: "..tostring(stats.lastError))
    assert(stats.pixelWidth>100 and stats.bytes>0,"no pixel framebuffer")
    for _,id in ipairs({"files","terminal","settings","navigation","combat","nexus"}) do
      local launched,pid=apps.launch(id) assert(launched,tostring(pid))
      os.queueEvent("mintcraft_test") sleep(0.5)
      local proc=apps.ctx.scheduler.processes[pid]
      assert(proc.state=="ready" and proc.window and not proc.window.closed,id..": "..tostring(proc.error))
      apps.ctx.scheduler:kill(pid)
    end
    local native=term.native()
    assert(native.getGraphicsMode()==2 and not native.getFrozen())
    -- A hidden legacy clear must not erase the physical pixel framebuffer.
    os.queueEvent("mintcraft_test") sleep(0.3)
    assert(native.getPixel(0,0)~=15,"legacy clear erased desktop")
    -- Save raw indexed bytes for independent visual inspection (no screenshot API).
    local w,h=native.getSize(2)
    local image=assert(fs.open("/graphics-frame.bin","wb"))
    for y=0,h-1 do image.write(native.getPixels(0,y,w,1,true)[1]) end
    image.close()
    local meta=assert(fs.open("/graphics-frame.json","w"))
    meta.write(textutils.serializeJSON({width=w,height=h})) meta.close()
    local metrics=assert(fs.open("/graphics-metrics.json","w"))
    metrics.write(textutils.serializeJSON(apps.ctx.renderStats())) metrics.close()
    apps.ctx.setGraphicsMode("pixel16") os.queueEvent("mintcraft_test") sleep(0.3)
    assert(native.getGraphicsMode()==1,"16-color native mode not activated")
    assert(not native.getFrozen(),"16-color display remained frozen")
    apps.ctx.setGraphicsMode("text") os.queueEvent("mintcraft_test") sleep(0.3)
    assert(native.getGraphicsMode()==false or native.getGraphicsMode()==0,"text mode not restored")
    result("PASS: native 256/16 pixel desktop, six legacy apps, indexed framebuffer, no freeze, live switch to text")
  end)
end)
if not ok then result("FAIL: "..tostring(err)) end
if term.setFrozen then pcall(term.setFrozen,false) end
if term.setGraphicsMode then pcall(term.setGraphicsMode,0) end
os.shutdown()
