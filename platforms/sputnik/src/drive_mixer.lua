-- Pure demand mixing. Never writes a Link, changes an inverter or claims flight readiness.
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
function M.differential(drive,leftTurn,mode)
 if not finite(drive) or not finite(leftTurn) or math.abs(drive)>1 or math.abs(leftTurn)>1 then return nil,'Drive/Left turn must be in [-1,1]' end
 mode=mode or 'pivot'
 if mode~='pivot' and mode~='blend' then return nil,'Unknown differential mixing mode' end
 local left,right
 if mode=='blend' or drive==0 then
  left,right=drive-leftTurn,drive+leftTurn
  local scale=math.max(1,math.abs(left),math.abs(right)) left,right=left/scale,right/scale
 else
  -- Pivot while moving: throttle outer bank, reduce inner bank to zero at full turn.
  -- Direction of turn is a body yaw request, also while reversing.
  local direction=drive>0 and 1 or -1
  local outer=math.max(math.abs(drive),math.abs(leftTurn))
  local inner=outer*(1-math.abs(leftTurn))
  if leftTurn*direction>=0 then left,right=direction*inner,direction*outer
  else left,right=direction*outer,direction*inner end
 end
 return {left=left,right=right,mode=mode,normalized=true,physicalFeedback=false}
end
function M.transmission(rpm,points)
 -- Map a signed bank demand to measured RPM separately. This helper only picks
 -- a measured nonnegative RPM level; it never invents a 0..15 transfer curve.
 if not finite(rpm) or rpm<0 or type(points)~='table' or #points<2 or #points>16 or getmetatable(points) then return nil,'Measured transmission RPM levels required' end
 local minimum,maximum=math.huge,-math.huge local seen={} local best,error
 local count=0
 for index,p in pairs(points) do
  count=count+1
  if type(index)~='number' or index%1~=0 or index<1 or index>#points or type(p)~='table' or
   not finite(p.signal) or p.signal%1~=0 or p.signal<0 or p.signal>15 or seen[p.signal] or not finite(p.rpm) or p.rpm<0 then return nil,'Invalid measured RPM table' end
  seen[p.signal]=true minimum=math.min(minimum,p.rpm) maximum=math.max(maximum,p.rpm)
  local e=math.abs(p.rpm-rpm)
  if not error or e<error or e==error and p.rpm<best.rpm then best,error=p,e end
 end
 if count~=#points or rpm<minimum or rpm>maximum then return nil,'Requested RPM outside actual measured transmission range' end
 return {signal=best.signal,rpm=best.rpm,requestedRPM=rpm,errorRPM=error,measuredLevel=true,physicalFeedback=false}
end
function M.quadLift(collective,frontBias,rightBias)
 if not finite(collective) or collective<0 or collective>1 or not finite(frontBias) or not finite(rightBias) or math.abs(frontBias)>1 or math.abs(rightBias)>1 then return nil,'Normalized collective/bias demand outside supported range' end
 -- Equal nominal geometry only. These are abstract demands, NOT thrust proofs,
 -- RPM values or redstone levels. Unequal motors require measured allocation.
 local delta={frontBias-rightBias,frontBias+rightBias,-frontBias-rightBias,-frontBias+rightBias}
 local scale=1
 for _,v in ipairs(delta) do
  if v>0 then scale=math.min(scale,(1-collective)/v)
  elseif v<0 then scale=math.min(scale,collective/(-v)) end
 end
 local names={'frontLeft','frontRight','rearLeft','rearRight'}
 local out={collective=collective,attitudeScale=scale,normalized=true,physicalFeedback=false}
 for i,name in ipairs(names) do out[name]=collective+scale*delta[i] end
 return out
end
return M
