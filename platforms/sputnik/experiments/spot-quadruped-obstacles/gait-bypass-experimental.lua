-- Experimental yaw correction and tilt guard; no foot contact or actuator position feedback.
-- A powered clutch is disengaged. Values 15/0 represent redstone strengths.
-- EXPLORATORY bypass: stops on invalid/stale sensor data or within six blocks.
-- This offset is specific to the test course; no guarantee of clearance.
local enabled=input('Enable')
local start=input('Start')
local terrainValid=input('Terrain valid')
local terrainObstacle=input('Terrain obstacle')
local terrainSample=input('Terrain sample tick')
local terrainDistance=input('Terrain distance')
local terrainLateral=input('Terrain lateral')
local now=type(getUniverseTime)=='function' and getUniverseTime() or nil
local valid=type(now)=='number' and now==now and now>=0 and now<math.huge
local s=_G.MintSpotQuadrupedGait
if not s then s={running=false,lastStart=false,lastTime=nil};_G.MintSpotQuadrupedGait=s end
local on=type(enabled)=='number' and enabled>0.5
local pressed=type(start)=='number' and start>0.5
local fault=0
if not on or not valid then s.running=false end
if on and valid and s.running and s.lastTime and (now<s.lastTime or now-s.lastTime>2) then s.running=false;fault=1 end
if on and valid and fault==0 and pressed and not s.lastStart and not s.running then s.running=true;s.started=now end
s.lastStart=pressed
s.lastTime=valid and now or nil
local gates={15,15,15,15,15,15,15,15,15,15,15,15}
local reverse,cycle,phase=0,-1,-1
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
local ok,pitch,yaw,roll=pcall(getOrientation)
local posOK,posX,posY,posZ=pcall(getPosition)
local poseValid=ok and finite(pitch) and finite(yaw) and finite(roll) and posOK and finite(posX) and finite(posY) and finite(posZ)
local function diff(a,b) return (a-b+180)%360-180 end
if not on then s.targetYaw=nil;s.targetX=nil;s.basePitch=nil;s.baseRoll=nil;s.tripped=false;s.bypass=false;s.terrainStopped=false
elseif not poseValid then s.running=false;s.tripped=true
elseif not s.targetYaw then s.targetYaw=yaw;s.targetX=posX;s.basePitch=pitch;s.baseRoll=roll end
if on and poseValid and s.targetYaw then
 if math.abs(diff(pitch,s.basePitch))>12 or math.abs(diff(roll,s.baseRoll))>12 then s.tripped=true end
end
if s.tripped then s.running=false end
if on then
 local fresh=finite(terrainSample) and valid and now>=terrainSample and now-terrainSample<=10
 if not fresh or not finite(terrainValid) or terrainValid<0.5 or not finite(terrainObstacle) then s.terrainStopped=true end
 if terrainObstacle and terrainObstacle>0.5 then
  if not finite(terrainDistance) or not finite(terrainLateral) or terrainDistance<=6 then s.terrainStopped=true
  elseif not s.bypass and poseValid and s.targetX then
   s.targetX=s.targetX+(terrainLateral<=0 and 16 or -16);s.bypass=true
  end
 end
 if s.terrainStopped then s.running=false end
