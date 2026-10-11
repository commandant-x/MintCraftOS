local renderer=require("system.gui.renderer")
local ui=require("system.gui.components")
local forms=require("system.gui.form")
local addon=require("system.libraries.addon")
local geometry=require("system.navigation.geometry")
local instruments=require("system.navigation.instruments")
local radarSetup=require("system.navigation.radar_setup")
local combat=require("system.services.combatd")
local radarNet=require("system.services.radarnetd")
local filter=require("system.navigation.radar_filter")
local M={}
local function find(rows,id) if id==nil then return nil end for _,row in ipairs(rows or {}) do if row.id==id or row.name==id then return row end end end
local function fmt(value) return addon.finite(value) and string.format("%.1f",value) or "unavailable" end
function M.run(ctx)
  local actor={pid=ctx.pid}
  local app={page="radar",tabState={},barState={},filterState={},filters={},form=forms.new(),scroll=1,snapshot={},view={zoom=1,yaw=30,pitch=25},message="Semi-auto; manual fire confirmation",configKind="radar",tracking=false}
  local tabs={{id="radar",label="Radar"},{id="three",label="3D"},{id="targets",label="Targets"},{id="cannons",label="Cannons"},{id="fire",label="Fire"},{id="probe",label="Probe"},{id="config",label="Config"}}
  local cfg=combat.configuration()
  tabs[#tabs+1]={id="network",label="Network"}
  local win,timer,trackTimer
  local function refresh()
    app.snapshot=combat.snapshot()
    if app.setup then app.setup:update(app.snapshot) end
    for _,target in ipairs(app.snapshot.targets or {}) do target.stale=not target.freshnessKnown or os.clock()-target.timestamp>5 end
    if not find(app.snapshot.radars,app.radarId) then app.radarId=app.snapshot.radars[1] and app.snapshot.radars[1].id app.canvas=nil end
    if app.targetId and not find(app.snapshot.targets,app.targetId) then app.targetId=nil app.tracking=false app.confirm=nil app.solution=nil end
    if not app.cannonId and app.snapshot.cannons[1] then app.cannonId=app.snapshot.cannons[1].id end
  end
  local function report(ok,message) app.message=ok and (type(message)=="number" and "Queued #"..message or message or "Done") or tostring(message or "Refused") end
  local function confirm(title,callback) app.confirm={title=title,callback=callback} end
  local function selectTarget(id) app.targetId=filter.select(app.targetId,id) app.confirm=nil app.tracking=false app.solution=nil app.canvas=nil end
  local function solve()
    local solution,err=combat.solution(app.cannonId,app.targetId)
    app.solution=solution app.message=err or "Estimated vacuum trajectory (no drag)"
  end
  local function configObject()
    if app.configKind=="alias" then return app.alias or {value=""} end
    local section=app.configKind=="radar" and "radars" or "profiles"
    local id=app.configKind=="radar" and app.radarId or app.cannonId
    if not id then return end
    if not cfg[section][id] then
      local radar=find(app.snapshot.radars,id)
      cfg[section][id]=app.configKind=="radar" and {frame=radar and radar.frame=="world" and "world" or "unknown",headingFrame="world",headingSign=1,headingOffset=0,headingValidated=false} or {frame="unknown",headingFrame="world",yawSign=1,pitchSign=1,yawOffset=0,pitchOffset=0,validated=false}
    end
    return cfg[section][id]
  end
  local function fields()
    if app.configKind=="network" then
      local object=app.networkConfig
      local rows={}
      for _,entry in ipairs({{"group","World/dimension group","string"},{"x","Zone centre X","number"},{"y","Zone centre Y","number"},{"z","Zone centre Z","number"},{"radius","Zone radius m","number"},{"alerts","Perimeter alerts","boolean"}}) do
        rows[#rows+1]=forms.field(object,entry[1],entry[2],entry[3])
      end return rows
    end
    local object=configObject() local rows={}
    if not object then return rows end
    local function field(key,label,kind,options) rows[#rows+1]=forms.field(object,key,label,kind,options) end
    if app.configKind=="alias" then field("value","Local alias","string") return rows end
    field("frame","Position frame",nil,{"unknown","world","body"})
    field("headingFrame","Mount heading frame",nil,{"world","body"})
    if app.configKind=="radar" then
      field("apiProfile","Radar API profile",nil,{"auto","4.x","5.0-EA"})
      field("positionMode","Position source",nil,{"api","manual"})
      field("positionX","Radar position X","number")
      field("positionY","Radar position Y","number")
      field("positionZ","Radar position Z","number")
      field("headingSign","Rotation sign","number") field("headingOffset","Rotation offset deg","number")
      field("fov","Calibrated FOV deg","number") field("heading","Fixed heading deg (optional)","number")
      field("verticalFov","Calibrated vertical FOV (optional)","number")
      field("headingValidated","Rotating heading verified","boolean")
    else
      for _,key in ipairs({"gravity","muzzleVelocity","minYaw","maxYaw","minPitch","maxPitch","yawSign","pitchSign","yawOffset","pitchOffset"}) do field(key,key,"number") end
      field("validated","Geometry/ballistics physically calibrated","boolean")
    end
    return rows
  end
  local function actions()
    if app.page=="radar" or app.page=="three" then return {{id="rescan",label="Rescan"},{id="overview",label=app.view.network and "Local view" or "Overview"},{id="radarNext",label="Radar"},{id="radarConfig",label="Setup"},{id="alias",label="Alias"},{id="radarProbe",label="Read/Probe"},{id="zoomIn",label="Zoom+"},{id="zoomOut",label="Zoom-"},{id="left",label="Rotate-"},{id="right",label="Rotate+"},{id="up",label="Tilt+"},{id="down",label="Tilt-"}}
    elseif app.page=="network" then local net=radarNet.configuration() return {{id="networkToggle",label=net.enabled and "Network ON" or "Network OFF"},{id="publishToggle",label=net.publish and "Station ON" or "Station OFF"},{id="networkConfig",label="Zone/Group"},{id="networkRescan",label="Discover"},{id="previous",label="Up"},{id="next",label="Down"}}
    elseif app.page=="targets" then return {{id="alias",label="Alias"},{id="previous",label="Up"},{id="next",label="Down"}}
    elseif app.page=="cannons" then return {{id="rescan",label="Rescan"},{id="ack",label="Verify/acknowledge"},{id="previous",label="Up"},{id="next",label="Down"}}
    elseif app.page=="fire" then return {{id="solve",label="Solve"},{id="aim",label="Aim once"},{id="track",label=app.tracking and "Stop track" or "Track"},{id="fire",label="Fire"}}
    elseif app.page=="probe" then return {{id="probe",label="Read/export"},{id="rescan",label="Rescan"},{id="previous",label="Up"},{id="next",label="Down"}}
    elseif app.configKind=="network" then return {{id="networkSave",label="Save"},{id="networkCancel",label="Cancel"}}
    else return {{id="configKind",label="Radar/Cannon"},{id="save",label="Save"},{id="rescan",label="Rescan"}} end
  end
  function app:draw(w,h)
    if self.setup then self.setup:draw(w,h) return end
    if h<9 then renderer.writeAt(1,1,renderer.crop("Combat: enlarge window",w)) return end
    self.tabs=ui.tabs(1,1,w,tabs,self.page,self.tabState)
    self.bar=ui.toolbar(1,2,w,actions(),self.barState)
    self.rowHits={}
    local snap=self.snapshot
    if self.page=="radar" or self.page=="three" or self.page=="targets" then
      local counts={} for _,target in ipairs(snap.targets or {}) do local category=filter.category(target) counts[category]=(counts[category] or 0)+1 end
      local buttons={{id="all",label=(next(self.filters)==nil and "[x] " or "[ ] ").."All"}}
      for _,category in ipairs(filter.categories) do buttons[#buttons+1]={id=category.id,label=(self.filters[category.id] and "[x] " or "[ ] ")..category.label.." "..(counts[category.id] or 0)} end
      self.filterBar=ui.toolbar(1,4,w,buttons,self.filterState)
    else self.filterBar=nil end
    if self.page=="radar" or self.page=="three" then
      self.view.three=self.page=="three"
      self.view.filters=self.filters
      local panel=w>=75 and 27 or 0
      local graphW,graphH=w-panel,math.max(2,h-6)
      local key=table.concat({snap.revision or 0,graphW,graphH,tostring(self.targetId),tostring(self.radarId),self.page,self.view.zoom,self.view.yaw,self.view.pitch},":")
      if not self.canvas or self.graphW~=graphW or self.graphH~=graphH or (key~=self.graphKey and os.clock()-(self.graphAt or -1)>=0.2) then
        self.canvas,self.graphHits,self.labels,self.graphStatus=instruments.radar(graphW,graphH,snap,self.radarId,self.targetId,self.view)
        self.graphW,self.graphH,self.graphKey,self.graphAt=graphW,graphH,key,os.clock()
        self.labelLayout=nil
      end
      renderer.writeAt(1,3,renderer.crop((self.graphStatus or "").." | "..tostring(self.radarId or "No radar"),w),colors.cyan)
      if snap.ok==false and snap.errors and snap.errors[1] then renderer.writeAt(1,3,renderer.crop("Read error: "..snap.errors[1],w),colors.orange) end
      self.canvas:draw(1,5)
      local radar=find(snap.radars,self.radarId)
      if radar and (not radar.position or not radar.range or radar.range<=0) then
        local p=radar.rawPosition
        local rows={"Radar: "..radar.name,radar.readStatus or "Waiting for readings",
          "Contacts returned: "..tostring(radar.rawTrackCount or "unavailable"),
          "Raw position: "..(p and (fmt(p.x)..", "..fmt(p.y)..", "..fmt(p.z)) or "unavailable"),
          "Range: "..fmt(radar.range).."m | rotation: "..fmt(radar.rawRotation),
          "Dishes: "..tostring(radar.dishCount or "unavailable"),
          "Position source: "..tostring(radar.positionSource),
          "Position status: "..tostring(radar.positionIssue or "valid")}
        for i=1,math.min(#rows,graphH) do renderer.writeAt(1,4+i,renderer.crop(rows[i],graphW),colors.white,colors.black) end
      elseif radar then
        local source=self.view.network and ("All stations | contacts="..#filter.targets(snap.targets,self.filters)) or (radar.name.." | contacts="..tostring(radar.rawTrackCount or "?").." rot="..fmt(radar.rawRotation))
        renderer.writeAt(1,3,renderer.crop((self.graphStatus or "").." | "..source,w),colors.cyan)
        if snap.ok==false and snap.errors and snap.errors[1] then renderer.writeAt(1,3,renderer.crop("Read error: "..snap.errors[1],w),colors.orange) end
      else
        local unknown=(snap.unknownCombatDevices or {})[1]
        renderer.writeAt(1,5,renderer.crop(unknown and ("Unsupported: "..unknown.name.."; inspect Probe") or "No radar acquired; Rescan / Probe",graphW),colors.orange,colors.black)
      end
      if not self.labelLayout then
      self.labelLayout={}
      local occupied={}
      local labels=addon.copy(self.labels or {})
      table.sort(labels,function(a,b)
        local pa=a.id==self.targetId and a.id~=nil and 0 or a.id and 1 or 2
        local pb=b.id==self.targetId and b.id~=nil and 0 or b.id and 1 or 2
        if pa~=pb then return pa<pb end return tostring(a.id or a.text)<tostring(b.id or b.text)
      end)
      for _,label in ipairs(labels) do
        local x=math.max(1,math.min(label.x,graphW-4))
        local width=math.min(#label.text,22,graphW-x+1)
        for _,offset in ipairs({0,1,-1,2,-2,3,-3,4,-4}) do
          local y=label.y+offset local clear=y>=1 and y<=graphH
          for _,box in ipairs(occupied[y] or {}) do if x<box.x+box.w and x+width>box.x then clear=false break end end
          for _,marker in ipairs(self.graphHits or {}) do
            if math.abs(y-marker.y)<=1 and x<marker.x+2 and x+width>marker.x-1 then clear=false break end
          end
          if clear and width>0 then
            occupied[y]=occupied[y] or {} occupied[y][#occupied[y]+1]={x=x,w=width}
            self.labelLayout[#self.labelLayout+1]={id=label.id,x=x,y=4+y,w=width,h=1,text=renderer.crop(label.text,width),color=label.color}
            break
          end
        end
      end
      end
      for _,label in ipairs(self.labelLayout) do
        renderer.writeAt(label.x,label.y,label.text,label.color,colors.black)
        if label.id then self.rowHits[#self.rowHits+1]=label end
      end
      local target=find(snap.targets,self.targetId)
      if panel>0 then
        local x=graphW+2
        local radar=find(snap.radars,self.radarId)
        local relative=target and radar and geometry.relative(target.position,radar.position)
        local rows=target and {target.label,"Name source: "..target.labelSource,"Distance "..fmt(relative and relative.distance).."m","Bearing "..fmt(relative and relative.bearing).."deg","Altitude "..fmt(target.position.y).."m","Age "..fmt(os.clock()-target.timestamp).."s",target.stale and "STALE - control blocked" or "", "Cone: "..tostring(radar and radar.fovSource or "unknown")} or {"No selection","Radars: "..#(snap.radars or {}),"Contacts: "..#filter.targets(snap.targets,self.filters),"Refresh: 5 Hz","Zone: "..(snap.zone and snap.zone.alerts and "ON" or "OFF"),"Cone: "..tostring(radar and radar.fovSource or "unknown"),"Position: "..tostring(radar and radar.positionSource or "unavailable")}
        if target then rows[#rows+1]="Type: "..filter.category(target) rows[#rows+1]=target.remote and "Remote: display only" or "Local measurement" end
        for i=1,math.min(#rows,h-6) do renderer.writeAt(x,4+i,renderer.crop(rows[i],panel-2)) end
      end
    elseif self.page=="network" then
      local network=radarNet.snapshot()
      renderer.writeAt(1,3,renderer.crop(network.error or ((network.modem or "No modem").." | "..radarNet.configuration().group.." | ID "..os.getComputerID()),w),colors.cyan)
      renderer.writeAt(1,4,renderer.crop("Stations (tap to include/exclude)",w))
      self.scroll=math.max(1,math.min(self.scroll,math.max(1,#network.nodes-(h-7)+1)))
      for i=self.scroll,math.min(#network.nodes,self.scroll+h-8) do
        local row=network.nodes[i] local y=5+i-self.scroll
        renderer.writeAt(1,y,renderer.crop((row.included and "[x] " or "[ ] ")..row.label.." #"..row.id.." | "..(row.online and (row.radars.." radars / "..row.targets.." contacts") or "OFFLINE"),w),row.online and colors.white or colors.gray)
        self.rowHits[#self.rowHits+1]={id=row.id,x=1,y=y,w=w,h=1}
      end
      if #network.nodes==0 then renderer.writeAt(1,5,renderer.crop("No station discovered",w),colors.orange) end
      renderer.writeAt(1,h-1,renderer.crop("Rednet: unencrypted; no remote weapon commands",w),colors.orange)
    elseif self.page=="targets" or self.page=="cannons" or self.page=="probe" then
      local rows=self.page=="targets" and filter.targets(snap.targets,self.filters) or self.page=="cannons" and snap.cannons or snap.devices
      local listHeight=self.page=="probe" and math.max(1,math.floor((h-5)/3)) or h-(self.page=="targets" and 6 or 5)
      self.scroll=math.max(1,math.min(self.scroll,math.max(1,#rows-listHeight+1)))
      for i=self.scroll,math.min(#rows,self.scroll+listHeight-1) do
        local row=rows[i] local y=(self.page=="targets" and 5 or 4)+i-self.scroll
        local badge=row.synthetic and " SYNTHETIC" or row.friendly and " FRIENDLY" or ""
        local label=self.page=="targets" and (row.label..badge.." | y="..fmt(row.position.y)..(row.stale and " STALE" or "")) or self.page=="cannons" and (row.name.." | yaw="..fmt(row.yaw).." pitch="..fmt(row.pitch).." assembled="..tostring(row.assembled)) or (row.name.." "..row.role)
        local selected=self.page=="targets" and self.targetId or self.page=="cannons" and self.cannonId or self.deviceId
        renderer.writeAt(1,y,renderer.crop(label,w),row.id==selected and colors.yellow or colors.white,row.id==selected and colors.gray or nil)
        self.rowHits[#self.rowHits+1]={id=row.id,x=1,y=y,w=w,h=1}
      end
      if #rows==0 then renderer.writeAt(1,self.page=="targets" and 5 or 4,renderer.crop("No visible contacts/peripherals",w),colors.orange) end
      if self.page=="probe" then
        local selected=find(rows,self.deviceId)
        local y=5+listHeight
        renderer.writeAt(1,y,renderer.crop("Methods: "..table.concat(selected and selected.methods or {},", "),w),colors.cyan)
        local probe=snap.probe
        if probe and probe.name==self.deviceId then
          local values={}
          for key,value in pairs(probe.values or {}) do values[#values+1]=key.." = "..textutils.serialize(value):gsub("\n"," ") end
          for key,value in pairs(probe.errors or {}) do values[#values+1]=key.." ERROR "..value end
          table.sort(values)
          for i=1,math.min(#values,h-y-1) do renderer.writeAt(1,y+i,renderer.crop(values[i],w)) end
        end
      end
    elseif self.page=="fire" then
      local target=find(snap.targets,self.targetId)
      local rows={"Cannon: "..tostring(self.cannonId or "select in Cannons"),"Target: "..tostring(target and target.label or "select in Targets"),"Track: "..(self.tracking and "2 Hz" or "OFF"),"Fire: independent, single-use confirmation"}
      if self.solution then rows[#rows+1]="Yaw "..fmt(self.solution.yaw).." Pitch "..fmt(self.solution.pitch) rows[#rows+1]="ESTIMATE: vacuum trajectory, no drag" end
      for i=1,math.min(#rows,h-5) do renderer.writeAt(1,3+i,renderer.crop(rows[i],w)) end
    else
      renderer.writeAt(1,3,renderer.crop(self.configKind..": "..tostring(self.configKind=="radar" and self.radarId or self.configKind=="alias" and self.targetId or self.cannonId or "none"),w),colors.cyan)
      self.form:draw(w,h,fields())
    end
    renderer.writeAt(1,h,renderer.crop(self.message,w),colors.white,colors.gray)
    if self.confirm then
      renderer.fill(1,3,w,h-3,colors.gray)
      renderer.writeAt(1,4,renderer.crop(self.confirm.title,w),colors.white,colors.gray)
      self.confirmBar=ui.toolbar(1,6,w,{{id="confirm",label="Confirm"},{id="cancel",label="Cancel"}})
    end
  end
  function app:handle(event)
    if self.setup then
      self.setup:handle(event)
      if self.setup.closed then
        if self.setup.saved then self.radarId=self.setup.id cfg=combat.configuration() self.page="radar" end
        self.setup=nil
      end
      return true
    end
    if self.confirm then
      if event.name=="mouse_click" then
        local id=ui.toolbarHit(self.confirmBar,event.args[2],event.args[3])
        if id=="confirm" then local callback=self.confirm.callback self.confirm=nil callback()
        elseif id=="cancel" then self.confirm=nil end
      end return true
    end
    if self.form.edit then return self.form:handle(event) end
    if event.name=="mouse_scroll" and self.page~="config" then self.scroll=self.scroll+event.args[1] return true end
    if event.name~="mouse_click" then return self.page=="config" and self.form:handle(event) or false end
    local _,x,y=table.unpack(event.args)
    for _,box in ipairs(self.filterBar or {}) do if ui.hit(box,x,y) then
      if box.delta then self.filterState.first=math.max(1,(self.filterState.first or 1)+box.delta)
      else
        filter.toggle(self.filters,box.id) self.canvas=nil self.scroll=1
        local target=find(self.snapshot.targets,self.targetId)
        if target and not filter.visible(target,self.filters) then selectTarget(self.targetId) end
      end return true
    end end
    for _,box in ipairs(self.tabs or {}) do if ui.hit(box,x,y) then
      if box.delta then self.tabState.first=math.max(1,(self.tabState.first or 1)+box.delta)
      else self.page=box.id self.barState.first=1 self.scroll=1 self.tracking=false self.canvas=nil end return true
    end end
    for _,box in ipairs(self.bar or {}) do if box.delta and ui.hit(box,x,y) then self.barState.first=math.max(1,(self.barState.first or 1)+box.delta) return true end end
    local id=ui.toolbarHit(self.bar,x,y)
    if id=="networkToggle" or id=="publishToggle" then
      local value=radarNet.configuration() local key=id=="networkToggle" and "enabled" or "publish"
      value[key]=not value[key] if key=="publish" and value.publish then value.enabled=true end
      report(radarNet.configure(actor,value)) return true
    elseif id=="networkRescan" then radarNet.rescan() return true
    elseif id=="networkConfig" then self.networkConfig=radarNet.configuration() self.configKind="network" self.page="config" self.form.scroll=1 self.barState.first=1 return true
    elseif id=="networkSave" then
      local ok,message=radarNet.configure(actor,self.networkConfig) report(ok,message)
      if ok then self.page="network" self.configKind="radar" self.barState.first=1 end return true
    elseif id=="networkCancel" then self.page="network" self.configKind="radar" self.barState.first=1 return true
    elseif id=="overview" then self.view.network=not self.view.network self.canvas=nil self.view.zoom=1 return true end
    if id=="rescan" then combat.rescan() return true
    elseif id=="radarConfig" then
      local radar=find(self.snapshot.radars,self.radarId)
      if radar and radar.remote then self.message="Configure this radar on its source station" return true end
      self.tracking=false
      self.setup=radarSetup.new(self.snapshot,self.radarId,combat.configuration(),require("system.services.sabled").status().inSublevel,
        function(radarId,value) return combat.configure(actor,"radars",radarId,value) end,combat.validateRadar)
      return true
    elseif id=="radarProbe" then
      local radar=find(self.snapshot.radars,self.radarId)
      if radar and radar.remote then self.message="Probe runs on the source station" return true end
      self.deviceId=self.radarId self.page="probe" self.scroll=1 self.barState.first=1
      if self.deviceId then report(combat.requestProbe(actor,self.deviceId)) end return true
    elseif id=="zoomIn" or id=="zoomOut" then self.view.zoom=math.max(0.25,math.min(16,self.view.zoom*(id=="zoomIn" and 1.5 or 1/1.5))) self.canvas=nil return true
    elseif id=="left" or id=="right" then self.view.yaw=(self.view.yaw+(id=="right" and 15 or -15))%360 self.canvas=nil return true
    elseif id=="up" or id=="down" then self.view.pitch=math.max(-80,math.min(80,self.view.pitch+(id=="up" and 10 or -10))) self.canvas=nil return true
    elseif id=="radarNext" then
      local index=1 for i,row in ipairs(self.snapshot.radars) do if row.id==self.radarId then index=i break end end
      if #self.snapshot.radars>0 then self.radarId=self.snapshot.radars[index%#self.snapshot.radars+1].id self.canvas=nil end return true
    elseif id=="previous" or id=="next" then self.scroll=math.max(1,self.scroll+(id=="next" and 1 or -1)) return true
    elseif id=="solve" then solve() return true
    elseif id=="aim" then report(combat.requestAim(actor,self.cannonId,self.targetId)) return true
    elseif id=="track" then
      if self.tracking then self.tracking=false else solve() self.tracking=self.solution~=nil end return true
    elseif id=="fire" then
      self.tracking=false
      local cannonId,targetId=self.cannonId,self.targetId
      local token,err=combat.prepareFire(actor,cannonId,targetId)
      if not token then self.message=err return true end
      confirm("Fire "..cannonId.." -> "..targetId:sub(1,12).."? (5s)",function() report(combat.requestFire(actor,cannonId,targetId,token)) end) return true
    elseif id=="ack" then local cannonId=self.cannonId confirm("Physically verify stopped mount/output",function() report(combat.acknowledge(actor,cannonId,true)) end) return true
    elseif id=="probe" then report(combat.requestProbe(actor,self.deviceId)) return true
    elseif id=="alias" then
      if self.targetId then self.configKind="alias" self.alias={value=cfg.aliases[self.targetId] or ""} self.page="config" self.form.scroll=1 end return true
    elseif id=="configKind" then self.configKind=self.configKind=="radar" and "cannon" or "radar" self.form.scroll=1 return true
    elseif id=="save" then
      local object=configObject()
      if not object then self.message="Select a device first" return true end
      local section=self.configKind=="radar" and "radars" or self.configKind=="alias" and "aliases" or "profiles"
      local targetId=self.configKind=="radar" and self.radarId or self.configKind=="alias" and self.targetId or self.cannonId
      local value=addon.copy(self.configKind=="alias" and object.value or object)
      confirm("Save verified "..self.configKind.." calibration?",function() report(combat.configure(actor,section,targetId,value)) end) return true
    end
    for _,box in ipairs(self.rowHits or {}) do if ui.hit(box,x,y) then
      if self.page=="network" then
        local value=radarNet.configuration() local key=tostring(box.id)
        if value.trusted[key] then value.trusted[key]=nil report(radarNet.configure(actor,value))
        else confirm("Include station #"..key.."? Same world/dimension required",function() value.trusted[key]=true report(radarNet.configure(actor,value)) end) end
      elseif self.page=="targets" or self.page=="radar" or self.page=="three" then selectTarget(box.id)
      elseif self.page=="cannons" then self.cannonId=box.id self.tracking=false else self.deviceId=box.id end return true
    end end
    if self.page=="radar" or self.page=="three" then
      for _,box in ipairs(self.graphHits or {}) do if ui.hit({x=math.max(1,box.x-1),y=box.y+3,w=box.w,h=box.h},x,y) then selectTarget(box.id) return true end end
    end
    return self.page=="config" and self.form:handle(event) or false
  end
  refresh()
  local w,h=term.getSize()
  win=ctx.windowManager:create({title="Combat",w=math.min(120,w-2),h=math.min(38,h-2),x=2,y=2,app=app})
  ctx.onCleanup(function() if timer then os.cancelTimer(timer) end if trackTimer then os.cancelTimer(trackTimer) end combat.release(ctx.pid) end)
  timer=os.startTimer(0.2) trackTimer=os.startTimer(0.5)
  while not win.closed do
    local event=ctx.pullEvent()
    if event.name=="timer" and event.args[1]==timer then
      if not win.minimized then refresh() end timer=os.startTimer(0.2)
    elseif event.name=="timer" and event.args[1]==trackTimer then
      if app.tracking and not win.minimized and not app.confirm then
        local ok,err=combat.requestAim(actor,app.cannonId,app.targetId)
        if not ok then app.tracking=false app.message=tostring(err) end
      end trackTimer=os.startTimer(0.5)
    elseif event.name=="mintcraft_combat_result" and event.args[1]==ctx.pid then
      report(event.args[3],event.args[4])
      if not event.args[3] then app.tracking=false end
    end
  end
end
return M
