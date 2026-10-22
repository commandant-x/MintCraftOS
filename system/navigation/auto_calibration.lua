-- Evidence from real closed-loop motion. Pure state machine; no writes or flags.
local addon=require('system.libraries.addon')
local M={}
function M.new(owner,binding,mass,unit)
 local self={state='waiting_model',phase='model',owner=owner,binding=addon.copy(binding),mass=mass,massUnit=unit,
  reason='Waiting for measured altitude model',checks={},manualSwitch='not observed',horizontal='No measured horizontal authority'}
 function self:running() return self.state=='waiting_model' or self.state=='running' end
 function self:abort(why) self.state='aborted' self.reason=why end
 function self:attach(model)
  local points=model and model.points
  if type(points)~='table' or #points<3 then self:abort('Qualified altitude table required') return false end
  local low,high=points[1].altitude,points[#points].altitude
  if not addon.finite(low) or not addon.finite(high) or high-low<4 then self:abort('At least 4 m of measured height range needed for motion verification') return false end
  self.model=addon.copy(model) self.center=(low+high)/2 self.delta=math.min(2,(high-low)/4)
  self.steps={{name='hover',target=self.center},{name='down',target=self.center-self.delta},
   {name='up',target=self.center+self.delta},{name='return',target=self.center}}
  self.state,self.phase,self.index,self.reason='running','hold',1,'Checking actual closed-loop hover'
  self.issued=false self.window={} self.motion=0 return true
 end
 function self:step(t,now,ack)
  if self.state~='running' then return end
  if not addon.finite(now) or self.clock and now<self.clock then self:abort('Calibration clock regressed') return end
  self.clock=now
  if not addon.finite(t.timestamp) or now<t.timestamp or now-t.timestamp>0.5 or not addon.finite(t.altitude) or not addon.finite(t.altitudeRate) then self:abort('Calibration telemetry stale/invalid') return end
  if self.phase=='hold' then
   local step=self.steps[self.index]
   if not self.issued then
    self.issued=true self.commandAt=now self.from=t.altitude self.window={} self.motion=0 self.last=nil
    self.reason='Measuring '..step.name..' at '..string.format('%.2f',step.target)..' m'
    return {kind='target',value=step.target}
   end
   if not ack or t.timestamp<=self.commandAt or self.last and t.timestamp-self.last<0.5 then return end
   local consecutive=not self.last or t.timestamp-self.last<=1.25
   self.last=t.timestamp
   local sign=step.name=='up' and 1 or step.name=='down' and -1 or 0
   if sign~=0 and sign*t.altitudeRate>0.02 and sign*(t.altitude-self.from)>0.2 then self.motion=self.motion+1 end
   if not consecutive or math.abs(t.altitudeRate)>0.25 or math.abs(t.altitude-step.target)>0.5 then self.window={} return end
   self.window[#self.window+1]={altitude=t.altitude,rate=t.altitudeRate}
   while #self.window>8 do table.remove(self.window,1) end
   if #self.window<8 or sign~=0 and self.motion<3 then return end
   local low,high,sum,sumRate=math.huge,-math.huge,0,0
   for _,r in ipairs(self.window) do low=math.min(low,r.altitude) high=math.max(high,r.altitude) sum=sum+r.altitude sumRate=sumRate+r.rate end
   if high-low>0.5 or math.abs(sumRate/8)>0.1 then return end
   self.checks[step.name]={passed=true,target=step.target,altitude=sum/8,spread=high-low,motionSamples=self.motion,meanRate=sumRate/8,observedAt=t.timestamp}
   self.index=self.index+1 self.issued=false
   if self.index>#self.steps then self.phase='rescue' self.reason='Testing actual rescue response' end
  elseif self.phase=='rescue' then
   if not self.issued then self.issued=true self.commandAt=now self.from=t.altitude return {kind='rescue'} end
   if ack and t.timestamp>self.commandAt and t.altitudeRate < -0.1 and t.altitude<self.from-0.1 then
    self.checks.rescue={passed=true,observedAt=t.timestamp,altitude=t.altitude,rate=t.altitudeRate}
    self.phase='recover' self.issued=false return {kind='restart',value=self.center}
   end
  elseif self.phase=='recover' then
   if not self.issued then self.issued=true self.window={} self.last=nil end
   if not ack or self.last and t.timestamp-self.last<0.5 then return end
   if self.last and t.timestamp-self.last>1.25 then self.window={} end self.last=t.timestamp
   if math.abs(t.altitude-self.center)>0.5 or math.abs(t.altitudeRate)>0.25 then self.window={} return end
   self.window[#self.window+1]={altitude=t.altitude,rate=t.altitudeRate}
   while #self.window>8 do table.remove(self.window,1) end
   if #self.window<8 then return end
   local low,high,sum=math.huge,-math.huge,0
   for _,r in ipairs(self.window) do low=math.min(low,r.altitude) high=math.max(high,r.altitude) sum=sum+r.rate end
   if high-low>0.5 or math.abs(sum/8)>0.1 then return end
   if not self.checks.priority then self.phase='priority' self.issued=false self.reason='Testing software pilot priority'
   else self.state='complete' self.phase='complete' self.reason='Measured vertical calibration passed; altitude pilot available' end
  elseif self.phase=='priority' then
   if not self.issued then self.issued=true self.commandAt=now return {kind='priority'} end
   if ack and t.timestamp>self.commandAt then
    self.checks.priority={passed=true,observedAt=t.timestamp,scope='Software STOP path and actual rescue signal; physical switch not inferred'}
    self.phase='recover' self.issued=false return {kind='restart',value=self.center}
   end
  end
 end
 function self:status()
  return {state=self.state,phase=self.phase,reason=self.reason,checks=addon.copy(self.checks),
   target=self.phase=='hold' and self.steps and self.steps[self.index] and self.steps[self.index].target or self.center,
   manualSwitch=self.manualSwitch,horizontal=self.horizontal}
 end
 return self
end
return M
