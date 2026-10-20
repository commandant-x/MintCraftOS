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
  -- Persisted pre-migration text preference must not select a second desktop.
  settings.graphicsMode="text" settings.safeMode=false cfg.save("/system/config/system.cfg",settings)
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
    for _,id in ipairs({"files","editor","terminal","settings","messenger","navigation","combat","logs","services","devices","taskmanager","update","nexus"}) do
      local launched,pid=apps.launch(id,id=="navigation" and {page="flight"} or id=='editor' and {path='/home/user/native-editor.lua'} or nil) assert(launched,tostring(pid))
      os.queueEvent("mintcraft_test") sleep(0.5)
      local proc=apps.ctx.scheduler.processes[pid]
      assert(proc.state=="ready" and proc.window and not proc.window.closed,id..": "..tostring(proc.error))
        if id=='terminal' then
          local win=proc.window local app=win.app
          assert(win.pixelNative,'Terminal is still a legacy client')
          win:toggleMaximize() os.queueEvent('mintcraft_test') sleep(0.2)
          queueInput('paste','pxd') queueInput('key',keys.left) queueInput('key',keys.left)
          queueInput('key',keys.delete) queueInput('char','w') sleep(0.1)
          assert(app.input=='pwd','native input cursor editing failed: '..app.input)
          queueInput('key',keys.enter) sleep(0.1)
          assert(app.lines[#app.lines]==app.cwd,'native command did not execute')
          queueInput('key',keys.up) sleep(0.1) assert(app.input=='pwd','native command history failed')
          queueInput('key',keys.leftCtrl) queueInput('key',keys.u) queueInput('key_up',keys.leftCtrl)
          queueInput('paste','unlock display-only-secret') sleep(0.1)
          local shown,private=app:visibleInput() assert(private and shown=='unlock ***' and not app.suggestion,'private command was not masked')
          win.dirty=true os.queueEvent('mintcraft_test') sleep(0.1) capture('pixel-terminal-masked')
          queueInput('key',keys.leftCtrl) queueInput('key',keys.u) queueInput('key_up',keys.leftCtrl) sleep(0.1)
          for _=1,110 do app.input='pwd' app.cursor=nil app.keyboard.onEnter() end
          assert(#app.lines==200 and #app.lineIds==200 and #app.lineColors==200,'Terminal output metadata diverged')
          app.selection={first=app.lineIds[199],last=app.lineIds[200]} app:action('copy')
          assert(app.clipboard:find(app.cwd,1,true),'native output copy missing')
          app.pixelKeyboard=true win.dirty=true os.queueEvent('mintcraft_test') sleep(0.15)
          capture('pixel-terminal-history')
        end
        if id=='editor' then
          local win=proc.window local app=win.app
          assert(win.pixelNative,'Editor is still a legacy client')
          win:toggleMaximize() os.queueEvent('mintcraft_test') sleep(0.2)
          queueInput('key',keys.leftCtrl) queueInput('key',keys.a) queueInput('key_up',keys.leftCtrl)
          queueInput('paste','local altitude = 42\nreturn altitude') sleep(0.15)
          assert(#app.lines==2 and app.lines[1]=='local altitude = 42','native selection/paste replacement failed')
          queueInput('key',keys.leftCtrl) queueInput('key',keys.s) queueInput('key_up',keys.leftCtrl) sleep(0.15)
          local file=assert(fs.open('/home/user/native-editor.lua','r')) local saved=file.readAll() file.close()
          assert(saved==table.concat(app.lines,'\n') and not app.isDirty,'native save shortcut failed: '..tostring(app.status))
          app:action('compile') assert(app.status=='Compile OK',tostring(app.status))
          app:action('find') app.keyboard.onText('altitude') app:action('findNext')
          assert(require('apps.editor.editing').selected(app)=='altitude','native find selection failed')
          win.dirty=true os.queueEvent('mintcraft_test') sleep(0.15) capture('pixel-editor-search')
          app.searchOpen=false app:insert('height')
          assert(app:canClose(win)==false and app.closePrompt and not win.closed,'unsaved editor closed without confirmation')
          win.dirty=true os.queueEvent('mintcraft_test') sleep(0.1) capture('pixel-editor-close')
          app:action('cancel') assert(not app.closePrompt and not win.closed)
          app:action('save') app.pixelKeyboard=true win.dirty=true os.queueEvent('mintcraft_test') sleep(0.15)
          capture('pixel-editor-keyboard')
        end
        if id=="settings" then
          local win=proc.window local app=win.app
          assert(win.pixelNative,'Settings is still a legacy client')
          win:toggleMaximize() os.queueEvent('mintcraft_test') sleep(0.2)
          for _,page in ipairs({'system','display','desktop','apps','network','sound','storage','security','packages','nav','combat','dev'}) do
            app:setPage(page)
            for _=1,40 do if app.model.page==page and not app.reading then break end sleep(0.05) end
            assert(app.model.page==page,'Settings page did not load: '..page)
            win.dirty=true os.queueEvent('mintcraft_test') sleep(0.05)
            assert(not win.closed and win.pixelNative,'Settings page crashed: '..page)
          end
          app:setPage('display') sleep(0.2) win.dirty=true os.queueEvent('mintcraft_test') sleep(0.1)
          capture('pixel-settings-display')
          app:setPage('security') sleep(0.2) win.dirty=true os.queueEvent('mintcraft_test') sleep(0.1)
          capture('pixel-settings-security')
          app:setPage('system') sleep(0.2)
          local allowed,operation=app:submit('label','Isolated native Settings')
          assert(allowed,tostring(operation))
          for _=1,40 do if os.getComputerLabel()=='Isolated native Settings' then break end sleep(0.05) end
          assert(os.getComputerLabel()=='Isolated native Settings','Settings service label write failed')
        end
        if id=='messenger' then
          local win=proc.window local app=win.app
          assert(win.pixelNative,'Messenger is still a legacy client')
          win:toggleMaximize() os.queueEvent('mintcraft_test') sleep(0.2)
          for i=1,115 do apps.ctx.eventBus:emit('rednet_message',900,{type='message',from='SIMULATED public sender',text='Isolated receive fixture '..i},'mintcraft.chat') end
          app:sync() win.dirty=true os.queueEvent('mintcraft_test') sleep(0.15)
          assert(#app.messages==80 and app.messages[80].text=='Isolated receive fixture 115','Messenger full inbox stopped updating')
          capture('pixel-messenger-history')
          local prior=app.seen app:action('clear') app:sync() assert(#app.messages==0 and app.seen==prior,'clear replayed received history')
          queueInput('paste','Retained offline draft') sleep(0.1)
          assert(app.input=='Retained offline draft','Messenger native paste not routed')
          app.softKeyboard=true win.dirty=true os.queueEvent('mintcraft_test') sleep(0.15)
          assert(#app.keyboard.pixelBoxes>0,'Messenger pixel keyboard missing')
          capture('pixel-messenger-keyboard')
        end
        if id=="navigation" then
        local win=proc.window local workspace=apps.ctx.pixelWorkspace
        assert(win.pixelNative and win.app.page=="flight","Flight is not a native client")
        capture("pixel-navigation-unavailable")
        win:toggleMaximize() os.queueEvent("mintcraft_test") sleep(0.2)
        -- Synthetic display-only telemetry, never injected into flight control.
        local pixel=require("apps.navigation.pixel") local original=pixel.sample
        local now=os.clock()
        local fixture={fresh=true,observedAt=now,attitude={pitch=12,roll=24,observedAt=now},attitudeValidUntil=now+10,
          state="disarmed",source="SIMULATED display fixture",values={altitude=128,altitudeRate=0.2,heading=359,speed=12,mass=80},
          expires={altitude=now+10,altitudeRate=now+10,heading=now+10,speed=now+10,mass=now+10}}
        pixel.sample=function() return fixture,fixture.attitude end
        win.app.nativeFlight=fixture win.dirty=true
        os.queueEvent("mintcraft_test") sleep(0.25)
        capture("pixel-navigation-simulated")
        assert(win.app.nativeHorizon and win.app.nativeHorizon.image.width>100,"pixel instrument missing")
        local client
        for _,hit in ipairs(workspace.windowHits) do if hit.win==win then client=hit.client end end
        local control
        for _,hit in ipairs(win.app.nativeHits) do if hit.id=="control" then control=hit.rect end end
        assert(client and control)
        queueInput("mouse_click",1,client.x+control.x+2,client.y+control.y+2) sleep(0.25)
        assert(win.app.page=="control" and not win.pixelNative and not win.closed,"safe control page lost during hybrid transition")
        pixel.sample=original
        assert(require("system.services.flightd").status().state~="armed","display navigation armed flight control")
      end
      if id=="combat" then
        local win=proc.window
        assert(win.pixelNative,"Combat radar is still a legacy bitmap")
        queueInput("key",keys.tab) sleep(0.1)
        assert(win.app.nativeFocus,"native Combat keyboard input not routed")
        capture("pixel-combat-unavailable")
        win:toggleMaximize() os.queueEvent("mintcraft_test") sleep(0.2)
        local original=win.app.drawPixels
        local fixture={revision=9999,radars={
          {id="station_a",name="Station A",position={x=0,y=64,z=0},range=800,heading=35,fov=65,running=true},
          {id="station_b",name="Station B",position={x=420,y=64,z=180},range=500,heading=245,fov=80,running=true,remote=true}},
          targets={{id="player",label="Alex",labelSource="SIMULATED",category="player",timestamp=os.clock(),position={x=110,y=80,z=-240}},
            {id="vessel",label="ID vessel",labelSource="SIMULATED",category="ship",timestamp=os.clock(),position={x=-180,y=170,z=120},history={
              {position={x=-260,y=150,z=160}},{position={x=-220,y=160,z=140}},{position={x=-180,y=170,z=120}}}},
            {id="mob",label="Zombie",labelSource="SIMULATED",category="mob",timestamp=os.clock(),position={x=150,y=66,z=280}}},
          devices={},cannons={},acquisition={targetHz=20,pending=0,elapsed=0}}
        -- Display fixture only: never installed in combatd's command snapshot.
        win.title="Combat - SIMULATED RADAR FIXTURE"
        win.app.drawPixels=function(self,...)
          local previous=self.snapshot self.snapshot=fixture
          local ok,err=pcall(original,self,...)
          self.snapshot=previous
          assert(ok,err)
        end
        win.app.radarId="station_a" win.app.view.network=true win.dirty=true
        os.queueEvent("mintcraft_test") sleep(0.3)
        assert(win.app.nativeGraph and #win.app.nativeGraph.hits==3,"native multi-radar fixture missing contacts")
        capture("pixel-combat-2d-simulated")
        win.app.page="three" win.dirty=true os.queueEvent("mintcraft_test") sleep(0.3)
        assert(win.pixelNative and not win.closed,"native 3D radar crashed")
        capture("pixel-combat-3d-simulated")
        win.app.drawPixels=original win.title="Combat" win.dirty=true
      end
      if id=="logs" then
        local win=proc.window local workspace=apps.ctx.pixelWorkspace
        assert(win.pixelNative,"Logs is not a native client")
        local log=require("system.libraries.log")
        for i=1,45 do log.info("isolated-test","Viewer entry "..i) end
        log.error("isolated-test","Full diagnostic\n"..string.rep("Wrapped message from isolated test. ",25))
        win.app:refresh() win.dirty=true os.queueEvent("mintcraft_test") sleep(0.2)
        local client
        for _,hit in ipairs(workspace.windowHits) do if hit.win==win then client=hit.client end end
        local row=win.app.rowHits[#win.app.rowHits] assert(client and row)
        queueInput("mouse_click",1,client.x+row.rect.x+2,client.y+row.rect.y+2) sleep(0.15)
        assert(win.app.selected and win.app.detailArea,"native log details inaccessible")
        capture("pixel-logs-detail")
        queueInput("key",keys.escape) sleep(0.1)
        assert(not win.app.inspect,"native log keyboard escape not routed")
        local filter
        for _,hit in ipairs(win.app.pixelHits) do if hit.id=="filter" then filter=hit.rect end end
        queueInput("mouse_click",1,client.x+filter.x+2,client.y+filter.y+2) sleep(0.1)
        queueInput("key",keys.down) queueInput("key",keys.enter) sleep(0.15)
        assert(win.app.filter=="error" and #win.app.rows>=1,"native log keyboard filter failed")
        capture("pixel-logs-filtered")
      end
      if id=="services" then
        local win=proc.window local manager=apps.ctx.services local workspace=apps.ctx.pixelWorkspace
        assert(win.pixelNative,"Services is still a legacy client")
        local stopping,stopped=false,false
        package.loaded["isolated.viewer-service"]={start=function() return true end,status=function() return {ok=true} end,stop=function()
          stopping=true local timer=os.startTimer(0.8)
          while true do local _,tick=os.pullEvent("timer") if tick==timer then break end end
          stopped=true return true
        end}
        manager:register("viewer_fixture","isolated.viewer-service",false)
        assert(manager:start("viewer_fixture"))
        win.app:refresh() win.app.selected="viewer_fixture" win.dirty=true os.queueEvent("mintcraft_test") sleep(0.15)
        local client
        for _,hit in ipairs(workspace.windowHits) do if hit.win==win then client=hit.client end end
        local function click(id)
          for _,hit in ipairs(win.app.pixelHits) do if hit.id==id then
            queueInput("mouse_click",1,client.x+hit.rect.x+2,client.y+hit.rect.y+2) return
          end end error("missing service action "..id)
        end
        capture("pixel-services")
        click("stop") sleep(0.1) assert(win.app.confirm and not stopping,"service stopped before confirmation")
        click("confirm") sleep(0.1)
        assert(stopping and not stopped and manager:controlStatus().busy,"native yielding service request failed: "..tostring(win.app.message))
        capture("pixel-services-pending")
        apps.ctx.scheduler:kill(pid)
        for _=1,30 do if stopped and not manager:controlStatus().busy then break end sleep(0.05) end
        assert(stopped and manager:controlStatus().ok and not manager.services.viewer_fixture.started,"closing Services abandoned in-flight transition")
      end
      if id=="devices" then
        local win=proc.window local app=win.app local workspace=apps.ctx.pixelWorkspace
        assert(win.pixelNative,"Devices is still a legacy client")
        local deviced=require('system.services.deviced') local originalList,originalMethods=deviced.list,peripheral.getMethods
        deviced.list=function()
          local rows={} for i=1,64 do rows[#rows+1]={name='fixture_'..i,type='create_radar:radar_bearing',types={'create_radar:radar_bearing'}} end return rows
        end
        peripheral.getMethods=function(name) if name:match('^fixture_') then return {'getTracks','getPosition','fire','setTargetAngles'} end return originalMethods(name) end
        win.title='Devices - SIMULATED METADATA FIXTURE'
        win:toggleMaximize() app:requestRead(false) os.queueEvent('mintcraft_test') sleep(0.25)
        assert(#app.rows==64,'Devices async inventory failed: '..tostring(app.message))
        local client for _,hit in ipairs(workspace.windowHits) do if hit.win==win then client=hit.client end end
        queueInput('mouse_click',1,client.x+app.searchArea.x+10,client.y+app.searchArea.y+10)
        queueInput('paste','fixture_2') sleep(0.15)
        assert(#app:filteredRows()==11,'Devices search input failed')
        local row=assert(app.rowHits[1]) queueInput('mouse_click',1,client.x+row.rect.x+2,client.y+row.rect.y+2) sleep(0.25)
        assert(app.selected=='fixture_2' and app.methods.fixture_2,'Devices selection metadata failed')
        capture('pixel-devices-inspector')
        local function click(id)
          for _,hit in ipairs(app.pixelHits) do if hit.id==id then queueInput('mouse_click',1,client.x+hit.rect.x+2,client.y+hit.rect.y+2) return end end error('missing Devices control '..id)
        end
        click('probe') sleep(0.3)
        assert(not app.probePending and app.message:find('unknown device',1,true),'Devices Probe error not retained: '..tostring(app.message))
        capture('pixel-devices-probe-error')
        click('display') sleep(0.25)
        local settingsPid
        for otherId,other in pairs(apps.ctx.scheduler.processes) do if otherId~=pid and other.state=='ready' and other.meta.appId=='settings' then
          assert(other.window.app.page=='display','Display shortcut opened wrong Settings page') settingsPid=otherId break
        end end
        assert(settingsPid,'Display settings shortcut failed') apps.ctx.scheduler:kill(settingsPid)
        deviced.list,peripheral.getMethods=originalList,originalMethods
      end
      if id=="taskmanager" then
        local win=proc.window local workspace=apps.ctx.pixelWorkspace
        assert(win.pixelNative,"Task Manager is still a legacy client")
        for _=1,60 do if #win.app.history>=2 and win.app.snapshot.render.generation then break end sleep(0.05) end
        assert(#win.app.history>=2 and win.app.snapshot.render.generation,"task sampling unavailable: history="..#win.app.history.." backend="..tostring(win.app.snapshot.render.backend).." generation="..tostring(win.app.snapshot.render.generation))
        win:toggleMaximize() os.queueEvent("mintcraft_test") sleep(0.2)
        local client
        for _,hit in ipairs(workspace.windowHits) do if hit.win==win then client=hit.client end end
        local function click(id)
          for _,hit in ipairs(win.app.pixelHits) do if hit.id==id then queueInput("mouse_click",1,client.x+hit.rect.x+2,client.y+hit.rect.y+2) return end end
          error("missing Task Manager control "..id)
        end
        local fixture=apps.ctx.scheduler:spawn("isolated-task-fixture",function() while true do coroutine.yield() end end,{appId="isolated-test",permissions={}})
        apps.ctx.scheduler:start(fixture)
        win.app:refresh(true)
        for index,row in ipairs(win.app:filteredRows()) do if row.pid==fixture then win.app:select(index) end end
        win.dirty=true os.queueEvent("mintcraft_test") sleep(0.15)
        capture("pixel-taskmanager-processes")
        click("kill") sleep(0.1) assert(win.app.confirm and apps.ctx.scheduler.processes[fixture].state=="ready","fixture killed before confirmation")
        click("cancel") sleep(0.1) assert(apps.ctx.scheduler.processes[fixture].state=="ready")
        click("kill") sleep(0.1) click("confirm") sleep(0.15)
        assert(apps.ctx.scheduler.processes[fixture].state=="killed","native delegated kill failed: "..win.app.message)
        click("views") sleep(0.1) queueInput("key",keys.down) queueInput("key",keys.enter) sleep(0.15)
        assert(win.app.page=="performance","native Task Manager keyboard view selector failed")
        capture("pixel-taskmanager-performance")
      end
      if id=="update" then
        local win=proc.window assert(win.pixelNative,"Update is still a legacy client")
        win:toggleMaximize() os.queueEvent("mintcraft_test") sleep(0.2)
        win.app.message="UPD-NET: simulated transport diagnostic\n"..string.rep("Long technical detail remains readable. ",400)
        win.dirty=true os.queueEvent("mintcraft_test") sleep(0.15)
        assert(win.app.detailLayout and #win.app.detailLayout.lines>3,"Update diagnostics not wrapped")
        capture("pixel-update-diagnostic")
        local before=win.app.detailScroll
        queueInput("mouse_scroll",1,win.pixelBounds.x+20,win.pixelBounds.y+170) sleep(0.15)
        assert(win.app.detailScroll>before,"Update diagnostic scroll not routed")
      end
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
    result("PASS: native desktop, Terminal cursor/history/private input/output copy, Editor selection/save/find/close protection, Messenger rollover/paste/keyboard, Settings twelve pages/service-owned label write, Devices/search/inspector/Probe error/Display shortcut, Files/Combat/Logs/Services/Update, measured Task Manager/confirmed fixture kill, thirteen apps, 256/16/text and "..(_G.mintcraftTerminalFixture and "source-isolated terminal transport simulation" or "computer input"))
  end)
end)
if not ok then result("FAIL: "..tostring(err)) end
if term.setFrozen then pcall(term.setFrozen,false) end
if term.setGraphicsMode then pcall(term.setGraphicsMode,0) end
os.shutdown()
