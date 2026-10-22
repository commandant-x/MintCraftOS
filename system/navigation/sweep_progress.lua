-- Read-only evidence of progress. Never advances a heat level or sets a deadline.
local A=require('system.libraries.addon')
local M={}
function M.new()
 local self={windows={},total=0}
 function self:observe(level)
  local tail=level.tail or {} local last=tail[#tail]
  if not last then return end
  local out={schema=1,scope='sweep-progress-diagnostic',clock='sweep_elapsed',signal=level.signal,observedAt=last.time,samples=#tail,
   stable=level.stableAltitude==true,completedWindows=self.total,noProgress=false}
  self.current=out
  local contiguous=true local turns=0 local previousSign
  local sum,peak=0,0
  for i,r in ipairs(tail) do
   if i>1 and r.time-tail[i-1].time>1.25 then contiguous=false end
   sum=sum+r.rate peak=math.max(peak,math.abs(r.rate))
   local sign=r.rate>.1 and 1 or r.rate<-.1 and -1 or nil
   if sign and previousSign and sign~=previousSign then turns=turns+1 end
   if sign then previousSign=sign end
  end
  out.peakSpeed=peak out.meanSpeed=A.finite(sum) and sum/#tail or nil out.heightSpread=A.finite(level.altitudeSpread) and level.altitudeSpread or nil
  out.speedSlope=A.finite(level.speedSlope) and level.speedSlope or nil out.signChanges=turns
  if not contiguous then self.windows={} self.lastEnd=nil end
  if #tail<8 or (level.windowSpan or 0)<3 or not contiguous then
   out.state='gathering' out.reason=contiguous and 'Need eight contiguous measured samples for stability' or 'Measurement gap; collecting contiguous stability evidence'
   return
  end
  local score=math.max(peak/.1,(level.altitudeSpread or 0)/.5)
  if not A.finite(score) or not A.finite(sum) then
   out.state='unavailable' out.reason='Progress arithmetic unavailable; stability still required' return
  end
  if not self.lastEnd or tail[1].time>self.lastEnd then
   self.total=self.total+1 self.windows[#self.windows+1]={score=score,at=last.time}
   if #self.windows>8 then table.remove(self.windows,1) end self.lastEnd=last.time
  end
  out.completedWindows=self.total out.comparedWindows=#self.windows
  if #self.windows==8 then
   local first=self.windows[1].score local best=math.huge
   for i=2,8 do best=math.min(best,self.windows[i].score) end
   out.firstScore=first out.bestLaterScore=best
   out.noProgress=score>1 and best>=first-math.max(.05,first*.1)
  end
  if out.stable then out.state='stable' out.reason='Measured height and vertical speed satisfy stability criteria'
  elseif turns>=2 then out.state='oscillating' out.reason='Repeated vertical direction changes above 0.1 m/s; not stable'
  elseif level.steadySpeed and math.abs(out.meanSpeed)>.1 then
   out.state='steady-motion' out.reason=out.meanSpeed>0 and 'Steady ascent is not a stable altitude' or 'Steady descent is not a stable altitude'
  elseif out.noProgress then out.state='no-progress' out.reason='No clear stability improvement across eight separate windows'
  else out.state='settling' out.reason='Vertical speed or height spread still exceeds stability criteria' end
  if out.noProgress and out.state~='no-progress' then out.reason=out.reason..'; no clear improvement across eight separate windows' end
  out.atMaximumHeat=level.signal==15
  if out.atMaximumHeat and not out.stable then out.reason=out.reason..'; maximum heat requested, lift authority not established' end
 end
 function self:status() return A.copy(self.current) end
 return self
end
return M
