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
  local function capture(name)
    local native=term.native() local w,h=native.getSize(2)
    local image=assert(fs.open("/"..name..".bin","wb"))
    for y=0,h-1 do image.write(native.getPixels(0,y,w,1,true)[1]) end image.close()
    local palette={}
    for i=0,255 do palette[i+1]={native.getPaletteColor(i)} end
    local meta=assert(fs.open("/"..name..".json","w"))
    meta.write(textutils.serializeJSON({width=w,height=h,palette=palette})) meta.close()
  end
  parallel.waitForAny(function() require("system.boot.bootloader").start() end,function()
    for _=1,80 do if apps.ctx and apps.get("settings") and apps.ctx.renderStats then break end sleep(0.1) end
    assert(apps.ctx and apps.ctx.renderStats,"kernel not ready")
    sleep(0.5)
    local stats=apps.ctx.renderStats()
    assert(stats.backend=="PIXEL256","pixel backend inactive: "..tostring(stats.lastError))
    assert(stats.pixelWidth>100 and stats.bytes>0,"no pixel framebuffer")
    capture("pixel-desktop")
    for _,id in ipairs({"files","terminal","settings","navigation","combat","nexus"}) do
      local launched,pid=apps.launch(id) assert(launched,tostring(pid))
      os.queueEvent("mintcraft_test") sleep(0.5)
      local proc=apps.ctx.scheduler.processes[pid]
      assert(proc.state=="ready" and proc.window and not proc.window.closed,id..": "..tostring(proc.error))
      if id=="files" then
        local win=proc.window local workspace=apps.ctx.pixelWorkspace
        local hit=workspace.windowHits[#workspace.windowHits]
        assert(win.pixelManaged and hit.win==win,"native window was not integrated")
        local r=hit.controls.minimize os.queueEvent("mouse_click",1,r.x+3,r.y+3) sleep(0.25)
        assert(win.minimized,"pixel minimize failed")
        local task
        for _,box in ipairs(workspace.taskHits) do if box.win==win then task=box.rect end end
        assert(task,"minimized task missing")
        os.queueEvent("mouse_click",1,task.x+2,task.y+2) sleep(0.25)
        assert(not win.minimized,"pixel restore failed")
        local before=win.pixelBounds.x
        local x,y=win.pixelBounds.x+5,win.pixelBounds.y+5
        os.queueEvent("mouse_click",1,x,y) sleep(0.1)
        os.queueEvent("mouse_drag",1,x+1,y+1) sleep(0.1)
        os.queueEvent("mouse_up",1,x+1,y+1) sleep(0.15)
        assert(win.pixelBounds.x==before+1,"native drag snapped to cells")
        capture("pixel-files")
      end
      apps.ctx.scheduler:kill(pid)
    end
    local native=term.native()
    assert(native.getGraphicsMode()==2 and not native.getFrozen())
    -- A hidden legacy clear must not erase the physical pixel framebuffer.
    os.queueEvent("mintcraft_test") sleep(0.3)
    assert(native.getPixel(0,0)~=15,"legacy clear erased desktop")
    -- Save raw indexed bytes for independent visual inspection (no screenshot API).
    capture("graphics-frame")
    local workspace=apps.ctx.pixelWorkspace
    os.queueEvent("mouse_click",1,workspace.start.x+3,workspace.start.y+3) sleep(0.2)
    assert(workspace.menu,"native launcher failed")
    os.queueEvent("paste","Files") sleep(0.2)
    assert(#workspace:filtered()==1,"native app filtering failed")
    capture("pixel-launcher")
    local kb=workspace.keyboardButton
    os.queueEvent("mouse_click",1,kb.x+2,kb.y+2) sleep(0.2)
    if workspace.menuPanel.h>=130 then
      assert(workspace.touchKeyboard and #workspace.keyboardHits>0,"native touch keyboard missing")
      capture("pixel-keyboard")
    end
    os.queueEvent("key",keys.escape) sleep(0.15)
    local launched,pid=apps.launch("files",{path="/home/user/desktop",action="new_lua"}) assert(launched,tostring(pid))
    os.queueEvent("mintcraft_test") sleep(0.3)
    local process=apps.ctx.scheduler.processes[pid]
    assert(process.window.app.mode=="new_file" and process.window.app.input:match("%.lua$"),"desktop create action missing")
    assert(not fs.exists("/home/user/desktop/"..process.window.app.input),"desktop action wrote without confirmation")
    apps.ctx.scheduler:kill(pid)
    local metrics=assert(fs.open("/graphics-metrics.json","w"))
    metrics.write(textutils.serializeJSON(apps.ctx.renderStats())) metrics.close()
    apps.ctx.setGraphicsMode("pixel16") os.queueEvent("mintcraft_test") sleep(0.3)
    assert(native.getGraphicsMode()==1,"16-color native mode not activated")
    assert(not native.getFrozen(),"16-color display remained frozen")
    apps.ctx.setGraphicsMode("text") os.queueEvent("mintcraft_test") sleep(0.3)
    assert(native.getGraphicsMode()==false or native.getGraphicsMode()==0,"text mode not restored")
    result("PASS: native 256/16 desktop and chrome, raw pixel drag/minimize/restore, launcher/search, confirmed file dialog, six legacy apps, no freeze and text restoration")
  end)
end)
if not ok then result("FAIL: "..tostring(err)) end
if term.setFrozen then pcall(term.setFrozen,false) end
if term.setGraphicsMode then pcall(term.setGraphicsMode,0) end
os.shutdown()
