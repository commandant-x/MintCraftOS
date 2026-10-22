-- Direct pilot dashboard. Draws cached measurements only; flightd owns all writes.
local ui=require('system.graphics.widgets')
local fonts=require('system.graphics.fonts')
local View=require('system.graphics.view')
local addon=require('system.libraries.addon')
local M={}
local function num(v) return addon.finite(v) and string.format('%.1f',v) or '?' end
function M.new(api)
 local self={mode='hold',draft={},dirty=false,hits={},scale=1}
 local state,t,pose={},{},{}
 local function changed() self.dirty=true end
 local function field(key,label)
  return {label=label,kind='number',get=function() return self.draft[key] end,set=function(value) self.draft[key]=value changed() end}
 end
 local function apply()
  local request={altitude=self.draft.altitude}
  if state.differentialReady then request.speed=self.draft.speed request.heading=self.draft.heading end
  local ok,why=api.apply(request)
  self.message=ok and 'Consignes appliquees' or tostring(why or 'Refuse')
  if ok then self.dirty=false self.mode='hold' end
 end
 self.editor=require('system.graphics.form_client').new({urgent={id='stop',label='STOP / F10'},
  model=function()
   local model={page=self.mode,actions={},fields={},rows={},footer=self.message}
   if self.mode=='confirm' then
    model.actions={{id='go',label='Confirmer trajet degage'},{id='cancel',label='Annuler'}}
    model.rows={{title='Destination monde',description='X '..num(self.pending.x)..' / Z '..num(self.pending.z)},
     {title='Altitude maintenue',description=num(self.pending.altitude)..' m'},
     {title='Trajet sans detection des obstacles',description='Confirmez un trajet degage. F10 = secours. Gardez Navigation ouvert.'}}
   else
    model.actions={{id='apply',label='Appliquer'},{id='cancel',label='Retour'}}
    model.fields={field('altitude','Altitude cible (m monde)')}
    if state.differentialReady then model.fields[2]=field('speed','Vitesse cible (m/s)') model.fields[3]=field('heading','Cap (degres, +Z=0)') end
   end
   return model
  end,error=function(why) self.message=why end,
  action=function(id)
   if id=='stop' then self:action('stop')
   elseif id=='cancel' then self.mode='hold' self.pending=nil
   elseif id=='apply' then apply()
   elseif id=='go' then
    local ok,why=api.go(self.pending)
    self.message=ok and 'Trajet actif' or tostring(why or 'Refuse')
    if ok then self.mode='map' self.pending=nil end
   end
  end})
 function self:refresh(s,telemetry,p)
  state,t,pose=s or {},telemetry or {},p or {}
  if self.mapVehicleId and self.mapVehicleId~=pose.vehicleId then
   self.origin=nil self.destination=nil self.pending=nil self.mapVehicleId=nil self.mode='hold' self.message='Vaisseau change : destination effacee'
  end
  if not self.dirty and self.mode~='edit' and self.mode~='confirm' then
   self.draft.altitude=(state.targets or {}).altitude or t.altitude
   self.draft.speed=(state.pilot or {}).speed or self.draft.speed or 0
   self.draft.heading=(state.pilot or {}).heading or t.heading or 0
  end
 end
 function self:action(id)
  if id=='stop' then api.stop() self.pending=nil self.mode='hold' self.message='Secours demande'
  elseif id=='back' then api.page('flight')
  elseif id=='prepare' then api.prepare()
  elseif id=='edit' then self.mode='edit'
  elseif id=='hold' then self.mode='hold'
  elseif id=='map' then
   self.scroll=0 self.mode='map' self.mapVehicleId=pose.vehicleId self.origin=addon.vec(pose.logicalPose and (pose.logicalPose.position or pose.logicalPose.pos)) self.destination=nil
  elseif id=='zoomIn' then self.scale=math.max(0.125,self.scale/2)
  elseif id=='zoomOut' then self.scale=math.min(16,self.scale*2)
  elseif id=='apply' then apply()
  elseif id=='here' then if addon.finite(t.altitude) then self.draft.altitude=t.altitude changed() end
  elseif id=='go' then
   if not state.differentialReady then self.message=state.differentialReason or 'Direction motorisee non calibree' return end
   if not self.destination then self.message='Cliquez une destination sur la carte' return end
   self.pending={vehicleId=self.mapVehicleId,x=self.destination.x,z=self.destination.z,altitude=self.draft.altitude,speed=self.draft.speed}
   self.mode='confirm'
  else
   local delta=tonumber(id:match('^height:(.+)$'))
   if delta and addon.finite(self.draft.altitude) then self.draft.altitude=self.draft.altitude+delta changed() end
  end
 end
 function self:drawPixels(s,w,h,p)
  if self.mode=='edit' or self.mode=='confirm' then self.editor:drawPixels(s,w,h,p) return end
  self.height=h
  local screen=s local offset=0 local body=false
  s:rect(0,0,w,h,p.panel) self.hits={}
  local function label(y,text,color) ui.label(s,6,y-offset,text,w-12,color or p.text,p.panel) end
  local function button(id,text,x,y,bw)
   local r={x=x,y=y-offset,w=bw,h=22}
   ui.button(s,r,text,p,id=='apply')
   local top=body and math.max(46,y-(self.scroll or 0)) or y
   local bottom=body and math.min(h-22,y+22-(self.scroll or 0)) or y+22
   if bottom>top then self.hits[#self.hits+1]={id=id,rect={x=x,y=top,w=bw,h=bottom-top}} end
  end
  local gap=4 local bw=math.floor((w-16)/3)
  button('back','Flight',4,3,bw) button('stop','STOP / F10',8+bw,3,bw) button('prepare','Calibrer',12+2*bw,3,bw)
  label(32,'AUTOPILOT | '..(state.measuredHold and 'Maintien actif' or 'Calibration requise'),p.accent)
  self.maxScroll=math.max(0,330-h) self.scroll=math.max(0,math.min(self.maxScroll,self.scroll or 0))
  local fullHeight=math.max(330,h)
  offset=46+self.scroll body=true s=View.new(screen,0,46,w,math.max(1,h-68))
  if self.mode=='map' then
   button('hold','Altitude',4,48,bw) button('zoomIn','Zoom +',8+bw,48,bw) button('zoomOut','Zoom -',12+2*bw,48,bw)
   local r={x=6,y=88-offset,w=w-12,h=fullHeight-179} self.map={x=r.x,y=88-self.scroll,w=r.w,h=r.h}
   s:rect(r.x,r.y,r.w,r.h,p.desktop)
   for x=r.x+32,r.x+r.w-1,32 do s:rect(x,r.y,1,r.h,p.panel) end
   for y=r.y+32,r.y+r.h-1,32 do s:rect(r.x,y,r.w,1,p.panel) end
   local origin=self.origin
   if origin then
    local function dot(point,color)
     local x=math.floor(r.x+r.w/2+(point.x-origin.x)/self.scale)
     local y=math.floor(r.y+r.h/2+(point.z-origin.z)/self.scale)
     if x>=r.x+2 and x<r.x+r.w-2 and y>=r.y+2 and y<r.y+r.h-2 then s:rect(x-2,y-2,5,5,color) end
    end
    dot(origin,p.muted)
    local current=addon.vec(pose.logicalPose and (pose.logicalPose.position or pose.logicalPose.pos))
    local fresh=addon.finite(pose.timestamp) and os.clock()>=pose.timestamp and os.clock()-pose.timestamp<=0.5
    if current and fresh then dot(current,p.accent) end
    if self.destination then dot(self.destination,p.text) end
   else ui.label(s,r.x+3,r.y+3,'Position monde indisponible',r.w-6,p.text,p.desktop) end
   label(76,'ATLAS X/Z | +Z bas | sans terrain')
   label(fullHeight-83,self.destination and ('X '..num(self.destination.x)..' Z '..num(self.destination.z)) or 'Cliquez la destination')
   label(fullHeight-70,'Altitude '..num(self.draft.altitude)..' m | '..num(self.scale)..' m/pixel')
   button('go','Suivre destination',4,fullHeight-53,w-8)
  else
   label(51,'Altitude mesuree / vitesse verticale')
   fonts.drawText(s,6,65-offset,w-12,28,num(t.altitude)..' m',p.text,p.panel,{scale=w>=260 and 3 or 2,wrap=false})
   label(94,'V/S '..num(t.altitudeRate)..' m/s | erreur '..num(addon.finite(t.altitude) and addon.finite(self.draft.altitude) and self.draft.altitude-t.altitude)..' m')
   label(110,'ALTITUDE CIBLE'..(self.dirty and ' | a appliquer' or ''))
   fonts.drawText(s,6,124-offset,w-12,28,num(self.draft.altitude)..' m',p.accent,p.panel,{scale=w>=260 and 3 or 2,wrap=false})
   local fourth=math.floor((w-20)/4)
   for i,delta in ipairs({-10,-1,1,10}) do button('height:'..delta,delta>0 and '+'..delta..'m' or delta..'m',4+(i-1)*(fourth+4),156,fourth) end
   button('edit','Saisir',4,182,bw) button('here','Ici',8+bw,182,bw) button('map','Atlas',12+2*bw,182,bw)
   button('apply','Maintenir cette altitude',4,208,w-8)
   local hold=state.measuredHold or {}
   label(239,'Consigne active '..num((state.targets or {}).altitude)..' m')
   label(254,'Chauffe '..num(hold.requestedHeat)..'/15 | signal '..tostring(hold.heat or '?'))
   local heat=hold.requestedHeat
   label(269,addon.finite(heat) and ('Alternance '..math.floor(heat)..' / '..math.ceil(heat)..' | haut '..math.floor((heat-math.floor(heat))*100+0.5)..'%') or 'Alternance : disponible apres calibration')
   if hold.range then label(284,'Plage '..num(hold.range.minAltitude)..' a '..num(hold.range.maxAltitude)..' m') end
   label(299,state.differentialReady and ('Cap '..num(t.heading)..' deg | vitesse '..num(state.groundSpeed)..' m/s') or 'Altitude seule | direction non calibree')
  end
  s=screen offset=0 body=false
  label(h-18,(state.state~='armed' and state.reason) or self.message or state.reason or '',p.muted)
 end
 function self:handlePixels(event)
  if self.mode=='edit' or self.mode=='confirm' then return self.editor:handlePixels(event) end
  if event.name=='mouse_scroll' then self.scroll=math.max(0,math.min(self.maxScroll or 0,(self.scroll or 0)+event.args[1]*18)) return true end
  if event.name~='mouse_click' then return false end
  local _,x,y=table.unpack(event.args)
  for _,hit in ipairs(self.hits) do if ui.hit(hit.rect,x,y) then self:action(hit.id) return true end end
  if self.mode=='map' and self.origin and y>=46 and y<(self.height or 330)-22 and ui.hit(self.map,x,y) then
   self.destination={x=self.origin.x+(x-self.map.x-self.map.w/2)*self.scale,z=self.origin.z+(y-self.map.y-self.map.h/2)*self.scale}
  end
  return true
 end
 function self:handlePixelKey(event)
  if self.mode=='edit' or self.mode=='confirm' then return self.editor:handlePixelKey(event) end
  return false
 end
 return self
end
return M
