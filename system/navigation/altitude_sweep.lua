-- Measurement-driven identification. No peripheral writes or physical-validation flags.
local addon=require("system.libraries.addon")
local Progress=require("system.navigation.sweep_progress")
local M={}
function M.defaults() return {first=7,last=15,maxSpeed=0,maxTravel=0,autoPrepare=true,autoHold=true,certify=true} end
function M.validate(value)
  if type(value)~="table" then return nil,"Sweep options missing" end
  local p={}
  for key,range in pairs({first={1,15},last={1,15}}) do
    local v=value[key]
    if not addon.finite(v) or v<range[1] or v>range[2] then return nil,"Sweep "..key.." outside "..range[1]..".."..range[2] end
    p[key]=v
  end
  for key,maximum in pairs({maxSpeed=1000,maxTravel=10000000}) do
    local v=value[key]
    if v==nil then v=0 end
    if not addon.finite(v) or v<0 or v>maximum then return nil,"Invalid optional sweep "..key end
    p[key]=v
  end
  if p.first%1~=0 or p.last%1~=0 or p.last-p.first<2 then return nil,"At least three integer heat levels required" end
  for _,key in ipairs({"autoPrepare","autoHold","certify"}) do
    if value[key]~=nil and type(value[key])~="boolean" then return nil,"Invalid sweep "..key end
    p[key]=value[key]==true
  end
  if p.certify and not p.autoHold then return nil,"Closed-loop calibration requires automatic altitude hold" end
  if p.autoHold and not p.autoPrepare then return nil,"Automatic hold requires automatic receiver tests" end
  return p
end
function M.analyze(samples,options,levels)
  if type(levels)~="table" then return nil,"Measured stable heights required" end
  return require("system.navigation.altitude_model").analyze(samples,levels,options)
