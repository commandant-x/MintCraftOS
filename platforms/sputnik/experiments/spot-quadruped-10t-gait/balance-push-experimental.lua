-- Experimental corrective pulses. One motor 128 rpm, 2:1 gearing, no contact or joint feedback.
-- The sign is uncalibrated: compare against a no-control trial before using.
local now=getUniverseTime()
local enable=input('Enable')
local ok,pitch,yaw,roll=pcall(getOrientation)
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function diff(a,b)return (a-b+180)%360-180 end
local s=_G.MintSpotBalancePush
if not s then s={};_G.MintSpotBalancePush=s end
local on=finite(enable) and enable>0.5
local pose=ok and finite(pitch) and finite(yaw) and finite(roll) and finite(now)
if not on then s.basePitch=nil;s.baseRoll=nil;s.tripped=false;s.cycle=nil
elseif not pose then s.tripped=true
elseif not s.basePitch then s.basePitch=pitch;s.baseRoll=roll end
local pe=pose and s.basePitch and diff(pitch,s.basePitch) or 0
local re=pose and s.baseRoll and diff(roll,s.baseRoll) or 0
if on and pose and (math.abs(pe)>12 or math.abs(re)>12) then s.tripped=true end
local gates={15,15,15,15,15,15,15,15,15,15,15,15}
local rev={0,0,0,0,0,0,0,0,0,0,0,0}
local selected=0
if on and pose and not s.tripped then
 local cycle=math.floor(now/20);local phase=math.floor(now)%20
 if s.cycle~=cycle then
  s.cycle=cycle;s.axis=0;s.direction=0
  if math.max(math.abs(pe),math.abs(re))>0.7 then
   local leg=({1,4,2,3})[cycle%4+1]
   local isRoll=math.abs(re)>=math.abs(pe)
   s.axis=(leg-1)*3+(isRoll and 1 or 2)
   local error=isRoll and re or pe
   s.direction=error>0 and 15 or 0
  end
 end
 if s.axis and s.axis>0 then
  selected=s.axis;rev[selected]=s.direction
  if phase>=4 and phase<6 then gates[selected]=0 end
 end
end
local colors={'white_wool','orange_wool','magenta_wool','light_blue_wool','yellow_wool','lime_wool','pink_wool','gray_wool','light_gray_wool','cyan_wool','purple_wool','blue_wool'}
local names={'FL roll','FL hip','FL knee','FR roll','FR hip','FR knee','RL roll','RL hip','RL knee','RR roll','RR hip','RR knee'}
for i=1,12 do
 output(names[i]..' clutch',gates[i]);output(names[i]..' reverse',rev[i])
 if type(transmitWirelessRedstone)=='function' then
  transmitWirelessRedstone('minecraft:'..colors[i],'minecraft:netherite_block',gates[i])
  transmitWirelessRedstone('minecraft:'..colors[i],'minecraft:diamond_block',rev[i])
 end
end
output('Correction axis',selected);output('Tilt guard',s.tripped and 1 or 0);output('Pitch error',pe);output('Roll error',re);output('Pose valid',pose and 1 or 0)
