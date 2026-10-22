local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")
local config = require("system.libraries.config")
local version = require("system.libraries.version")
local deviced = require("system.services.deviced")
local networkd = require("system.services.networkd")
local securityd = require("system.services.securityd")
local audiod = require("system.services.audiod")
local ui = require("system.gui.components")
local keyboard = require("system.gui.keyboard")
local profile = require("system.libraries.profile")
local menu = require("system.gui.action_menu")
local workers=require('system.libraries.app_worker')
local settingsd=require('system.services.settingsd')
local pixel=require('apps.settings.pixel')
local M = {}
local pages = {}
for _, entry in ipairs({{"system","System"},{"display","Display"},{"desktop","Desktop"},{"network","Network"},
  {"storage","Storage"},{"sound","Sound"},{"security","Security"},{"apps","Apps"},{"packages","Packages"},
  {"dev","Dev"},{"nav","Navigation"},{"combat","Combat"}}) do pages[#pages+1]={id=entry[1],label=entry[2]} end

local function computerId()
  return os.getComputerID and os.getComputerID() or os.computerID and os.computerID() or 0
end
local function sizeLabel(value)
  if type(value)~="number" then return tostring(value or "unavailable") end
  if value>=1048576 then return string.format("%.1f MB",value/1048576) end
  if value>=1024 then return string.format("%.1f KB",value/1024) end
  return value.." B"
end

function M.run(ctx)
  local initial="system"
  for _,page in ipairs(pages) do if ctx.args and ctx.args.page==page.id then initial=page.id break end end
  local app={page=initial,scroll=1,input="",keyboard={},
    appMessage="",views=menu.new(),actions=menu.new(),model={items={},lines={},apps={}},control={busy=false}}
  local reader,win,timer
  local function notify(ok,title,message)
    if ctx.notifications then ctx.notifications:push(ok and "success" or "warn",title,tostring(message or (ok and "Saved" or "Failed")),3) end
  end
  local function allowed(permission)
    local ok,err=ctx.security.require(permission,"Settings")
    if not ok then notify(false,"Settings",err) end
    return ok
  end
  local actor={pid=ctx.pid,appId=ctx.appId,permissions=ctx.permissions or {}}
  local closed=false
  local function authenticate(action,password,oldPassword)
    if app.authBusy then notify(false,"Security","Authentication already in progress") return end
    local scheduler=ctx.system and ctx.system.scheduler
    if not scheduler then notify(false,"Security","Authentication worker unavailable") return end
    app.authBusy=true app.authCancel=false app.appMessage="Hashing password; 0%"
    app.authStage="Authentication"
    local options={cancelled=function() return closed or app.authCancel end,
      stage=function(label) app.authStage=label app.appMessage=label if ctx.invalidate and not closed then ctx.invalidate() end end,
      progress=function(done,total)
        app.appMessage=app.authStage.." "..math.floor(done/total*100).."%"
        if ctx.invalidate and not closed then ctx.invalidate() end
      end}
    local pid=scheduler:spawn("Settings authentication",function()
      local called,ok,message=pcall(function()
        if action=="unlock" then return securityd.unlock(password,options) end
        if action=="adminLogin" then return securityd.login("admin",password,options) end
        return securityd.setPassword("admin",password,oldPassword,actor,options)
      end)
      password,oldPassword=nil,nil
      app.authBusy=false
      if not closed then
        if app.authCancel then ok,message=false,"Authentication cancelled"
        elseif not called then ok,message=false,"Authentication failed" end
        app.appMessage=tostring(message or (ok and "Password changed" or "Authentication failed"))
        notify(ok,"Security",app.appMessage)
        if ctx.invalidate then ctx.invalidate() end
        os.queueEvent("mintcraft_app_result",ctx.pid)
      end
    end,{eventMode="raw",appId=ctx.appId,permissions=ctx.permissions,protected=true})
    local ok,err=scheduler:start(pid)
    if ok==false then app.authBusy=false notify(false,"Security",err) end
  end
  if ctx.onCleanup then ctx.onCleanup(function()
    -- Let the raw worker cancel before commit and release the shared auth mutex.
    closed=true app.authCancel=true app:cancelInput()
  end) end
  function app:beginInput(mode)
    menu.dismiss(self.views,self.actions) self.mode,self.input=mode,""
    if mode=="label" then self.input=os.getComputerLabel and (os.getComputerLabel() or "") or "" end
  end
  function app:cancelInput() self.mode,self.input,self.oldPassword,self.newPassword=nil,"",nil,nil end
  function app:items()
    local result={}
    local function add(id,label,active) result[#result+1]={id=id,label=label,active=active} end
    if self.authBusy then add("cancelAuth","Cancel authentication") return result end
    if self.page=="system" then add("label","Set label")
    elseif self.page=="display" then
      add("refresh","Refresh")
      local cfg=config.load('/system/config/system.cfg',{})
      add("graphics:auto","Automatic pixels",not cfg.safeMode and cfg.graphicsMode~='pixel16')
      add('graphics:pixel16','16-color pixels',not cfg.safeMode and cfg.graphicsMode=='pixel16')
      add('graphics:text','Text rescue',cfg.safeMode==true)
      for _,name in ipairs({'stable','balanced','performance'}) do
        add('gfxprofile:'..name,'Performance: '..name,(cfg.graphicsProfile or 'balanced')==name)
      end
      add('gfxopt:off','Disable new graphics optimizations',cfg.graphicsOptimizations==false)
      add('gfxopt:on','Enable graphics optimizations',cfg.graphicsOptimizations~=false)
      for _,hz in ipairs({10,15,20}) do add('gfxhz:'..hz,'Presentation max '..hz..' Hz',(cfg.graphicsMaxHz or 20)==hz) end
      for _,scale in ipairs({1,1.5,2}) do add('uiscale:'..scale,'UI scale '..scale..'x',(cfg.uiScale or 1)==scale) end
      local selected=deviced.getPreference and deviced.getPreference() or "auto"
      add("display:auto","Automatic",selected=="auto") add("display:computer","Computer",selected=="computer")
      for _,device in ipairs(deviced.list()) do
        if device.type=="monitor" or device.type=="terminal" then add("display:"..device.name,device.name,selected==device.name) end
      end
      if deviced.getDisplay().target=="monitor" then
        for _,v in ipairs({0.5,1,1.5,2,2.5,3,3.5,4,4.5,5}) do add("scale:"..v,"Scale "..v,deviced.getDisplay().scale==v) end
      end
    elseif self.page=="desktop" then add("theme:mint","Mint",theme.currentId=="mint") add("theme:dark","Dark",theme.currentId=="dark")
    elseif self.page=="network" then add("launch:browser","Browser") add("launch:messenger","Messenger") add("launch:crafttube","CraftTube")
    elseif self.page=="nav" then add("launch:navigation","Open Navigation")
    elseif self.page=="combat" then add("launch:combat","Open Combat")
    elseif self.page=="dev" then add("launch:files","Open Files")
    elseif self.page=="sound" then
      local st=audiod.status() add("audio",st.enabled and "Disable" or "Enable") add("test","Test")
      for _,v in ipairs({0.5,1,1.5,2}) do add("volume:"..v,"Volume "..v,st.volume==v) end
      for _,speaker in ipairs(st.speakers or {}) do add("speaker:"..speaker.side,"Use "..speaker.side) end
    elseif self.page=="security" then
      add("lock","Lock") add("unlock","Unlock") add("adminLogin","Admin") add("guest","Guest") add("passwordOld","Change password")
    elseif self.page=="apps" then add("profile:desktop","Full") add("profile:pocket","Pocket") add("profile:auto","Auto")
    elseif self.page=="storage" then
      if self.cleanupPending then add("cleanupConfirm","Confirm prune") add("cleanupCancel","Cancel")
      else add("cleanup","Prune old backups") end
    end
    return result
  end
  function app:getItems()
    if self.authBusy then return {{id='cancelAuth',label='Cancel authentication'}} end
    if self.rescuePending then return {{id='rescueConfirm',label='Confirm text rescue'},{id='rescueCancel',label='Cancel'}} end
    if self.cleanupPending then return {{id='cleanupConfirm',label='Confirm prune'},{id='cleanupCancel',label='Cancel'}} end
    return self.model.page==self.page and self.model.items or {}
  end
  function app:lines()
    local rows={}
    local function line(value) rows[#rows+1]=tostring(value) end
    local id=computerId()
    local ip="10.0."..(math.floor(id/256)%256).."."..(id%256)
    if self.page=="system" then
      line("Computer ID: "..id) line("Label: "..tostring(os.getComputerLabel and (os.getComputerLabel() or "-") or "-"))
      line("MintCraft: "..version.current()) line("Pseudo IP: "..ip) line("CraftOS over CC:Tweaked")
    elseif self.page=="display" then
      local d=deviced.getDisplay() local cells=(d.width or 0)*(d.height or 0)
      line("Target: "..tostring(d.target)) line("Text cells: "..tostring(d.width).."x"..tostring(d.height))
      line("Monitor side: "..tostring(d.monitorSide or "-")) line("Scale: "..tostring(d.scale or "-"))
      if d.target=="terminal" then
        line("Terminal: "..tostring(d.terminalSide)) line("Input: "..(d.mouse and "keyboard + mouse" or "keyboard"))
      end
      line("Preference: "..tostring(deviced.getPreference and deviced.getPreference() or "auto"))
      line("Monitor grade: "..(d.target~="monitor" and "computer" or cells>=4500 and "A" or cells>=2500 and "B" or cells>=1200 and "C" or "D"))
      line("Text fallback mosaic: "..((d.width or 0)*2).."x"..((d.height or 0)*3).." subpixels")
      local g=ctx.system and ctx.system.renderStats and ctx.system.renderStats()
      if g then
        line("Backend: "..tostring(g.backend or "TEXT"))
        if g.pixelWidth then line("Pixels: "..g.pixelWidth.."x"..g.pixelHeight) end
        if g.lastError then line("Graphics error: "..g.lastError) end
        line('Performance: '..tostring(g.profile or 'unavailable'))
        line('Optimizations: '..tostring(g.optimized))
        line('Boot Guard: '..tostring(g.bootGuard or 'unavailable'))
        line('Skipped presents: '..tostring(g.skippedPresents or 0))
        line('drawPixels calls: '..tostring(g.drawCalls or 0))
        if g.bootGuardReason then line('Boot reason: '..tostring(g.bootGuardReason)) end
        local ok,checkpoint=pcall(function() return require('system.services.updated').rollbackInfo() end)
        line('Checkpoint: '..tostring(ok and checkpoint and checkpoint.id or 'unavailable'))
        local measured,heap=pcall(collectgarbage,'count')
        if measured then line(string.format('Lua heap: %.1f KiB',heap)) end
      end
    elseif self.page=="desktop" then line("Theme: "..theme.currentId) line("Keyboard: AZERTY")
    elseif self.page=="network" then
      local st=networkd.getStatus() local tube=config.load("/system/config/crafttube.cfg",{})
      line("HTTP: "..(st.http and "available" or "missing")) line("WebSocket: "..(st.websocket and "available" or "missing"))
      line("Rednet: "..(deviced.scanError and "scan unavailable" or deviced.hasType("modem") and "modem detected" or "no modem"))
      line("Pseudo IP: "..ip) line("CraftTube "..tostring(tube.provider or "proxy")..": "..tostring(tube.proxy or ""))
    elseif self.page=="storage" then
      local free=fs.getFreeSpace and fs.getFreeSpace("/") local cap=fs.getCapacity and fs.getCapacity("/")
      line("Root: /") if type(cap)=="number" and type(free)=="number" then line("Used: "..sizeLabel(cap-free).." / "..sizeLabel(cap)) end
      line("Free: "..sizeLabel(free)) line("Trash: /home/user/.trash")
      local ok, updated=pcall(require,"system.services.updated")
      if ok and updated.storageInfo then
        local ready,info=pcall(updated.storageInfo)
        if ready then
          line("Update backups: "..sizeLabel(info.bytes))
          for _,backup in ipairs(info.backups or {}) do line(backup.id.." "..sizeLabel(backup.bytes)..(backup.protected and " protected" or "")) end
        else line("Update storage unavailable") end
      end
      if self.cleanupPending then line("Prune old backups? Protected checkpoints remain.") end
    elseif self.page=="sound" then
      local st=audiod.status() line("Audio service: "..(st.ready and "ready" or "stopped")) line("Enabled: "..tostring(st.enabled==true))
      line("Speakers: "..tostring(st.count or 0)) line("Default side: "..tostring(st.defaultSide or "-"))
      line("Volume: "..tostring(st.volume).." Notify: "..tostring(st.notificationVolume))
      for _,speaker in ipairs(st.speakers or {}) do line("Speaker: "..speaker.side) end
    elseif self.page=="security" then
      local cfg=config.load("/system/config/security.cfg",{}) local user=securityd.currentUser()
      line("Security: "..(cfg.enabled~=false and "enabled" or "disabled")) line("Mode: "..tostring(cfg.mode or "users"))
      line("User: "..tostring(user and user.name or "?")) line("Service: "..securityd.statusText())
      for _,item in ipairs(securityd.users()) do line((item.active and "* " or "  ")..item.name.."  "..item.role.."  "..table.concat(item.permissions or {},",")) end
    elseif self.page=="packages" then
      local installed=ctx.system.packages.installed() line("PACKAGE          VERSION")
      if #installed==0 then line("No package installed") end
      for _,item in ipairs(installed) do line(item.name.."          "..item.version) end
    elseif self.page=="dev" then line("Editor: Files") line("Autocomplete: enabled") line("Keyboard: AZERTY")
    elseif self.page=="nav" then
      local st=require("system.services.sabled").status() local av=require("system.services.avionicsd").status()
      local counts=av.counts or {} local nav=config.load("/system/config/navigation.cfg",{}) local aircraft=nav.aircraft or {}
      line("CC:Sable: "..(st.available and "available" or "missing")) line("Sublevel: "..(st.inSublevel and "ready" or "not detected"))
      line("APIs: "..table.concat(st.apiNames or {},",")) line("Avionics: "..(av.available and "ready" or "missing"))
      line("Alt="..tostring(counts.altitude or 0).." Gimbal="..tostring(counts.gimbal or 0).." Prop="..tostring(counts.propeller or 0))
      line("Aircraft: "..tostring(aircraft.name or "-").." mass="..tostring(aircraft.massKg or "-").."kg weight="..tostring(aircraft.declaredWeightNewton or "-").."N")
      line("Frequencies:") for _,cmd in ipairs(aircraft.commands or {}) do line(tostring(cmd.name).." -> "..tostring(cmd.frequency)) end
      line("Redstone profiles:") for _,item in ipairs(nav.redstoneProfiles or {}) do line(tostring(item.name).." -> "..tostring(item.side).." "..tostring(item.pulseSeconds).."s") end
    elseif self.page=="combat" then
      local st=require("system.services.combatd").status() local counts=st.counts or {} local cfg=config.load("/system/config/combat.cfg",{})
      line("Combat: "..(st.available and "ready" or "missing"))
      line("Radar="..tostring(counts.radars or 0).." Targets="..tostring(counts.targets or 0).." Cannons="..tostring(counts.cannons or 0).." Unknown="..tostring(counts.unknown or 0))
      line("Semi-auto: "..tostring(cfg.semiAuto~=false).." confirmFire="..tostring(cfg.requireFireConfirmation~=false))
      line("Ballistics: gravity="..tostring(cfg.ballistics and cfg.ballistics.gravity or "-").." muzzle="..tostring(cfg.ballistics and cfg.ballistics.muzzleVelocity or "-"))
      for _,err in ipairs(st.errors or {}) do line("Error: "..tostring(err)) end
    end
    return rows
  end
  function app:draw(w,h)
    self.width,self.height=w,h
    local label="Settings" for _,page in ipairs(pages) do if page.id==self.page then label=page.label break end end
    menu.bar(self.views,1,1,w,pages,{selector=true,label=label,selected=self.page,title="Settings"})
    menu.bar(self.actions,1,2,w,self:getItems(),{title=label.." actions"})
    local fg,bg=theme.get("windowFg"),theme.get("windowBg")
    local function text(y,value) if y>=3 and y<=h-2 then renderer.writeAt(1,y,renderer.crop(tostring(value),w),fg,bg) end end
    self.appRows={}
    if self.page=="apps" then
      text(3,"Profile: "..tostring(self.model.profileMode or 'pending')) text(4,"Activation only; files kept") text(5,"Services: restart required")
      local rows=self.model.apps or {} local count=math.max(0,h-7)
      self.scroll=math.max(1,math.min(self.scroll,math.max(1,#rows-count+1)))
      for i=1,count do local item=rows[self.scroll+i-1] if not item then break end
        text(i+5,(item.enabled and "[x] " or "[ ] ")..item.name..(item.core and " *" or ""))
        self.appRows[#self.appRows+1]={id=item.id,x=1,y=i+5,w=w,h=1}
      end
    else
      local wrapped={}
      for _,line in ipairs(self.model.page==self.page and self.model.lines or {'Reading settings...'}) do
        if #line==0 then wrapped[#wrapped+1]="" end
        for first=1,#line,math.max(1,w) do wrapped[#wrapped+1]=line:sub(first,first+w-1) end
      end
      local count=math.max(0,h-4) self.scroll=math.max(1,math.min(self.scroll,math.max(1,#wrapped-count+1)))
      for i=1,count do text(i+2,wrapped[self.scroll+i-1] or "") end
    end
    self.pager=ui.toolbar(1,h-1,math.min(8,w),{{id="up",label="^"},{id="down",label="v"}})
    if w>8 then renderer.writeAt(9,h-1,renderer.crop(self.appMessage,w-8),fg,bg) end
    renderer.writeAt(1,h,renderer.crop("Settings",w),fg,bg)
    if self.mode then
      local hints={label="Label",unlock="Unlock password",adminLogin="Admin password",passwordOld="Current admin password",passwordNew="New password",passwordConfirm="Confirm password"}
      self.keyboard.x=1 self.keyboard.y=math.max(1,h-keyboard.height()+1)
      self.keyboard.hint=(hints[self.mode] or "Password")..": "..(self.mode=="label" and self.input or string.rep("*",#self.input))
      keyboard.draw(1,self.keyboard.y,w,self.keyboard)
    else menu.overlay(self.views,w,h) menu.overlay(self.actions,w,h) end
  end
  function app:submit(id,value)
    local ok,result=settingsd.request({pid=ctx.pid},id,value)
    self.appMessage=ok and ('Queued #'..result) or tostring(result)
    if ok then self.operation=result end
    self.control=settingsd.status()
    return ok,result
  end
  function app:toggleApp(id)
    for _,row in ipairs(self.model.apps or {}) do if row.id==id then
      if row.core then self.appMessage='Essential app' else self:submit('app:'..id,not row.enabled) end return
    end end
  end
  function app:setPage(id)
    for _,page in ipairs(pages) do if page.id==id then
      self.page=id self.scroll=1 self.bodyScroll=0 self.cleanupPending=false self.rescuePending=false
      self:cancelInput() menu.dismiss(self.views,self.actions) self:requestRead() return true
    end end
  end
  function app:action(id)
    if id=="cancelAuth" then if self.authBusy then self.authCancel=true self.appMessage="Cancelling authentication" end return end
    if self.authBusy then notify(false,"Security","Authentication already in progress") return end
    if id=='graphics:text' then if allowed('system.config') then self.rescuePending=true end return end
    if id=='rescueCancel' then self.rescuePending=false return end
    if id=='rescueConfirm' then if self.rescuePending then self.rescuePending=false self:submit('graphics:text') end return end
    if id=="cleanup" then
      if allowed("system.storage.manage") then self.cleanupPending=true end return
    elseif id=="cleanupCancel" then self.cleanupPending=false return
    elseif id=="cleanupConfirm" then
      if not self.cleanupPending then return end
      self.cleanupPending=false
      if not allowed("system.storage.manage") then return end
      self:submit('cleanupConfirm',true) return
    end
    if id:sub(1,7)=="launch:" then ctx.apps.launch(id:sub(8)) return end
    if id=="unlock" or id=="adminLogin" then self:beginInput(id) return end
    if id=="passwordOld" then if allowed("system.security.admin") then self:beginInput(id) end return end
    if id=="lock" or id=="guest" then
      if not allowed("system.auth") then return end
      self:submit(id) return
    end
    if id:sub(1,8)=="profile:" then self:submit(id) return end
    if id=="audio" or id=="test" or id:sub(1,7)=="volume:" or id:sub(1,8)=="speaker:" then
      if not allowed("audio.control") then return end
      if id=='audio' then
        if not self.model.audio then self.appMessage='Read audio state first' return end
        self:submit(id,not self.model.audio.enabled)
      else self:submit(id) end return
    end
    if not allowed("system.config") then return end
    if id=="label" then self:beginInput(id)
    else self:submit(id) end
  end
  app.keyboard.onText=function(ch) app.input=(app.input..ch):sub(1,1024) end
  app.keyboard.onBackspace=function() app.input=app.input:sub(1,-2) end
  app.keyboard.onEnter=function()
    local mode,input=app.mode,app.input
    if mode=="passwordOld" then app.oldPassword=input app:beginInput("passwordNew") return end
    if mode=="passwordNew" then app.newPassword=input app:beginInput("passwordConfirm") return end
    if mode=="passwordConfirm" then
      if input~=app.newPassword then notify(false,"Security","Passwords do not match")
      elseif allowed("system.security.admin") then authenticate("setPassword",input,app.oldPassword) end
    elseif mode=="unlock" or mode=="adminLogin" then authenticate(mode,input)
    elseif mode=="label" and allowed("system.config") and os.setComputerLabel then app:submit('label',input) end
    app:cancelInput()
  end
  function app:handle(event)
    if self.graphicsActive and not event.name:match('^mouse_') then return self:handlePixels(event) end
    if self.mode then
      if event.name=="char" or event.name=="paste" then self.keyboard.onText(event.args[1])
      elseif event.name=="key" then
        if event.args[1]==keys.escape then self:cancelInput()
        elseif event.args[1]==keys.backspace then self.keyboard.onBackspace()
        elseif event.args[1]==keys.enter then self.keyboard.onEnter() end
      elseif event.name=="mouse_click" and event.monitorTouch then keyboard.handle(event,self.keyboard) end
      return true
    end
    local source,id,handled=menu.route({{name="views",state=self.views},{name="actions",state=self.actions}},event)
    if handled then
      if id and source=="views" then self:setPage(id)
      elseif id then self:action(id) end return true
    end
    if event.name=="mouse_scroll" then self.scroll=math.max(1,self.scroll+event.args[1]) return true end
    if event.name~="mouse_click" then return false end
    local _,x,y=table.unpack(event.args) local direction=ui.toolbarHit(self.pager,x,y)
    if direction then self.scroll=math.max(1,self.scroll+(direction=="down" and 1 or -1)) return true end
    if self.page=="apps" then for _,box in ipairs(self.appRows) do if ui.hit(box,x,y) then
      self:toggleApp(box.id) return true
    end end end
    return false
  end
  function app:requestRead()
    if self.reading then return end
    self.reading=true
    local ok,err=reader:submit({page=self.page,authBusy=self.authBusy==true,cleanupPending=self.cleanupPending==true})
    if not ok then self.reading=false self.appMessage=tostring(err) end
  end
  reader=workers.new(ctx,'Settings metadata',function(request)
    local snapshot=setmetatable({page=request.page,authBusy=false,cleanupPending=false},{__index=app})
    local result={page=request.page,items={},lines={},apps={}}
    for i,item in ipairs(snapshot:items()) do if i>256 then break end
      if type(item.id)=='string' and #item.id<=128 then result.items[#result.items+1]={id=item.id,label=tostring(item.label):sub(1,256),active=item.active==true} end
    end
    local bytes=0
    for i,line in ipairs(snapshot:lines()) do
      line=line:sub(1,4096) bytes=bytes+#line
      if i>256 or bytes>65536 then result.lines[#result.lines+1]='[settings detail limit reached]' break end result.lines[#result.lines+1]=line
    end
    result.control=settingsd.status()
    if request.page=='apps' then
      result.profileMode=profile.mode()
      result.profileRequested=profile.configuration().mode
      result.lines[#result.lines+1]='Requested profile: '..result.profileRequested
      result.lines[#result.lines+1]='Effective profile: '..result.profileMode
      for _,item in ipairs(result.items) do if item.id:sub(1,8)=='profile:' then item.active=item.id:sub(9)==result.profileRequested end end
      for i,row in ipairs(ctx.apps.list(true,true)) do if i>256 then break end result.apps[#result.apps+1]={id=row.id,name=row.name,enabled=profile.appEnabled(row.id),core=profile.isCore(row.id)} end
    elseif request.page=='sound' then result.audio=audiod.status()
    elseif request.page=='display' then
      result.capabilities=ctx.system.graphicsCapabilities and ctx.system.graphicsCapabilities() or {}
      local cfg=config.load('/system/config/system.cfg',{})
      result.lines[#result.lines+1]='Requested UI scale: '..tostring(cfg.uiScale or 1)..'x (small displays use 1x)'
      result.lines[#result.lines+1]='Frame policy: retained/event-driven'
      for _,key in ipairs({'graphics','palette','freeze','color','probed'}) do result.lines[#result.lines+1]=key..': '..tostring(result.capabilities[key]) end
    end
    return result
  end,function(_,ok,result)
    app.reading=false
    if not ok then app.appMessage='Settings read failed: '..tostring(result):sub(1,2048)
    elseif result.page==app.page then app.model=result app.control=result.control
    else app:requestRead() end
  end)
  pixel.attach(app,pages)
  local sw,sh=term.getSize()
  win=ctx.windowManager:create({title="Settings",w=math.min(96,sw),h=math.min(32,sh-1),x=1,y=1,app=app})
  ctx.onCleanup(function() if timer then ctx.cancelTimer(timer) end end)
  app:requestRead() timer=ctx.startTimer(1)
  while not win.closed do
    local event=ctx.pullEvent()
    if event and event.name=='timer' and event.args[1]==timer then
      app.control=settingsd.status()
      if not win.minimized then app:requestRead() end timer=ctx.startTimer(1)
    elseif event and event.name=='mintcraft_settings_result' and event.args[1]==ctx.pid and event.args[2]==app.operation then
      app.operation=nil app.appMessage=tostring(event.args[4]) notify(event.args[3],'Settings',app.appMessage) app:requestRead()
    elseif event and (event.name=='peripheral' or event.name=='peripheral_detach' or event.name=='mintcraft_display_resize') then app:requestRead() end
  end
end
return M
