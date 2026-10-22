-- Bounded open-loop identification. No peripheral writes or calibration flags.
local addon=require("system.libraries.addon")
local M={}
function M.defaults() return {first=7,last=15,dwell=15,timeout=180,maxSpeed=0,maxTravel=0} end
function M.validate(value)
  if type(value)~="table" then return nil,"Sweep options missing" end
  local p={}
  for key,range in pairs({first={1,15},last={1,15},dwell={4,60},timeout={10,180}}) do
    local v=value[key]
    if not addon.finite(v) or v<range[1] or v>range[2] then return nil,"Sweep "..key.." outside "..range[1]..".."..range[2] end
    p[key]=v
  end
  for key,maximum in pairs({maxSpeed=1000,maxTravel=10000000}) do
    local v=value[key] or 0
    if not addon.finite(v) or v<0 or v>maximum then return nil,"Invalid optional sweep "..key end
    p[key]=v
  end
  if p.first%1~=0 or p.last%1~=0 or p.last-p.first<2 then return nil,"At least three integer heat levels required" end
  if (p.last-p.first+1)*4>p.timeout then return nil,"Timeout too short for stability measurements" end
  return p
end
local function fit(rows)
  if #rows<12 then return nil,"Not enough acknowledged dynamic samples" end
  local mv,mu,my=0,0,0
  for _,r in ipairs(rows) do mv=mv+r.v mu=mu+r.u my=my+r.y end
  mv,mu,my=mv/#rows,mu/#rows,my/#rows
  local vv,uu,vu,vy,uy=0,0,0,0,0
  for _,r in ipairs(rows) do
    local v,u,y=r.v-mv,r.u-mu,r.y-my
    vv=vv+v*v uu=uu+u*u vu=vu+v*u vy=vy+v*y uy=uy+u*y
  end
  local det=vv*uu-vu*vu
  if vv<1e-8 or uu<1e-8 or det<=1e-5*vv*uu then return nil,"Response not identifiable; vary heat around hover" end
  local a,b=(vy*uu-uy*vu)/det,(uy*vv-vy*vu)/det
  local c=my-a*mv-b*mu
  if not addon.finite(a) or not addon.finite(b) or not addon.finite(c) then return nil,"Nonfinite fitted response" end
  return {a=a,b=b,c=c}
