-- Measured control-space diagnostics and bounded horizontal supervision.
-- This module never probes hardware, invents an axis or writes an actuator.
local A=require('system.libraries.addon')
local M={}
local limits={forward=.01,right=.01,vertical=.01,pitch=.1,yaw=.1,roll=.1}
local function sequence(value,maximum)
 if type(value)~='table' or getmetatable(value) or #value<1 or #value>maximum then return false end
 local count=0 for key in pairs(value) do
  if type(key)~='number' or key%1~=0 or key<1 or key>#value then return false end count=count+1
 end
 return count==#value
end
function M.identify(axes,columns)
 if not sequence(axes,6) or not sequence(columns,32) then return nil,'Response matrix bounds invalid' end
 local seen,scale={},{}
 for i,axis in ipairs(axes) do
  if not limits[axis] or seen[axis] then return nil,'Unknown/duplicate response axis' end seen[axis]=true scale[i]=0
  for _,column in ipairs(columns) do
   if type(column)~='table' or getmetatable(column) or type(column.id)~='string' or #column.id<1 or #column.id>192 or type(column.values)~='table' or getmetatable(column.values) or not A.finite(column.values[axis]) then return nil,'Complete measured columns required' end
   scale[i]=math.max(scale[i],math.abs(column.values[axis]))
  end
 end
 local ids,Q,vectors={}, {},{} local smallest,largest=math.huge,0
 for _,column in ipairs(columns) do
  if ids[column.id] then return nil,'Duplicate actuator column' end ids[column.id]=true
  local v={}
  for i,axis in ipairs(axes) do v[i]=scale[i]>=limits[axis] and column.values[axis]/scale[i] or 0 end
  vectors[#vectors+1]=v
 end
 -- Column-pivoted, reorthogonalized Gram-Schmidt. Redundant weak columns
 -- cannot spoil a well-conditioned independently observed subset.
 local used={}
 for step=1,math.min(#axes,#vectors) do
  local best,bestVector,bestNorm=nil,nil,0
  for j,original in ipairs(vectors) do if not used[j] then
   local v={} for i,value in ipairs(original) do v[i]=value end
   for pass=1,2 do for _,q in ipairs(Q) do
    local dot=0 for i=1,#axes do dot=dot+v[i]*q[i] end
    for i=1,#axes do v[i]=v[i]-dot*q[i] end
   end end
   local norm=0 for _,value in ipairs(v) do norm=norm+value*value end norm=math.sqrt(norm)
   if norm>bestNorm then best,bestVector,bestNorm=j,v,norm end
  end end
  if bestNorm<=1e-3 then break end
  used[best]=true smallest,largest=math.min(smallest,bestNorm),math.max(largest,bestNorm)
  for i=1,#axes do bestVector[i]=bestVector[i]/bestNorm end Q[#Q+1]=bestVector
 end
 local out={schema=1,rank=#Q,axes={},columns=#columns,condition=#Q>0 and largest/smallest or nil,scope='response-subspace-only'}
 for i,axis in ipairs(axes) do
  local projection=0 for _,q in ipairs(Q) do projection=projection+q[i]^2 end
  local observed=scale[i]>=limits[axis]
  local independent=observed and 1-projection<1e-5 and out.condition<=1000
  out.axes[axis]={observed=observed,independent=independent,peak=scale[i],
   reason=independent and 'Independent response measured in supplied subspace' or observed and 'Coupled/ill-conditioned response; axis not independently certified' or 'Response below identification threshold'}
 end
 return out
end
function M.braking(rows)
 local a,reaction,speed,count=math.huge,0,0,0
 for _,r in ipairs(rows or {}) do
  if A.finite(r.brakeSpeed) and r.brakeSpeed>=.15 and A.finite(r.brakingDistance) and r.brakingDistance>1e-5 and
   A.finite(r.reactionTime) and r.reactionTime>=0 and r.reactionTime<=10 then
   a=math.min(a,r.brakeSpeed^2/(2*r.brakingDistance)) reaction=math.max(reaction,r.reactionTime)
   speed=math.max(speed,r.brakeSpeed) count=count+1
  end
 end
 if count<2 or not A.finite(a) or a<=0 then return nil,'Observed neutral braking envelope unavailable' end
 return {schema=1,deceleration=a,reactionTime=reaction,maxObservedSpeed=speed,samples=count,source='acknowledged-neutral-stops'}
end
function M.speed(envelope,distance)
 if not envelope or not A.finite(envelope.deceleration) or envelope.deceleration<=0 or not A.finite(envelope.reactionTime) or envelope.reactionTime<0 or
  not A.finite(envelope.maxObservedSpeed) or envelope.maxObservedSpeed<=0 or not A.finite(distance) then return nil end
 distance=math.max(0,distance)
 local a,t=envelope.deceleration,envelope.reactionTime
 local denominator=math.sqrt((a*t)^2+2*a*distance)+a*t
 return denominator>0 and math.min(envelope.maxObservedSpeed,2*a*distance/denominator) or 0
end
function M.monitor()
 local self={samples=0}
 function self:observe(s,expected,ack)
  if not ack or not expected or not s or not s.velocity or not A.finite(s.at) or not A.finite(s.yawRate) then self.samples=0 return end
  if self.last and s.at<=self.last then return end
  if self.last and s.at-self.last<.5 then return end
  if self.last and s.at-self.last>1.5 then self.samples=0 end self.last=s.at
  if not A.finite(expected.forward) or not A.finite(expected.yaw) or not A.finite(s.velocity.x) or not A.finite(s.velocity.z) then self.samples=0 return end
  local strong=math.abs(expected.forward)>=.02 or math.abs(expected.yaw)>=.5
  local stationary=s.velocity.x^2+s.velocity.z^2<.05^2 and math.abs(s.yawRate)<.1
  self.samples=strong and stationary and self.samples+1 or 0
  if self.samples>=8 then return 'Confirmed motor commands without measurable horizontal response' end
 end
 return self
end
return M
