-- Isolated x- push experiment. Two left legs extend west once; no claim of general recovery.
-- Motor 32 rpm, 2:1 local gearing. No foot contact or joint-angle feedback.
local now=getUniverseTime();local enable=input('Enable')
local ok,pitch,yaw,roll=pcall(getOrientation);local pok,x,y,z=pcall(getPosition)
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function diff(a,b)return (a-b+180)%360-180 end
local s=_G.MintSpotCrouchPushControl;if not s then s={};_G.MintSpotCrouchPushControl=s end
local on=finite(enable) and enable>.5
local pose=ok and finite(pitch) and finite(yaw) and finite(roll) and pok and finite(x) and finite(y) and finite(z) and finite(now)
if not on then s.basePitch=nil;s.baseRoll=nil;s.baseY=nil;s.lastX=nil;s.lastTime=nil;s.tripped=false;s.started=nil;s.emergency=false;s.armedAt=nil;s.referenceAdjusted=false
elseif not pose then s.tripped=true
elseif not s.basePitch then s.basePitch=pitch;s.baseRoll=roll;s.baseY=y;s.armedAt=now end
if on and pose and s.armedAt and not s.referenceAdjusted and now-s.armedAt>=500 then
 s.basePitch=pitch;s.baseRoll=roll;s.baseY=y;s.emergency=false;s.referenceAdjusted=true
end
local pe=pose and s.basePitch and diff(pitch,s.basePitch) or 0;local re=pose and s.baseRoll and diff(roll,s.baseRoll) or 0;local drop=pose and s.baseY and s.baseY-y or 0
if on and pose and s.lastTime and (now<s.lastTime or now-s.lastTime>2) then s.tripped=true end
local vx=0
if on and pose and s.lastTime and now>s.lastTime and s.lastX then vx=(x-s.lastX)/(now-s.lastTime) end
if on and pose then s.lastTime=now;s.lastX=x end
if on and pose and (math.max(math.abs(pe),math.abs(re))>10 or drop>2) then s.emergency=true end
if on and pose and s.emergency and math.max(math.abs(pe),math.abs(re))<3 and drop<1 then s.emergency=false end
if on and pose and not s.tripped and not s.started and s.armedAt and now-s.armedAt>=500 and vx<-.15 then s.started=now end
local gates={15,15,15,15,15,15,15,15,15,15,15,15};local rev={0,15,15,0,0,0,15,15,15,15,0,0}
if on and pose and not s.tripped and s.armedAt then
 local warm=math.floor(now-s.armedAt)
 if warm>=4 and warm<6 then gates[1]=0;gates[7]=0 end
 if warm>=24 and warm<26 then gates[4]=0;gates[10]=0 end
 if (warm>=44 and warm<46) or (warm>=54 and warm<56) or (warm>=64 and warm<66) then gates[2]=0;gates[5]=0 end
 if (warm>=74 and warm<76) or (warm>=84 and warm<86) or (warm>=94 and warm<96) then gates[8]=0;gates[11]=0 end
 if warm>=120 and warm<180 then
  local ph=warm-120
  if ph>=4 and ph<30 and ((ph-4)%8)<2 then for _,axis in ipairs({3,6,9,12}) do gates[axis]=0 end end
 end
 if warm>=480 then rev[3]=0;rev[6]=15;rev[9]=0;rev[12]=15 end
 if warm>=65 then rev[1]=15;rev[7]=0 end
end
local selected=0
if on and pose and not s.tripped and s.started then local dt=math.floor(now-s.started);if (dt>=9999 and dt<10001) then for _,axis in ipairs({3,6,9,12}) do gates[axis]=0 end;selected=3 end end
local colors={'white_wool','orange_wool','magenta_wool','light_blue_wool','yellow_wool','lime_wool','pink_wool','gray_wool','light_gray_wool','cyan_wool','purple_wool','blue_wool'}
local names={'FL roll','FL hip','FL knee','FR roll','FR hip','FR knee','RL roll','RL hip','RL knee','RR roll','RR hip','RR knee'}
for i=1,12 do output(names[i]..' clutch',gates[i]);output(names[i]..' reverse',rev[i]);if type(transmitWirelessRedstone)=='function' then transmitWirelessRedstone('minecraft:'..colors[i],'minecraft:netherite_block',gates[i]);transmitWirelessRedstone('minecraft:'..colors[i],'minecraft:diamond_block',rev[i]) end end
output('Emergency',s.emergency and 1 or 0);output('Drop',drop);output('Correction axis',selected);output('Tilt guard',s.tripped and 1 or 0);output('Pitch error',pe);output('Roll error',re);output('Pose valid',pose and 1 or 0);output('Pitch rate',0);output('Roll rate',0);output('Projected pitch',pe);output('Projected roll',re)
