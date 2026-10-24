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
-- Differential demand generator only: no actuator API calls, no lift output.
local s=_G.MintCraftDrive
if not s then
 s={label=ui.label('Demandes uniquement, jamais des signaux transmission'),lift=ui.label('4 sustentations independantes; pas de maintien qualifie')}
 _G.MintCraftDrive=s
end
addElement(s.label) addElement(s.lift)
local drive=input('Drive') local turn=input('Left turn') local mode=input('Blend mode')
local stop=input('Drive STOP')
if stop~=0 then drive,turn=0,0 end
local result,why=Mixer.differential(drive,turn,mode==1 and 'blend' or 'pivot')
local left,right=0,0
if result then left,right=result.left,result.right end
s.label.setText(result and ('Demande G '..string.format('%.2f',left)..' / D '..string.format('%.2f',right)..'; pas des signaux 0..15') or tostring(why))
output('Left signed demand',left)
output('Right signed demand',right)
output('Left reverse requested',left<0 and 1 or 0)
output('Right reverse requested',right<0 and 1 or 0)
output('Demands valid',result and 1 or 0)
local collective=input('Lift collective') local front=input('Front bias') local rightBias=input('Right bias')
local lift,issue=Mixer.quadLift(collective,front,rightBias)
s.lift.setText(lift and ('Moyenne '..string.format('%.2f',lift.collective)..' / corrections '..string.format('%.2f',lift.attitudeScale)..'; aucune preuve de poussee') or tostring(issue))
output('Front left lift demand',lift and lift.frontLeft or 0)
output('Front right lift demand',lift and lift.frontRight or 0)
output('Rear left lift demand',lift and lift.rearLeft or 0)
output('Rear right lift demand',lift and lift.rearRight or 0)
output('Lift demands valid',lift and 1 or 0)
output('Flight qualified',0)
