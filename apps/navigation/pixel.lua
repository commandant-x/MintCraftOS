local ui=require("system.graphics.widgets")
local fonts=require("system.graphics.fonts")
local Surface=require("system.graphics.surface")
local View=require("system.graphics.view")
local primitives=require("system.graphics.primitives")
local attitude=require("system.navigation.attitude")
local addon=require("system.libraries.addon")
local M={}
local function rect(x,y,w,h) return {x=x,y=y,w=w,h=h} end
local function number(value,unit)
  return addon.finite(value) and string.format("%.1f%s",value,unit or "") or "unavailable"
end
function M.sample(av,sub,state,t,previous,now)
  local sample,fresh=attitude.sample(av.measurements or {},previous,now)
  if sample and (not addon.finite(sample.observedAt) or sample.observedAt>now) then sample,fresh=nil,false end
  local out={attitude=sample,fresh=fresh,state=state.state or "unknown",source=t.headingSource,
    sublevel=sub.status or "unavailable",observedAt=now,values={},expires={}}
  if sample then
    local a,b=(av.measurements or {}).pitch,(av.measurements or {}).roll
    out.attitudeValidUntil=math.min(a and a.validUntil or sample.observedAt+0.5,b and b.validUntil or sample.observedAt+0.5)
  end
  for _,key in ipairs({"altitude","altitudeRate","heading"}) do
    local m=t.measurements and t.measurements[key]
    local observed=m and (m.observedAt or m.timestamp) or t.timestamp
    local valid=m and m.valid==true and addon.finite(m.validUntil) and now<=m.validUntil
    if not m then valid=addon.finite(t.timestamp) and now-t.timestamp<=0.5 end
    valid=valid and addon.finite(observed) and observed<=now
    if valid and addon.finite(t[key]) then out.values[key]=t[key] out.expires[key]=m and m.validUntil or observed+0.5 end
  end
  local physical=sub.sublevel or {}
  local function current(key)
    local timing=physical.timings and physical.timings[key]
    local observed=timing and timing.startedAt or physical.observedAt or sub.timestamp
    return addon.finite(observed) and now>=observed and now-observed<=1 and not (timing and timing.ok==false),observed
  end
  local massFresh,massAt=current("mass")
  if massFresh then out.values.mass=addon.finite(physical.mass) and physical.mass or nil out.expires.mass=massAt+1 end
  local speedFresh,speedAt=current("linearVelocity")
  if speedFresh then
    local v=addon.vec(physical.linearVelocity)
    out.values.speed=v and math.sqrt(v.x*v.x+v.y*v.y+v.z*v.z) or nil
    out.expires.speed=speedAt+1
  end
  return out,sample
end
local function horizon(cache,w,h,pitch,roll)
  local key=w..":"..h..":"..(pitch and string.format("%.1f",pitch) or "?")..":"..(roll and string.format("%.1f",roll) or "?")
  if cache and cache.key==key then return cache end
  local image=cache and cache.image.width==w and cache.image.height==h and cache.image or Surface.new(w,h,15)
  if not (addon.finite(pitch) and addon.finite(roll)) then image:rect(0,0,w,h,15)
  else
    local a=math.rad(roll) local s,c=math.sin(a),math.cos(a)
    local cx,cy=(w-1)/2,(h-1)/2
    -- Preserve the existing instrument's pitch sign and 60-deg vertical scale.
    local shift=math.max(-90,math.min(90,pitch))*h/60
    for y=0,h-1 do
      local d=(y-cy)*c+shift
      if math.abs(s)<1e-9 then image:span(0,y,string.rep(string.char(d<0 and 3 or 12),w))
      else
        local cut=math.max(0,math.min(w,math.ceil(cx-d/s)))
        image:span(0,y,string.rep(string.char(s>0 and 3 or 12),cut)..string.rep(string.char(s>0 and 12 or 3),w-cut))
      end
    end
    for degree=-30,30,10 do
      local dy=degree*h/60-shift local half=degree==0 and w or degree%20==0 and w/7 or w/10
      primitives.line(image,cx-half*c+dy*s,cy+dy*c+half*s,cx+half*c+dy*s,cy+dy*c-half*s,0)
    end
    local span=math.max(8,math.min(26,w/7))
    primitives.line(image,cx-span,cy,cx-4,cy,4) primitives.line(image,cx+4,cy,cx+span,cy,4)
    primitives.line(image,cx,cy-4,cx,cy+4,4)
  end
  return {key=key,image=image,builds=(cache and cache.builds or 0)+1}
