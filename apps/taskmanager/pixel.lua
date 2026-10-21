local ui=require("system.graphics.widgets")
local fonts=require("system.graphics.fonts")
local View=require("system.graphics.view")
local primitives=require("system.graphics.primitives")
local metrics=require("apps.taskmanager.metrics")
local M={}
local pages={{id="processes",label="Processes"},{id="performance",label="Performance"},{id="renderer",label="Renderer"},{id="io",label="Acquisition"}}
local function rect(x,y,w,h) return {x=x,y=y,w=w,h=h} end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function number(v,unit) return metrics.finite(v) and string.format("%.1f%s",v,unit or "") or "unavailable" end
local function selected(app)
  for i,row in ipairs(app:filteredRows()) do if row.pid==app.selectedPid then return row,i end end
end
local function chart(s,r,history,key,label,p)
  local maximum=0 local latest local observed=false
  for _,point in ipairs(history) do if metrics.finite(point[key]) then maximum=math.max(maximum,point[key]) observed=true end end
  if history[#history] then latest=history[#history][key] end
  ui.label(s,r.x,r.y,label..": "..number(latest),r.w,p.text,p.panel)
  local area=rect(r.x+42,r.y+18,r.w-46,r.h-26)
  s:rect(area.x,area.y,area.w,area.h,p.desktop)
  local axis=maximum>=1e6 and string.format("%.1fM",maximum/1e6) or maximum>=1e3 and string.format("%.1fk",maximum/1e3) or number(maximum)
  ui.label(s,r.x,area.y,axis,38,p.muted,p.panel)
  ui.label(s,r.x,area.y+area.h-9,"0",38,p.muted,p.panel)
  for _,fraction in ipairs({0.5,1}) do primitives.line(s,area.x,area.y+math.floor((area.h-1)*fraction),area.x+area.w-1,area.y+math.floor((area.h-1)*fraction),p.border) end
  local first,last=history[1],history[#history]
  if not first or not last or not observed then ui.label(s,area.x+5,area.y+8,"Unavailable",area.w-10,p.muted,p.desktop) return end
  local duration=last.timestamp-first.timestamp local previous
  for _,point in ipairs(history) do
    if metrics.finite(point[key]) then
      local x=area.x+(duration>0 and (point.timestamp-first.timestamp)/duration or 1)*(area.w-1)
      local y=area.y+area.h-1-(maximum>0 and point[key]/maximum or 0)*(area.h-1)
      if previous and point.timestamp-previous.timestamp<=2.5 then primitives.line(s,previous.x,previous.y,x,y,p.accent) end
      s:rect(math.floor(x),math.floor(y),2,2,p.accent) previous={x=x,y=y,timestamp=point.timestamp}
    else previous=nil end
  end
end
function M.attach(app)
  function app:select(index)
    local rows=self:filteredRows() index=clamp(index,1,math.max(1,#rows))
    self.selectedPid=rows[index] and rows[index].pid or nil self.confirm=nil self.detailScroll=0 self.focus="list"
    if index<self.scroll then self.scroll=index elseif index>=self.scroll+(self.visible or 1) then self.scroll=index-(self.visible or 1)+1 end
  end
  function app:drawPixels(s,w,h,p)
    s:rect(0,0,w,h,p.panel) self.pixelHits={} self.rowHits={} self.scrollbar=nil self.thumb=nil self.detailArea=nil self.pageArea=nil
    self.smallLayout=w<200 or h<160
    if self.smallLayout then self.confirm=nil self.dragging=false ui.label(s,5,6,"Task Manager: enlarge window",w-10,p.text,p.panel) return end
    local snap=self.snapshot local age=os.clock()-snap.timestamp local stale=age<0 or age>2
    local function button(id,label,r,active,disabled,kind)
      if kind then ui.symbol(s,r,kind,p,active) else ui.button(s,r,label,disabled and {button=p.panel,text=p.muted} or p,active) end
      if self.focus==id then primitives.rect(s,r.x,r.y,r.w,r.h,p.accent) end
      self.pixelHits[#self.pixelHits+1]={id=id,rect=r,disabled=disabled}
    end
    local title="Processes" for _,page in ipairs(pages) do if page.id==self.page then title=page.label end end
    button("views",title,rect(5,4,96,23),self.menu)
    button("refresh","",rect(w-28,4,23,23),false,false,"refresh")
    if self.page=="processes" then
      local row=selected(self)
      button("kill","Kill",rect(106,4,44,23),false,stale or not row or row.protected or row.state~="ready")
      if w>=270 then button("details",self.inspect and "Back" or "Details",rect(155,4,64,23),self.inspect) end
      if w>=340 then button("live",self.onlyLive and "Live" or "All",rect(224,4,52,23),self.onlyLive) end
    end
    local status=stale and ("STALE snapshot: "..number(math.max(0,age)," s")) or #snap.rows.." listed / "..snap.ready.." live | "..snap.memory
    if snap.errors[1] then status="Read error: "..snap.errors[1] end
    ui.label(s,6,34,status,w-12,(stale or snap.errors[1]) and 1 or p.muted,p.panel)
    if self.page=="processes" then
      local rows=self:filteredRows() local wide=w>=680 local width=wide and w-250 or w-10
      local area=rect(5,64,width,h-86) self.visible=math.max(1,math.floor(area.h/20))
      self.scroll=clamp(self.scroll,1,math.max(1,#rows-self.visible+1))
      s:rect(area.x,48,area.w,14,p.desktop)
      ui.label(s,area.x+4,51,"PID",38,p.muted,p.desktop) ui.label(s,area.x+46,51,"STATE",65,p.muted,p.desktop)
      ui.label(s,area.x+116,51,"NAME",area.w-128,p.muted,p.desktop)
      for i=self.scroll,math.min(#rows,self.scroll+self.visible-1) do
        local row=rows[i] local y=area.y+(i-self.scroll)*20 local active=row.pid==self.selectedPid local bg=active and p.accent or p.panel local fg=active and p.ink or p.text
        s:rect(area.x,y,area.w-10,20,bg)
        ui.label(s,area.x+4,y+6,tostring(row.pid),38,fg,bg) ui.label(s,area.x+46,y+6,row.state,65,fg,bg)
        ui.label(s,area.x+116,y+6,row.name..(row.protected and " [protected]" or ""),area.w-128,fg,bg)
        self.rowHits[#self.rowHits+1]={index=i,rect=rect(area.x,y,area.w-10,20)}
      end
      if #rows==0 then ui.label(s,area.x+4,area.y+8,"No listed processes",area.w-14,p.muted,p.panel) end
      self.scrollbar=rect(area.x+area.w-8,area.y,8,area.h) self.thumb=ui.scrollbar(s,self.scrollbar,#rows,self.visible,self.scroll,p)
      if self.focus=="list" then primitives.rect(s,area.x,area.y,area.w,area.h,p.accent) end
      local row=selected(self)
      self.detailArea=self.inspect and rect(5,48,w-10,h-70) or wide and rect(w-238,48,233,h-70) or nil
      if self.detailArea then
        local r=self.detailArea
        if self.inspect then s:rect(r.x,r.y,r.w,r.h,p.panel) self.scrollbar=nil self.rowHits={} if w<270 then button("details","Back",rect(5,4,96,23)) end end
        local text=row and (row.name.."\nPID: "..row.pid.."\nState: "..row.state.."\nApp: "..tostring(row.appId or "unavailable").."\nProtected: "..tostring(row.protected==true)..
          "\nEvents: "..tostring(row.eventMode or "unavailable").."\nWindow: "..tostring(row.windowId or "unavailable").."\nStarted (UTC ms): "..tostring(row.startedAt or "unavailable")..
          "\nActive wall ms: "..number(row.runtimeMs).."\nResumes: "..tostring(row.resumes or "unavailable").."\nPermissions:\n"..table.concat(row.permissions or {},", ").."\n\nError:\n"..tostring(row.error or "none")) or "No process selected"
        if self.detailText~=text or self.detailWidth~=r.w then self.detailLayout=fonts.layout(text,r.w-12,65536,{wrap=true,lineSpacing=2}) self.detailText=text self.detailWidth=r.w end
        self.detailVisible=math.max(1,math.floor((r.h-20)/11)) self.detailMaximum=math.max(0,#self.detailLayout.lines-self.detailVisible) self.detailScroll=clamp(self.detailScroll or 0,0,self.detailMaximum)
        ui.label(s,r.x+4,r.y+2,"DETAILS",r.w-8,p.muted,p.panel)
        local v=View.new(s,r.x+5,r.y+18,r.w-10,r.h-20)
        for i=self.detailScroll+1,math.min(#self.detailLayout.lines,self.detailScroll+self.detailVisible) do fonts.draw(v,0,(i-self.detailScroll-1)*11,self.detailLayout.lines[i].text,p.text,p.panel) end
      end
    else
      local area=rect(5,49,w-18,h-71) self.pageArea=area
      local columns=w>=680 and 2 or 1 local contentHeight
      local lines
      if self.page=="performance" then contentHeight=math.ceil(4/columns)*126+76
      elseif self.page=="renderer" then
        local r=snap.render
        local pixels=r.backend=="PIXEL16" or r.backend=="PIXEL256"
        lines={"Backend: "..tostring(r.backend or "unavailable"),"Pixel dimensions: "..tostring(r.pixelWidth or "?").." x "..tostring(r.pixelHeight or "?"),
          "Compositor draw calls: "..number(r.frames),"Compositor draws / s: "..number(snap.renderRate),"Pixel payload total B: "..(pixels and r.generation and number(r.bytes) or "unavailable"),
          "Pixel payload B / s: "..number(snap.pixelRate),"Dirty region submissions: "..(pixels and number(r.regions) or "unavailable"),"Last successful present ms: "..(pixels and metrics.finite(r.lastDrawSeconds) and number(r.lastDrawSeconds*1000) or "unavailable"),
          "Backend generation: "..tostring(r.generation or "unavailable"),"Present requests / skipped: "..number(r.presentRequests).." / "..number(r.skippedPresents),
          "Presented images: "..number(r.presentedFrames),"drawPixels calls: "..number(r.drawCalls),
          "Dirty lines: "..number(r.dirtyLines),"Damage rectangles: "..number(r.damageRectangles),
          "Render requests / skipped: "..number(r.renderRequests).." / "..number(r.skippedRenders),
          "Prepare ms / max: "..number(r.prepareSeconds and r.prepareSeconds*1000).." / "..number(r.maxPrepareSeconds and r.maxPrepareSeconds*1000),
          "Compose ms / max: "..number(r.compositionSeconds and r.compositionSeconds*1000).." / "..number(r.maxCompositionSeconds and r.maxCompositionSeconds*1000),
          "Present max ms: "..number(r.maxDrawSeconds and r.maxDrawSeconds*1000),
          "Cache hits / misses / evictions: "..number(r.cacheHits).." / "..number(r.cacheMisses).." / "..number(r.cacheEvictions),
          "Cache pixel bytes / limit: "..number(r.cacheBytes).." / "..number(r.cacheLimit),
          "Graphics profile: "..tostring(r.profile or "unavailable"),"Boot Guard: "..tostring(r.bootGuard or "unavailable"),
          "Physical display FPS: unavailable","Aggregate network bytes: unavailable","Last render error:\n"..tostring(r.lastError or "none")}
      else
        local io=snap.acquisition
        lines={"Instrumented peripheral acquisition","Read attempts: "..number(io.reads),"Read attempts / s: "..number(snap.readRate),"In flight: "..number(io.inFlight),"Queued: "..number(io.queue),
          "Timeouts: "..number(io.timeouts),"Cycle overruns: "..number(io.overruns),"Concurrency limit: "..number(io.concurrency),"Read budget / tick: "..number(io.readsPerTick),"Aggregate network traffic: unavailable","","Runners:"}
        local names={} for name in pairs(io.runners or {}) do names[#names+1]=name end table.sort(names)
        for _,name in ipairs(names) do local r=io.runners[name] lines[#lines+1]=name..": last cycle "..number(r.seconds," s")..", "..number(r.reads).." reads; total overruns "..number(r.overruns) if r.error then lines[#lines+1]=tostring(r.error) end end
      end
      local layout
      if lines then layout=fonts.layout(table.concat(lines,"\n"),area.w-8,65536,{wrap=true,lineSpacing=3}) contentHeight=#layout.lines*12+8 end
      self.pageMaximum=math.max(0,contentHeight-area.h) self.pageScroll=clamp(self.pageScroll or 0,0,self.pageMaximum)
      local v=View.new(s,area.x,area.y,area.w,area.h)
      if self.page=="performance" then
        local charts={{"heapKB","Lua heap KiB"},{"readRate","Instrumented reads / s"},{"pixelRate","Pixel payload B / s"},{"renderRate","Compositor draws / s"}}
        local width=math.floor(area.w/columns)
        for i,entry in ipairs(charts) do chart(v,rect((i-1)%columns*width,math.floor((i-1)/columns)*126-self.pageScroll,width-8,120),self.history,entry[1],entry[2],p) end
        local y=math.ceil(4/columns)*126-self.pageScroll
        ui.label(v,2,y,snap.disk,area.w-4,p.text,p.panel)
        if snap.used and snap.capacity then v:rect(2,y+16,area.w-6,6,p.desktop) v:rect(2,y+16,math.floor((area.w-6)*snap.used/snap.capacity),6,p.accent) end
        ui.label(v,2,y+34,"CPU utilization: unavailable",area.w-4,p.muted,p.panel)
        ui.label(v,2,y+48,"Physical RAM: unavailable",area.w-4,p.muted,p.panel)
      else
        for _,line in ipairs(layout.lines) do if line.y-self.pageScroll>-12 and line.y-self.pageScroll<area.h then fonts.draw(v,2,line.y-self.pageScroll,line.text,p.text,p.panel) end end
      end
      self.scrollbar=rect(w-11,area.y,7,area.h) self.thumb=ui.scrollbar(s,self.scrollbar,contentHeight,area.h,self.pageScroll+1,p)
    end
    local footer=self.message
    if self.page=="performance" and #self.history>1 then footer="History span: "..number(self.history[#self.history].timestamp-self.history[1].timestamp," s").." | "..footer end
    ui.label(s,6,h-15,footer,w-12,p.muted,p.panel)
    if self.menu then
      local items={} for _,page in ipairs(pages) do items[#items+1]=page end items[#items+1]={id="live",label=self.onlyLive and "Show all processes" or "Show live processes"}
      local capacity=math.max(1,math.floor((h-34)/23)) self.menuCapacity=capacity self.menuFirst=clamp(self.menuFirst or 1,1,math.max(1,#items-capacity+1))
      for i=self.menuFirst,math.min(#items,self.menuFirst+capacity-1) do
        local item=items[i] local r=rect(5,29+(i-self.menuFirst)*23,160,22)
        button("page:"..item.id,item.label,r,item.id==self.page)
        if i==(self.menuCursor or 1) then primitives.rect(s,r.x,r.y,r.w,r.h,p.accent) end
      end
    end
    if self.confirm then
      self.menu=false self.pixelHits={} self.rowHits={} self.scrollbar=nil self.detailArea=nil
      local r=rect(8,math.max(32,math.floor(h/2)-43),w-16,86) s:rect(r.x,r.y,r.w,r.h,p.desktop)
      ui.paragraph(s,rect(r.x+7,r.y+7,r.w-14,34),"Kill PID "..self.confirm.pid.." - "..self.confirm.name.."?",p.text,p.desktop,{wrap=true})
      button("confirm","Confirm",rect(r.x+8,r.y+54,78,24)) button("cancel","Cancel",rect(r.x+94,r.y+54,70,24))
    end
  end
  function app:handlePixels(event)
    if self.smallLayout then return true end
    local x,y=event.args[2],event.args[3]
    local function action(id)
      if id=="views" then self.menu=not self.menu self.menuFirst=1 self.menuCursor=1
      elseif id=="refresh" then self:refresh(true)
      elseif id=="live" or id=="page:live" then self.onlyLive=not self.onlyLive self.scroll=1 self.selectedPid=nil self.menu=false self.inspect=false self.focus="list"
      elseif id:sub(1,5)=="page:" then self.page=id:sub(6) self.pageScroll=0 self.menu=false self.inspect=false self.focus="list"
      elseif id=="details" then self.inspect=not self.inspect self.focus=self.inspect and "details" or "list"
      elseif id=="kill" then
        local row=selected(self) local age=os.clock()-self.snapshot.timestamp
        if row and row.state=="ready" and not row.protected and age>=0 and age<=2 then self.confirm={pid=row.pid,name=row.name}
        else self.message="Process snapshot stale, exited or protected" end
      elseif id=="cancel" then self.confirm=nil
      elseif id=="confirm" and self.confirm then local pid=self.confirm.pid self.confirm=nil self:kill(pid) end
    end
    if event.name=="key" then
      local key=event.args[1]
      if key==keys.escape then self.confirm=nil self.menu=false self.inspect=false self.focus="list" return true end
      if self.confirm then if key==keys.enter then action("confirm") end return true end
      if self.menu then
        if key==keys.enter then action("page:"..(pages[self.menuCursor or 1] and pages[self.menuCursor or 1].id or "live"))
        elseif key==keys.up or key==keys.down or key==keys.tab then
          self.menuCursor=clamp((self.menuCursor or 1)+(key==keys.up and -1 or 1),1,#pages+1)
          if self.menuCursor<(self.menuFirst or 1) then self.menuFirst=self.menuCursor
          elseif self.menuCursor>=(self.menuFirst or 1)+(self.menuCapacity or 1) then self.menuFirst=self.menuCursor-(self.menuCapacity or 1)+1 end
        end return true
      end
      if key==keys.tab then
        local order={"views","refresh","kill","details","live","list"} local index=0 for i,id in ipairs(order) do if self.focus==id then index=i end end self.focus=order[index%#order+1] return true
      elseif key==keys.enter then
        for _,hit in ipairs(self.pixelHits or {}) do if hit.id==self.focus then if not hit.disabled then action(hit.id) end return true end end
        if self.page=="processes" then self.inspect=true self.focus="details" end return true
      elseif key==keys.up or key==keys.down or key==keys.home or key==keys["end"] or key==keys.pageUp or key==keys.pageDown then
        local pageSize=self.page~="processes" and math.max(1,math.floor(((self.pageArea or {}).h or 96)/12)) or self.focus=="details" and (self.detailVisible or 1) or (self.visible or 1)
        local step=key==keys.up and -1 or key==keys.pageUp and -pageSize or key==keys.pageDown and pageSize or 1
        if self.menu then self.menuFirst=math.max(1,(self.menuFirst or 1)+step)
        elseif self.page~="processes" then self.pageScroll=key==keys.home and 0 or key==keys["end"] and self.pageMaximum or clamp((self.pageScroll or 0)+step*12,0,self.pageMaximum or 0)
        elseif self.focus=="details" then self.detailScroll=key==keys.home and 0 or key==keys["end"] and self.detailMaximum or clamp((self.detailScroll or 0)+step,0,self.detailMaximum or 0)
        else local _,index=selected(self) index=index or self.scroll-1 self:select(key==keys.home and 1 or key==keys["end"] and #self:filteredRows() or index+step) end
        return true
      end
      return false
    end
    if self.confirm and event.name~="mouse_click" then return true end
    if event.name=="mouse_scroll" then
      if self.menu then self.menuFirst=math.max(1,(self.menuFirst or 1)+event.args[1])
      elseif self.page~="processes" then self.pageScroll=clamp((self.pageScroll or 0)+event.args[1]*36,0,self.pageMaximum or 0)
      elseif ui.hit(self.detailArea,x,y) then self.detailScroll=clamp((self.detailScroll or 0)+event.args[1]*3,0,self.detailMaximum or 0)
      else self.scroll=math.max(1,self.scroll+event.args[1]*3) end return true
    end
    if event.name=="mouse_up" then self.dragging=false return true end
    if event.name=="mouse_drag" and self.dragging and self.scrollbar then
      local y=y+(self.thumb and self.thumb.h/2 or 0)-(self.grab or (self.thumb and self.thumb.h/2 or 0))
      if self.pageArea then self.pageScroll=ui.scrollbarValue(self.scrollbar,self.pageMaximum+self.pageArea.h,self.pageArea.h,y)-1
      else self.scroll=ui.scrollbarValue(self.scrollbar,#self:filteredRows(),self.visible,y) end return true
    end
    if event.name~="mouse_click" then return false end
    if event.args[1]~=1 then return true end
    for i=#(self.pixelHits or {}),1,-1 do local hit=self.pixelHits[i] if ui.hit(hit.rect,x,y) then
      if self.menu and hit.id~="views" and hit.id:sub(1,5)~="page:" then self.menu=false elseif not hit.disabled then action(hit.id) end return true
    end end
    if self.menu then self.menu=false return true end
    if self.confirm then return true end
    if ui.hit(self.scrollbar,x,y) then
      self.grab=ui.hit(self.thumb,x,y) and y-self.thumb.y or nil self.dragging=true
      if not self.grab then return self:handlePixels({name="mouse_drag",args={1,x,y}}) end return true
    end
    if ui.hit(self.detailArea,x,y) then self.focus="details" return true end
    for _,hit in ipairs(self.rowHits or {}) do if ui.hit(hit.rect,x,y) then self:select(hit.index) if not self.detailArea then self.inspect=true self.focus="details" end return true end end
    return true
  end
end
return M
