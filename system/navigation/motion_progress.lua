-- Fixed-memory physical progress evidence; never a stabilization timeout.
local A=require('system.libraries.addon')
local M={}
function M.new()
 local self={samples={},last=nil,diagnostic='Collecting physical progress evidence',axes={}}
 function self:observe(error,rates,at)
  if not A.finite(at) or self.last and at<=self.last then return false end
  for i=1,6 do if not A.finite(error and error[i]) or not A.finite(rates and rates[i]) then return false end end
  if self.last and at-self.last<.5-1e-8 then return false end
  if self.last and at-self.last>1 then self.samples={} end self.last=at
  self.samples[#self.samples+1]={error=A.copy(error),rates=A.copy(rates)}
  if #self.samples>32 then table.remove(self.samples,1) end
  self.axes={}
  if #self.samples<32 then self.diagnostic='Collecting physical progress evidence' return true end
  for axis=1,6 do
   local first,last,turns,sign=0,0,0,0
   for j,sample in ipairs(self.samples) do
    local e=sample.error[axis] local r=sample.rates[axis]
    if j<=16 then first=first+e*e else last=last+e*e end
    local threshold=axis<=3 and .05 or .5
    local current=r>threshold and 1 or r< -threshold and -1 or 0
    if current~=0 then if sign~=0 and current~=sign then turns=turns+1 end sign=current end
   end
   local rms=math.sqrt(last/16) local threshold=axis<=3 and .25 or 3
   if rms>threshold and last>=first*.9 then
    self.axes[axis]=turns>=6 and 'nondecaying-oscillation' or 'no-measured-convergence'
   end
  end
  self.diagnostic=next(self.axes) and 'Physical errors are not converging; no qualification granted by waiting' or 'Observed errors converge or remain within the diagnostic band'
  return true
 end
 function self:status() return {samples=#self.samples,capacity=32,axes=A.copy(self.axes),reason=self.diagnostic} end
 return self
end
return M
