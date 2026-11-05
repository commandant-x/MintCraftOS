-- Experimental calibrated roll-pulse response; not a proven recovery.
-- Motor 32 rpm, 2:1 local gearing. No foot contact or joint-angle feedback.
local now=getUniverseTime();local enable=input('Enable')
local ok,pitch,yaw,roll=pcall(getOrientation);local pok,x,y,z=pcall(getPosition)
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function diff(a,b)return (a-b+180)%360-180 end
local s=_G.MintFunctionalRollRecoveryV1;if not s then s={};_G.MintFunctionalRollRecoveryV1=s end
local on=finite(enable) and enable>.5
local pose=ok and finite(pitch) and finite(yaw) and finite(roll) and pok and finite(x) and finite(y) and finite(z) and finite(now)
if not on then s.basePitch=nil;s.baseRoll=nil;s.baseY=nil;s.lastX=nil;s.lastTime=nil;s.tripped=false;s.started=nil;s.emergency=false;s.armedAt=nil;s.rollCount=0;s.rollStart=nil;s.rollNext=nil
elseif not pose then s.tripped=true
elseif not s.basePitch then s.basePitch=pitch;s.baseRoll=roll;s.baseY=y;s.armedAt=now end
local pe=pose and s.basePitch and diff(pitch,s.basePitch) or 0;local re=pose and s.baseRoll and diff(roll,s.baseRoll) or 0;local drop=pose and s.baseY and s.baseY-y or 0
if on and pose and s.lastTime and (now<s.lastTime or now-s.lastTime>2) then s.tripped=true end
local vx=0
if on and pose and s.lastTime and now>s.lastTime and s.lastX then vx=(x-s.lastX)/(now-s.lastTime) end
if on and pose then s.lastTime=now;s.lastX=x end
if on and pose and (math.max(math.abs(pe),math.abs(re))>10 or drop>2) then s.emergency=true end
if on and pose and s.emergency and math.max(math.abs(pe),math.abs(re))<3 and drop<1 then s.emergency=false end
if on and pose and not s.tripped and not s.started and s.armedAt and now-s.armedAt>=80 and vx<-.10 then s.started=now end
local gates={15,15,15,15,15,15,15,15,15,15,15,15};local rev={0,15,15,0,0,0,15,15,15,15,0,0}
if on and pose and not s.tripped and s.armedAt then
 local warm=math.floor(now-s.armedAt)
 -- Keep lateral axes neutral. Counter-rotate hip and knee to keep feet beneath the body.
 if warm<120 then rev[2]=0;rev[5]=15;rev[8]=0;rev[11]=15 end
 -- Synchronize two hip pulses with the first two of four knee pulses.
 if (warm>=44 and warm<46) or (warm>=54 and warm<56) then
  for _,axis in ipairs({2,5,8,11}) do gates[axis]=0 end
 end
 if (warm>=44 and warm<46) or (warm>=54 and warm<56) or (warm>=64 and warm<66) or (warm>=74 and warm<76) then
  for _,axis in ipairs({3,6,9,12}) do gates[axis]=0 end
 end
 if warm>=580 then rev[3]=0;rev[6]=15;rev[9]=0;rev[12]=15 end
 if false and warm>=600 and warm<640 then
  local ph=warm-600
  if (ph>=4 and ph<6) or (ph>=12 and ph<14) then for _,axis in ipairs({3,6,9,12}) do gates[axis]=0 end end
 end

end
local selected=0
-- Bench experiment from local grounded-axis calibration, not a proven recovery.
-- Bound the total pulses because real joint angles and contacts are not measured.
if on and pose and not s.tripped and s.armedAt and now-s.armedAt>=500 then
 if math.abs(re)<3 then s.rollCount=0;s.rollStart=nil;s.rollNext=nil end
 if math.abs(re)>6 and (s.rollCount or 0)<4 and (not s.rollNext or now>=s.rollNext) then
  s.rollCount=(s.rollCount or 0)+1;s.rollStart=now;s.rollNext=now+12
 end
 if s.rollStart and now-s.rollStart<2 then
  if re>0 then rev[1]=0;rev[4]=0;rev[7]=15;rev[10]=0 else rev[1]=15;rev[4]=15;rev[7]=0;rev[10]=15 end
  for _,i in ipairs({1,4,7,10}) do gates[i]=0 end;selected=1
 end
end
local colors={'white_wool','orange_wool','magenta_wool','light_blue_wool','yellow_wool','lime_wool','pink_wool','gray_wool','light_gray_wool','cyan_wool','purple_wool','blue_wool'}
local names={'FL roll','FL hip','FL knee','FR roll','FR hip','FR knee','RL roll','RL hip','RL knee','RR roll','RR hip','RR knee'}
for i=1,12 do output(names[i]..' clutch',gates[i]);output(names[i]..' reverse',rev[i]);if type(transmitWirelessRedstone)=='function' then transmitWirelessRedstone('minecraft:'..colors[i],'minecraft:netherite_block',gates[i]);transmitWirelessRedstone('minecraft:'..colors[i],'minecraft:diamond_block',rev[i]) end end
output('Emergency',s.emergency and 1 or 0);output('Drop',drop);output('Correction axis',selected);output('Tilt guard',s.tripped and 1 or 0);output('Pitch error',pe);output('Roll error',re);output('Pose valid',pose and 1 or 0);output('Pitch rate',0);output('Roll rate',0);output('Projected pitch',pe);output('Projected roll',re)