end
function M.analyze(samples,options)
  local rows,levels={},{}
  local low,high=math.huge,-math.huge
  for i,s in ipairs(samples) do
    levels[s.signal]=true low=math.min(low,s.rate) high=math.max(high,s.rate)
    local previous=samples[i-1]
    if previous and previous.signal==s.signal then
      local dt=s.time-previous.time
      if dt>=0.2 and dt<=1 then rows[#rows+1]={v=(s.rate+previous.rate)/2,u=s.signal,y=(s.rate-previous.rate)/dt} end
    end
  end
  local count=0 for _ in pairs(levels) do count=count+1 end
  if count<3 then return nil,"At least three measured heat levels needed" end
  local model,err=fit(rows) if not model then return nil,err end
  local mean=0 for _,r in ipairs(rows) do mean=mean+r.y end mean=mean/#rows
  local residual,total=0,0
  for _,r in ipairs(rows) do residual=residual+(r.y-model.a*r.v-model.b*r.u-model.c)^2 total=total+(r.y-mean)^2 end
  local r2=total>1e-8 and 1-residual/total or 0
  if r2<0.9 then return nil,"Response too noisy/nonlinear for automatic PI; retain measurements" end
  -- Independent chronological holdout rejects an apparently good overall fit
  -- which cannot predict the latter part of the run.
  local train,hold={},{}
  for i,r in ipairs(rows) do local t=i<=math.floor(#rows*0.7) and train or hold t[#t+1]=r end
  local cross=fit(train)
  if not cross then return nil,"Insufficient independent fit for validation" end
  local mse=0 for _,r in ipairs(hold) do mse=mse+(r.y-cross.a*r.v-cross.b*r.u-cross.c)^2 end
  if math.sqrt(mse/math.max(1,#hold))>0.02+0.25*math.sqrt(total/#rows) then return nil,"Measured response changed during sweep" end
  if model.a>=-1/60 or model.a < -2 or model.b<=0 then return nil,"No bounded first-order vertical-speed response identified" end
  local tau,k=-1/model.a,-model.b/model.a
  local hover=-model.c/model.b
  if hover<options.first or hover>options.last or low>=-0.03 or high<=0.03 then return nil,"Hover not bracketed; choose lower/higher levels, no extrapolation" end
  local neutral=math.floor(hover+0.5)
  local limit=math.min(2,neutral-options.first,options.last-neutral)
  if limit<1 then return nil,"Hover too near tested edge; more bidirectional signal margin needed" end
  local kp=1/(8*k*tau)
  if not addon.finite(kp) or kp<0.001 or kp>2 then return nil,"Identified sensitivity outside supported PI range" end
  local ki=kp/(8*tau)
  return {hover=hover,neutral=neutral,tau=tau,sensitivity=k,r2=r2,
    measuredRange={first=options.first,last=options.last,minSpeed=low,maxSpeed=high},
    gains={kp=kp,ki=ki,kd=0,limit=limit,slew=0.25,integralLimit=math.min(100,limit/ki),deadband=0.1},
    note="PI candidate for measured first-order speed model; D=0. Physical hold/manual/rescue verification still required."}
end
-- Estimated steady vertical speed between measured heat levels only.
function M.speedAt(proposal,heat)
  local range=type(proposal)=="table" and proposal.measuredRange
  if type(range)~="table" or not addon.finite(range.first) or not addon.finite(range.last)
    or not addon.finite(heat) or heat<range.first or heat>range.last
    or not addon.finite(proposal.sensitivity) or not addon.finite(proposal.hover) then return nil,"Outside measured response range" end
  return proposal.sensitivity*(heat-proposal.hover)
end
function M.new(options,start,now)
  local p,err=M.validate(options) if not p then return nil,err end
  if not addon.finite(start) or not addon.finite(now) then return nil,"Fresh starting altitude required" end
  local self={options=p,startAltitude=start,startedAt=now,stageAt=now,signal=p.first,state="running",samples={},levels={},reason="Measure response",lastObserved=nil}
  function self:abort(reason) self.state="aborted" self.reason=reason return nil,reason end
  function self:step(t,clock,ack)
    if self.state~="running" then return nil,self.reason end
    if not addon.finite(clock) or clock<(self.lastClock or self.startedAt) then return self:abort("Sweep clock regressed") end
    self.lastClock=clock
    if clock-self.startedAt>self.options.timeout then return self:abort("Sweep time limit reached") end
    if not t.inSublevel or not addon.finite(t.timestamp) or clock<t.timestamp or clock-t.timestamp>0.5 or
      not addon.finite(t.altitude) or not addon.finite(t.altitudeRate) then return self:abort("Fresh altitude/rate/sublevel telemetry lost") end
    if self.options.maxSpeed>0 and math.abs(t.altitudeRate)>self.options.maxSpeed then return self:abort("Operator vertical-speed limit reached") end
    if self.options.maxTravel>0 and math.abs(t.altitude-self.startAltitude)>self.options.maxTravel then return self:abort("Operator altitude travel limit reached") end
    if ack and t.timestamp>=self.stageAt and (not self.lastObserved or t.timestamp-self.lastObserved>=0.5) then
      if #self.samples>=360 then return self:abort("Sweep sample limit reached") end
      local sample={time=t.timestamp-self.startedAt,signal=self.signal,altitude=t.altitude,rate=t.altitudeRate}
      self.samples[#self.samples+1]=sample self.lastObserved=t.timestamp
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
      level.windowSpan,level.speedSpread=span,maxV-minV
      local windowReady=#level.tail>=8 and span>=3 and contiguous
      level.stableAltitude=windowReady and maxY-minY<=0.2 and math.max(math.abs(minV),math.abs(maxV))<=0.05
      level.steadySpeed=windowReady and maxV-minV<=0.04 and math.abs(level.speedSlope)<=0.01
      self.levels[self.signal]=level
    end
    local level=self.levels[self.signal]
    if ack and level and self.lastObserved==t.timestamp and level.steadySpeed then
      level.settled=true level.finishedAt=clock-self.startedAt

      if self.signal==self.options.last then
        self.state="complete" self.reason="Measurements complete; returning to rescue"
        self.proposal,self.fitError=M.analyze(self.samples,self.options)
        return nil,self.reason
      end
      self.signal=self.signal+1 self.stageAt=clock self.lastObserved=nil
      self.reason="Waiting for measured speed stability at heat "..self.signal
    elseif clock-self.stageAt>=self.options.dwell then
      return self:abort("No measured stability before level safety timeout at heat "..self.signal)
    else self.reason="Measuring heat "..self.signal.."; waiting for steady vertical speed" end
    return self.signal
  end
  function self:status(full)
    local out={state=self.state,reason=self.reason,startAltitude=self.startAltitude,startedAt=self.startedAt,signal=self.signal,count=#self.samples,options=addon.copy(self.options),
      proposal=addon.copy(self.proposal),fitError=self.fitError,levels=addon.copy(self.levels)}
    for _,level in pairs(out.levels) do level.tail=nil end
    if full then out.samples=addon.copy(self.samples) end
    return out
  end
  return self
end
return M
