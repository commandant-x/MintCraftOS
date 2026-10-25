-- Shipped native bundle, exact same math; mocked IO is explicitly not hardware evidence.
local function read(path) local f=assert(io.open(path));local t=f:read('*a');f:close();return t end
local function field(value) local f={v=value};f.getValue=function() return f.v end;f.setValue=function(v) f.v=v end;f.setText=f.setValue;return f end
local e=setmetatable({_G=false},{__index=function(_,key) if type(key)=='string' and key:match('^MintCraft') then return nil end return _G[key] end});e._G=e
 e.ui={label=field,textfield=function() return field('') end};e.addElement=function() end;e.input=function() return 0 end;e.output=function() end
 e.getUniverseTime=function() return 0 end;e.getShipMass=function() return 0 end
local source=read('platforms/sputnik/dist/mintcraft-autopilot-control.lua')
local export='\nreturn {Portable=_G.MintCraftFlightModules[1],Vehicle=_G.MintCraftFlightModules[7],Flight=_G.MintCraftFlightModules[10],Mission=_G.MintCraftFlightModules[8],Calibration=_G.MintCraftFlightModules[9],Response=_G.MintCraftFlightModules[4],Geometry=_G.MintCraftFlightModules[2],Physics=_G.MintCraftFlightModules[3]}'
local B=assert(load(source..export,'native-universal','t',e))()
local V,F=B.Vehicle,B.Flight
local definitions=assert(load(read('platforms/sputnik/src/vehicle_model.lua'),'mount-defaults','t',{Portable=B.Portable,math=math,type=type,ipairs=ipairs,pairs=pairs,tostring=tostring,tonumber=tonumber}))()
V.defaults=definitions.defaults
local function pose(t) return {tick=t,x=0,y=80,z=0,pitch=0,yaw=0,roll=0,mass=32,ix=250,iy=400,iz=230,dimension='minecraft:overworld',gravity=11} end
local config={gravity=11,climb=1,tilt=8,margin=1,braking=1,protected={}}
local function groups(profile,count)
 local out={};for i=1,count do local g=V.defaults(profile,i);g.powerA='minecraft:stone';g.powerB='minecraft:group_'..i;out[i]=g end;return out
end
for profile,count in ipairs({4,4,6,4}) do
 local g=groups(profile,count);assert(V.validate(g))
 local text=V.encode(g[1]);assert(V.encode(assert(V.decode(text)))==text)
 local s=assert(F.new(g,pose(100),config));local signals,info=s:step(pose(101),{forward=0,left=0,vertical=0},{})
 assert(signals,info)
 for _,value in pairs(signals) do assert(value%1==0 and value>=0 and value<=15) end
 assert(info.rxConfirmed==false and info.shaftConfirmed==false)
 print('Native architecture '..profile..': bounded motor outputs at measured mass; no hardware proof')
