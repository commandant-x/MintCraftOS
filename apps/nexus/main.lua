local renderer=require("system.gui.renderer")
local theme=require("system.gui.theme")
local ui=require("system.gui.components")
local menus=require("system.gui.action_menu")
local forms=require("system.gui.form")
local nexus=require("system.services.nexusd")
local M={}
function M.run(ctx,args)
  args=ctx.args or (type(args)=="table" and args or {})
  local actor={pid=ctx.pid}
  local app={page=args.deploy and "computers" or "dashboard",pages=menus.new(),commands=menus.new(),form=forms.new(),scroll=1,
    settings={key="",group=args.group or "factory"},message="",snapshot=nexus.snapshot()}
  if app.snapshot.role~="master" then app.page="setup" end
  if not args.group and app.snapshot.group then app.settings.group=app.snapshot.group end
  local pages={{id="dashboard",label="Dashboard"},{id="computers",label="Deploy"},{id="map",label="Network"},
    {id="missions",label="Missions"},{id="setup",label="Setup"}}
  local win,timer
  local function report(ok,err) app.message=ok and (err or "Done") or tostring(err) end
  local function request(action,options) report(nexus.request(actor,action,options)) end
  local function confirm(title,fn) app.confirm={title=title,fn=fn} end
  local function actions()
    if app.page=="setup" then return {{id="setup",label="Save MASTER"},{id="scan",label="Rescan"}} end
    if app.page=="computers" then return {{id="scan",label="Rescan"},{id="drive",label="Disk"},{id="prepare",label="Prepare disk"},
      {id="auto",label="Automate"},{id="pause",label="Pause automation"},
      {id="deploy",label="Deploy selected"},{id="seal",label="Seal disk"},{id="reboot",label="Restart agent"},{id="shutdown",label="Power off"}} end
    if app.page=="missions" then return {{id="groupPing",label="Ping group"},{id="groupInventory",label="Inventory group"},
      {id="groupStorage",label="Storage group"},{id="assign",label="Auto assign check"}} end
    return {{id="scan",label="Rescan"},{id="ping",label="Ping"},{id="inventory",label="Inventory"},{id="storage",label="Storage"}}
  end
  function app:draw(w,h)
    if w<18 or h<9 then renderer.writeAt(1,1,renderer.crop("NEXUS: enlarge window",w)) return end
    local pageLabel=self.page for _,page in ipairs(pages) do if page.id==self.page then pageLabel=page.label end end
    menus.bar(self.pages,1,1,w,pages,{selector=true,label="NEXUS / "..pageLabel,title="NEXUS OVERMIND",selected=self.page})
    local buttons=actions() for _,button in ipairs(buttons) do button.primary=true end
    menus.bar(self.commands,1,2,w,buttons,{title="NEXUS actions"})
    local s=self.snapshot
    renderer.writeAt(1,3,renderer.crop("MASTER "..s.master.." | "..s.online.." online / "..s.managed.." managed",w),theme.get("accent"))
    self.boxes={}
    if self.page=="setup" then
      self.form:draw(w,h,{forms.field(self.settings,"group","Deployment group","string"),forms.field(self.settings,"key","Private MASTER key (32+ chars)","secret")})
    elseif self.page=="computers" then
      local drive=s.drives[self.driveIndex or 1]
      renderer.writeAt(1,4,renderer.crop("Disk: "..(drive and (drive.name.." / "..tostring(drive.mount or "no data disk")) or "none").." | group "..self.settings.group,w))
      self.scroll=math.max(1,math.min(self.scroll,math.max(1,#s.computers-h+8)))
      for index=self.scroll,math.min(#s.computers,self.scroll+h-8) do
        local row=s.computers[index] local y=5+index-self.scroll
        local text=(row.authorized and "[x] " or "[ ] ")..row.id.." "..row.label.." | "..row.state..(row.powered and " / ON" or " / OFF")
        renderer.writeAt(1,y,renderer.crop(text,w),row.id==self.selected and colors.black or theme.get("windowFg"),row.id==self.selected and colors.cyan or theme.get("windowBg"))
        self.boxes[#self.boxes+1]={x=1,y=y,w=w,h=1,row=row}
      end
    elseif self.page=="map" then
      local wide=w>=64 and h>=16
      local compact=h<12
      local listW=wide and math.floor(w*0.62) or w
      local pageSize=math.max(1,math.floor((h-8)/3))
      local page=math.floor((math.max(1,self.scroll)-1)/pageSize)
      local pages=math.max(1,math.ceil(#s.computers/pageSize))
      page=math.min(page,pages-1) self.scroll=page*pageSize+1
      renderer.fill(1,4,listW,h-5,colors.black)
      renderer.writeAt(2,4,renderer.crop("MASTER #"..s.master.."  /  "..tostring(s.group or "unassigned"),listW-2),colors.cyan,colors.black)
      local selected
      for _,row in ipairs(s.computers) do if row.id==self.selected then selected=row end end
      for index=self.scroll,math.min(#s.computers,self.scroll+pageSize-1) do
        local row=s.computers[index] local y=(compact and 5 or 6)+(index-self.scroll)*3
        local focused=row.id==self.selected
        local bg=focused and colors.gray or colors.black
        local status=row.state=="ONLINE" and colors.lime or (row.state=="DISCOVERED" and colors.lightGray or colors.orange)
        renderer.fill(2,y,listW-3,compact and 1 or 2,bg)
        renderer.writeAt(2,y,renderer.crop((focused and "> " or "  ").."#"..row.id.." "..row.label,listW-3),colors.white,bg)
        if not compact then renderer.writeAt(4,y+1,renderer.crop(row.state.." | "..(row.authorized and (row.group or "managed") or "not managed"),listW-5),status,bg) end
        self.boxes[#self.boxes+1]={x=2,y=y,w=listW-3,h=compact and 1 or 2,row=row}
      end
      self.networkBar=ui.toolbar(1,h-2,listW,{{id="prev",label="Prev"},{id="next",label="Next"}})
      if listW>=26 then renderer.writeAt(17,h-2,renderer.crop((page+1).." / "..pages,listW-16),colors.lightGray,colors.black) end
      self.networkPageSize=pageSize self.networkPages=pages
      if wide then
        local x=listW+2 local dw=w-x+1
        renderer.fill(x,4,dw,h-5,theme.get("windowBg"))
        renderer.writeAt(x,4,renderer.crop("AGENT DETAILS",dw),theme.get("accent"))
        local lines=selected and {"#"..selected.id.." "..selected.label,selected.state,
          "Group: "..tostring(selected.group or "unmanaged"),"Agent: "..tostring(selected.version or "unknown"),
          "Last seen: "..(selected.lastSeenSeconds and math.floor(selected.lastSeenSeconds).."s" or "never"),
          "Tasks: "..(selected.activeMissions or 0),"Link: "..(selected.name and "wired peripheral" or "Rednet only"),"Peripherals:"} or {"Select an agent"}
        if selected then
          for _,device in ipairs(selected.peripherals or {}) do lines[#lines+1]=tostring(device.name or "?").." / "..tostring(device.type or "?") end
          lines[#lines+1]="Capabilities:"
          for _,cap in ipairs(selected.capabilities or {}) do lines[#lines+1]=tostring(cap) end
          if selected.error then lines[#lines+1]=selected.error end
        end
        for i=1,math.min(#lines,h-7) do renderer.writeAt(x,5+i,renderer.crop(lines[i],dw),theme.get("windowFg"),theme.get("windowBg")) end
      else
        renderer.writeAt(1,h-3,renderer.crop(selected and ("#"..selected.id.." "..selected.state.." / "..(selected.activeMissions or 0).." tasks") or "Select an agent",w))
      end
    else
      local lines={}
      if self.page=="missions" then
        lines[#lines+1]="Group: "..self.settings.group.." | newest first"
        for index=#s.jobs,1,-1 do local job=s.jobs[index]
          lines[#lines+1]=job.type.." -> "..job.node.." | "..job.state
          if job.result then lines[#lines+1]=textutils.serialize(job.result,{compact=true}) end
        end
      else
        lines={"NEXUS OVERMIND "..nexus.version,"Group: "..tostring(s.group or "not configured"),
          "Discovered: "..s.discovered,"Managed: "..s.managed,"Online: "..s.online,"Missions: "..#s.jobs,
          "Automation: "..((s.automation and s.automation.enabled) and "ON" or "OFF"),
          s.automation and s.automation.message or ""}
        for _,row in ipairs(s.computers) do if row.authorized then
          lines[#lines+1]=row.id.." "..row.label.." | "..row.state.." | agent "..tostring(row.version or "not registered")
          if row.error then lines[#lines+1]=row.error end
        end end
      end
      self.scroll=math.max(1,math.min(self.scroll,math.max(1,#lines-h+6)))
      for index=self.scroll,math.min(#lines,self.scroll+h-6) do renderer.writeAt(1,4+index-self.scroll,renderer.crop(tostring(lines[index]),w)) end
    end
    renderer.writeAt(1,h,renderer.crop(self.message~="" and self.message or s.message,w),colors.white,colors.gray)
    if self.confirm then
      renderer.fill(1,3,w,h-3,colors.gray)
      local text=self.confirm.title
      local capacity=math.max(1,math.min(h-3,8)-3)*w
      local offset=self.confirm.offset or 0
      text=text:sub(offset+1)
      for y=4,math.min(h-3,8) do renderer.writeAt(1,y,text:sub(1,w),colors.white,colors.gray) text=text:sub(w+1) if text=="" then break end end
      self.confirm.capacity=capacity
      self.confirmBar=ui.toolbar(1,h-2,w,{{id=text~="" and "more" or "yes",label=text~="" and "Read more" or "Confirm"},{id="no",label="Cancel"}})
    elseif not self.form.edit then menus.overlay(self.pages,w,h) menus.overlay(self.commands,w,h) end
  end
  function app:handle(event)
    if self.confirm then
      if event.name=="mouse_click" then
        local id=ui.toolbarHit(self.confirmBar,event.args[2],event.args[3])
        if id=="more" then self.confirm.offset=(self.confirm.offset or 0)+self.confirm.capacity
        elseif id=="yes" then local fn=self.confirm.fn self.confirm=nil fn() elseif id=="no" then self.confirm=nil end
      end return true
    end
    if self.form.edit then return self.form:handle(event) end
    local section,id,handled=menus.route({{name="pages",state=self.pages},{name="commands",state=self.commands}},event)
    if handled and section=="pages" then if id then self.page=id self.scroll=1 end return true end
    if handled and id then
      local s=self.snapshot local drive=s.drives[self.driveIndex or 1]
      if id=="setup" then report(nexus.setup(actor,self.settings.key,self.settings.group)) self.settings.key="" self.snapshot=nexus.snapshot()
      elseif id=="scan" then request("scan")
      elseif id=="groupPing" or id=="groupInventory" or id=="groupStorage" then
        local kinds={groupPing="ping",groupInventory="inventory",groupStorage="storage"}
        request("groupMission",{type=kinds[id],group=self.settings.group})
      elseif id=="assign" then request("assign",{type="storage",group=self.settings.group})
      elseif id=="drive" then self.driveIndex=(self.driveIndex or 1)%math.max(1,#s.drives)+1
      elseif id=="pause" then request("pause")
      elseif id=="auto" then
        confirm("Allow background deployment/restarts of currently authorized group "..self.settings.group.." (max 2 attempts/node), then seal disk? Unknown PCs excluded.",function()
          request("auto",{drive=drive and drive.name,group=self.settings.group})
        end)
      elseif id=="prepare" or id=="deploy" then
        if not drive then self.message="Connect a shared drive with a data disk" return true end
        confirm(id=="deploy" and "Prepare trusted disk and RESTART every authorized computer in group "..self.settings.group.."? Blank machines only; existing startups are protected." or "Prepare selected disk for authorized computers? Provisioning secrets will be readable on this shared disk; eject it after deployment.",function()
          request(id,{drive=drive.name,group=self.settings.group})
        end)
      elseif id=="reboot" or id=="shutdown" then
        confirm(id.." authorized computer "..tostring(self.selected).."?",function() request(id,{id=self.selected}) end)
      elseif id=="seal" then
        if not drive then self.message="No bootstrap disk" return true end
        confirm("Remove NEXUS provisioning keys and startup from this disk? Verify all selected agents are ONLINE first.",function() request("seal",{drive=drive.name}) end)
      else request("mission",{id=self.selected,type=id}) end
      return true
    elseif handled then return true end
    if self.page=="setup" then return self.form:handle(event) end
    if event.name=="mouse_scroll" then self.scroll=self.scroll+event.args[1]*(self.page=="map" and (self.networkPageSize or 1) or 1) return true end
    if event.name=="mouse_click" then
      if self.page=="map" then
        local direction=ui.toolbarHit(self.networkBar,event.args[2],event.args[3])
        if direction then
          self.scroll=math.max(1,math.min(self.scroll+(direction=="next" and 1 or -1)*(self.networkPageSize or 1),1+((self.networkPages or 1)-1)*(self.networkPageSize or 1)))
          return true
        end
      end
      for _,box in ipairs(self.boxes) do if ui.hit(box,event.args[2],event.args[3]) then
        self.selected=box.row.id
        if self.page=="computers" and event.args[2]<=4 then report(nexus.select(actor,box.row.id,not box.row.authorized,self.settings.group)) self.snapshot=nexus.snapshot() end
        return true
      end end
    end
    return false
  end
  local w,h=term.getSize()
  win=ctx.windowManager:create({title="NEXUS OVERMIND",w=math.max(18,math.min(92,w-2)),h=math.max(9,math.min(30,h-2)),x=2,y=2,app=app})
  request("scan") timer=ctx.startTimer(0.5)
  ctx.onCleanup(function() if timer then os.cancelTimer(timer) end end)
  while not win.closed do
    local event=ctx.pullEvent()
    if event.name=="timer" and event.args[1]==timer then
      if not win.minimized then app.snapshot=nexus.snapshot() end
      timer=ctx.startTimer(0.5)
    end
  end
end
return M
