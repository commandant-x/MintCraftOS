-- Two independent Link-driven clutch/16-state transmission/reverser groups.
-- RPM is not guessed: qualification uses actual motion and receiver feedback.
local addon=require('system.libraries.addon')
local link=require('system.navigation.link_output')
local geometry=require('system.navigation.geometry')
local M={}
local sides={'left','right'}
local roles={'clutch','gear','reverse'}
function M.validate(d,burners)
 if type(d)~='table' or d.enabled~=true then return true end
 if type(d.name)~='string' or d.name=='' or #d.name>128 or (d.clutchOff~=0 and d.clutchOff~=15) then return false,'Select detected transmitter and clutch-off signal' end
 local seen={} for _,c in ipairs(burners or {}) do local k=link.key(c) if k then seen[k]=true end end
 for _,side in ipairs(sides) do for _,role in ipairs(roles) do
  local k=type(d[side])=='table' and link.key({link=d[side][role]})
  if not k or seen[k] then return false,'Six distinct motor frequencies required, separate from burners: '..side..' '..role end
  seen[k]=true
 end end
 return true
end
function M.channels(d)
 if not d or not d.enabled then return {} end
 local valid=M.validate(d) if not valid then return {} end
 local out={}
 for _,side in ipairs(sides) do for _,role in ipairs(roles) do
  local off=role=='clutch' and d.clutchOff or 0
  out[#out+1]={id='drive-'..side..'-'..role,backend='frequency',name=d.name,link=d[side][role],min=0,max=15,neutral=off,rescue=off}
 end end
 return out
end
function M.commands(d,selection)
 local out={}
 for _,side in ipairs(sides) do
  local mode=selection and selection[side]
  out['drive-'..side..'-clutch']=mode and 15-d.clutchOff or d.clutchOff
  out['drive-'..side..'-gear']=mode and mode.gear or 0
  out['drive-'..side..'-reverse']=mode and mode.reverse or 0
 end
 return out
end
function M.observed(d,snapshot)
 local out={}
 if not snapshot.ok or not snapshot.inventoryComplete then return nil end
 for _,c in ipairs(M.channels(d)) do
  for _,r in ipairs(snapshot.links or {}) do
   if r.receiver and link.key(c)==link.key({link={first=r.first.item,second=r.second.item,firstColor=r.first.dyedColor,secondColor=r.second.dyedColor}}) then
    if not addon.finite(r.signal) or r.signal%1~=0 or r.signal<0 or r.signal>15 then return nil end
    out[c.id]=r.signal
   end
  end
  if out[c.id]==nil then return nil end
 end
 return out
end
function M.stop(d,current)
 local out=addon.copy(current or {})
 for _,side in ipairs(sides) do out['drive-'..side..'-clutch']=d.clutchOff end
 return out
end
function M.transition(d,current,wanted)
 local out=addon.copy(wanted)
 for _,side in ipairs(sides) do
  local base='drive-'..side..'-' local clutch,gear,reverse=base..'clutch',base..'gear',base..'reverse'
  if current[clutch]~=d.clutchOff and (wanted[gear]~=current[gear] or wanted[reverse]~=current[reverse]) then
   out[clutch]=d.clutchOff out[gear]=current[gear] out[reverse]=current[reverse]
  elseif current[clutch]==d.clutchOff and (wanted[gear]~=current[gear] or wanted[reverse]~=current[reverse]) then out[clutch]=d.clutchOff end
 end
 return out
end
function M.feedback(d,snapshot,values,after)
 if not snapshot.ok or not snapshot.inventoryComplete or not addon.finite(snapshot.observedAt) or snapshot.observedAt<=after then return false,'Fresh motor receiver feedback required' end
 for _,c in ipairs(M.channels(d)) do
  local key=link.key(c) local found=false
  for _,r in ipairs(snapshot.links or {}) do
   if r.receiver and key==link.key({link={first=r.first.item,second=r.second.item,firstColor=r.first.dyedColor,secondColor=r.second.dyedColor}}) then
    found=true if values[c.id]~=nil and r.signal~=values[c.id] then return false,'Motor receiver mismatch: '..c.id end
   end
  end
  if values[c.id]~=nil and not found then return false,'Motor receiver missing: '..c.id end
 end
 return true
end
function M.newProbe()
 local self={phase='baseline',index=1,steps={},rows={},reason='Waiting for stationary motors',settled=0}
 for gear=1,15 do for _,side in ipairs(sides) do for _,reverse in ipairs({0,15}) do
  self.steps[#self.steps+1]={side=side,gear=gear,reverse=reverse}
 end end end
 function self:step(s,ack)
  if self.phase=='complete' then return end
  if not s.velocity or not addon.finite(s.heading) or not addon.finite(s.yawRate) then return nil,'Fresh world velocity/heading/yaw rate required' end
  local speed=math.sqrt(s.velocity.x^2+s.velocity.z^2)
  if self.last and s.at<=self.last then return end
  if self.last and s.at-self.last<0.5 then return end
  if self.last and s.at-self.last>1.25 then self.settled=0 end self.last=s.at
  if not ack then self.settled=0 return end
  if self.phase=='baseline' or self.phase=='brake' then
   self.settled=speed<=0.1 and math.abs(s.yawRate)<=0.5 and self.settled+1 or 0
   if self.settled<8 then return end
   if self.phase=='brake' then
    local row=self.rows[#self.rows]
    row.brakingDistance=math.sqrt((s.position.x-self.brakeFrom.x)^2+(s.position.z-self.brakeFrom.z)^2)
    row.stoppedAt=s.at
    self.index=self.index+1
   end
   if self.index>#self.steps then self.phase='complete' self.reason='All 60 motor modes observed and neutral braking measured' return {kind='complete'} end
   self.phase='pulse' self.from=addon.copy(s) self.samples=0 self.settled=0 self.appliedAt=nil
   local mode=self.steps[self.index]
   self.reason='Probe '..mode.side..' transmission '..mode.gear..'/15 reverser '..mode.reverse
   return {kind='drive',selection={[mode.side]={gear=mode.gear,reverse=mode.reverse}}}
  end
  self.samples=self.samples+1
  local travel=math.sqrt((s.position.x-self.from.position.x)^2+(s.position.z-self.from.position.z)^2)
  local angle=math.abs(geometry.wrap(s.heading-self.from.heading))
  if speed<0.3 and travel<2 and angle<5 and self.samples<8 then return end
  local mode=self.steps[self.index] local dt=s.at-(self.appliedAt or self.from.at)
  if dt<=0 then return nil,'Motor response clock invalid' end
  local a=math.rad(self.from.heading)
  local dvx,dvz=s.velocity.x-self.from.velocity.x,s.velocity.z-self.from.velocity.z
  self.rows[#self.rows+1]={side=mode.side,gear=mode.gear,reverse=mode.reverse,
   forward=(dvx*math.sin(a)+dvz*math.cos(a))/dt,yaw=(s.yawRate-self.from.yawRate)/dt,
   peakSpeed=speed,travel=travel,observedAt=s.at,observable=speed>=0.15 or angle>=1}
  self.phase='brake' self.brakeFrom=addon.copy(s.position) self.settled=0
  return {kind='drive'}
 end
 return self
end
function M.model(rows)
 local model={groups={},maxSpeed=0,brakingDistance=0}
 for _,side in ipairs(sides) do
  local group={positive={},negative={}}
  for _,r in ipairs(rows or {}) do if r.side==side and r.observable and addon.finite(r.brakingDistance) and r.brakingDistance<=8 and math.abs(r.forward)>=0.01 then
   local list=r.forward>0 and group.positive or group.negative list[#list+1]=addon.copy(r)
   model.maxSpeed=math.max(model.maxSpeed,r.peakSpeed) model.brakingDistance=math.max(model.brakingDistance,r.brakingDistance)
  end end
  if #group.positive==0 or #group.negative==0 then return nil,'Forward/reverse motion and neutral braking not observed on '..side..' motor' end
  local function strongest(list) local best=list[1] for _,r in ipairs(list) do if math.abs(r.forward)>math.abs(best.forward) then best=r end end return best end
  group.reference=strongest(group.positive) local back=strongest(group.negative)
  if math.abs(group.reference.yaw/group.reference.forward-back.yaw/back.forward)>math.max(0.5,math.abs(group.reference.yaw/group.reference.forward)*0.5) then return nil,'Reverser yaw response inconsistent on '..side end
  model.groups[side]=group
 end
 local a,b=model.groups.left.reference,model.groups.right.reference
 model.determinant=a.forward*b.yaw-b.forward*a.yaw
 if math.abs(model.determinant)<0.001 or a.yaw*b.yaw>=0 then return nil,'Independent left/right yaw authority not measured' end
 if model.maxSpeed<0.2 then return nil,"Insufficient observed motor speed for route qualification" end
 return model
end
function M.control(model,s,target)
 if not s.velocity or not addon.finite(s.yawRate) or not addon.finite(s.heading) then return nil,'Motor guidance telemetry unavailable' end
 local a=math.rad(s.heading) local forward=s.velocity.x*math.sin(a)+s.velocity.z*math.cos(a)
 local wantedForward=(target.speed-forward)*0.5
 local wantedYaw=math.max(-8,math.min(8,geometry.wrap(target.heading-s.heading)*0.5))-s.yawRate
 local l,r=model.groups.left.reference,model.groups.right.reference
 local demands={left=(wantedForward*r.yaw-wantedYaw*r.forward)/model.determinant,right=(wantedYaw*l.forward-wantedForward*l.yaw)/model.determinant}
 local selection={}
 for _,side in ipairs(sides) do
  local group=model.groups[side] local wanted=math.max(-1,math.min(1,demands[side]))*group.reference.forward
  if math.abs(wanted)>0.005 then
   local list=wanted>0 and group.positive or group.negative local best,delta
   for _,mode in ipairs(list) do local d=math.abs(mode.forward-wanted) if not delta or d<delta then best,delta=mode,d end end
   selection[side]={gear=best.gear,reverse=best.reverse}
  end
 end
 return selection
end
return M
