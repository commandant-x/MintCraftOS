-- Normal visible CraftOS-PC, isolated storage and read-only /source mount.
local function result(message)
  local f=assert(fs.open("/graphics-result.txt","w")) f.write(message) f.close()
end
local ok,err=pcall(function()
  if _G.mintcraftTerminalFixture then
    local original,native=peripheral,term.native()
    local function known(name) return name=="terminal_0" or name=="terminal_1" end
    peripheral={}
    for name,fn in pairs(original) do peripheral[name]=fn end
    peripheral.getNames=function() local names=original.getNames() names[#names+1]="terminal_0" names[#names+1]="terminal_1" return names end
    peripheral.getType=function(name) if known(name) then return "terminal" end return original.getType(name) end
    peripheral.isPresent=function(name) return known(name) or original.isPresent(name) end
    peripheral.hasType=function(name,kind) if known(name) then return kind=="terminal" end return original.hasType(name,kind) end
    peripheral.wrap=function(name) if known(name) then return native end return original.wrap(name) end
    peripheral.getMethods=function(name)
      if not known(name) then return original.getMethods(name) end
      local methods={} for method,fn in pairs(native) do if type(fn)=="function" then methods[#methods+1]=method end end return methods
    end
    peripheral.call=function(name,method,...) if known(name) then return assert(native[method])(...) end return original.call(name,method,...) end
    _G.peripheral=peripheral
  end
  local function queueInput(name,...)
    if _G.mintcraftTerminalFixture then os.queueEvent("terminal_"..name,"terminal_0",...)
    else os.queueEvent(name,...) end
  end
  shell.setDir("/")
  assert(shell.run("/source/install.lua"))
  local cfg=require("system.libraries.config")
  local settings=cfg.load("/system/config/system.cfg",{})
  settings.graphicsMode="auto" cfg.save("/system/config/system.cfg",settings)
  if _G.mintcraftTerminalFixture then settings.displayTarget="terminal_0" cfg.save("/system/config/system.cfg",settings) end
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
        assert(win.pixelNative and proc.window.app.graphicsActive,"Files is still a legacy bitmap client")
        local r=hit.controls.minimize queueInput("mouse_click",1,r.x+3,r.y+3) sleep(0.25)
        assert(win.minimized,"pixel minimize failed")
        local task
        for _,box in ipairs(workspace.taskHits) do if box.win==win then task=box.rect end end
        assert(task,"minimized task missing")
        queueInput("mouse_click",1,task.x+2,task.y+2) sleep(0.25)
        assert(not win.minimized,"pixel restore failed")
        local before=win.pixelBounds.x
        local x,y=win.pixelBounds.x+5,win.pixelBounds.y+5
        queueInput("mouse_click",1,x,y) sleep(0.1)
        queueInput("mouse_drag",1,x+1,y+1) sleep(0.1)
        queueInput("mouse_up",1,x+1,y+1) sleep(0.15)
        assert(win.pixelBounds.x==math.min(before+1,stats.pixelWidth-win.pixelBounds.w),"native drag or clamp failed")
        capture("pixel-files")
        local client
        for _,item in ipairs(workspace.windowHits) do if item.win==win then client=item.client end end
        local action
        for _,item in ipairs(win.app.pixelButtons) do if item.id=="new_file" then action=item.rect end end
        assert(client and action,"native file toolbar missing")
        queueInput("mouse_click",1,client.x+action.x+2,client.y+action.y+2) sleep(0.2)
        assert(win.app.mode=="new_file","native create dialog did not open")
        for _=1,#win.app.input do queueInput("key",keys.backspace) end
        local testName="native-caf"..string.char(195,169).."-"..os.epoch("utc")..".txt"
        sleep(0.3) queueInput("paste",testName) sleep(0.2)
        local destination=fs.combine(win.app.path,testName)
        assert(not fs.exists(destination),"native dialog wrote before submit")
        queueInput("key",keys.enter)
        for _=1,60 do if fs.exists(destination) then break end sleep(0.05) end
        assert(fs.exists(destination),"native keyboard/paste create failed")
        capture("pixel-files-created")
        local function fileAction(id)
          -- Toasts are real overlays; dismiss them before clicking covered menus.
          for _=1,4 do
            local toast=workspace.notificationHits[#workspace.notificationHits]
            if not toast then break end
            queueInput("mouse_click",1,toast.close.x+2,toast.close.y+2) sleep(0.1)
          end
          for _=1,22 do
            local target
            for _,item in ipairs(win.app.pixelButtons) do if item.id==id then target=item.rect end end
            if not target and win.app.nativeMenu then
              for _,item in ipairs(win.app.pixelMenuItems) do if item.id==id then target=item.rect end end
            end
            if target then
              queueInput("mouse_click",1,client.x+target.x+2,client.y+target.y+2) sleep(0.15) return
            end
            for _,item in ipairs(win.app.pixelButtons) do
              if item.id==(win.app.nativeMenu and "menu_next" or "menu") then target=item.rect end
            end
            assert(target,"file menu control missing")
            queueInput("mouse_click",1,client.x+target.x+2,client.y+target.y+2) sleep(0.15)
          end
          error("file action unreachable: "..id)
        end
        fileAction("copy") assert(win.app.clipboard,"copy action failed")
        fileAction("new_dir")
        for _=1,#win.app.input do queueInput("key",keys.backspace) end
        local folder="transfer-"..os.epoch("utc")
        queueInput("paste",folder) queueInput("key",keys.enter) sleep(0.3)
        fileAction("open")
        assert(fs.getName(win.app.path)==folder,"new folder navigation failed")
        fileAction("paste")
        assert(fs.exists(fs.combine(win.app.path,testName)) and fs.exists(destination),"copy/paste changed source or lost destination")
        fileAction("properties") assert(win.app.properties,"properties dialog missing")
        capture("pixel-properties")
        fileAction("cancel") assert(not win.app.properties,"properties modal did not close")
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
    queueInput("key",keys.f1) sleep(0.2)
    assert(workspace.menu,"native launcher failed")
    if _G.mintcraftTerminalFixture then
      os.queueEvent("terminal_paste","terminal_1","not selected") os.queueEvent("paste","native keyboard") sleep(0.2)
      assert(workspace.query=="","foreign/native input leaked to selected terminal")
    end
    queueInput("paste","Files") sleep(0.2)
    assert(#workspace:filtered()==1,"native app filtering failed")
    capture("pixel-launcher")
    local kb=workspace.keyboardButton
    queueInput("mouse_click",1,kb.x+2,kb.y+2) sleep(0.2)
    if workspace.menuPanel.h>=130 then
      assert(workspace.touchKeyboard and #workspace.keyboardHits>0,"native touch keyboard missing")
      capture("pixel-keyboard")
    end
    queueInput("key",keys.escape) sleep(0.15)
    local launched,pid=apps.launch("files",{path="/home/user/desktop",action="new_lua"}) assert(launched,tostring(pid))
    os.queueEvent("mintcraft_test") sleep(0.3)
    local process=apps.ctx.scheduler.processes[pid]
    assert(process.window.app.mode=="new_file" and process.window.app.input:match("%.lua$"),"desktop create action missing")
    assert(not fs.exists("/home/user/desktop/"..process.window.app.input),"desktop action wrote without confirmation")
    apps.ctx.scheduler:kill(pid)
    if _G.mintcraftTerminalFixture then
      local launched,terminalPid=apps.launch("terminal") assert(launched,tostring(terminalPid))
      os.queueEvent("mintcraft_test") sleep(0.3)
      queueInput("paste","display computer") queueInput("key",keys.enter) sleep(0.4)
      assert(require("system.services.deviced").getDisplay().target=="computer","keyboard-only display recovery failed")
      apps.ctx.scheduler:kill(terminalPid)
    end
    local metrics=assert(fs.open("/graphics-metrics.json","w"))
    metrics.write(textutils.serializeJSON(apps.ctx.renderStats())) metrics.close()
    apps.ctx.setGraphicsMode("pixel16") os.queueEvent("mintcraft_test") sleep(0.3)
    assert(native.getGraphicsMode()==1,"16-color native mode not activated")
    assert(not native.getFrozen(),"16-color display remained frozen")
    apps.ctx.setGraphicsMode("text") os.queueEvent("mintcraft_test") sleep(0.3)
    assert(native.getGraphicsMode()==false or native.getGraphicsMode()==0,"text mode not restored")
    result("PASS: native desktop, Files UTF8 create/copy/paste/properties, drag/minimize/restore, shared keyboard/search, six apps, 256/16/text and "..(_G.mintcraftTerminalFixture and "source-isolated terminal transport simulation" or "computer input"))
  end)
end)
if not ok then result("FAIL: "..tostring(err)) end
if term.setFrozen then pcall(term.setFrozen,false) end
if term.setGraphicsMode then pcall(term.setGraphicsMode,0) end
os.shutdown()
