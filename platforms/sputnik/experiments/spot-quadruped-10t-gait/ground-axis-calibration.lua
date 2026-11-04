-- Bench only: standing response to isolated, reversible pulses. Not a balance controller.
local now=getUniverseTime()
local enable=input('Enable')
local ok,pitch,yaw,roll=pcall(getOrientation)
local posOK,x,y,z=pcall(getPosition)
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function diff(a,b)return (a-b+180)%360-180 end
local s=_G.MintSpotGroundAxisBench
if not s then s={};_G.MintSpotGroundAxisBench=s end
local on=finite(enable) and enable>0.5
local pose=ok and finite(pitch) and finite(yaw) and finite(roll) and finite(now) and posOK and finite(y)
if not on then s.start=nil;s.trip=false;s.lastTime=nil
elseif not pose then s.trip=true
elseif not s.start then s.start=now;s.basePitch=pitch;s.baseRoll=roll;s.baseY=y end
if on and s.lastTime and pose and (now<s.lastTime or now-s.lastTime>2) then s.trip=true end
if on and pose then s.lastTime=now end
local pe=pose and s.basePitch and diff(pitch,s.basePitch) or 0
local re=pose and s.baseRoll and diff(roll,s.baseRoll) or 0
local drop=pose and s.baseY and s.baseY-y or 0
-- Stop the calibration, not the recovery controller, if this bench risks toppling.
if math.abs(pe)>10 or math.abs(re)>10 or drop>1 then s.trip=true end
local gates={15,15,15,15,15,15,15,15,15,15,15,15}
local rev={0,0,0,0,0,0,0,0,0,0,0,0}
local selected=0
if on and pose and not s.trip then
 local elapsed=math.floor(now-s.start)-20
 if elapsed>=0 and elapsed<960 then
  local cycle=math.floor(elapsed/120);local phase=elapsed%120
  local leg=math.floor(cycle/2);local axis=cycle%2
  selected=leg*3+axis+1
  if phase>=50 and phase<100 then rev[selected]=15 end
  if (phase>=4 and phase<6) or (phase>=54 and phase<56) then gates[selected]=0 end
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
output('Correction axis',selected);output('Tilt guard',s.trip and 1 or 0);output('Pitch error',pe);output('Roll error',re);output('Pose valid',pose and 1 or 0);output('Emergency',0);output('Drop',drop)
