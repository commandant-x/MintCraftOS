-- Experimental motor 128 RPM, 2:1 local gearing => 64 RPM per selected joint.
-- A powered clutch disconnects its cog. No measured foot contact or joint angle.
local enabled=input('Enable')
local start=input('Start')
local now=type(getUniverseTime)=='function' and getUniverseTime() or nil
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function diff(a,b)return (a-b+180)%360-180 end
local on=finite(enabled) and enabled>0.5
local pressed=finite(start) and start>0.5
local timeOK=finite(now) and now>=0
local s=_G.MintSpotQuadrupedIndependent128
if not s then s={running=false,lastStart=false};_G.MintSpotQuadrupedIndependent128=s end
local ok,pitch,yaw,roll=pcall(getOrientation)
local poseOK=ok and finite(pitch) and finite(yaw) and finite(roll)
local clockFault=false
if not on then
 s.running=false;s.tripped=false;s.targetYaw=nil;s.basePitch=nil;s.baseRoll=nil
elseif not timeOK or not poseOK then s.running=false;s.tripped=true
elseif not s.targetYaw then s.targetYaw=yaw;s.basePitch=pitch;s.baseRoll=roll end
if on and s.running and s.lastTime and timeOK and (now<s.lastTime or now-s.lastTime>2) then s.running=false;clockFault=true end
if on and poseOK and s.targetYaw and (math.abs(diff(pitch,s.basePitch))>12 or math.abs(diff(roll,s.baseRoll))>12 or math.abs(diff(yaw,s.targetYaw))>25) then s.running=false;s.tripped=true end
if on and not s.tripped and not clockFault and timeOK and pressed and not s.lastStart and not s.running then s.running=true;s.started=now end
s.lastStart=pressed;s.lastTime=timeOK and now or nil
local gates={15,15,15,15,15,15,15,15,15,15,15,15}
local reverses={0,0,0,0,0,0,0,0,0,0,0,0}
local cycle,phase=-1,-1
if s.running then
 local elapsed=math.floor(now-s.started)
 if elapsed<0 or elapsed>=500 then s.running=false
 else
  cycle=math.floor(elapsed/12);phase=elapsed%12
  local order={3,2,1,4};local leg=order[cycle%4+1]
  local initial=leg==1 or leg==4
  local inverted=phase>=6 and phase<12
  local dir=(initial~=inverted) and 15 or 0
  local hip=(leg-1)*3+2;local knee=hip+1
  reverses[hip]=dir;reverses[knee]=dir
  if (phase>=1 and phase<3) or (phase>=7 and phase<9) then gates[knee]=0 elseif (phase>=4 and phase<6) or (phase>=10 and phase<12) then gates[hip]=0 end
 end
end
local colors={'white_wool','orange_wool','magenta_wool','light_blue_wool','yellow_wool','lime_wool','pink_wool','gray_wool','light_gray_wool','cyan_wool','purple_wool','blue_wool'}
local names={'FL roll','FL hip','FL knee','FR roll','FR hip','FR knee','RL roll','RL hip','RL knee','RR roll','RR hip','RR knee'}
for i=1,12 do
 output(names[i]..' clutch',gates[i]);output(names[i]..' reverse',reverses[i])
 if type(transmitWirelessRedstone)=='function' then
  transmitWirelessRedstone('minecraft:'..colors[i],'minecraft:netherite_block',gates[i])
  transmitWirelessRedstone('minecraft:'..colors[i],'minecraft:diamond_block',reverses[i])
 end
end
output('Running',s.running and 1 or 0);output('Cycle',cycle);output('Phase',phase)
output('Clock fault',clockFault and 1 or 0);output('Tilt guard',s.tripped and 1 or 0);output('Pose valid',poseOK and 1 or 0)
output('Yaw error',(poseOK and s.targetYaw) and diff(yaw,s.targetYaw) or 0)
local posOK,x,y,z=pcall(getPosition)
output('Probe x',posOK and finite(x) and x or -9999);output('Probe y',posOK and finite(y) and y or -9999);output('Probe z',posOK and finite(z) and z or -9999)
output('Probe pitch',poseOK and pitch or -9999);output('Probe yaw',poseOK and yaw or -9999);output('Probe roll',poseOK and roll or -9999)
