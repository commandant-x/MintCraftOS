-- Real measured-target transitions, never success from an elapsed timer.
local A=require('system.libraries.addon')
local G=require('system.navigation.geometry')
local R=require('system.navigation.response_model')
local Progress=require('system.navigation.motion_progress')
local M={}
local function multiply(a,b)
 return {w=a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z,x=a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,
  y=a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,z=a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w}
end
local function offset(controller,index,value)
 local p,q=A.copy(controller.origin),A.copy(controller.reference)
 if index<=3 then
  local v={x=index==2 and value or 0,y=index==3 and value or 0,z=index==1 and value or 0}
  for _,axis in ipairs({'x','y','z'}) do p[axis]=p[axis]+v[axis] end
 else
  local half=math.rad(value)/2 local r={x=0,y=0,z=0,w=math.cos(half)}
  r[index==4 and 'x' or index==5 and 'y' or 'z']=math.sin(half) q=multiply(r,q)
 end
 return p,q
end
function M.new(controller,only)
 local self={state='running',index=1,steps={},checks={},reason='Checking actual closed-loop response on candidate axes'}
 for i,axis in ipairs(R.axes) do if controller.axes[axis] and (not only or only[axis]) then
  local amplitude=math.min(controller.model.motionDomain.worldExcursion[i]*.2,i<=3 and .5 or 2)
  for _,sign in ipairs({1,-1,0}) do self.steps[#self.steps+1]={axis=axis,index=i,offset=amplitude*sign,amplitude=amplitude} end
 end end
 if #self.steps==0 then return nil,'No candidate axis for closed-loop qualification' end
 function self:abort(why) self.state,self.reason='aborted',why end
 function self:step(current,at,ack)
  if self.state~='running' then return end
  if not A.finite(at) or self.last and at<self.last then self:abort('Qualification clock regressed') return end
  local step=self.steps[self.index]
  if not self.issued then
   local p,q=offset(controller,step.index,step.offset)
   local ok,why=controller:target(p,q) if not ok then self:abort(why) return end
   self.progress=Progress.new()
   self.issued=true self.commandAt=at self.last=nil self.samples=0 self.motion=0 self.from=nil self.low,self.high=math.huge,-math.huge
   self.reason='Measuring '..step.axis..' target '..string.format('%.3f',step.offset)..'; wait for actual motion and stability'
   return
  end
  if not ack or at<=self.commandAt or self.last and at-self.last<.1-1e-8 then return end
  if self.last and at-self.last>.5 then self.samples=0 self.motion=0 self.from=nil end self.last=at
  local error,rates=current.error,current.rates
  if type(error)~='table' or type(rates)~='table' then self:abort('Closed-loop measurements unavailable') return end
  for i=1,6 do if not A.finite(error[i]) or not A.finite(rates[i]) then self:abort('Nonfinite closed-loop measurement') return end end
  self.progress:observe(error,rates,at)
  self.from=self.from or error[step.index]
  local sign=self.from>=0 and 1 or -1
  if sign*rates[step.index]>(step.index<=3 and .01 or .1) and sign*(self.from-error[step.index])>step.amplitude*.25 then self.motion=self.motion+1 end
  local stable=true
  for i,axis in ipairs(R.axes) do if controller.axes[axis] then
   local tolerance=math.max(i<=3 and .02 or .1,math.min(i<=3 and .1 or .5,controller.model.motionDomain.worldExcursion[i]*.04))
   if math.abs(error[i])>tolerance or math.abs(rates[i])>controller.rateTolerance[i] then stable=false end
  end end
  if not stable then self.samples=0 self.low,self.high=math.huge,-math.huge return end
  self.samples=self.samples+1 self.low=math.min(self.low,error[step.index]) self.high=math.max(self.high,error[step.index])
  if self.samples<8 or self.motion<3 or self.high-self.low>step.amplitude*.4 then return end
  self.checks[#self.checks+1]={axis=step.axis,offset=step.offset,amplitude=step.amplitude,motionSamples=self.motion,settledSamples=self.samples,error=error[step.index],rate=rates[step.index],observedAt=at,startedAt=self.commandAt,settleDuration=at-self.commandAt,spread=self.high-self.low}
  self.index=self.index+1 self.issued=false
  if self.index>#self.steps then self.state='complete' self.reason='All candidate axes passed real motion, return and settling tests' end
 end
 function self:status() return {state=self.state,index=self.index,count=#self.steps,reason=self.reason,stableSamples=self.samples or 0,motionSamples=self.motion or 0,checks=A.copy(self.checks),progress=self.progress and self.progress:status() or nil} end
 return self
end
return M