end
function M.attach(app,api,tabs)
  app.pixelPages={flight=true}
  function app:drawPixels(s,w,h,p)
    s:rect(0,0,w,h,p.panel) self.nativeHits={}
    local function button(id,label,r)
      ui.button(s,r,label,p) self.nativeHits[#self.nativeHits+1]={id=id,rect=r}
    end
    local controlWidth=w<260 and 56 or 78
    local controlX=w-controlWidth-30
    button("views","Flight",rect(4,3,math.min(96,controlX-8),22))
    if w>=400 then
      button("activateAutomatic","Autopilot",rect(106,3,100,22))
      button("control","Control",rect(controlX,3,controlWidth,22))
    else button("activateAutomatic","Pilot",rect(controlX,3,controlWidth,22)) end
    local rescan=rect(w-26,3,22,22) ui.symbol(s,rescan,"refresh",p)
    self.nativeHits[#self.nativeHits+1]={id="rescan",rect=rescan}
    local snap=self.nativeFlight or {values={},state="unknown"}
    local now=os.clock()
    local sample=snap.attitude and now<=snap.attitude.observedAt+1 and snap.attitude or nil
    local fresh=sample and snap.fresh and now<=(snap.attitudeValidUntil or 0)
    ui.label(s,6,33,fresh and "MEASURED | attitude" or sample and "STALE | held attitude" or "ATTITUDE UNAVAILABLE",w-12,fresh and p.accent or 1,p.panel)
    local side=w>=450
    local gw=side and math.floor(w*0.62) or w-12
    local gh=math.max(24,side and h-99 or math.floor((h-86)*0.52))
    local r=rect(6,52,gw,gh)
    local pitch=sample and sample.pitch local roll=sample and sample.roll
    self.nativeHorizon=horizon(self.nativeHorizon,r.w,r.h,pitch,roll)
    local image=self.nativeHorizon.image
    local canvas=View.new(s,r.x,r.y,r.w,r.h)
    for y=math.max(0,canvas.clip.y),math.min(r.h,canvas.clip.y+canvas.clip.h)-1 do canvas:span(0,y,image.rows[y+1]) end
    if not sample then ui.label(s,r.x+4,r.y+math.floor(r.h/2),"No valid gimbal",r.w-8,p.text,15,"center") end
    local v={}
    for key,value in pairs(snap.values) do if snap.expires and now<=(snap.expires[key] or 0) then v[key]=value end end
    local x,top,width=side and r.x+r.w+12 or 6,side and 54 or r.y+r.h+19,side and w-r.w-24 or w-12
    local rows={{"Altitude",number(v.altitude," m")},{"Vertical speed",number(v.altitudeRate," m/s")},
      {"Heading (+Z=0)",number(v.heading," deg")},{"Speed",number(v.speed," m/s")},
      {"Mass",number(v.mass," kg")},{"Control",snap.observedAt and now-snap.observedAt<=1 and snap.state or "stale"}}
    local step=side and math.max(24,math.floor((h-108)/6)) or 11
    self.nativeMetricRows={}
    for i,row in ipairs(rows) do
      local y=top+(i-1)*step
      if y+(side and 24 or 9)>h-27 then break end
      if not side then
        local short={"ALT","V/S","HDG","SPD","MASS","CTRL"}
        ui.label(s,x,y,short[i].." "..row[2],width,p.text,p.panel)
      else
        ui.label(s,x,y,row[1],width,p.muted,p.panel)
        local scale=width>=200 and step>=32 and 2 or 1
        fonts.drawText(s,x,y+10,width,18,row[2],p.text,p.panel,{wrap=false,scale=scale})
      end
      self.nativeMetricRows[#self.nativeMetricRows+1]={label=row[1],value=row[2]}
    end
    ui.label(s,r.x,r.y+r.h+5,"P "..number(pitch).." | R "..number(roll),r.w,p.text,p.panel)
    ui.label(s,6,h-20,tostring(snap.source or "Heading source unavailable").." | "..tostring(self.message or ""),w-12,p.muted,p.panel)
    if self.nativeViews then
      local capacity=math.max(1,math.floor((h-55)/22))
      self.nativeCapacity=capacity
      self.nativeFirst=math.max(1,math.min(self.nativeFirst or 1,math.max(1,#tabs-capacity+1)))
      self.nativeViewHits={}
      local width=math.min(w-8,196)
      s:rect(4,28,width,capacity*22+24,p.desktop)
      for i=self.nativeFirst,math.min(#tabs,self.nativeFirst+capacity-1) do
        local r=rect(6,30+(i-self.nativeFirst)*22,width-4,21)
        ui.button(s,r,tabs[i].label,p,i==(self.nativeSelected or 1))
        self.nativeViewHits[#self.nativeViewHits+1]={id=tabs[i].id,rect=r}
      end
      for _,item in ipairs({{"view_up","previous",6},{"view_down","next",width-20}}) do
        local r=rect(item[3],30+capacity*22,20,18) ui.symbol(s,r,item[2],p)
        self.nativeViewHits[#self.nativeViewHits+1]={id=item[1],rect=r}
      end
    end
  end
  function app:handlePixels(event)
    if self.nativeViews and event.name=="mouse_scroll" then self.nativeFirst=math.max(1,(self.nativeFirst or 1)+event.args[1]) return true end
    if event.name~="mouse_click" then return false end
    local _,x,y=table.unpack(event.args)
    if self.nativeViews then
      for _,hit in ipairs(self.nativeViewHits or {}) do if ui.hit(hit.rect,x,y) then
        if hit.id=="view_up" or hit.id=="view_down" then self.nativeFirst=math.max(1,(self.nativeFirst or 1)+(hit.id=="view_up" and -1 or 1))
        else self.nativeViews=false api.page(hit.id) end return true
      end end
      self.nativeViews=false return true
    end
    for _,hit in ipairs(self.nativeHits or {}) do if ui.hit(hit.rect,x,y) then
      if hit.id=="views" then self.nativeViews=true self.nativeFirst=1 self.nativeSelected=1
      elseif hit.id=="control" then api.page("control")
      else api.action(hit.id) end return true
    end end
    return true
  end
  function app:handleNativeKey(event)
    if not self.graphicsActive or not self.nativeViews or event.name~="key" then return false end
    local key=event.args[1]
    if key==keys.escape then self.nativeViews=false
    elseif key==keys.up or key==keys.down then
      local index=math.max(1,math.min(#tabs,(self.nativeSelected or 1)+(key==keys.up and -1 or 1)))
      self.nativeSelected=index
      if index<(self.nativeFirst or 1) then self.nativeFirst=index
      elseif index>=(self.nativeFirst or 1)+(self.nativeCapacity or 1) then self.nativeFirst=index-(self.nativeCapacity or 1)+1 end
    elseif key==keys.enter then self.nativeViews=false api.page(tabs[self.nativeSelected or 1].id) end
    return true
  end
end
return M
