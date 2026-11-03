-- Experimental yaw correction and tilt guard; no foot contact or actuator position feedback.
-- A powered clutch is disengaged. Values 15/0 represent redstone strengths.
local enabled=input('Enable')
local start=input('Start')
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
local poseValid=ok and finite(pitch) and finite(yaw) and finite(roll)
local function diff(a,b) return (a-b+180)%360-180 end
if not on then s.targetYaw=nil;s.basePitch=nil;s.baseRoll=nil;s.tripped=false
elseif not poseValid then s.running=false;s.tripped=true
elseif not s.targetYaw then s.targetYaw=yaw;s.basePitch=pitch;s.baseRoll=roll end
if on and poseValid and s.targetYaw then
 if math.abs(diff(pitch,s.basePitch))>12 or math.abs(diff(roll,s.baseRoll))>12 then s.tripped=true end
end
if s.tripped then s.running=false end
-- Stop and latch if the static terrain sensor is invalid, stale or reports a block.
-- This cannot detect dynamic bodies and does not stop the creative motor itself.
local terrainValid=input('Terrain valid')
local terrainObstacle=input('Terrain obstacle')
local terrainTick=input('Terrain sample tick')
local fresh=finite(terrainValid) and terrainValid>0.5 and finite(terrainObstacle) and finite(terrainTick) and valid and now>=terrainTick and now-terrainTick<=10
if not on then s.terrainStopped=false;s.terrainReason='disarmed'
elseif not fresh then s.terrainStopped=true;s.terrainReason='unknown or stale'
elseif terrainObstacle>0.5 then s.terrainStopped=true;s.terrainReason='obstacle'
end
if s.terrainStopped then s.running=false end
output('Terrain stop',s.terrainStopped and 1 or 0)
output('Terrain fresh',fresh and 1 or 0)
output('Terrain reason',s.terrainReason or 'clear')
local yawError=(poseValid and s.targetYaw) and diff(yaw,s.targetYaw) or 0
if s.running then
 local elapsed=math.floor((now-s.started)*2)
 if elapsed<0 or elapsed>=960 then s.running=false
 else
  cycle=math.floor(elapsed/120);phase=elapsed%120
  local order={3,2,1,4} -- RL, FR, FL, RR
  local leg=order[cycle%4+1]
  local initialReverse=leg==1 or leg==4
  local invert=initialReverse
  if phase>=46 and phase<92 then invert=not initialReverse elseif phase>=92 then invert=false end
  reverse=invert and 15 or 0
  local knee=(phase>=10 and phase<20) or (phase>=56 and phase<66)
  -- Capture the correction once per leg so its forward and reverse pulses match.
  if s.pulseEpoch~=s.started or s.pulseCycle~=cycle then
   s.pulseEpoch=s.started;s.pulseCycle=cycle
   local steer=yawError>2 and 1 or (yawError< -2 and -1 or 0)
   s.hipTicks=leg==3 and (steer>0 and 16 or (steer<0 and 10 or 14))
       or (leg==1 and (steer>0 and 2 or (steer<0 and 6 or 4)) or 6)
  end
  local hipTicks=s.hipTicks
  local hip=(phase>=30 and phase<30+hipTicks) or (phase>=76 and phase<76+hipTicks)
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
output('Tilt guard',s.tripped and 1 or 0)
output('Pose valid',poseValid and 1 or 0)

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
