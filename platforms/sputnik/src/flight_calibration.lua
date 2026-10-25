-- Motion-based functional commissioning, not a radio ACK or hardware identity.
local M={schema=1}
function M.hash(g)
 local n=0;local text=Vehicle.encode(g);for i=1,#text do n=(n*33+text:byte(i))%2147483647 end;return n
end
function M.archive(s,mass)
 local lines={'MCAL1,'..tostring(mass)}
 for _,g in ipairs(s.groups) do local r=s.results[g.id];if r then lines[#lines+1]=table.concat({g.id,M.hash(g),r.dx,r.dy,r.dz,r.pitch,r.roll,r.yaw},',') end end
 return table.concat(lines,'\n')
end
function M.new(groups,pose,caps,saved)
 local s={mass=pose.mass,phase='BASELINE',index=1,stable=0,window={},results={},groups=groups,home={x=pose.x,y=pose.y,z=pose.z},heading=pose.yaw,paused=false,last=nil,reason='Repos mesure requis',samples=0}
 local function point(x,y,z,h) return {x=s.home.x+(x or 0),y=s.home.y+(y or 0),z=s.home.z+(z or 0),heading=h} end
 s.priors={}
 if type(saved)=='string' and #saved<=12000 then
  local mass=tonumber(saved:match('^MCAL1,([^\n]+)'))
  if mass and mass>0 and math.abs(mass-pose.mass)/mass<=.02 then
   for line in saved:gmatch('[^\n]+') do local id,hash=line:match('^(%d+),(%d+),');id,hash=tonumber(id),tonumber(hash);if id then for _,g in ipairs(groups) do if g.id==id and M.hash(g)==hash then s.priors[id]=line end end end end
  end
 end
 function s:pause(why) self.paused=true;self.reason=why or 'Pause operateur' end
 function s:resume() self.paused=false;self.stable=0;self.window={} end
 function s:step(p,v,omega,active)
  if self.last and p.tick<=self.last then return nil end
  if self.last and p.tick-self.last>2 then self.stable=0;self.window={} end;self.last=p.tick
  if self.paused or self.phase=='COMPLETE' then return nil end
  if not active then self:pause('Maintien indisponible');return nil end
  if math.abs(p.pitch)>15 or math.abs(p.roll)>15 then self:pause('Assiette hors domaine; maintien');return nil end
  local target=self.home
  if self.phase=='UP' then target=point(0,.5)
  elseif self.phase=='DOWN' then target=point()
  elseif self.phase=='FORWARD' then local bearing=math.rad(self.heading-(caps.surface and 5 or 0));local extent=caps.surface and 3 or 1;target=point(extent*math.sin(bearing),0,extent*math.cos(bearing),caps.surface and self.heading-5 or nil)
  elseif self.phase=='RETURN' then target=point(0,0,0,caps.surface and self.heading or nil)
  elseif self.phase=='BACK' then target=point(-math.sin(math.rad(self.heading)),0,-math.cos(math.rad(self.heading)),caps.surface and self.heading or nil)
  elseif self.phase=='BACK_RETURN' then target=point(0,0,0,caps.surface and self.heading or nil)
  elseif self.phase=='YAW_LEFT' then target=point(0,0,0,self.heading-10)
  elseif self.phase=='YAW_RETURN' then target=point(0,0,0,self.heading) end
  local horizontal=math.sqrt(v.x^2+v.z^2)
  if caps.surface and horizontal>.2 and target.heading and math.abs(target.heading-self.heading)>=2 then local delta=(p.yaw-self.heading+180)%360-180;if delta*(target.heading-self.heading)>0 and math.abs(delta)>=2 and math.abs(delta-(target.heading-self.heading))<5 then self.surfaceYawObserved=true end end
  local stable=math.abs(v.y)<=.1 and horizontal<=.1 and math.abs(omega.x)<=math.rad(2) and math.abs(omega.y)<=math.rad(2) and math.abs(omega.z)<=math.rad(2) and math.abs(p.y-target.y)<=.2
  if caps.travel then stable=stable and Mission.distance(p,target)<=(caps.surface and .8 or .3) end
  if target.heading and not caps.surface then stable=stable and math.abs((p.yaw-target.heading+180)%360-180)<=1 end
  self.window[#self.window+1]={p.y,p.pitch,(p.yaw-self.heading+180)%360-180,p.roll};if #self.window>20 then table.remove(self.window,1) end
  local bounded=true
  for axis=1,4 do local lo,hi=math.huge,-math.huge;for _,sample in ipairs(self.window) do lo=math.min(lo,sample[axis]);hi=math.max(hi,sample[axis]) end;if hi-lo>(axis==1 and .2 or 1) then bounded=false end end
  if stable and bounded then self.stable=self.stable+1 else self.stable=0 end
  self.samples=self.samples+1
  self.reason=self.phase..': stabilite '..math.min(20,self.stable)..'/20, |Vy|='..string.format('%.3f',math.abs(v.y))..' Vh='..string.format('%.2f',horizontal)..' Wy='..string.format('%.1f',math.deg(omega.y))..'; aucun timeout valide'
  if self.phase=='PROBE' then
   local g=self.groups[self.index]
   self.probeSamples=(self.probeSamples or 0)+1
   self.probeResponse=self.probeResponse or {vx=v.x,vy=v.y,vz=v.z,p=p.pitch,r=p.roll,yaw=p.yaw}
   if self.probeSamples>=4 then
    local a=self.probeResponse
    self.results[g.id]={kind='motion-candidate',priorRechecked=self.priors[g.id]~=nil,samples=4,dx=v.x-a.vx,dy=v.y-a.vy,dz=v.z-a.vz,pitch=p.pitch-a.p,roll=p.roll-a.r,yaw=p.yaw-a.yaw,rxConfirmed=false}
    self.phase='RECOVER';self.stable=0;self.window={};self.probeSamples=0;self.probeResponse=nil
   else return target,{index=self.index,delta=.2} end
  elseif self.stable>=20 then
   self.stable=0;self.window={}
   if self.phase=='BASELINE' then self.phase='PROBE'
   elseif self.phase=='RECOVER' then self.index=self.index+1;self.phase=self.index<=#self.groups and 'PROBE' or 'UP'
   elseif self.phase=='UP' then self.phase='DOWN'
   elseif self.phase=='DOWN' then self.verticalVerified=true;self.phase=caps.travel and 'FORWARD' or 'COMPLETE'
   elseif self.phase=='FORWARD' then self.phase='RETURN'
   elseif self.phase=='RETURN' then if caps.surface and not self.surfaceYawObserved then self:pause('Gouverne non observee en mouvement');return target end;self.horizontalVerified=true;self.phase=caps.reverse and 'BACK' or caps.yaw and caps.yaw.available and 'YAW_LEFT' or 'COMPLETE'
   elseif self.phase=='BACK' then self.phase='BACK_RETURN'
   elseif self.phase=='BACK_RETURN' then self.reverseVerified=true;self.phase=caps.yaw and caps.yaw.available and 'YAW_LEFT' or 'COMPLETE'
   elseif self.phase=='YAW_LEFT' then self.phase='YAW_RETURN'
   elseif self.phase=='YAW_RETURN' then self.yawVerified=true;self.phase='COMPLETE' end
   if self.phase=='COMPLETE' then self.reason='Essais termines; aucun ACK materiel';self.complete=true end
  end
  return target
 end
 return s
end
return M
