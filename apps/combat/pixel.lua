local ui=require("system.graphics.widgets")
local View=require("system.graphics.view")
local instruments=require("system.navigation.instruments")
local canvas=require("system.graphics.radar_canvas")
local geometry=require("system.navigation.geometry")
local filter=require("system.navigation.radar_filter")
local addon=require("system.libraries.addon")
local primitives=require("system.graphics.primitives")
local M={}
local function rect(x,y,w,h) return {x=x,y=y,w=w,h=h} end
local function find(rows,id) if id==nil then return end for _,r in ipairs(rows or {}) do if r.id==id or r.name==id then return r end end end
local function num(v,unit) return addon.finite(v) and string.format("%.1f%s",v,unit or "") or "unavailable" end
local function overlap(a,b) return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h end
local function graphKey(app,area)
  local parts={}
  local function add(value) local text=tostring(value) parts[#parts+1]=#text..":"..text end
  local function position(v) for _,axis in ipairs({"x","y","z"}) do add(v and v[axis]) end end
  for _,value in ipairs({area.w,area.h,app.page,app.view.zoom,app.view.yaw,app.view.pitch}) do add(value) end
  add(app.radarId) add(app.targetId) add(app.view.network) add(app.view.relative)
  for _,c in ipairs(filter.categories) do add(app.filters[c.id]) end
  for _,r in ipairs(app.snapshot.radars or {}) do
    for _,key in ipairs({"id","name","range","heading","fov","verticalFov","halfHeight","running","remote"}) do add(r[key]) end
    position(r.position)
  end
  for _,t in ipairs(app.snapshot.targets or {}) do if filter.visible(t,app.filters) then
    for _,key in ipairs({"id","label","category","entityType","stale","friendly","synthetic"}) do add(t[key]) end
    position(t.position)
    for _,point in ipairs(t.history or {}) do position(point.position) end
    add("end history")
  end end
  local zone=app.snapshot.zone add(zone and zone.alerts)
  for _,key in ipairs({"x","y","z","radius"}) do add(zone and zone[key]) end
  return table.concat(parts,"|")
end
function M.attach(app,api,tabs)
  app.pixelPages={radar=true,three=true,targets=true,cannons=true,fire=true,probe=true,network=true}
  local legacyHandle=app.handle
  function app:handle(event)
    local handled=legacyHandle(self,event)
    self.pixelPages.radar=not self.setup self.pixelPages.three=not self.setup
    return handled
  end
  function app:drawPixels(s,w,h,p)
    s:rect(0,0,w,h,p.panel) self.nativeHits={} self.nativeContacts={}
    local function button(id,label,r,active,kind)
      if kind then ui.symbol(s,r,kind,p,active) else ui.button(s,r,label,p,active) end
      if self.nativeFocus==id then primitives.rect(s,r.x,r.y,r.w,r.h,p.accent) end
      self.nativeHits[#self.nativeHits+1]={id=id,rect=r}
    end
    if w<180 or h<180 then ui.label(s,5,6,"Combat: enlarge window",w-10,p.text,p.panel) return end
    local map=self.page=="radar" or self.page=="three"
    local title="Combat" for _,tab in ipairs(tabs) do if tab.id==self.page then title=tab.label end end
    button("views",title,rect(4,3,96,22),self.nativeViews)
    if map then
      button("radar", "2D",rect(104,3,30,22),self.page=="radar")
      button("three", "3D",rect(136,3,30,22),self.page=="three")
      if w>=270 then button("overview", "Network",rect(170,3,math.min(70,w-204),22),self.view.network) end
    end
    button("rescan","",rect(w-26,3,22,22),false,"refresh")
    local snap=self.snapshot or {} local acquisition=snap.acquisition or {}
    local measured=acquisition.effectiveHz
    local readStatus="READ "..num(measured," Hz").." / 20 Hz target | "..#(snap.radars or {}).." radars | "..#(snap.targets or {}).." contacts"
    if snap.ok==false then readStatus=readStatus.." | DEGRADED: "..tostring((snap.errors or {})[1] or snap.status or "pending") end
    ui.label(s,6,32,readStatus,w-12,snap.ok==false and 1 or p.accent,p.panel)
    self.nativeMap=nil
    if map then
      local x=4 local y=47
      local counts={}
      for _,target in ipairs(snap.targets or {}) do local category=filter.category(target) counts[category]=(counts[category] or 0)+1 end
      button("all","All",rect(x,y,34,20),next(self.filters)==nil) x=x+37
      for _,category in ipairs(filter.categories) do
        local bw=(#category.label+4)*6+12
        if x+bw>w-4 then x=4 y=y+23 end
        button("filter:"..category.id,category.label.." "..(counts[category.id] or 0),rect(x,y,bw,20),self.filters[category.id]) x=x+bw+3
      end
      local top=y+25 local panel=w>=500 and 184 or 0
      local area=rect(5,top,w-panel-10,math.max(12,h-top-51))
      self.nativeMap=area
      self.view.three=self.page=="three" self.view.filters=self.filters
      -- Acquisition revisions also change for timing/diagnostics. Reproject
      -- only when actual map inputs change, not for a stationary scan tick.
      local key=graphKey(self,area)
      if not self.nativeGraph or self.nativeGraph.key~=key then
        local image,hits,labels,status=instruments.radar(area.w,area.h,snap,self.radarId,self.targetId,self.view,true)
        self.nativeGraph={key=key,image=image.surface,hits=hits,labels=labels,status=status}
      end
      local graph=self.nativeGraph local image=graph.image
      local v=View.new(s,area.x,area.y,area.w,area.h)
      for row=0,image.height-1 do v:span(0,row,image.rows[row+1]) end
      local occupied={}
      local labels={} for _,label in ipairs(graph.labels) do labels[#labels+1]=label end
      table.sort(labels,function(a,b) if (a.id==self.targetId)~=(b.id==self.targetId) then return a.id==self.targetId end return tostring(a.id or a.text)<tostring(b.id or b.text) end)
      for _,label in ipairs(labels) do
        local width=math.min(150,#tostring(label.text or "")*6,area.w-4)
        local lx=math.max(1,math.min(area.w-width-1,label.x))
        for _,dy in ipairs({-12,2,14,-24,26}) do
          local r=rect(lx,label.y+dy,width,10) local clear=r.y>=1 and r.y+r.h<area.h
          for _,previous in ipairs(occupied) do if overlap(r,previous) then clear=false break end end
          for _,marker in ipairs(graph.hits) do if overlap(r,rect(marker.x-5,marker.y-5,10,10)) then clear=false break end end
          if clear then
            occupied[#occupied+1]=r
            ui.label(v,r.x,r.y,label.text,width,canvas.index(label.color),15)
            if label.id then self.nativeContacts[#self.nativeContacts+1]={id=label.id,rect=rect(area.x+r.x,area.y+r.y,width,10)} end
            break
          end
        end
      end
      for _,hit in ipairs(graph.hits) do self.nativeContacts[#self.nativeContacts+1]={id=hit.id,rect=rect(area.x+hit.x-7,area.y+hit.y-7,14,14)} end
      local radar=find(snap.radars,self.radarId) or (snap.radars or {})[1]
      if not radar or not radar.position or not addon.finite(radar.range) or radar.range<=0 then
        ui.label(v,8,15,"Radar position / range unavailable",area.w-16,1,15)
        ui.label(v,8,30,radar and radar.positionIssue or "Rescan or open Setup",area.w-16,p.text,15)
      end
      if panel>0 then
        local target=find(snap.targets,self.targetId)
        local relative=target and radar and geometry.relative(target.position,radar.position)
        local rows=target and {
          target.label or "ID "..tostring(target.id):sub(1,12),"Type: "..filter.category(target),
          "Name: "..tostring(target.labelSource or "identifier"),"Distance: "..num(relative and relative.distance," m"),
          "Bearing: "..num(relative and relative.bearing," deg"),"Altitude: "..num(target.position and target.position.y," m"),
          "Age: "..num(os.clock()-(target.timestamp or 0)," s"),target.stale and "STALE: commands blocked" or "Measured contact",
          target.remote and "Remote / display only" or "Local observation"
        } or {"No target selected","Radar: "..tostring(radar and radar.name or "none"),"Range: "..num(radar and radar.range," m"),
          "Heading: "..num(radar and radar.heading," deg"),"FOV: "..num(radar and radar.fov," deg"),
          "Cone: "..tostring(radar and radar.fovSource or "unknown"),"Pending: "..tostring(acquisition.pending or 0),
          "Cycle: "..num(acquisition.elapsed," s"),acquisition.overrun and "Acquisition over budget" or ""}
        for i,text in ipairs(rows) do if top+(i-1)*17<h-65 then ui.label(s,w-panel+3,top+(i-1)*17,text,panel-10,p.text,p.panel) end end
        button("alias","Alias",rect(w-panel+3,h-77,72,22),false)
      end
      local controls={{"zoomOut","-"},{"zoomIn","+"},{"radarNext","Radar"},{"radarConfig","Setup"},{"radarProbe","Probe"}}
      if self.page=="three" then controls={{"zoomOut","-"},{"zoomIn","+"},{"left","Yaw -"},{"right","Yaw +"},{"up","Tilt +"},{"down","Tilt -"}} end
      local bx=4
      for _,control in ipairs(controls) do local bw=#control[2]*6+14 if bx+bw<w-4 then button(control[1],control[2],rect(bx,h-47,bw,22)) bx=bx+bw+4 end end
      ui.label(s,6,h-20,graph.status or "",w-12,p.muted,p.panel)
    else
      local rows=self.page=="targets" and filter.targets(snap.targets,self.filters) or self.page=="cannons" and snap.cannons or self.page=="network" and (self.networkSnapshot or {}).nodes or snap.devices
      local top=51 local capacity=math.max(1,math.floor((h-116)/(self.page=="probe" and 52 or 26)))
      self.scroll=math.max(1,math.min(self.scroll,math.max(1,#(rows or {})-capacity+1)))
      if self.page=="fire" then
        local target=find(snap.targets,self.targetId) local cannon=find(snap.cannons,self.cannonId)
        local lines={"Cannon: "..tostring(cannon and cannon.name or "none"),"Target: "..tostring(target and target.label or "none"),
          "Mode: semi-auto / manual fire confirmation",self.solution and ("ESTIMATE: yaw "..num(self.solution.yaw).." / pitch "..num(self.solution.pitch).." (vacuum)") or "No verified solution"}
        for i,line in ipairs(lines) do ui.label(s,8,top+(i-1)*20,line,w-16,p.text,p.panel) end
      else
        for i=self.scroll,math.min(#(rows or {}),self.scroll+capacity-1) do
          local row=rows[i] local id=row.id or row.name
          local label=tostring(row.label or row.name or id)
          if self.page=="targets" then label=label.." | "..filter.category(row)..(row.stale and " | STALE" or "") end
          if self.page=="cannons" then label=label.." | yaw "..num(row.yaw).." / pitch "..num(row.pitch).." | assembled "..tostring(row.assembled) end
          if self.page=="network" then label=label..(row.included and " | included" or " | excluded")..(row.online and " | online" or " | offline") end
          button("row:"..i,label,rect(6,top+(i-self.scroll)*26,w-12,24),id==self.targetId or id==self.cannonId or id==self.deviceId)
        end
        if #(rows or {})==0 then ui.label(s,8,top,"No devices / contacts",w-16,p.muted,p.panel) end
      end
      if self.page=="probe" then
        local device=find(rows,self.deviceId)
        local y=top+capacity*26+8
        ui.label(s,8,y,"Methods: "..table.concat(device and device.methods or {},", "),w-16,p.accent,p.panel)
        local probe=snap.probe
        if probe and probe.name==self.deviceId then
          local values={}
          for key,value in pairs(probe.values or {}) do
            values[#values+1]=key.." = "..(type(value)=="table" and "[table; full data in exported log]" or tostring(value))
          end
          for key,value in pairs(probe.errors or {}) do values[#values+1]=key.." ERROR "..tostring(value) end
          table.sort(values)
          for i,value in ipairs(values) do if y+i*13<h-58 then ui.label(s,8,y+i*13,value,w-16,p.text,p.panel) end end
        end
      end
      local actions=self.page=="fire" and {{"solve","Solve"},{"aim","Aim"},{"track",self.tracking and "Stop" or "Track"},{"fire","Fire"}} or self.page=="network" and {{"networkToggle","Network"},{"publishToggle","Station"},{"networkConfig","Configure"},{"networkRescan","Discover"}} or self.page=="probe" and {{"probe","Read/export"},{"previous","Up"},{"next","Down"}} or {{"previous","Up"},{"next","Down"},{self.page=="targets" and "alias" or "ack",self.page=="targets" and "Alias" or "Verify"}}
      local bx=5 for _,a in ipairs(actions) do local bw=#a[2]*6+16 if bx+bw<w then button(a[1],a[2],rect(bx,h-49,bw,22)) bx=bx+bw+4 end end
      ui.label(s,6,h-20,self.message or "",w-12,p.muted,p.panel)
    end
    if self.nativeViews or self.nativeRadars then
      local mw=math.min(180,w-12) local capacity=math.max(1,math.floor((h-42)/23))
      local rows=self.nativeViews and tabs or snap.radars or {}
      self.nativeViewFirst=math.max(1,math.min(self.nativeViewFirst or 1,math.max(1,#rows-capacity+1)))
      for i=self.nativeViewFirst,math.min(#rows,self.nativeViewFirst+capacity-1) do
        local row=rows[i]
        button(self.nativeViews and "page:"..row.id or "station:"..i,row.label or row.name or row.id,
          rect(5,29+(i-self.nativeViewFirst)*23,mw,22),row.id==(self.nativeViews and self.page or self.radarId))
      end
    end
    if self.confirm then
      self.nativeViews=false self.nativeRadars=false self.nativeHits={} self.nativeContacts={}
      local r=rect(8,math.max(28,math.floor(h/2)-42),w-16,86)
      s:rect(r.x,r.y,r.w,r.h,p.desktop)
      ui.paragraph(s,rect(r.x+8,r.y+7,r.w-16,38),self.confirm.title,p.text,p.desktop,{wrap=true})
      button("confirm","Confirm",rect(r.x+8,r.y+55,78,23)) button("cancel","Cancel",rect(r.x+94,r.y+55,72,23))
    end
  end
  function app:handlePixels(event)
    local x,y=event.args[2],event.args[3]
    if event.name=="key" then
      local key=event.args[1]
      if key==keys.escape then self.nativeViews=false self.nativeRadars=false self.confirm=nil return true end
      if key==keys.tab then
        local hits=self.nativeHits or {} local index=0
        for i,hit in ipairs(hits) do if hit.id==self.nativeFocus then index=i break end end
        if #hits>0 then self.nativeFocus=hits[index%#hits+1].id end
        return true
      end
      if key==keys.enter then
        for _,hit in ipairs(self.nativeHits or {}) do if hit.id==self.nativeFocus then
          return self:handlePixels({name="mouse_click",args={1,hit.rect.x+1,hit.rect.y+1}})
        end end
      end
    end
    if self.confirm and event.name~="mouse_click" then return true end
    if event.name=="mouse_scroll" then
      if self.nativeViews or self.nativeRadars then self.nativeViewFirst=math.max(1,(self.nativeViewFirst or 1)+event.args[1])
      elseif self.page=="radar" or self.page=="three" then api.action(event.args[1]>0 and "zoomOut" or "zoomIn")
      else self.scroll=math.max(1,self.scroll+event.args[1]) end
      return true
    end
    if event.name~="mouse_click" then return false end
    for i=#(self.nativeHits or {}),1,-1 do local hit=self.nativeHits[i] if ui.hit(hit.rect,x,y) then
      local id=hit.id
      if self.confirm then
        if id=="confirm" then local callback=self.confirm.callback self.confirm=nil callback()
        elseif id=="cancel" then self.confirm=nil end
      elseif id=="views" then self.nativeViews=not self.nativeViews self.nativeRadars=false self.nativeViewFirst=1
      elseif id:sub(1,5)=="page:" then self.page=id:sub(6) self.scroll=1 self.tracking=false self.nativeViews=false
      elseif id:sub(1,8)=="station:" then
        local station=(self.snapshot.radars or {})[tonumber(id:sub(9))]
        if station then self.radarId=station.id end self.nativeRadars=false
      elseif self.nativeViews or self.nativeRadars then self.nativeViews=false self.nativeRadars=false
      elseif id=="radarNext" then self.nativeRadars=true self.nativeViews=false self.nativeViewFirst=1
      elseif id=="radar" or id=="three" then self.page=id
      elseif id=="all" or id:sub(1,7)=="filter:" then
        filter.toggle(self.filters,id=="all" and "all" or id:sub(8))
        local target=find(self.snapshot.targets,self.targetId)
        if target and not filter.visible(target,self.filters) then api.select(self.targetId) end
      elseif id:sub(1,4)=="row:" then
        local rows=self.page=="targets" and filter.targets(self.snapshot.targets,self.filters) or self.page=="cannons" and self.snapshot.cannons or self.page=="network" and (self.networkSnapshot or {}).nodes or self.snapshot.devices
        local row=rows[tonumber(id:sub(5))]
        if row then
          if self.page=="targets" then api.select(row.id)
          elseif self.page=="cannons" then self.cannonId=row.id self.tracking=false
          elseif self.page=="network" then api.station(row.id)
          else self.deviceId=row.id end
        end
      else api.action(id) end
      return true
    end end
    if self.nativeViews or self.nativeRadars then self.nativeViews=false self.nativeRadars=false return true end
    for _,hit in ipairs(self.nativeContacts or {}) do if ui.hit(hit.rect,x,y) then api.select(hit.id) return true end end
    return true
  end
end
return M