end
local g=groups(1,4);g[2].powerB=g[1].powerB;assert(not V.validate(g),'cross-group collision accepted')
local q1=V.quaternion(5,35,-7);local fwd=V.world({x=0,y=0,z=1},q1);assert(math.abs(math.deg(B.Geometry.atan2(fwd.x,fwd.z))-35)<1e-8)
local err=V.attitudeError(q1,q1);assert(math.abs(err.x)+math.abs(err.y)+math.abs(err.z)<1e-9)
local s=assert(F.new(groups(1,4),pose(100),config));local filter=s.filters.y
assert(s:apply({revision=1,mode='ALTITUDE',altitude=81,speed=0,heading=0},pose(100)))
assert(s.filters.y==filter and s.target.y==81,'live target reset estimator')
assert(not s:apply({revision=1,mode='ALTITUDE',altitude=90,speed=0,heading=0},pose(100)),'stale consigne applied')
assert(s.target.y==81)
local route=assert(B.Mission.parse('0,80,0;10,80,10,3'));assert(#route==2 and route[2].speed==3)
assert(not B.Mission.parse('nan,0,0') and not B.Mission.parse('1,2'))
local zones=assert(B.Mission.parse('2,79,-1,4,81,1',true));assert(B.Mission.blocked({x=0,y=80,z=0},{x=6,y=80,z=0},zones,0))
local planner=B.Mission.planner({x=0,y=80,z=0},{x=6,y=80,z=0},zones,.5)
for _=1,100 do if not planner.done then planner:step() end end
assert(planner.done and not planner.failed)
for i=2,#planner.path do assert(not B.Mission.blocked(planner.path[i-1],planner.path[i],zones,.5)) end
local C=B.Calibration.new(groups(1,4),pose(100),{})
for tick=101,119 do C:step(pose(tick),{x=0,y=0,z=0},{x=0,y=0,z=0},true) end
assert(C.phase=='BASELINE','stability passed with fewer than 20 samples')
C:step(pose(120),{x=0,y=0,z=0},{x=0,y=0,z=0},true);assert(C.phase=='PROBE')
local C2=B.Calibration.new(groups(1,4),pose(100),{})
for tick=101,2000 do C2:step(pose(tick),{x=0,y=.11,z=0},{x=0,y=0,z=0},true) end
assert(C2.phase=='BASELINE','elapsed time certified unstable motion')
print('Universal contracts: serialization, duplicate rejection, quaternion convention, live/replayed consignes, declared-zone detour and measured 20-sample calibration passed')
-- Compare readable bundle to shipped compact bundle, including implicit method self.
if MINTCRAFT_UNCOMPACTED then
 local plain=setmetatable({},{__index=function(_,key) if type(key)=='string' and key:match('^MintCraft') then return nil end return _G[key] end});plain._G=plain
 plain.ui=e.ui;plain.addElement=e.addElement;plain.input=e.input;plain.output=e.output;plain.getUniverseTime=e.getUniverseTime;plain.getShipMass=e.getShipMass
 local original=assert(load(read(MINTCRAFT_UNCOMPACTED)..export,'readable-universal','t',plain))()
 local function equal(a,b,path)
  assert(type(a)==type(b),'compact type changed: '..path)
  if type(a)=='table' then for k,v in pairs(a) do equal(v,b[k],path..'.'..tostring(k)) end;for k in pairs(b) do assert(a[k]~=nil,'compact key added: '..path..'.'..tostring(k)) end
  elseif type(a)=='number' then assert(math.abs(a-b)<=1e-10*math.max(1,math.abs(a)),'compact number changed: '..path)
  else assert(a==b,'compact value changed: '..path) end
 end
 for profile=1,5 do
  local gs=groups(profile==5 and 1 or profile,profile==3 and 6 or 4)
  for i,g in ipairs(gs) do if g.role=='drive' then g.reverseA='minecraft:stick';g.reverseB='minecraft:reverse_'..i end;if profile==5 then g.kind='bearing';g.sails=({8,12,16,20})[i];g.thrust=.2;g.airflow=.05 end end
  local a=assert(F.new(gs,pose(100),config));local b=assert(original.Flight.new(gs,pose(100),config))
  local sa,sb=a.initialSignals,b.initialSignals;equal(sa,sb,'initial')
  for t=101,260 do
   local p=pose(t);p.x=.01*math.sin(t/10);p.y=80+.02*math.sin(t/20);p.z=.01*math.cos(t/10);p.pitch=.2*math.sin(t/7);p.roll=.2*math.cos(t/7);p.yaw=.1*math.sin(t/10)
   if t==160 then p.mass=28 end
   if t==120 or t==200 then local request={revision=t,mode=t==120 and 'ALTITUDE' or 'CALIBRATE',altitude=80.2,speed=1,heading=15};assert(a:apply(request,p)==b:apply(request,p)) end
   local command={forward=t>130 and t<145 and .2 or 0,left=t>130 and t<145 and .1 or 0,vertical=0}
   local ia,ib;sa,ia=a:step(B.Portable.copy(p),command,sa);sb,ib=b:step(B.Portable.copy(p),command,sb)
   equal(sa,sb,'signals');equal(ia,ib,'diagnostic');assert(sa)
  end
 end
 print('Readable/compact native equivalence: five architectures, quaternion motion, live requests, mass change and calibration traces matched')
end
-- Mission interruption must never leave an old mission or probe overriding targets.
local c=assert(F.new(groups(1,4),pose(100),config));c.calibration={complete=true,horizontalVerified=true}
assert(c:apply({revision=1,mode='ROUTE',altitude=80,speed=1,heading=0,route='0,80,3',zones=''},pose(100)))
assert(c:apply({revision=2,mode='ALTITUDE',altitude=82,speed=0,heading=0},pose(100)))
assert(c.mission.paused and c.target.y==82)
assert(c:apply({revision=3,mode='CALIBRATE',altitude=80,speed=0,heading=0},pose(100)))
assert(c:apply({revision=4,mode='MANUAL',altitude=80,speed=0,heading=0},pose(100)))
assert(c.calibration.paused and c.mission.paused)
-- Persistence is a candidate only; all group probes are freshly re-run.
local cache=assert(F.new(groups(1,4),pose(100),config));local cal=B.Calibration.new(cache.groups,pose(100),{})
cal.results[1]={dx=0,dy=1,dz=0,pitch=0,roll=0,yaw=0};local saved=B.Calibration.archive(cal,32)
local candidate=B.Calibration.new(cache.groups,pose(100),{},saved);assert(candidate.priors[1] and candidate.phase=='BASELINE' and not candidate.complete)
local edited=B.Portable.copy(cache.groups);edited[1].sails=16;assert(not B.Calibration.new(edited,pose(100),{},saved).priors[1])
local max=groups(1,32);assert(V.validate(max));local full=assert(F.new(max,pose(100),config));local bounded=assert(full:step(pose(101),{forward=0,left=0,vertical=0},full.initialSignals))
local count=0;for _,signal in pairs(bounded) do assert(signal>=0 and signal<=15 and signal%1==0);count=count+1 end;assert(count==32)
print('Universal regressions: direct-command interruption, cache revalidation and 32 bounded independent groups passed')
-- An inverter command is emitted with stopped power for a fresh observation,
-- never with immediate full thrust; stale shaft values cannot authorize it.
do
 local gs=groups(3,6);for i=5,6 do gs[i].reverseA='minecraft:stick';gs[i].reverseB='minecraft:gear_'..i end
 local engine=assert(F.new(gs,pose(100),config))
 local output,info=engine:step(pose(101),{forward=-1,left=0,vertical=0},engine.initialSignals,{[5]={rpm=0,tick=101},[6]={rpm=0,tick=101}})
 assert(output and engine.directions[5]==1 and output['5']==15 and output['6']==15 and info.reversing[5])
 output,info=engine:step(pose(102),{forward=-1,left=0,vertical=0},output,{[5]={rpm=0,tick=102},[6]={rpm=0,tick=102}})
 assert(output and engine.directions[5]==-1 and output['5']==15 and output['6']==15)
 assert(info.shaftConfirmed==false,'shaft standstill became gearshift acknowledgement')
 local stale=assert(F.new(gs,pose(100),config))
 local stopped=assert(stale:step(pose(101),{forward=-1,left=0,vertical=0},stale.initialSignals,{[5]={rpm=0,tick=90},[6]={rpm=0,tick=90}}))
 assert(stale.directions[5]==1 and stopped['5']==15,'stale shaft sample authorized inversion')
 print('Reversal regression: stopped-power shift frame, fresh/stale shaft separation and no fabricated gearshift ACK passed')
end
do
 local normal=assert(F.new(groups(1,4),pose(100),config));local lateralConfig=B.Portable.copy(config);lateralConfig.steering=false
 local lateral=assert(F.new(groups(1,4),pose(100),lateralConfig))
 local _,a=normal:step(pose(101),{forward=0,left=1,vertical=0},normal.initialSignals)
 local _,b=lateral:step(pose(101),{forward=0,left=1,vertical=0},lateral.initialSignals)
 assert(math.abs(a.rollTarget)<1e-8 and b.rollTarget>7,'quad steering/strafe selector ignored')
 print('Manual steering selector: no fabricated stationary yaw, lateral quad demand available separately')
end
do
 local p=pose(100);p.vx,p.vy,p.vz=1,-.5,2
 local airborne=assert(F.new(groups(1,4),p,config))
 assert(airborne.filters.y.v==-.5 and airborne.velocity.x==1 and airborne.velocity.z==2,'fresh server velocity lost at initialization')
 print('Estimator initialization: available native velocity is retained, without resetting an active target')
end
-- Progress diagnosis must use the same positional band as mission arrival.
-- A pending speed/settling check inside that band is not a position failure.
for _,distance in ipairs({.4,.8}) do
 local engine=assert(F.new(groups(1,4),pose(100),config))
 engine.mission={index=1,segment=2,phase='APPROACH',completed=false,paused=false,events={},
  step=function() return {x=distance,y=80,z=0,speed=0} end,pause=function(m) m.paused=true end}
 local output=engine.initialSignals
 for tick=101,450 do output=assert(engine:step(pose(tick),{forward=0,left=0,vertical=0},output)) end
 assert(engine.mission.paused==(distance>.5),'progress diagnosis conflicts with arrival position band')
end
print('Mission approach regression: settling within arrival band stays active; distant nonconvergence still pauses')
-- A 90-degree bearing must not alternate forward/reverse nose choices under
-- tiny pose noise while the physical vehicle still lags the requested heading.
do
 local gs=groups(3,6);for i=5,6 do gs[i].reverseA='minecraft:stick';gs[i].reverseB='minecraft:gear_'..i end
 local engine=assert(F.new(gs,pose(100),config));engine.calibration={complete=true,horizontalVerified=true}
 assert(engine:apply({revision=1,mode='ROUTE',altitude=80,speed=1,heading=0,route='-1,80,0',zones=''},pose(100)))
 local previous;local output=engine.initialSignals
 for tick=101,120 do local p=pose(tick);p.z=tick%2==0 and .0001 or -.0001;output=assert(engine:step(p,{forward=0,left=0,vertical=0},output));local heading=engine.navigationHeading
  if engine.phase=='APPROACH' or engine.phase=='CRUISE' then if previous then assert(math.abs((heading-previous+180)%360-180)<1,'bearing jitter toggled forward/reverse nose selection') end;previous=heading end
 end
 print('Heading-branch regression: noisy perpendicular target preserves a continuous nose request')
end
-- Long-distance motion is progress even when it is a small fraction of the route.
do
 local engine=assert(F.new(groups(1,4),pose(100),config));engine.calibration={complete=true,horizontalVerified=true}
 assert(engine:apply({revision=1,mode='ROUTE',altitude=80,speed=1,heading=0,route='10000,80,0,1',zones=''},pose(100)))
 local output=engine.initialSignals
 for tick=101,450 do local p=pose(tick);p.x=(tick-100)*.05;output=assert(engine:step(p,{forward=0,left=0,vertical=0},output)) end
 assert(not engine.mission.paused,'long route was refused despite measured continuous progress')
 print('Native long-route regression: no distance-induced false progress stop')
end
-- A real mass change uses feedback trim, not a calibration pulse or target reset.
do
 local engine=assert(F.new(groups(1,4),pose(100),config));local filter=engine.filters.y
 assert(engine:apply({revision=1,mode='ALTITUDE',altitude=82,speed=0,heading=0},pose(100)))
 local p=pose(101);p.mass=28;p.ix,p.iy,p.iz=220,350,200
 assert(engine:step(p,{forward=0,left=0,vertical=0},engine.initialSignals))
 assert(engine.massAdapted and engine.target.y==82 and engine.filters.y==filter and not engine.calibration,'mass change launched tests or replaced altitude control')
 local p2=pose(102);assert(engine:step(p2,{forward=0,left=0,vertical=0},engine.initialSignals))
 assert(engine.massAdapted and engine.target.y==82,'restored mass disabled an already learned trim')
 print('Mass adaptation contract: altitude/estimator preserved, no active tests and observed-change latch retained')
end
-- Closed-loop torque changes cannot repeatedly cancel a stop-before-reverse.
do
 local gs=groups(3,6);for i=5,6 do gs[i].reverseA='minecraft:stick';gs[i].reverseB='minecraft:gear_'..i end
 local engine=assert(F.new(gs,pose(100),config))
 local first=assert(engine:step(pose(101),{forward=-1,left=0,vertical=0},engine.initialSignals))
 local second=assert(engine:step(pose(102),{forward=1,left=0,vertical=0},first))
 assert(engine.shifts[5].d==-1 and second['5']==15,'new torque intent cancelled a pending shaft stop')
 print('Latched reversal: changing intent preserves stop/shift ordering until completion')
end
