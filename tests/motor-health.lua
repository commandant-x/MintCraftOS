package.path='./?.lua;'..package.path
local H=require('system.navigation.motor_health')
local A=require('system.libraries.addon')
local d={enabled=true,name='tx',clutchOff=15,left={},right={}}
for _,side in ipairs({'left','right'}) do for _,role in ipairs({'clutch','gear','reverse'}) do d[side][role]={first='minecraft:'..side..'_'..role,second='minecraft:iron_ingot'} end end
local function values(side)
 local out={}
 for _,bank in ipairs({'left','right'}) do
  out['drive-'..bank..'-clutch']=(side==bank or side=='both') and 0 or 15
  out['drive-'..bank..'-gear']=5 out['drive-'..bank..'-reverse']=0
 end
 return out
end
local now=10
local function sample(side)
 now=now+1
 local s={ok=true,inventoryComplete=true,vehicleId='ship',frame='body_plot',observedAt=now,validUntil=now+2,actuators={},mechanics={}}
 for _,bank in ipairs({'left','right'}) do
  local on=side==bank or side=='both'
  s.actuators[#s.actuators+1]={id=bank..'-prop'}
  s.mechanics[#s.mechanics+1]={id=bank..'-prop',sourceId=on and bank..'-clutch' or nil,rpm=on and 32 or 0,theoreticalRPM=on and 32 or 0}
  s.mechanics[#s.mechanics+1]={id=bank..'-clutch',sourceId=bank..'-engine',block='create:clutch',role='clutch',disengaged=not on,rpm=32,theoreticalRPM=32}
  s.mechanics[#s.mechanics+1]={id=bank..'-engine',rpm=32,theoreticalRPM=32}
 end
 -- Unrelated but nearby is not a source edge or a command association.
 s.mechanics[#s.mechanics+1]={id='unrelated',block='create:clutch',role='clutch',disengaged=false,overstressed=true,rpm=0,theoreticalRPM=256}
 return s
end
local function trained()
 local h=H.new('ship',d)
 for _,mode in ipairs({'off','left','right'}) do for _=1,3 do local s=sample(mode) h:learn(s,d,values(mode),now-1,true,now) end end
 local report=h:status(now)
 assert(report.available and report.qualifiedRoots==2 and report.banks.left.clutches==1 and report.banks.right.clutches==1)
 assert(report.scope=='observed-source-subset-not-axis-certificate')
 return h
end
local h=trained()
for _=1,4 do local s=sample('both') assert(not h:check(s,d,values('both'),now-1,true,now,{forward=.1,yaw=0})) end
assert(not h:status(now).fault,'unrelated overstress was attributed to motor bank')
local function node(s,id) for _,n in ipairs(s.mechanics) do if n.id==id then return n end end end
for _,case in ipairs({'overstress','clutch_disengaged','rpm_incoherent','source_feedback_lost','rotation_missing'}) do
 h=trained()
 local required=case=='rotation_missing' and 8 or 2
 for i=1,required do
  local s=sample('both')
  if case=='overstress' then node(s,'left-engine').overstressed=true
  elseif case=='clutch_disengaged' then node(s,'left-clutch').disengaged=true
  elseif case=='rpm_incoherent' then node(s,'left-prop').rpm=0
  elseif case=='source_feedback_lost' then node(s,'left-prop').sourceId=nil
  else node(s,'left-prop').rpm=0 node(s,'left-prop').theoreticalRPM=0 end
  local issue=h:check(s,d,values('both'),now-1,true,now,{forward=.1,yaw=0})
  assert((issue~=nil)==(i==required),'fault did not require distinct fresh evidence: '..case)
  for _=1,10 do h:check(s,d,values('both'),now-1,true,now,{forward=.1,yaw=0}) end
 end
 local r=h:status(now) assert(r.fault.kind==case and r.fault.side=='left')
 r.fault.kind='fake' assert(h:status(now).fault.kind==case,'consumer modified private evidence')
end
-- Unqualified observations can never trigger a physical fault inference.
h=H.new('ship',d)
for _=1,20 do local s=sample('both') node(s,'left-engine').overstressed=true assert(not h:check(s,d,values('both'),now-1,true,now,{forward=.1,yaw=0})) end
assert(not h:status(now).available)
-- An absent optional diagnostic is unavailable, not a fabricated motor fault.
h=trained()
for _=1,4 do local x=sample('both') x.mechanics={}
 assert(not h:check(x,d,values('both'),now-1,true,now,{forward=.1,yaw=0}))
end
assert(not h:status(now).available and not h:status(now).fault)
-- Freshness, identity, binding and command-ack boundaries.
h=trained() local s=sample('both') node(s,'left-engine').overstressed=true
assert(not h:check(s,d,values('both'),now-1,false,now,{forward=.1,yaw=0}))
assert(not h:status(now).available)
assert(not h:check(s,d,values('both'),now-1,true,now+3,{forward=.1,yaw=0}))
s=sample('both') s.vehicleId='foreign' assert(not h:check(s,d,values('both'),now-1,true,now,{forward=.1,yaw=0}))
assert(not h:status(now).available)
h=trained() local changed=A.copy(d) changed.name='other'
s=sample('both') assert(not h:check(s,changed,values('both'),now-1,true,now,{forward=.1,yaw=0})) assert(not h:status(now).available)
-- Missing patterns and mixed physical states refuse association.
h=H.new('ship',d)
for _,mode in ipairs({'off','left','right'}) do for i=1,3 do local x=sample(mode)
 if mode=='left' and i==1 then node(x,'left-clutch').disengaged=true end
 h:learn(x,d,values(mode),now-1,true,now)
end end
assert(h:status(now).banks.left.roots==0 and h:status(now).banks.right.roots==1)
-- Rotation-free calibration and graph ambiguity do not invent a control link.
h=H.new('ship',d)
for _,mode in ipairs({'off','left','right'}) do for _=1,3 do local x=sample(mode) node(x,'left-prop').rpm=0 node(x,'right-prop').rpm=0 h:learn(x,d,values(mode),now-1,true,now) end end
assert(h:status(now).qualifiedRoots==0)
-- A large gap breaks consecutive fault evidence; duplicate/too-close samples
-- cannot manufacture the required quorum.
h=trained()
local function overloaded()
 local x=sample('both') node(x,'left-engine').overstressed=true return x
end
s=overloaded() assert(not h:check(s,d,values('both'),now-1,true,now,{forward=.1,yaw=0}))
now=now+3 s=overloaded()
assert(not h:check(s,d,values('both'),now-1,true,now,{forward=.1,yaw=0}),'gap retained old fault quorum')
s.observedAt=now+.1 s.validUntil=now+2
assert(not h:check(s,d,values('both'),now-1,true,now+.1,{forward=.1,yaw=0}),'too-close sample counted')
s=overloaded() assert(h:check(s,d,values('both'),now-1,true,now,{forward=.1,yaw=0}))
-- Clock regression permanently invalidates this session's association.
h=trained() s=sample('both') h:check(s,d,values('both'),now-1,true,now,{forward=.1,yaw=0})
s.observedAt=now-.1
assert(not h:check(s,d,values('both'),now-1,true,now,{forward=.1,yaw=0}))
assert(not h:status(now).available and h:status(now).reason:find('regressed',1,true))
-- A root observed on both isolated banks remains ambiguous, even if both
-- clutches independently match their command patterns.
h=H.new('ship',d)
for _,mode in ipairs({'off','left','right'}) do for _=1,3 do
 local x=sample(mode)
 x.actuators={{id='shared'}}
 x.mechanics[#x.mechanics+1]={id='shared',rpm=32,theoreticalRPM=32,sourceId=mode~='off' and mode..'-clutch' or nil}
 h:learn(x,d,values(mode),now-1,true,now)
end end
assert(h:status(now).qualifiedRoots==0,'ambiguous source assigned to one bank')
-- Engaged with zero gear cannot masquerade as the all-disengaged baseline.
h=H.new('ship',d)
for _,mode in ipairs({'off','left','right'}) do for _=1,3 do
 local x=sample(mode) local v=values(mode)
 if mode=='off' then v=values('both') v['drive-left-gear']=0 v['drive-right-gear']=0 end
 h:learn(x,d,v,now-1,true,now)
end end
assert(h:status(now).qualifiedRoots==0,'zero gear forged the disengaged baseline')
-- Changing IDs over time cannot grow the retained root catalogue without bound.
h=H.new('ship',d)
for i=1,100 do local x=sample('left')
 x.actuators={{id='prop-'..i}}
 x.mechanics[#x.mechanics+1]={id='prop-'..i,rpm=32,theoreticalRPM=32,sourceId='left-clutch'}
 h:learn(x,d,values('left'),now-1,true,now)
end
assert(#h.order==32 and h:status(now).truncated,'observed root catalogue grew unbounded')
fs=setmetatable({},{__index=function() error('filesystem access in observer') end})
peripheral=setmetatable({},{__index=function() error('peripheral acquisition in observer') end})
assert(trained():status(now))
print('Motor health: command-correlated physical clutch/source subset, unrelated-node isolation, post-ACK fresh quorums, five fault classes, no inference from missing/mixed data and no hardware writes passed')
