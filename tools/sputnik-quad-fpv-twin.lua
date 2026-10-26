-- Independent quad response / cable-point-mass plant. No collisions or terrain.
-- Rope metadata is deliberately NEVER included in observations sent to the controller.
local function read(path) local f=assert(io.open(path));local t=f:read('*a');f:close();return t end
local function field(v) return {getValue=function() return v end,setValue=function(x) v=x end,setText=function() end} end
local env=setmetatable({},{__index=function(_,key) if type(key)=='string' and key:match('^MintCraft') then return nil end return _G[key] end});env._G=env
 env.ui={label=field,textfield=function() return field('') end};env.addElement=function() end;env.input=function() return 0 end;env.output=function() end;env.getUniverseTime=function() return 0 end;env.getShipMass=function() return 0 end
local B=assert(load(read(MINTCRAFT_UNIVERSAL_CONTROLLER or 'platforms/sputnik/dist/mintcraft-autopilot-control.lua')..'\nreturn {Portable=_G.MintCraftFlightModules[1],Vehicle=_G.MintCraftFlightModules[7],Flight=_G.MintCraftFlightModules[10]}','universal-controller','t',env))()
local defaults=assert(load(read(MINTCRAFT_UNIVERSAL_DEFAULTS or 'platforms/sputnik/src/vehicle_model.lua'),'defaults','t',{Portable=B.Portable,math=math,type=type,ipairs=ipairs,pairs=pairs,tostring=tostring,tonumber=tonumber}))().defaults
local function cross(a,b) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
local function rotate(q,v) local t=cross({q[2],q[3],q[4]},v);local u=cross({q[2],q[3],q[4]},t);return {v[1]+2*(q[1]*t[1]+u[1]),v[2]+2*(q[1]*t[2]+u[2]),v[3]+2*(q[1]*t[3]+u[3])} end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local pressure={};for line in read('platforms/sputnik/tests/fixtures/sable-pressure.csv'):gmatch('[^\n]+') do local a,b=line:match('([^,]+),([^,]+)');pressure[tonumber(a)]=tonumber(b) end
local function air(y) if y<=-80 then return 1.5 elseif y>=320 then return 0 end;local n=math.floor(y);return pressure[n]+(pressure[n+1]-pressure[n])*(y-n) end
local out=MINTCRAFT_UNIVERSAL_OUTPUT
local summary=out and assert(io.open(out..'/summary.csv','w'))
if summary then summary:write('profile,scenario,status,altitude_error,max_tilt,final_speed,tail_speed_rms,tail_tilt,min_altitude,max_altitude,target_altitude,first_upright_seconds,recovery_seconds,climb90_seconds,tilt90_seconds,brake_seconds,release_speed,rope_stretch,first_fault\n') end
local scenarios=MINTCRAFT_FPV_CASES or {'hover','tilt','flip90','flip150','flip180','climb','brake','rope12','rope32','rope-swing','rope-release','rope-offset'}
local total,passed=0,0
local fixture=MINTCRAFT_UNIVERSAL_FIXTURE or {}
local delay=fixture.delay or 1;assert(delay>=1 and delay<=6 and delay%1==0)
local baseMass=fixture.mass or 32;local inertiaScale=fixture.inertiaScale or 1
for _,profile in ipairs(MINTCRAFT_UNIVERSAL_PROFILES or {1,6,5}) do
 for _,scenario in ipairs(scenarios) do
  local n=profile==3 and 6 or 4;local groups={}
  for i=1,n do
   local g=defaults((profile==5 or profile==6) and 1 or profile,i);g.powerA='minecraft:paper';g.powerB='minecraft:rotor_'..i
   if g.role=='drive' then g.reverseA='minecraft:stick';g.reverseB='minecraft:reverse_'..i end
   if g.kind=='linear' or g.kind=='surface' then g.gain=g.role=='lift' and 20 or 50 end
   if profile==5 then g.kind='bearing';g.thrust=.2;g.airflow=.05;g.sails=({8,12,16,20})[i];g.x=i%2==1 and -4 or 2 end
   if profile==6 then g.kind='bearing';g.thrust=.2;g.airflow=.05;g.sails=12 end
   groups[i]=g
  end
  local w={x=0,y=80,z=0,v={0,0,0},q={1,0,0,0},omega={0,0,0},rpm={},linear={},mass=baseMass,I={250*inertiaScale,400*inertiaScale,230*inertiaScale}}
  local function pose(tick)
   local vx,vy,vz=rotate(w.q,{1,0,0}),rotate(w.q,{0,1,0}),rotate(w.q,{0,0,1})
   return {vx=w.v[1],vy=w.v[2],vz=w.v[3],tick=tick,x=w.x+(fixture.noise or 0)*math.sin(tick*1.7),y=w.y+(fixture.noise or 0)*math.sin(tick*2.3),z=w.z+(fixture.noise or 0)*math.cos(tick*1.3),pitch=math.deg(math.asin(clamp(-vz[2],-1,1))),yaw=math.deg(math.atan2(vz[1],vz[3])),roll=math.deg(math.atan2(vx[2],vy[2])),mass=w.mass,ix=w.I[1],iy=w.I[2],iz=w.I[3],dimension='minecraft:overworld',gravity=11}
  end
  local core,why=B.Flight.new(groups,pose(100),{gravity=11,climb=4,tilt=25,braking=4,margin=1,protected={}})
  if not core then
   total=total+1;print(profile..' '..scenario..' REFUSED: '..tostring(why))
   if summary then summary:write(string.format('%d,%s,REFUSED,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,%q\n',profile,scenario,tostring(why))) end
  else
  local signals=core.initialSignals
  for i,g in ipairs(groups) do
   if g.kind=='linear' or g.kind=='surface' then w.linear[i]=g.neutral else local t=g.kind=='bearing' and .2*g.sails^1.5 or 1;local share=profile==5 and (i%2==1 and 1/6 or 1/3) or 1/4;w.rpm[i]=g.role=='lift' and baseMass*11*share/(t*air(80)) or 0 end
  end
  if profile==2 or profile==4 then w.rpm[1]=profile==4 and baseMass*11/(.2*12^1.5*air(80)) or nil end
  local fault;local maxTilt,maxError,maxSpeed,maxHorizontal,maxYaw,maxX,tailSquare,tailCount,pitchSum,pitchSquare,pitchCount=0,0,0,0,0,0,0,0,0,0,0;local target=80
  local pending={};local initialSignals=B.Portable.copy(signals);local actualDirections={};for _,g in ipairs(groups) do actualDirections[g.id]=1 end
  local seconds=40
  local ropeMass=fixture.ropeMass or (scenario=='rope32' and 32 or 12);local ropeActive=false;local ropePosition,ropeVelocity;local ropeLength=fixture.ropeLength or 5
  local anchor=scenario=='rope-offset' and {1,-1,0} or {0,-1,0}
  local recoveryTime,climbTime,tiltTime,stopTime,releaseSpeed,minimumY=0,0,0,0,0,80
  local peakTailTilt,maxStretch,maximumY,firstUpright=0,0,80,0
  local missionRequested=false;local damaged=false
  for step=1,seconds*20 do
   local now=step*.05
   if step==60 then
    if scenario=='tilt' or scenario:match('^flip') then
     local degrees=scenario=='tilt' and 10 or tonumber(scenario:match('%d+'))
     local a=math.rad(degrees)/2;w.q={math.cos(a),0,0,math.sin(a)};w.omega={0,0,0}
    end
    if scenario:match('^rope') then
     ropeActive=true;local r=rotate(w.q,anchor);local a=scenario=='rope-swing' and math.rad(20) or 0
     ropePosition={w.x+r[1]+ropeLength*math.sin(a),w.y+r[2]-ropeLength*math.cos(a),w.z+r[3]};ropeVelocity={w.v[1],w.v[2],w.v[3]}
    end
   end
   if scenario=='rope-release' and step==400 then ropeActive=false end
   local p=pose(100+step)

   if (scenario=='calibration' or scenario=='mission' or scenario=='mission_straight') and step==40 then assert(core:apply({revision=1,mode='CALIBRATE',altitude=80,speed=0,heading=0},p)) end
   if (scenario=='mission' or scenario=='mission_straight') and core.calibration and core.calibration.complete and not missionRequested then
    local route='0,81,3,1;0,80,0,1'
    if scenario=='mission_straight' then local x,z=w.x,w.z;local heading=math.rad(p.yaw);route=table.concat({x+6*math.sin(heading),81,z+6*math.cos(heading),1},',')..';'..table.concat({x,80,z,1},',') end
    local accepted,why=core:apply({revision=2,mode='ROUTE',altitude=80,speed=1,heading=0,route=route,zones=''},p);assert(accepted,why);missionRequested=true
   end
   if scenario=='altitude' and step==40 then assert(core:apply({revision=1,mode='ALTITUDE',altitude=81,speed=0,heading=0},p));target=81 end
   if (scenario=='mass' or scenario=='damage') and step==120 then w.mass=baseMass*.875;p.mass=w.mass;w.I={220*inertiaScale,350*inertiaScale,200*inertiaScale};p.ix,p.iy,p.iz=w.I[1],w.I[2],w.I[3];if scenario=='damage' then damaged=true end end
   local command={forward=scenario=='brake' and now>=3 and now<8 and 1 or 0,left=0,vertical=scenario=='climb' and now>=3 and now<5 and 1 or 0}
   if scenario=='climb' then target=core.target.y end
   if scenario=='brake' and step==160 then releaseSpeed=math.sqrt(w.v[1]^2+w.v[3]^2) end

   local requested,info=core:step(p,command,signals)
   if not requested then fault=fault or info;break end
   pending[#pending+1]={signals=B.Portable.copy(requested),directions=B.Portable.copy(core.directions)}
   local applied={signals=initialSignals,directions=actualDirections}
   if not fixture.rotorDelays and #pending>delay then applied=table.remove(pending,1);actualDirections=applied.directions end
   -- Independent delayed Link bus, then motor spool; no controller shaft ACK.
   for i,g in ipairs(groups) do
    local signal=applied.signals[tostring(g.id)]
    if fixture.rotorDelays then local frame=pending[#pending-fixture.rotorDelays[i]];signal=frame and frame.signals[tostring(g.id)] or initialSignals[tostring(g.id)] end
    if g.kind=='linear' or g.kind=='surface' then w.linear[i]=w.linear[i]+.15*(signal-w.linear[i])
    else local rpm=signal==0 and g.source or g.source*(15-signal)/16;local alpha=g.kind=='bearing' and .4/math.sqrt(g.sails) or .15;w.rpm[i]=w.rpm[i]+alpha*(rpm-w.rpm[i]) end
   end
   if fixture.rotorDelays and #pending>8 then table.remove(pending,1) end
   signals=requested
   if MINTCRAFT_UNIVERSAL_DEBUG and step%100==0 then print('DEBUG',now,core.calibration and core.calibration.phase,core.calibration and core.calibration.index,p.x,p.y,p.z,core.target.x,core.target.y,core.target.z,p.yaw,info.residual,table.concat({signals['1'],signals['2'],signals['3'],signals['4'],signals['5'] or 0,signals['6'] or 0},'/')) end
   for _=1,10 do
    local dt=.005;local force={0,0,0};local torque={0,0,0}
    for i,g in ipairs(groups) do
     local sign=actualDirections[g.id];local direction={g.dx*sign,g.dy*sign,g.dz*sign};local worldDir=rotate(w.q,direction);local r={g.x-(fixture.comX or 0)-(damaged and .5 or 0),g.y,g.z};local rw=rotate(w.q,r);local rotational=rotate(w.q,cross(w.omega,r))
     local f
     if g.kind=='linear' or g.kind=='surface' then
      if g.role=='lift' then f=baseMass*11+(w.linear[i]-g.neutral)*g.gain else f=w.linear[i]*g.gain;if g.kind=='surface' then local forward=rotate(w.q,{0,0,1});local flow=w.v[1]*forward[1]+w.v[2]*forward[2]+w.v[3]*forward[3];f=f*flow*math.abs(flow) end end
     else
      local t=g.kind=='bearing' and g.thrust*g.sails^1.5 or g.thrust;local a=g.kind=='bearing' and g.airflow*math.sqrt(g.sails) or g.airflow
      local rpm=w.rpm[i];local axial=(w.v[1]+rotational[1])*worldDir[1]+(w.v[2]+rotational[2])*worldDir[2]+(w.v[3]+rotational[3])*worldDir[3]
      f=rpm>1/30 and t*rpm*air(w.y+rw[2])*clamp(1-axial/(a*rpm),0,1)*g.members or 0
     end
     if i==1 then f=f*(fixture.rotorFactor or 1)*(damaged and .7 or 1) end
     if g.role=='yaw-left' or g.role=='yaw-right' then torque[2]=torque[2]+(g.role=='yaw-left' and -f or f)
     else
      for j=1,3 do force[j]=force[j]+worldDir[j]*f end
      local tau=cross(r,{direction[1]*f,direction[2]*f,direction[3]*f});for j=1,3 do torque[j]=torque[j]+tau[j] end
     end
    end
    if ropeActive then
     local r=rotate(w.q,anchor);local attach={w.x+r[1],w.y+r[2],w.z+r[3]};local rotational=rotate(w.q,cross(w.omega,anchor))
     local delta={};local length=0;for j=1,3 do delta[j]=ropePosition[j]-attach[j];length=length+delta[j]^2 end;length=math.sqrt(length)
     local n={delta[1]/length,delta[2]/length,delta[3]/length};local bodyN=rotate({w.q[1],-w.q[2],-w.q[3],-w.q[4]},n);local arm=cross(anchor,bodyN)
     local freeGyro=cross(w.omega,{w.I[1]*w.omega[1],w.I[2]*w.omega[2],w.I[3]*w.omega[3]})
     local angularFree={(torque[1]-freeGyro[1])/w.I[1]-.05*w.omega[1],(torque[2]-freeGyro[2])/w.I[2]-.05*w.omega[2],(torque[3]-freeGyro[3])/w.I[3]-.05*w.omega[3]}
     local angularR=rotate(w.q,cross(angularFree,anchor));local centripetal=rotate(w.q,cross(w.omega,cross(w.omega,anchor)))
     local relativeNormal,relativeSpeed2=0,0
     for j=1,3 do
      local relativeV=ropeVelocity[j]-w.v[j]-rotational[j];relativeSpeed2=relativeSpeed2+relativeV^2
      relativeNormal=relativeNormal+(-.05*ropeVelocity[j]-force[j]/w.mass+.2*w.v[j]-angularR[j]-centripetal[j])*n[j]
     end
     local inverse=1/ropeMass+1/w.mass;for j=1,3 do inverse=inverse+arm[j]^2/w.I[j] end
     local tension=length>=ropeLength-.005 and math.max(0,(relativeNormal+relativeSpeed2/ropeLength)/inverse) or 0
     for j=1,3 do
      force[j]=force[j]+tension*n[j];torque[j]=torque[j]+tension*arm[j]
      ropeVelocity[j]=ropeVelocity[j]+dt*(-(j==2 and 11 or 0)-.05*ropeVelocity[j]-tension*n[j]/ropeMass)
      ropePosition[j]=ropePosition[j]+ropeVelocity[j]*dt
     end
     maxStretch=math.max(maxStretch,math.max(0,length-ropeLength))
    end
    local gyro=cross(w.omega,{w.I[1]*w.omega[1],w.I[2]*w.omega[2],w.I[3]*w.omega[3]})
    for j=1,3 do w.v[j]=w.v[j]+dt*(force[j]/w.mass-(j==2 and 11 or 0)-.2*w.v[j]);w.omega[j]=w.omega[j]+dt*((torque[j]-gyro[j])/w.I[j]-.05*w.omega[j]) end
    w.x=w.x+w.v[1]*dt;w.y=w.y+w.v[2]*dt;w.z=w.z+w.v[3]*dt
    local q=w.q;local ox,oy,oz=w.omega[1],w.omega[2],w.omega[3]
    local dq={-q[2]*ox-q[3]*oy-q[4]*oz,q[1]*ox+q[3]*oz-q[4]*oy,q[1]*oy+q[4]*ox-q[2]*oz,q[1]*oz+q[2]*oy-q[3]*ox}
    local length=0;for j=1,4 do q[j]=q[j]+dq[j]*dt*.5;length=length+q[j]^2 end;for j=1,4 do q[j]=q[j]/math.sqrt(length) end
    if ropeActive then
     local r=rotate(w.q,anchor);local delta={ropePosition[1]-w.x-r[1],ropePosition[2]-w.y-r[2],ropePosition[3]-w.z-r[3]}
     local length=math.sqrt(delta[1]^2+delta[2]^2+delta[3]^2)
     if length>ropeLength then
      local n={delta[1]/length,delta[2]/length,delta[3]/length};local bodyN=rotate({w.q[1],-w.q[2],-w.q[3],-w.q[4]},n);local arm=cross(anchor,bodyN)
      local inverse=1/ropeMass+1/w.mass;for j=1,3 do inverse=inverse+arm[j]^2/w.I[j] end
      local lambda=(length-ropeLength)/inverse
      w.x=w.x+n[1]*lambda/w.mass;w.y=w.y+n[2]*lambda/w.mass;w.z=w.z+n[3]*lambda/w.mass
      for j=1,3 do ropePosition[j]=ropePosition[j]-n[j]*lambda/ropeMass end
      local x,y,z=arm[1]*lambda/w.I[1],arm[2]*lambda/w.I[2],arm[3]*lambda/w.I[3]
      local q=w.q;local nextQ={q[1]-(q[2]*x+q[3]*y+q[4]*z)/2,q[2]+(q[1]*x+q[3]*z-q[4]*y)/2,q[3]+(q[1]*y+q[4]*x-q[2]*z)/2,q[4]+(q[1]*z+q[2]*y-q[3]*x)/2}
      local size=0;for j=1,4 do size=size+nextQ[j]^2 end;for j=1,4 do w.q[j]=nextQ[j]/math.sqrt(size) end
      local rotational=rotate(w.q,cross(w.omega,anchor));local outward=0
      for j=1,3 do outward=outward+(ropeVelocity[j]-w.v[j]-rotational[j])*n[j] end
      local impulse=math.max(0,outward)/inverse
      for j=1,3 do w.v[j]=w.v[j]+n[j]*impulse/w.mass;ropeVelocity[j]=ropeVelocity[j]-n[j]*impulse/ropeMass;w.omega[j]=w.omega[j]+arm[j]*impulse/w.I[j] end
     end
    end
   end
   local current=pose(99999);local upNow=rotate(w.q,{0,1,0});local tiltNow=math.deg(math.acos(clamp(upNow[2],-1,1)))
   minimumY=math.min(minimumY,w.y);maximumY=math.max(maximumY,w.y)
   if now>=3 and firstUpright==0 and scenario:match("^flip") and upNow[2]>.95 then firstUpright=now-3 end
   if now>=3 and recoveryTime==0 and (scenario=='tilt' or scenario:match('^flip')) and tiltNow<5 and math.abs(w.omega[1])+math.abs(w.omega[3])<.2 then recoveryTime=now-3 end
   if scenario=='climb' and now>=3 and climbTime==0 and w.v[2]>=3.6 then climbTime=now-3 end
   if scenario=='brake' and now>=3 and now<8 and tiltTime==0 and math.abs(current.pitch)>=22.5 then tiltTime=now-3 end
   if scenario=='brake' and now>=8 and stopTime==0 and math.sqrt(w.v[1]^2+w.v[3]^2)<.2 then stopTime=now-8 end
   if now>seconds-10 then peakTailTilt=math.max(peakTailTilt,tiltNow) end
   if scenario=='cruise' and now>=10 and now<20 then pitchSum=pitchSum+p.pitch;pitchSquare=pitchSquare+p.pitch^2;pitchCount=pitchCount+1 end
   local horizontal=math.sqrt(w.v[1]^2+w.v[3]^2)
   maxSpeed=math.max(maxSpeed,horizontal);maxHorizontal=math.max(maxHorizontal,math.sqrt(w.x^2+w.z^2));maxX=math.max(maxX,math.abs(w.x));maxYaw=math.max(maxYaw,math.abs(pose(99999).yaw))
   if now>seconds-10 then tailSquare=tailSquare+horizontal^2+w.v[2]^2;tailCount=tailCount+1 end
   local up=rotate(w.q,{0,1,0});maxTilt=math.max(maxTilt,math.deg(math.acos(clamp(up[2],-1,1))));maxError=math.max(maxError,math.abs(w.y-target))
  end
  if scenario=='climb' then target=core.target.y end
  local error=math.abs(w.y-target);local speed=math.sqrt(w.v[1]^2+w.v[2]^2+w.v[3]^2)
  local success=not fault and error<1 and speed<.3 and peakTailTilt<5 and math.sqrt(tailSquare/math.max(1,tailCount))<.35
  if scenario=='tilt' or scenario:match('^flip') then success=success and recoveryTime>0 and recoveryTime<8 end
  if scenario=='climb' then success=success and climbTime>0 and climbTime<2 and w.y>84 end
  if scenario=='brake' then success=success and tiltTime>0 and tiltTime<1.5 and stopTime>0 and stopTime<releaseSpeed/(11*math.tan(math.rad(25)))+1.5 end
  if scenario:match('^rope') then success=success and maxStretch<.03 end
  total=total+1;if success then passed=passed+1 end
  print(profile..' '..scenario..' '..(success and 'PASS' or 'FAIL')..' error='..error..' tailTilt='..peakTailTilt..' speed='..speed..' recovery='..recoveryTime..' climb90='..climbTime..' tilt90='..tiltTime..' stop='..stopTime..' firstUpright='..firstUpright..' minimumY='..minimumY..' stretch='..maxStretch..' fault='..tostring(fault))
  if summary then
   local row={profile,scenario,success and 'PASS' or 'FAIL',error,maxTilt,speed,math.sqrt(tailSquare/math.max(1,tailCount)),peakTailTilt,minimumY,maximumY,target,firstUpright,recoveryTime,climbTime,tiltTime,stopTime,releaseSpeed,maxStretch}
   for i,v in ipairs(row) do row[i]=tostring(v) end
   summary:write(table.concat(row,',')..','..string.format('%q',tostring(fault or ''))..'\n')
  end
  end
 end
end
if summary then summary:close() end
print('Quad independent cable plant '..passed..'/'..total..'; no Minecraft world qualification')
if MINTCRAFT_UNIVERSAL_ASSERT then assert(passed==total,'Universal reference scenarios failed') end
