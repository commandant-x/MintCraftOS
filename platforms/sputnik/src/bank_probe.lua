-- Small horizontal propulsion experiment. All hardware IO belongs to the node adapter.
-- Sense A/B, not a fabricated global vehicle front or a flight certificate.
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function wrap(v) return (v+180)%360-180 end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
local function point(v) return {x=v.x,y=v.y,z=v.z} end
local function bounded(v,lo,hi) return finite(v) and v>=lo and v<=hi end
function M.new(config,obs)
 if type(config)~='table' or not bounded(config.stop,0,15) or config.stop%1~=0 or not bounded(config.test,0,15) or config.test%1~=0 or config.test==config.stop or
  not bounded(config.maxProbe,.5,10) or not bounded(config.maxTravel,1,32) then return nil,'Explicit stop/test levels and test envelope required' end
 if type(obs)~='table' or not finite(obs.tick) or obs.tick<=0 or obs.tick%1~=0 or not finite(obs.mass) or obs.mass<=0 or type(obs.namespace)~='string' or #obs.namespace<1 or #obs.namespace>128 then return nil,'Actual server observation required' end
 for _,key in ipairs({'x','y','z','pitch','yaw','roll'}) do if not finite(obs[key]) then return nil,'Invalid initial observed '..key end end
 local self={config=config,phase='restA',reason='Waiting for real shaft and vessel rest',home=point(obs),mass=obs.mass,namespace=obs.namespace,pitch=obs.pitch,roll=obs.roll,
  report={kind='horizontal-functional-probe',flightQualified=false,identityAvailable=false,samples=0},rest=0,done=false,failed=false}
 function self:abort(why) self.failed=true self.phase='failed' self.reason=why return self:command() end
 function self:command()
  local running=self.phase=='pulseA' or self.phase=='pulseB'
  return {run=running and 15 or 0,power=running and self.config.test or self.config.stop,direction=self.direction}
 end
 function self:requested(tick)
  -- Attempted RPC only. Actual spinning and movement are required independently.
  if not self.requestTick then self.requestTick=tick end
 end
 function self:enter(phase,obs)
  self.phase=phase self.requestTick=nil self.rest=0 self.moving=0
  if phase=='selectA' or phase=='pulseA' then self.direction=0 end
  if phase=='selectB' or phase=='pulseB' then self.direction=15 end
  if phase=='restore' then self.direction=0 end
  if phase=='pulseA' or phase=='pulseB' then self.origin=point(obs) self.yaw=obs.yaw self.spinning=false end
  if phase=='coastA' or phase=='coastB' then self.stopPoint=point(obs) self.braking=0 end
 end
 function self:step(obs)
  if self.failed or self.done then return self:command() end
  if type(obs)~='table' then return self:abort('Server observations unavailable') end
  for _,key in ipairs({'tick','x','y','z','pitch','yaw','roll','mass','spin'}) do if not finite(obs[key]) then return self:abort('Nonfinite/missing observed '..key) end end
  if obs.tick%1~=0 or obs.spin<0 or obs.spin>15 or obs.namespace~=self.namespace or obs.mass<=0 then return self:abort('Shaft/world/vehicle observations changed') end
  if math.abs(obs.mass-self.mass)>self.mass*.02 then return self:abort('Mass changed during propulsion probe; no recertification') end
  if distance(obs,self.home)>self.config.maxTravel or math.abs(obs.y-self.home.y)>.5 or math.abs(wrap(obs.pitch-self.pitch))>8 or math.abs(wrap(obs.roll-self.roll))>8 then return self:abort('Operator probe envelope exceeded; propulsion stopped, lift untouched') end
  local old=self.previous
  if old and obs.tick<old.tick then return self:abort('Server clock regressed') end
  if old and obs.tick==old.tick then return self:command() end
  self.previous={tick=obs.tick,x=obs.x,y=obs.y,z=obs.z,yaw=obs.yaw,pitch=obs.pitch,roll=obs.roll}
  if not old then return self:command() end
  local dt=(obs.tick-old.tick)/20
  if dt>.5 then return self:abort('Server observation gap') end
  if not self.requestTick or obs.tick<=self.requestTick then return self:command() end
  local speed=distance(obs,old)/dt local vertical=math.abs(obs.y-old.y)/dt
  local angular=math.max(math.abs(wrap(obs.yaw-old.yaw)),math.abs(wrap(obs.pitch-old.pitch)),math.abs(wrap(obs.roll-old.roll)))/dt
  local steady=obs.spin==0 and speed<=.1 and vertical<=.1 and angular<=1
  self.report.samples=self.report.samples+1
  if self.phase=='pulseA' or self.phase=='pulseB' then
   if obs.spin==15 then self.spinning=true end
   local moved=distance(obs,self.origin)
   if self.spinning and obs.spin==15 and moved>=.25 then self.moving=self.moving+1 else self.moving=0 end
   if self.moving>=3 then
    local dx,dz=obs.x-self.origin.x,obs.z-self.origin.z local yaw=math.rad(self.yaw)
    local record={worldX=dx,worldZ=dz,bodyX=dx*math.cos(yaw)-dz*math.sin(yaw),bodyZ=dx*math.sin(yaw)+dz*math.cos(yaw),distance=moved,signal=self.config.test,spinningObserved=true}
    if self.phase=='pulseA' then self.report.A=record self:enter('coastA',obs)
    else
     local a=self.report.A
     local cosine=(record.bodyX*a.bodyX+record.bodyZ*a.bodyZ)/(record.distance*a.distance)
     record.opposition=cosine self.report.B=record
     if cosine>-.6 then return self:abort('Sense B did not oppose the measured motion of A') end
     self:enter('coastB',obs)
    end
   elseif (obs.tick-self.requestTick)/20>=self.config.maxProbe then return self:abort('No sufficient spinning + movement before maximum energized probe duration') end
  else
   self.rest=steady and self.rest+1 or 0
   if self.phase=='coastA' or self.phase=='coastB' then self.braking=math.max(self.braking,distance(obs,self.stopPoint)) end
   if self.rest>=6 then
    if self.phase=='restA' then self:enter('selectA',obs)
    elseif self.phase=='selectA' then self:enter('pulseA',obs)
    elseif self.phase=='coastA' then self.report.A.brakingDistance=self.braking self:enter('selectB',obs)
    elseif self.phase=='selectB' then self:enter('pulseB',obs)
    elseif self.phase=='coastB' then self.report.B.brakingDistance=self.braking self:enter('restore',obs)
    elseif self.phase=='restore' then self.phase='done' self.done=true self.report.functionalReverseMeasured=true end
   end
  end
  self.reason=self.phase=='done' and 'Two opposed movements and actual stops observed; not a flight certificate' or self.phase
  return self:command()
 end
 return self
end
return M
