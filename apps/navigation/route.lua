local Route=require("system.navigation.autopilot")
local addon=require("system.libraries.addon")
local forms=require("system.gui.form")
local renderer=require("system.gui.renderer")
local client=require("system.graphics.client")
local widgets=require("system.graphics.widgets")
local View=require("system.graphics.view")
local M={}
local function number(v) return addon.finite(v) and string.format("%.1f",v) or "?" end
local function coordinate(p) return "X "..number(p.x).." / Y "..number(p.y).." / Z "..number(p.z) end
function M.new(api)
  local self={plan=Route.defaults(),selected=1,view="route",message="Calibrate full flight control before autonomous flight",form=forms.new(),scroll=1,state={},pose={}}
  local nativeState
  local function option(object,key,label,kind,options)
    local f=forms.field(object,key,label,kind,options) f.id=key
    local set=f.set
    f.set=function(value)
      if key=="translationVerified" and value==true then
        local pose=api.pose() local now=os.clock()
        if type(pose.vehicleId)~="string" or not addon.finite(pose.identityAt) or now<pose.identityAt or now-pose.identityAt>0.5 then
          self.message="Fresh sublevel identity required for physical verification" return
        end
        self.plan.verifiedVehicleId=pose.vehicleId
      end
      set(value)
      if key=="driveMode" or key=="pitchSign" or key=="rollSign" then self.plan.translationVerified=false self.plan.verifiedVehicleId=nil end
    end
    return f
  end
  function self:fields()
    if self.view=="point" then
      local point=self.plan.points[self.selected]
      if not point then return {} end
      return {option(point,"x","World X","number"),option(point,"y","World Y (vehicle origin)","number"),option(point,"z","World Z","number")}
    end
    return {
      option(self.plan,"driveMode","Translation method",nil,{"thrusters","tilt","differential"}),
      option(self.plan,"maxSpeed","Maximum requested speed (blocks/s)","number"),
      option(self.plan,"maxTilt","Maximum tilt (degrees)","number"),
      option(self.plan,"positionGain","Position to speed gain","number"),
      option(self.plan,"velocityGain","Velocity error gain","number"),
      option(self.plan,"pitchSign","Tilt: forward pitch sign",nil,{1,-1}),
      option(self.plan,"rollSign","Tilt: right roll sign",nil,{1,-1}),
      option(self.plan,"radius","Waypoint horizontal radius (blocks)","number"),
      option(self.plan,"altitudeTolerance","Altitude tolerance (blocks)","number"),
      option(self.plan,"settleSeconds","Stable arrival dwell (seconds)","number"),
      option(self.plan,"maxDistance","Launch geofence radius (blocks)","number"),
      option(self.plan,"timeout","Route time limit (seconds)","number"),
      option(self.plan,"translationVerified","Hover, translation and braking tested","boolean"),
      option(self.plan,"clearRouteConfirmed","Route clear: no obstacle avoidance","boolean"),
    }
  end
  function self:refresh(state,pose,bridge,endpoints)
    self.state,self.pose,self.bridge,self.endpoints=state or {},pose or {},bridge or {},endpoints or {}
    if self.state.differentialReady and self.pose.vehicleId then
      self.plan.translationVerified=true self.plan.verifiedVehicleId=self.pose.vehicleId self.plan.driveMode="differential"
    elseif self.plan.driveMode=="differential" then self.plan.translationVerified=false self.plan.verifiedVehicleId=nil end
  end
  function self:rows()
    if self.pending then
      local rows={{title=self.pending.kind=="arm" and "Arm stabilization?" or "Start world route?"},
        {title="CONFIRM asserts the route is clear; obstacles are not detected"},{title="Landing: manual"},{title="Manual input stops"},{title="Close app = rescue"}}
      for i,p in ipairs(self.pending.plan and self.pending.plan.points or {}) do
        for _,axis in ipairs({"x","y","z"}) do rows[#rows+1]={title="Point "..i.." / "..axis:upper(),description=number(p[axis])} end
      end
      return rows
    end
    local rows={}
    if self.view=="sublevel" then
      rows[#rows+1]={title="Sublevel "..tostring(self.pose.vehicleId or "unavailable")}
      rows[#rows+1]={title="Wired network + loaded parent plot",description="Wired endpoints may be outside this vehicle. No child-sublevel scan or arbitrary physics writes"}
      local bridge=self.bridge or {}
      rows[#rows+1]={title=bridge.status or "Vehicle Bridge unavailable",description=bridge.error or "Geometry discovery is read-only; control wiring remains explicit"}
      for _,row in ipairs(self.endpoints or {}) do rows[#rows+1]={id="devices",title=tostring(row.backend).." | "..tostring(row.name),description="Available for explicit Actuators mapping"} end
      for _,row in ipairs(bridge.actuators or {}) do rows[#rows+1]={title=tostring(row.block),description=coordinate(row.position).." | wiring unknown"} end
      for _,row in ipairs(bridge.links or {}) do rows[#rows+1]={title=(row.receiver and "RX " or "TX ")..row.first.item.." + "..row.second.item,description="Signal "..tostring(row.signal or "?").." | "..coordinate(row.position)} end
      for _,row in ipairs(bridge.burners or {}) do rows[#rows+1]={title="Burner "..row.id,description=coordinate(row.position).." | signal "..tostring(row.signal)} end
      for _,row in ipairs(bridge.mechanics or {}) do rows[#rows+1]={title=row.block.." | "..number(row.rpm).." RPM",description=coordinate(row.position).." | theoretical "..number(row.theoreticalRPM).." RPM | overstressed "..tostring(row.overstressed).." | source "..tostring(row.sourceId or "none")} end
      return rows
    end
    if self.view=="options" or self.view=="point" then
      for _,field in ipairs(self:fields()) do rows[#rows+1]={id="field:"..field.id,title=field.label,description=tostring(field.get())} end
      return rows
    end
    if self.state.automatic then local a=self.state.automatic rows[#rows+1]={title="Automatic pilot: "..a.state.." / "..a.phase,description=a.reason} end
    local a=self.state.autopilot or {state="idle",reason="No autonomous mission"}
    rows[#rows+1]={title="Flight: "..tostring(self.state.state or "unavailable").." | Pilot: "..a.state,description=a.reason}
    local p=addon.vec(self.pose.logicalPose and (self.pose.logicalPose.position or self.pose.logicalPose.pos))
    local fresh=addon.finite(self.pose.timestamp) and os.clock()>=self.pose.timestamp and os.clock()-self.pose.timestamp<=0.5
    rows[#rows+1]={title=p and ((fresh and "" or "STALE | ")..coordinate(p)) or "World position unavailable",description="World coordinates of the vehicle origin, not GPS or map guesses"}
    rows[#rows+1]={title="Waypoint "..tostring(a.index or 0).." / "..tostring(a.count or 0),description="Distance "..number(a.distance).." blocks | speed "..number(a.speed).." blocks/s"}
    for i,point in ipairs(self.plan.points) do rows[#rows+1]={id=i,title=tostring(i).." | "..coordinate(point),selected=self.selected==i} end
    return rows
  end
  function self:actions()
    if self.pending then return {{id=self.warningRead and "route:confirm" or "route:review",label=self.warningRead and "Confirm" or "Read next"},{id="route:cancel",label="Cancel"}} end
    local actions={{id="route:flight",label="Flight"},{id="route:route",label="Route"},{id="route:sublevel",label="Sublevel"},
      {id="route:options",label="Options"},{id="route:add",label="Add here"},{id="route:edit",label="Edit point"},{id="route:remove",label="Remove point"},
      {id="route:automatic",label="Activate autopilot"},{id="route:arm",label="Arm"},{id="route:start",label="Start route"},{id="route:stop",label="Take over"},{id="route:disarm",label="Rescue/disarm"},
      {id="route:devices",label="Devices"},{id="route:mapping",label="Actuators"}}
    if self.view=="point" or self.view=="options" then table.insert(actions,1,{id="route:done",label="Apply field"}) end
    return actions
  end
  local function report(ok,err) self.message=ok and "Done" or tostring(err or "Refused") end
  function self:apply()
    if not self.editing then return true end
    local f=self.editing local value=self.editText
    if f.kind=="number" then value=tonumber(value) if not addon.finite(value) then self.message="Invalid number" return false end end
    f.set(value) self.editing=nil return true
  end
  function self:action(id)
    id=id:gsub("^route:","")
    if id=="automatic" then if api.activate then api.activate() end return end
    if id=="stop" then self.pending=nil report(api.stop()) return end
    if id=="disarm" then self.pending=nil report(api.disarm()) return end
    if self.pending then
      if id=="cancel" then self.pending=nil
      elseif id=="review" then
        if not self.warningRead then
          if nativeState then nativeState.first=math.max(1,(nativeState.lastVisible or 0)+1) end
          self.scroll=self.scroll+math.max(1,self.visible or 1)
        end
      elseif id=="confirm" then
        if not self.warningRead then return end
        local pending=self.pending self.pending=nil
        if pending.kind=="arm" then report(api.arm()) else report(api.start(pending.plan)) end
      end
      return
    end
    if id=="done" then self:apply() return end
    if not self:apply() then return end
    self.form.edit=nil self.form.scroll=1 self.scroll=1
    if id=="flight" or id=="mapping" then api.page(id)
    elseif id=="route" or id=="options" or id=="sublevel" then self.view=id
    elseif id=="devices" then api.devices()
    elseif id=="edit" then if self.plan.points[self.selected] then self.view="point" end
    elseif id=="remove" then table.remove(self.plan.points,self.selected) self.selected=math.max(1,math.min(self.selected,#self.plan.points))
    elseif id=="add" then
      if #self.plan.points>=32 then self.message="Route limit: 32 waypoints" return end
      local pose=api.pose() local now=os.clock()
      local p=addon.vec(pose and pose.logicalPose and (pose.logicalPose.position or pose.logicalPose.pos))
      if not p or pose.inSublevel~=true or pose.frame~="world" or not addon.finite(pose.timestamp) or now<pose.timestamp or now-pose.timestamp>0.5 then self.message="Fresh Sable world position required" return end
      self.plan.points[#self.plan.points+1]=p self.selected=#self.plan.points self.view="point"
    elseif id=="arm" then self.pending={kind="arm"} self.warningRead=false
    elseif id=="start" then
      local candidate=addon.copy(self.plan)
      -- The final read-through + Confirm is the explicit route-clearance claim.
      candidate.clearRouteConfirmed=true
      local valid,err=Route.validate(candidate) if not valid then self.message=err return end
      self.pending={kind="start",plan=candidate} self.warningRead=false
    end
  end
  function self:select(id)
    local key=tostring(id):match("^field:(.+)$")
    if key then
      for _,f in ipairs(self:fields()) do if f.id==key then
        if f.kind=="boolean" then f.set(not f.get())
        elseif f.options then local index=0 for i,v in ipairs(f.options) do if v==f.get() then index=i end end f.set(f.options[index%#f.options+1])
        else self.editing=f self.editText=tostring(f.get() or "") end
        break
      end end
    elseif id=="devices" then api.devices()
    elseif type(id)=="number" then self.selected=id end
  end
  nativeState=client.attach(self,{
    model=function()
      return {page=self.pending or self.view,actions=self:actions(),rows=self:rows(),
        fields=self.editing and {{id="value",label=self.editing.label,value=self.editText}} or {},footer=self.message}
    end,
    input=function(_,value) self.editText=value end,submit=function() self:apply() end,
    action=function(id) self:action(id) end,select=function(id) self:select(id) end,
  })
  local drawPixels,handlePixels=self.drawPixels,self.handlePixels
  function self:drawPixels(s,w,h,p)
    if self.form.edit then self.editing=self.form.edit self.editText=self.form.text self.form.edit=nil end
    self.headerHits={{id="stop",rect={x=3,y=2,w=w<260 and 62 or 110,h=22}},
      {id="disarm",rect={x=w<260 and 69 or 117,y=2,w=68,h=22}}}
    s:rect(0,0,w,26,p.panel)
    widgets.button(s,self.headerHits[1].rect,w<260 and "F10 STOP" or "Take over F10",p)
    widgets.button(s,self.headerHits[2].rect,"Rescue",p)
    drawPixels(self,View.new(s,0,26,w,math.max(1,h-26)),w,math.max(1,h-26),p)
    if self.pending and nativeState.page==self.pending and (nativeState.lastVisible or 0)>=#self:rows() then self.warningRead=true end
  end
  function self:handlePixels(event)
    if event.name:match("^mouse_") then
      local _,x,y=table.unpack(event.args)
      if type(y)=="number" and y<26 then
        if event.name=="mouse_click" then for _,hit in ipairs(self.headerHits or {}) do if widgets.hit(hit.rect,x,y) then self:action(hit.id) break end end end
        return true
      end
      local adjusted={name=event.name,args=table.pack(table.unpack(event.args))}
      if type(y)=="number" then adjusted.args[3]=y-26 end
      return handlePixels(self,adjusted)
    end
    return handlePixels(self,event)
  end
  function self:drawText(w,h)
    if self.editing then self.form.edit=self.editing self.form.text=self.editText self.editing=nil end
    if not self.pending and (self.view=="options" or self.view=="point") then self.form:draw(w,h,self:fields()) return end
    local rows=self:rows() self.hits={} self.visible=math.max(1,h-5)
    self.scroll=math.max(1,math.min(self.scroll,math.max(1,#rows-self.visible+1)))
    for i=self.scroll,math.min(#rows,self.scroll+self.visible-1) do
      local row=rows[i] local y=4+i-self.scroll
      renderer.writeAt(1,y,renderer.crop(row.title..(row.description and (" | "..row.description) or ""),w)) self.hits[y]=row.id
    end
    if self.pending and self.scroll+self.visible-1>=#rows then self.warningRead=true end
    renderer.writeAt(1,h,renderer.crop(self.message,w))
  end
  function self:handleText(event)
    if not self.pending and (self.view=="options" or self.view=="point") then return self.form:handle(event) end
    if event.name=="mouse_scroll" then self.scroll=math.max(1,self.scroll+event.args[1]) return true end
    if event.name=="mouse_click" and not self.pending then local id=(self.hits or {})[event.args[3]] if id then self:select(id) return true end end
    return false
  end
  return self
end
return M
