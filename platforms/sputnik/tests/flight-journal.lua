local function read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local J=assert(load(read('platforms/sputnik/src/flight_journal.lua')))()
local P=assert(load(read('platforms/sputnik/src/portable.lua')))()
local V=assert(load(read('platforms/sputnik/src/vehicle_model.lua'),'vehicle','t',setmetatable({Portable=P},{__index=_G})))()
local settings='MCU1;1;11;4;20;8;4;1;1;1;1'
local descriptors={};for id=1,4 do local g=V.defaults(1,id);g.powerA='minecraft:paper';g.powerB='minecraft:motor_'..id;descriptors[id]=V.encode(g) end
local function frame(t,changes,count)
 local f={tick=t,mass=32,ix=250,iy=400,iz=230,x=0,y=80,z=0,pitch=0,yaw=0,roll=0,vx=0,vy=0,vz=0,target=80,active=1,forward=0,left=0,vertical=0,residual=0,saturated=0,load=0,dimension='minecraft:overworld',mode='HOLD',revision=0,settings=settings,scale=1}
 for k,v in pairs(changes or {}) do f[k]=v end
 local values={'MCF1'};for _,key in ipairs(J.fields) do values[#values+1]=f[key]==nil and '?' or tostring(f[key]) end
 local phase=f.mode=='ROUTE' and 'CRUISE' or f.mode=='CALIBRATE' and 'CALIBRATING' or 'HOLDING'
 local rows={'MCREPORT1 | '..phase,table.concat(values,',')}
 for id=1,count or 4 do rows[#rows+1]=table.concat({'G',id,14,16,J.hash(descriptors[id] or ('MCV1;'..id))},',') end
 return table.concat(rows,'\n')
end
_G.MintCraftJournalFixture={J=J,settings=settings,descriptors=descriptors,frame=frame}
local f=assert(J.decode(frame(100)));local context=assert(J.context(f,settings,table.concat(descriptors,'\n'),''));assert(context.settings==settings)
assert(not J.decode(frame(100)..'\nG,1,15,0,0'),'Duplicate control accepted')
assert(not J.decode(frame(100):gsub('MCF1,100','MCF1,nan')),'Nonfinite time accepted')
assert(not J.context(f,settings,descriptors[1],''),'Incomplete active layout accepted')
local s=J.new()
for t=100,239 do local value=assert(J.decode(frame(t)));assert(s:accept(value,t,context)) end
local d=s:diagnose(239);assert(d.ready and not d.protect,'Measured quiet stationary window not recognized')
assert(not s:diagnose(250).ready,'Stale history certified')
assert(not s:accept(f,239,context),'Regressing time accepted')
assert(not s:accept(assert(J.decode(frame(250))),249,context),'Future frame accepted')
s:freeze('unit');local pages=s:pages();assert(#pages>=1 and pages[1]:match('^MCLOG1;'))
for _,page in ipairs(pages) do assert(#page<45000) end
local before=s.snapshot.rows[1];for t=240,1600 do assert(s:accept(assert(J.decode(frame(t))),t,context)) end
assert(s.snapshot.rows[1]==before,'Frozen evidence mutated with live ring');assert(s.count<=J.maxFrames and s.bytes<=J.maxBytes and s.dropped>0)
local noisy=J.new()
for t=100,219 do assert(noisy:accept(assert(J.decode(frame(t,{pitch=8*math.sin(t*math.pi/8)}))),t,context)) end
assert(noisy:diagnose(219).oscillating and noisy:diagnose(219).protect,'Severe quiet oscillation hidden')
for _,mode in ipairs({'ROUTE','CALIBRATE'}) do
 local moving=J.new();for t=100,219 do assert(moving:accept(assert(J.decode(frame(t,{pitch=8*math.sin(t*math.pi/8),mode=mode}))),t,context)) end
 assert(not moving:diagnose(219).protect,'Intentional mission/calibration mistaken for quiet oscillation')
end
local changed=J.new();for t=100,219 do assert(changed:accept(assert(J.decode(frame(t,{target=80+(t-100)*.02}))),t,context)) end;assert(not changed:diagnose(219).ready,'Changing target became measured stationary goal')
local big=J.new();for t=100,2100 do assert(big:accept(assert(J.decode(frame(t,nil,32))),t,nil)) end
assert(big.bytes<=J.maxBytes and big.count<J.maxFrames,'32-motor byte budget did not evict')
local model=J.identify(s.history);assert(not model.qualified and not model.collective,'Unexcited data invented response')
local fh={};for t=100,219 do local v=assert(J.decode(frame(t)));v.groups[1].level=t%8<4 and 14 or 15;fh[#fh+1]=v end
assert(not J.identify(fh).qualified,'Passive correlation became qualification')
-- Export a real fixture consumed by the independent Python parser/replayer.
if MINTCRAFT_JOURNAL_EXPORT then
 local archive=J.new();for t=100,259 do assert(archive:accept(assert(J.decode(frame(t))),t,context)) end;archive:freeze('cross-runtime')
 for i,page in ipairs(archive:pages()) do local out=assert(io.open(MINTCRAFT_JOURNAL_EXPORT..'/page-'..i..'.txt','w'));out:write(page);out:close() end
end
print('Flight journal: strict observations, immutable snapshots, frame/byte bounds, measured 20-sample stability, command-aware oscillation guard, missing excitation and cross-runtime export passed')
-- The adaptive envelope is bounded; worsening trials roll back without arming IO.
local policy=J.policy();local now=100
local bad={oscillating=true,heightSpan=1,pitchSpan=6,rollSpan=2,ready=false}
for i=1,20 do now=now+1;policy:update(bad,{tick=now,active=1},true) end
assert(math.abs(policy.factor-.9)<1e-10)
local worse={oscillating=true,heightSpan=3,pitchSpan=10,rollSpan=10,ready=false}
for i=1,120 do now=now+1;policy:update(worse,{tick=now,active=1},true) end
assert(policy.factor==1 and policy.cooldown>0,'Worsening envelope trial did not roll back')
for i=1,1500 do now=now+1;policy:update(bad,{tick=now,active=1},true);assert(policy.factor>=.5 and policy.factor<=1) end
policy:update(bad,{tick=now+1,active=1},false);assert(policy.factor==1,'Operator disabling adaptation did not restore declared envelope')
print('Adaptive envelope: measured-sample progression, 0.5..1 bounds, deterioration rollback and explicit disable passed')