end
M.heatAt=require("system.navigation.altitude_model").heatAt
function M.new(options,start,now)
  local p,err=M.validate(options) if not p then return nil,err end
  if not addon.finite(start) or not addon.finite(now) then return nil,"Fresh starting altitude required" end
  local self={options=p,startAltitude=start,startedAt=now,stageAt=now,signal=p.first,state="running",samples={},levels={},reason="Measure stable altitude",lastObserved=nil,phase=p.autoPrepare and "initialize" or "measure",rescueHeat=0}
  local progress=Progress.new()
  function self:abort(reason) self.state="aborted" self.reason=reason return nil,reason end
  function self:step(t,clock,ack)
    if self.state~="running" then return nil,self.reason end
    if not addon.finite(clock) or clock<(self.lastClock or self.startedAt) then return self:abort("Sweep clock regressed") end
    self.lastClock=clock
    if not t.inSublevel or not addon.finite(t.timestamp) or clock<t.timestamp or clock-t.timestamp>0.5 or
      not addon.finite(t.altitude) or not addon.finite(t.altitudeRate) then return self:abort("Fresh altitude/rate/sublevel telemetry lost") end
    if self.options.maxSpeed>0 and math.abs(t.altitudeRate)>self.options.maxSpeed then return self:abort("Operator vertical-speed limit reached") end
    if self.options.maxTravel>0 and math.abs(t.altitude-self.startAltitude)>self.options.maxTravel then return self:abort("Operator altitude travel limit reached") end
    if self.phase~="measure" then
      if ack then
        if self.phase=="initialize" then self.initialized=true self.phase="rescue" self.signal=self.rescueHeat
        else self.prepared=true self.phase="measure" self.signal=self.options.first end
        self.stageAt=clock self.lastObserved=nil
      end
      self.reason=self.phase=="initialize" and "Automatic burner test / initialization: waiting for every receiver" or
        self.phase=="rescue" and "Automatic rescue test: waiting for every receiver" or "Tests acknowledged; waiting for stable altitude"
      return self.signal
    end
    if ack and t.timestamp>=self.stageAt and (not self.lastObserved or t.timestamp-self.lastObserved>=0.5) then
      local sample={time=t.timestamp-self.startedAt,signal=self.signal,altitude=t.altitude,rate=t.altitudeRate}
      self.samples[#self.samples+1]=sample self.lastObserved=t.timestamp
      -- Retain 24 initial dynamic samples and a rolling 16 per heat level.
      -- Waiting indefinitely never grows RAM or creates a hidden sample timeout.
      local count=0
      for i,r in ipairs(self.samples) do
        if r.signal==self.signal then count=count+1 if count==25 then self.replaceAt=i end end
      end
      if count>40 then table.remove(self.samples,self.replaceAt) end
      local level=self.levels[self.signal] or {signal=self.signal,count=0,minAltitude=t.altitude,maxAltitude=t.altitude,sumRate=0}
      level.count=level.count+1 level.minAltitude=math.min(level.minAltitude,t.altitude) level.maxAltitude=math.max(level.maxAltitude,t.altitude)
      level.sumRate=level.sumRate+t.altitudeRate
      level.tail=level.tail or {} level.tail[#level.tail+1]=sample
      while #level.tail>8 do table.remove(level.tail,1) end
      local minY,maxY,minV,maxV=math.huge,-math.huge,math.huge,-math.huge
      for _,r in ipairs(level.tail) do minY=math.min(minY,r.altitude) maxY=math.max(maxY,r.altitude) minV=math.min(minV,r.rate) maxV=math.max(maxV,r.rate) end
      local span=sample.time-level.tail[1].time
      local contiguous=true
      local mt,mv=0,0
      for i,r in ipairs(level.tail) do
        mt=mt+r.time mv=mv+r.rate
        if i>1 and r.time-level.tail[i-1].time>1.25 then contiguous=false end
      end
      mt,mv=mt/#level.tail,mv/#level.tail
      local covariance,variance=0,0
      for _,r in ipairs(level.tail) do covariance=covariance+(r.time-mt)*(r.rate-mv) variance=variance+(r.time-mt)^2 end
      level.speedSlope=variance>0 and covariance/variance or math.huge
      level.windowSpan,level.speedSpread,level.altitudeSpread=span,maxV-minV,maxY-minY
      local windowReady=#level.tail>=8 and span>=3 and contiguous
      level.stableAltitude=windowReady and maxY-minY<=0.5 and math.max(math.abs(minV),math.abs(maxV))<=0.1
      level.steadySpeed=windowReady and maxV-minV<=0.04 and math.abs(level.speedSlope)<=0.01
      self.levels[self.signal]=level
      progress:observe(level) self.diagnostic=progress:status()
      level.progress=addon.copy(self.diagnostic)
    end
    local level=self.levels[self.signal]
    if ack and level and self.lastObserved==t.timestamp and level.stableAltitude then
      level.settled=true level.finishedAt=clock-self.startedAt
      local height=0 for _,r in ipairs(level.tail) do height=height+r.altitude end
      level.altitude=height/#level.tail
      local rate=0 for _,r in ipairs(level.tail) do rate=rate+r.rate end level.meanRate=rate/#level.tail

      if self.signal==self.options.last then
        self.state="complete" self.reason="Measurements complete; returning to rescue"
        self.proposal,self.fitError=M.analyze(self.samples,self.options,self.levels)
        return nil,self.reason
      end
      self.signal=self.signal+1 self.stageAt=clock self.lastObserved=nil self.diagnostic=nil progress=Progress.new()
      self.reason="Waiting for |vertical speed| <= 0.1 m/s at heat "..self.signal
    elseif not ack then self.reason="Waiting for every burner receiver to confirm heat "..self.signal
    else self.reason="Heat "..self.signal..": "..(self.diagnostic and self.diagnostic.reason or "waiting for fresh stability observations") end
    return self.signal
  end
  function self:status(full)
    local out={state=self.state,phase=self.phase,prepared=self.prepared==true,initialized=self.initialized==true,reason=self.reason,startAltitude=self.startAltitude,startedAt=self.startedAt,signal=self.signal,count=#self.samples,options=addon.copy(self.options),
      proposal=addon.copy(self.proposal),fitError=self.fitError,diagnostic=addon.copy(self.diagnostic),levels=addon.copy(self.levels)}
    for _,level in pairs(out.levels) do level.tail=nil end
    if full then out.samples=addon.copy(self.samples) end
    return out
  end
  return self
end
return M
