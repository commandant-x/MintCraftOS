local Mixer=(function()
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
-- Body axes: forward and left are normalized acceleration intentions, not m/s.
-- Conversion to pitch/roll is only enabled after measured tilt authority.
function M.quadIntent(forward,left,maxTilt,qualified)
 if not finite(forward) or not finite(left) or math.abs(forward)>1 or math.abs(left)>1 or
  not finite(maxTilt) or maxTilt<=0 or maxTilt>30 then return nil,'Invalid body movement/tilt envelope' end
 if qualified~=true then return nil,'Measured roll/pitch and horizontal response required' end
 local scale=math.max(1,math.sqrt(forward*forward+left*left))
 return {forwardTilt=forward/scale*maxTilt,leftTilt=left/scale*maxTilt,
  yawAvailable=false,physicalFeedback=false}
end
function M.balloon(drive,turn,lift)
 if not finite(drive) or not finite(turn) or math.abs(drive)>1 or math.abs(turn)>1 or
  not finite(lift) or lift<0 or lift>1 then return nil,'Invalid balloon demand' end
 return {drive=drive,reverseRequested=drive<0,steerLeft=math.max(0,turn),
  steerRight=math.max(0,-turn),lift=lift,physicalFeedback=false}
end
return M

end)()
-- Profile demand router only. No transmission/gearshift/spring/Link actuation.
local s=_G.MintCraftVehicle
if not s then s={label=ui.label('Profils: 1 ballon, 2 quad; demandes uniquement')} _G.MintCraftVehicle=s end
addElement(s.label)
local profile=input('Profile')
local drive=input('Forward demand') local turn=input('Left demand')
local lift=input('Collective demand')
local front=input('Front correction') local right=input('Right correction')
local tiltLimit=input('Measured tilt limit deg')
local tiltQualified=input('Tilt response qualified')
local stop=input('Horizontal STOP')
if stop~=0 then drive,turn=0,0 end
local balloon,quad,intent,issue
if profile==1 then balloon,issue=Mixer.balloon(drive,turn,lift)
elseif profile==2 then
 -- STOP requests a level attitude; it does not prove braking/position hold.
 if stop~=0 then front,right=0,0 end
 quad,issue=Mixer.quadLift(lift,front,right)
 if quad and (drive~=0 or turn~=0) then
  intent,issue=Mixer.quadIntent(drive,turn,tiltLimit,tiltQualified==1)
 end
else issue='Choisir profil 1 ballon ou 2 quad' end
local valid=(balloon or quad) and not issue
s.label.setText(issue or (profile==1 and 'Ballon: 5 frequences; demandes sans actionnement' or 'Quad: 4 sustentations; inclinaison via boucle attitude requise'))
output('Profile valid',valid and 1 or 0)
output('Single drive demand',valid and balloon and balloon.drive or 0)
output('Reverse requested',valid and balloon and balloon.reverseRequested and 1 or 0)
output('Spring left demand',valid and balloon and balloon.steerLeft or 0)
output('Spring right demand',valid and balloon and balloon.steerRight or 0)
-- Lift validity is separate: an unavailable horizontal axis never cuts lift.
output('Lift valid',(balloon or quad) and 1 or 0)
output('Single lift demand',balloon and balloon.lift or 0)
output('Front left demand',quad and quad.frontLeft or 0)
output('Front right demand',quad and quad.frontRight or 0)
output('Rear left demand',quad and quad.rearLeft or 0)
output('Rear right demand',quad and quad.rearRight or 0)
output('Forward tilt target deg',intent and intent.forwardTilt or 0)
output('Left tilt target deg',intent and intent.leftTilt or 0)
output('Tilt target valid',valid and quad and tiltQualified==1 and 1 or 0)
output('Yaw available',0)
output('Flight qualified',0)
