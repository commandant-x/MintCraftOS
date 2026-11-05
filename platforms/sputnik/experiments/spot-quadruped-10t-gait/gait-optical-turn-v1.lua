-- Experimental simultaneous hip/knee pose; no push recovery or walking claim.
-- Motor 32 rpm, 2:1 local gearing. No foot contact or joint-angle feedback.
local now=getUniverseTime();local enable=input('Enable')
local ok,pitch,yaw,roll=pcall(getOrientation);local pok,x,y,z=pcall(getPosition)
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function diff(a,b)return (a-b+180)%360-180 end
local s=_G.MintFunctionalOpticalTurnV1;if not s then s={};_G.MintFunctionalOpticalTurnV1=s end
local on=finite(enable) and enable>.5
local pose=ok and finite(pitch) and finite(yaw) and finite(roll) and pok and finite(x) and finite(y) and finite(z) and finite(now)
if not on then s.basePitch=nil;s.baseRoll=nil;s.baseY=nil;s.lastX=nil;s.lastTime=nil;s.tripped=false;s.started=nil;s.emergency=false;s.armedAt=nil;s.gaitFault=nil;s.obstacleStop=nil;s.turnAt=nil;s.turnBaseYaw=nil;s.turnDone=nil
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
local sensorOK,obstacle=pcall(receiveWirelessRedstone,'minecraft:emerald_block','minecraft:gold_block')
if not sensorOK or not finite(obstacle) then obstacle=-1 end
-- Bench experiment: detect the wall, pause, then attempt a bounded differential turn.
-- It has no side sensors, contact feedback or wireless-disconnect detection.
if on and pose and s.armedAt and now-s.armedAt>=580 and not s.turnAt and obstacle>=6 then
 s.obstacleStop=true;s.turnAt=now;s.turnBaseYaw=yaw
end
local turning=on and pose and s.turnAt and not s.turnDone and now-s.turnAt>=30
local turnAngle=s.turnBaseYaw and diff(yaw,s.turnBaseYaw) or 0
if turning and (math.abs(turnAngle)>=25 or now-s.turnAt>=1200) then s.turnDone=true;turning=false end
if on and pose and not s.tripped and s.armedAt and now-s.armedAt>=600 then
 if math.max(math.abs(pe),math.abs(re))>12 or obstacle<0 then s.gaitFault=true end
 local forward=not s.obstacleStop and now-s.armedAt<1100
 if not s.gaitFault and (forward or turning) then
  local elapsed=math.floor(turning and (now-s.turnAt-30) or (now-s.armedAt-600));local cycle=math.floor(elapsed/12);local ph=elapsed%12
  local leg=({3,2,1,4})[cycle%4+1];local hip=(leg-1)*3+2;local knee=hip+1
  local initial=leg==1 or leg==4;local inverted=ph>=6;local direction=(initial~=inverted) and 15 or 0
  if turning and (leg==2 or leg==4) then direction=15-direction end
  rev[hip]=direction;rev[knee]=direction
  if (ph>=0 and ph<2) or (ph>=6 and ph<8) then gates[knee]=0 end
  if (ph>=3 and ph<5) or (ph>=9 and ph<11) then gates[hip]=0 end
 end
end
local selected=0
if on and pose and not s.tripped and s.started then local dt=math.floor(now-s.started);if (dt>=9999 and dt<10001) then gates[1]=0;gates[7]=0;selected=1 end end
local colors={'white_wool','orange_wool','magenta_wool','light_blue_wool','yellow_wool','lime_wool','pink_wool','gray_wool','light_gray_wool','cyan_wool','purple_wool','blue_wool'}
local names={'FL roll','FL hip','FL knee','FR roll','FR hip','FR knee','RL roll','RL hip','RL knee','RR roll','RR hip','RR knee'}
for i=1,12 do output(names[i]..' clutch',gates[i]);output(names[i]..' reverse',rev[i]);if type(transmitWirelessRedstone)=='function' then transmitWirelessRedstone('minecraft:'..colors[i],'minecraft:netherite_block',gates[i]);transmitWirelessRedstone('minecraft:'..colors[i],'minecraft:diamond_block',rev[i]) end end
output('Turn active',turning and 1 or 0);output('Turn angle',turnAngle);output('Turn done',s.turnDone and 1 or 0);output('Obstacle signal',obstacle);output('Obstacle stop',s.obstacleStop and 1 or 0);output('Gait fault',s.gaitFault and 1 or 0);output('Emergency',s.emergency and 1 or 0);output('Drop',drop);output('Correction axis',selected);output('Tilt guard',s.tripped and 1 or 0);output('Pitch error',pe);output('Roll error',re);output('Pose valid',pose and 1 or 0);output('Pitch rate',0);output('Roll rate',0);output('Projected pitch',pe);output('Projected roll',re)
