-- Experimental local response map from ground-axis-calibration-16rpm, motor 32 -> axis 16 rpm.
-- Near-upright body-angle response 10 ticks after a two-tick gate pulse, with no push.
-- No foot-contact, joint-position, force or velocity feedback; not a validated recovery controller.
local now=getUniverseTime()
local enable=input('Enable')
local ok,pitch,yaw,roll=pcall(getOrientation)
local posOK,x,y,z=pcall(getPosition)
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function diff(a,b)return (a-b+180)%360-180 end
local s=_G.MintSpotPredictiveRecovery
if not s then s={};_G.MintSpotPredictiveRecovery=s end
local on=finite(enable) and enable>0.5
local pose=ok and finite(pitch) and finite(yaw) and finite(roll) and finite(now) and posOK and finite(y)
if not on then s.basePitch=nil;s.baseRoll=nil;s.baseY=nil;s.tripped=false;s.cycle=nil;s.emergency=false;s.lastTime=nil;s.lastPe=nil;s.lastRe=nil;s.ratePe=0;s.rateRe=0
elseif not pose then s.tripped=true
elseif not s.basePitch then s.basePitch=pitch;s.baseRoll=roll;s.baseY=y end
local pe=pose and s.basePitch and diff(pitch,s.basePitch) or 0
local re=pose and s.baseRoll and diff(roll,s.baseRoll) or 0
local drop=pose and s.baseY and s.baseY-y or 0
if on and s.lastTime and pose and (now<s.lastTime or now-s.lastTime>2) then s.tripped=true end
if on and pose then
 if s.lastTime and now>s.lastTime and s.lastPe and s.lastRe then
  local dt=now-s.lastTime
  local vp=diff(pe,s.lastPe)/dt;local vr=diff(re,s.lastRe)/dt
  s.ratePe=.65*(s.ratePe or 0)+.35*math.max(-5,math.min(5,vp))
  s.rateRe=.65*(s.rateRe or 0)+.35*math.max(-5,math.min(5,vr))
 end
 s.lastTime=now;s.lastPe=pe;s.lastRe=re
end
local projectedPe=pe+4*(s.ratePe or 0)
local projectedRe=re+4*(s.rateRe or 0)
if on and pose and (math.max(math.abs(pe),math.abs(re))>10 or drop>2) then s.emergency=true end
if on and pose and s.emergency and math.max(math.abs(pe),math.abs(re))<3 and drop<1 then s.emergency=false end
local gates={15,15,15,15,15,15,15,15,15,15,15,15}
local rev={0,0,0,0,0,0,0,0,0,0,0,0}
local selected=0
local responses={
 {1,0, .24,-.25},{1,15,-.10,.26},{2,0,-.42,.36},{2,15,.04,-.14},
 {4,0,-.97,-.45},{4,15,1.24,.49},{5,0,.11,.07},{5,15,-.03,.02},
 {7,0,.80,.64},{7,15,-1.32,-1.23},{8,0,.10,.08},{8,15,0,-.05},
 {10,0,-.56,.27},{10,15,.24,-.41},{11,0,.04,-.05},{11,15,-.08,.09}
}
if on and pose and not s.tripped then
 local cycle=math.floor(now/20);local phase=math.floor(now)%20
 if s.cycle~=cycle then
  s.cycle=cycle;s.axis=0;s.direction=0
  if math.max(math.abs(projectedPe),math.abs(projectedRe))>.7 then
   local best=0
   for _,v in ipairs(responses) do
    local dp,dr=v[3],v[4]
    local improvement=projectedPe*projectedPe+projectedRe*projectedRe-((projectedPe+dp)^2+(projectedRe+dr)^2)
    if improvement>best+.01 then best=improvement;s.axis=v[1];s.direction=v[2] end
   end
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
output('Pitch rate',s.ratePe or 0);output('Roll rate',s.rateRe or 0);output('Projected pitch',projectedPe);output('Projected roll',projectedRe);output('Emergency',s.emergency and 1 or 0);output('Drop',drop);output('Correction axis',selected);output('Tilt guard',s.tripped and 1 or 0);output('Pitch error',pe);output('Roll error',re);output('Pose valid',pose and 1 or 0)