end
local yawError=(poseValid and s.targetYaw) and diff(yaw,s.targetYaw) or 0
local laneError=(poseValid and s.targetX) and (posX-s.targetX) or 0
local steeringError=yawError+math.max(-8,math.min(8,laneError*1.5))
if s.running then
 local elapsed=math.floor((now-s.started)*4)
 if elapsed<0 or elapsed>=960 then s.running=false
 else
  cycle=math.floor(elapsed/120);phase=elapsed%120
  local order={3,2,1,4} -- RL, FR, FL, RR
  local leg=order[cycle%4+1]
  local initialReverse=leg==1 or leg==4
  local invert=initialReverse
  if phase>=44 and phase<92 then invert=not initialReverse elseif phase>=92 then invert=false end
  reverse=invert and 15 or 0
  local knee=(phase>=8 and phase<20) or (phase>=56 and phase<68)
  -- Capture the correction once per leg so its forward and reverse pulses match.
  if s.pulseEpoch~=s.started or s.pulseCycle~=cycle then
   s.pulseEpoch=s.started;s.pulseCycle=cycle
   local steer=steeringError>2 and 1 or (steeringError< -2 and -1 or 0)
   s.hipStart=(leg==3 and steer>0) and 24 or 28
   s.hipTicks=leg==3 and (steer>0 and 20 or (steer<0 and 12 or 16))
       or (leg==1 and (steer<0 and 8 or 4) or (leg==2 and (steer>0 and 4 or 8) or 8))
  end
  local hipTicks=s.hipTicks
  local hip=(phase>=s.hipStart and phase<s.hipStart+hipTicks) or (phase>=s.hipStart+48 and phase<s.hipStart+48+hipTicks)
  if knee then gates[(leg-1)*3+3]=0 elseif hip then gates[(leg-1)*3+2]=0 end
 end
end
output('FL roll clutch',gates[1]);output('FL hip clutch',gates[2]);output('FL knee clutch',gates[3])
output('FR roll clutch',gates[4]);output('FR hip clutch',gates[5]);output('FR knee clutch',gates[6])
output('RL roll clutch',gates[7]);output('RL hip clutch',gates[8]);output('RL knee clutch',gates[9])
output('RR roll clutch',gates[10]);output('RR hip clutch',gates[11]);output('RR knee clutch',gates[12])
output('Common reverse',reverse)
output('Running',s.running and 1 or 0)
output('Cycle',cycle)
output('Clock fault',fault)
output('Yaw error',yawError)
output('Lane error',laneError)
output('Steering error',steeringError)
output('Tilt guard',s.tripped and 1 or 0)
output('Pose valid',poseValid and 1 or 0)
output('Terrain stop',s.terrainStopped and 1 or 0)
output('Bypass active',s.bypass and 1 or 0)
output('Bypass target x',s.targetX or 0)

-- Test bridge: explicit frequencies for this experimental vehicle.
if type(transmitWirelessRedstone)=='function' then
 transmitWirelessRedstone('minecraft:white_wool','minecraft:netherite_block',gates[1])
 transmitWirelessRedstone('minecraft:orange_wool','minecraft:netherite_block',gates[2])
 transmitWirelessRedstone('minecraft:magenta_wool','minecraft:netherite_block',gates[3])
 transmitWirelessRedstone('minecraft:light_blue_wool','minecraft:netherite_block',gates[4])
 transmitWirelessRedstone('minecraft:yellow_wool','minecraft:netherite_block',gates[5])
 transmitWirelessRedstone('minecraft:lime_wool','minecraft:netherite_block',gates[6])
 transmitWirelessRedstone('minecraft:pink_wool','minecraft:netherite_block',gates[7])
 transmitWirelessRedstone('minecraft:gray_wool','minecraft:netherite_block',gates[8])
 transmitWirelessRedstone('minecraft:light_gray_wool','minecraft:netherite_block',gates[9])
 transmitWirelessRedstone('minecraft:cyan_wool','minecraft:netherite_block',gates[10])
 transmitWirelessRedstone('minecraft:purple_wool','minecraft:netherite_block',gates[11])
 transmitWirelessRedstone('minecraft:blue_wool','minecraft:netherite_block',gates[12])
 transmitWirelessRedstone('minecraft:brown_wool','minecraft:netherite_block',reverse)
end

-- Audit telemetry returned by Sputnik; no correction yet.
local ok,pitch,yaw,roll=pcall(getOrientation)
local okp,x,y,z=pcall(getPosition)
output('Probe pitch',ok and type(pitch)=='number' and pitch or -9999)
output('Probe yaw',ok and type(yaw)=='number' and yaw or -9999)
output('Probe roll',ok and type(roll)=='number' and roll or -9999)
output('Probe x',okp and type(x)=='number' and x or -9999)
output('Probe y',okp and type(y)=='number' and y or -9999)
output('Probe z',okp and type(z)=='number' and z or -9999)
