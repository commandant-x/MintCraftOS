-- Independent moving-load rigid-body mechanics. No game access.
-- Position/velocity refer to a fixed body origin; COM is integrated independently.
-- Load changes preserve chassis pose/velocity and apply no collision impulse.
-- Derived from the audited 0.3.1 twin; NO controller allocation/geometry functions
-- are used by the physical integrator. Full actual inertia remains hidden except
-- for the three diagonal components exposed by Sputnik.
local function read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function field(v) return {getValue=function() return v end,setValue=function(x) v=x end,setText=function() end} end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function cross(a,b) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
local function mv(a,v) return {a[1][1]*v[1]+a[1][2]*v[2]+a[1][3]*v[3],a[2][1]*v[1]+a[2][2]*v[2]+a[2][3]*v[3],a[3][1]*v[1]+a[3][2]*v[2]+a[3][3]*v[3]} end
local function inverse(a)
 local x,y,z=a[1][1],a[2][2],a[3][3];local b,c,d=a[1][2],a[1][3],a[2][3]
 local det=x*y*z+2*b*c*d-x*d*d-y*c*c-z*b*b
 assert(x>0 and x*y-b*b>0 and det>0,'Actual inertia must be positive definite')
 return {{(y*z-d*d)/det,(c*d-b*z)/det,(b*d-c*y)/det},{(c*d-b*z)/det,(x*z-c*c)/det,(b*c-x*d)/det},{(b*d-c*y)/det,(b*c-x*d)/det,(x*y-b*b)/det}}
end
local function rotate(q,v) local t=cross({q[2],q[3],q[4]},v);local u=cross({q[2],q[3],q[4]},t);return {v[1]+2*(q[1]*t[1]+u[1]),v[2]+2*(q[1]*t[2]+u[2]),v[3]+2*(q[1]*t[3]+u[3])} end
-- Nine significant digits without LuaJ's expensive per-cell Java Formatter.
-- The mantissa is an exact integer below 1e9; precision is tested in native LuaJ.
local function csv(v)
 if type(v)=='number' then
  if v==0 or v%1==0 and math.abs(v)<1e9 then return tostring(v) end
  local e=math.floor(math.log(math.abs(v))/math.log(10));local m=math.floor(math.abs(v)*10^(-e)*1e8+.5)
  return (v<0 and '-' or '')..tostring(m)..'e'..tostring(e-8)
 end
 return '"'..tostring(v):gsub('"','""'):gsub('[\r\n]',' ')..'"'
end
local function row(f,values) local out={};for i,v in ipairs(values) do out[i]=csv(v) end;f:write(table.concat(out,',')..'\n') end
if MINTCRAFT_CAMPAIGN_MATH_TEST then return {inverse=inverse,mv=mv,cross=cross,rotate=rotate,csv=csv} end
local C=assert(MINTCRAFT_CAMPAIGN)
local fixture=C.fixture;local seconds=C.seconds;assert(seconds>=40)
local pressure={};for line in read(C.pressure):gmatch('[^\n]+') do local a,b=line:match('([^,]+),([^,]+)');if tonumber(a) then pressure[tonumber(a)]=tonumber(b) end end
local function air(y) if y<=-80 then return 1.5 elseif y>=320 then return 0 end;local n=math.floor(y);return pressure[n]+(pressure[n+1]-pressure[n])*(y-n) end
local env=setmetatable({},{__index=function(_,k) if type(k)=='string' and (k:match('^MintCraft') or k:match('^MINTCRAFT_')) then return nil end;return _G[k] end});env._G=env
 env.ui={label=field,textfield=function() return field('') end};env.addElement=function() end;env.input=function() return 0 end;env.output=function() end;env.getUniverseTime=function() return 0 end;env.getShipMass=function() return 0 end
local B=assert(load(read(C.controller)..'\nreturn _G.MintCraftFlightModules','campaign-controller','t',env))()
local defaults=assert(load(read(C.defaults),'defaults','t',{Portable=B[1],math=math,type=type,ipairs=ipairs,pairs=pairs,tostring=tostring,tonumber=tonumber}))().defaults
local events=assert(io.open(C.output..'/events.csv','w'));events:write('case,status,reason,frames,simulated_seconds,solver_steps\n')
local traceColumns='t,x,y,z,vx,vy,vz,pitch,yaw,roll,tilt,attitude_error,target_y,target_pitch,target_roll,forward,left,vertical,phase,u1,u2,u3,u4,rpm1,rpm2,rpm3,rpm4,residual,saturated,load_bias,rope_stretch,course,true_com_x,true_com_y,true_com_z,true_mass,true_ix,true_iy,true_iz,true_ixy,true_ixz,true_iyz,world_com_x,world_com_y,world_com_z,trim_pitch,trim_roll,trim_limited,qw,qx,qy,qz\n'
local function command(name,t)
 local f,l,v=0,0,0;local phase=t<5 and 0 or t<10 and 1 or t<16 and 2 or 3
 if t>=5 and t<10 then
  if name=='forward' or name=='brake' or name=='climb-forward' or name=='forward-left' or name=='forward-right' or name=='turn-left' or name=='turn-right' or name=='slalom' or name=='reverse-command' or name=='descend-left' then f=1 end
  if name=='reverse' or name=='reverse-left' or name=='reverse-right' then f=-1 end
  if name=='left' or name=='forward-left' or name=='reverse-left' or name=='turn-left' or name=='descend-left' then l=1 end
  if name=='right' or name=='forward-right' or name=='reverse-right' or name=='turn-right' then l=-1 end
  if name=='climb' or name=='climb-forward' or name=='vertical-cycle' then v=1 end
  if name=='descend' or name=='descend-left' then v=-1 end
  if name=='slalom' then l=(math.floor((t-5)/1.25)%2==0) and 1 or -1 end
 end
 if name=='reverse-command' and t>=10 and t<15 then f=-1;phase=1 end
 if name=='vertical-cycle' and t>=15 and t<20 then v=-1;phase=1 end
 if name=='recovery-diagonal' or name=='recovery-inverted' then phase=t<5 and 0 or t<13 and 4 or 3 end
 return {forward=f,left=l,vertical=v},phase
end
for _,name in ipairs(C.cases) do
 local groups={};for i=1,4 do
  local g=defaults(1,i);local r=fixture.rotors[i]
  for k,v in pairs(r) do g[k]=v end
  g.powerA='minecraft:paper';g.powerB='minecraft:campaign_rotor_'..i
  groups[i]=g
 end
 local baseMass=fixture.mass
 local I=fixture.inertia;local tensor={{I[1],I[4] or 0,I[5] or 0},{I[4] or 0,I[2],I[6] or 0},{I[5] or 0,I[6] or 0,I[3]}}
 local w={x=0,y=fixture.altitude or 80,z=0,v={0,0,0},q={1,0,0,0},omega={0,0,0},rpm={},linear={},mass=baseMass,I={I[1],I[2],I[3]},tensor=tensor,inverse=inverse(tensor)}
 w.com={fixture.comX or 0,fixture.comY or 0,fixture.comZ or 0}
 local function observed()
  if fixture.sensorFrame=='com' then return {w.x,w.y,w.z},w.v end
  local r=rotate(w.q,w.com);local rotational=rotate(w.q,cross(w.omega,w.com))
  return {w.x-r[1],w.y-r[2],w.z-r[3]},{w.v[1]-rotational[1],w.v[2]-rotational[2],w.v[3]-rotational[3]}
 end
 local function loadChange(event)
  local center,newMass,newTensor
  if event.payload then
   local load=event.payload;local mass=fixture.chassisMass or baseMass;newMass=mass+load.mass;center={}
   for i=1,3 do center[i]=load.mass*load.position[i]/newMass end
   newTensor={}
   local inertia=fixture.chassisInertia or fixture.inertia
   for i=1,3 do newTensor[i]={};for j=1,3 do newTensor[i][j]=(i==j and inertia[i] or 0) end end
   for _,part in ipairs({{mass=mass,p={0,0,0}},{mass=load.mass,p=load.position}}) do
    local d={};local norm=0;for i=1,3 do d[i]=part.p[i]-center[i];norm=norm+d[i]^2 end
    for i=1,3 do for j=1,3 do newTensor[i][j]=newTensor[i][j]+part.mass*((i==j and norm or 0)-d[i]*d[j]) end end
   end
  else center=event.center;newMass=event.mass or w.mass;newTensor=event.tensor or w.tensor end
  local delta={center[1]-w.com[1],center[2]-w.com[2],center[3]-w.com[3]}
  local shift=rotate(w.q,delta);local speed=rotate(w.q,cross(w.omega,delta))
  w.x=w.x+shift[1];w.y=w.y+shift[2];w.z=w.z+shift[3]
  for i=1,3 do w.v[i]=w.v[i]+speed[i] end
  w.com={center[1],center[2],center[3]};w.mass=newMass;w.tensor=newTensor;w.inverse=inverse(newTensor);w.I={newTensor[1][1],newTensor[2][2],newTensor[3][3]}
 end
 if fixture.initialLoad then loadChange(fixture.initialLoad) end
 local function pose(tick)
  local position,velocity=observed()
  local x,y,z=rotate(w.q,{1,0,0}),rotate(w.q,{0,1,0}),rotate(w.q,{0,0,1})
  return {tick=tick,x=position[1]+(fixture.noise or 0)*math.sin(tick*1.7),y=position[2]+(fixture.noise or 0)*math.sin(tick*2.3),z=position[3]+(fixture.noise or 0)*math.cos(tick*1.3),vx=velocity[1],vy=velocity[2],vz=velocity[3],pitch=math.deg(math.asin(clamp(-z[2],-1,1)))+(fixture.attitudeNoise or 0)*math.sin(tick*1.3),yaw=math.deg(math.atan2(z[1],z[3])),roll=math.deg(math.atan2(x[2],y[2]))+(fixture.attitudeNoise or 0)*math.cos(tick*1.7),mass=w.mass,ix=w.I[1],iy=w.I[2],iz=w.I[3],dimension='minecraft:overworld',gravity=11}
 end
 local config={gravity=11,climb=4,tilt=C.tilt or 20,braking=4,margin=fixture.radius,protected={},steering=name=='turn-left' or name=='turn-right' or name=='slalom'}
 local ok,core,why=pcall(B[10].new,groups,pose(100),config)
 if not ok then row(events,{name,'ERROR',tostring(core),0,0,0})
 elseif not core then row(events,{name,'REFUSED',tostring(why),0,0,0})
 else
  -- Initial equilibrium belongs to the plant, not the allocator under test.
  -- Non-equilibrium force offsets remain deliberate fixture disturbances.
  local axes={{1,1,1,1},{},{}};for i,g in ipairs(groups) do axes[2][i]=g.z;axes[3][i]=g.x end
  local gram={{0,0,0},{0,0,0},{0,0,0}}
  for i=1,3 do for j=1,3 do for k=1,4 do gram[i][j]=gram[i][j]+axes[i][k]*axes[j][k] end end end
  local equilibrium=mv(inverse(gram),{baseMass*11,0,0})
  for i,g in ipairs(groups) do
   local support=equilibrium[1]+g.z*equilibrium[2]+g.x*equilibrium[3];assert(support>0,'Fixture center outside positive lift support')
   local thrust=g.kind=='bearing' and g.thrust*g.sails^1.5 or g.thrust
   w.rpm[i]=name=='cold-hover' and 0 or support/(thrust*air(w.y+rotate(w.q,{g.x-w.com[1],g.y-w.com[2],g.z-w.com[3]})[2])*g.members)
  end
  local trace=assert(io.open(C.output..'/'..name..'.csv','w'));trace:write(traceColumns)
  local pending={};local signals=B[1].copy(core.initialSignals);local initialSignals=B[1].copy(signals);local actualDirections={1,1,1,1}
  local ropeActive=false;local ropePosition,ropeVelocity;local ropeLength=fixture.ropeLength or 5;local ropeMass=fixture.ropeMass or 12;local anchor={0,-1,0};local maxStretch=0
  local frames,solverSteps=0,0;local fault;local observations={};local lastInput;local changeIndex=1;local lastInfo={pitchTarget=0,rollTarget=0,targetY=w.y}
  local function record(t,c,phase,info)
   local position,velocity=observed()
   local p=pose(100+math.floor(t*20+.5));local up=rotate(w.q,{0,1,0});local py,pp,pr=math.rad(p.yaw),math.rad(info.pitchTarget or 0),math.rad(info.rollTarget or 0)
   local wanted={math.sin(py)*math.sin(pp)*math.cos(pr)-math.cos(py)*math.sin(pr),math.cos(pp)*math.cos(pr),math.cos(py)*math.sin(pp)*math.cos(pr)+math.sin(py)*math.sin(pr)}
   local tilt=math.deg(math.acos(clamp(up[2],-1,1)));local error=math.deg(math.acos(clamp(up[1]*wanted[1]+up[2]*wanted[2]+up[3]*wanted[3],-1,1)))
   row(trace,{t,position[1],position[2],position[3],velocity[1],velocity[2],velocity[3],p.pitch,p.yaw,p.roll,tilt,error,core.target.y,info.pitchTarget or 0,info.rollTarget or 0,c.forward,c.left,c.vertical,phase,signals['1'],signals['2'],signals['3'],signals['4'],w.rpm[1],w.rpm[2],w.rpm[3],w.rpm[4],info.residual or 0,info.saturated and 1 or 0,info.loadBias or 0,maxStretch,info.course or p.yaw,w.com[1],w.com[2],w.com[3],w.mass,w.I[1],w.I[2],w.I[3],w.tensor[1][2],w.tensor[1][3],w.tensor[2][3],w.x,w.y,w.z,info.trimPitch or 0,info.trimRoll or 0,info.trimLimited and 1 or 0,w.q[1],w.q[2],w.q[3],w.q[4]})
  end
  record(0,{forward=0,left=0,vertical=0},0,lastInfo)
  for step=1,seconds*20 do
   local now=step*.05;local wind=fixture.wind or {0,0,0}
   if name=='gust' and now>=5 and now<10 then wind={5,0,-3} end
   if step==100 then
    if name=='recovery-diagonal' then local a=math.rad(15)/2;w.q={math.cos(a),math.sin(a)/math.sqrt(2),0,math.sin(a)/math.sqrt(2)};w.omega={.03,0,-.02} end
    if name=='recovery-inverted' then w.q={0,0,0,1};w.omega={0,0,0} end
    if name=='load-swing' then
     ropeActive=true;anchor={-w.com[1],-1-w.com[2],-w.com[3]};local r=rotate(w.q,anchor);local a=math.rad(20)
     ropePosition={w.x+r[1]+ropeLength*math.sin(a),w.y+r[2]-ropeLength*math.cos(a),w.z+r[3]};ropeVelocity={w.v[1],w.v[2],w.v[3]}
    end
   end
   while fixture.changes and fixture.changes[changeIndex] and now>=fixture.changes[changeIndex].at do loadChange(fixture.changes[changeIndex]);changeIndex=changeIndex+1 end
   local p=pose(100+step)
   if fixture.sampledVelocity and lastInput then p.vx=(p.x-lastInput.x)/.05;p.vy=(p.y-lastInput.y)/.05;p.vz=(p.z-lastInput.z)/.05 end
   lastInput={x=p.x,y=p.y,z=p.z}
   observations[#observations+1]=p
   if fixture.poseDelay and #observations>fixture.poseDelay then p=observations[#observations-fixture.poseDelay];p.tick=100+step end
   if #observations>8 then table.remove(observations,1) end
   local c,phase=command(name,now)
   local ran,requested,info=pcall(core.step,core,p,c,signals)
   if not ran then fault='ERROR: '..tostring(requested);break end
   if not requested then fault=tostring(info);break end
   for _,g in ipairs(groups) do local s=requested[tostring(g.id)];if not finite(s) or s<0 or s>15 or s%1~=0 then fault='Invalid emitted signal' end end
   if fault then break end
   pending[#pending+1]=B[1].copy(requested)
   for i,g in ipairs(groups) do
    local delay=fixture.rotorDelays and fixture.rotorDelays[i] or fixture.delay or 1
    local applied=pending[#pending-delay] or initialSignals;local signal=applied[tostring(g.id)]
    local rpm=(signal==0 and g.source or g.source*(15-signal)/16)*(fixture.sourceFactor or 1)
    local alpha=(g.kind=='bearing' and .4/math.sqrt(g.sails) or .15)*(fixture.spoolFactor or 1)
    w.rpm[i]=w.rpm[i]+alpha*(rpm-w.rpm[i])
   end
   if #pending>8 then table.remove(pending,1) end
   signals=requested;lastInfo=info
   for _=1,10 do
    local dt=.005;local force={0,0,0};local torque={0,0,0}
    for i,g in ipairs(groups) do
     local sign=actualDirections[g.id];local direction={g.dx*sign,g.dy*sign,g.dz*sign};local worldDir=rotate(w.q,direction);local r={g.x-w.com[1],g.y-w.com[2],g.z-w.com[3]};local rw=rotate(w.q,r);local rotational=rotate(w.q,cross(w.omega,r))
     local f
     if g.kind=='linear' or g.kind=='surface' then
      if g.role=='lift' then f=baseMass*11+(w.linear[i]-g.neutral)*g.gain else f=w.linear[i]*g.gain;if g.kind=='surface' then local forward=rotate(w.q,{0,0,1});local flow=w.v[1]*forward[1]+w.v[2]*forward[2]+w.v[3]*forward[3];f=f*flow*math.abs(flow) end end
     else
      local t=g.kind=='bearing' and g.thrust*g.sails^1.5 or g.thrust;local a=g.kind=='bearing' and g.airflow*math.sqrt(g.sails) or g.airflow
      local rpm=w.rpm[i];local axial=(w.v[1]+rotational[1]-wind[1])*worldDir[1]+(w.v[2]+rotational[2]-wind[2])*worldDir[2]+(w.v[3]+rotational[3]-wind[3])*worldDir[3]
      f=rpm>1/30 and t*rpm*air(w.y+rw[2])*(fixture.pressureFactor or 1)*clamp(1-axial/(a*rpm),0,1)*g.members or 0
     end
     f=f*(fixture.rotorFactors and fixture.rotorFactors[i] or 1)
     if g.role=='yaw-left' or g.role=='yaw-right' then torque[2]=torque[2]+(g.role=='yaw-left' and -f or f)
     else
      for j=1,3 do force[j]=force[j]+worldDir[j]*f end
      local tau=cross(r,{direction[1]*f,direction[2]*f,direction[3]*f});for j=1,3 do torque[j]=torque[j]+tau[j] end
     end
    end
    if ropeActive then
     anchor={-w.com[1],-1-w.com[2],-w.com[3]}
     local r=rotate(w.q,anchor);local attach={w.x+r[1],w.y+r[2],w.z+r[3]};local rotational=rotate(w.q,cross(w.omega,anchor))
     local delta={};local length=0;for j=1,3 do delta[j]=ropePosition[j]-attach[j];length=length+delta[j]^2 end;length=math.sqrt(length)
     local n={delta[1]/length,delta[2]/length,delta[3]/length};local bodyN=rotate({w.q[1],-w.q[2],-w.q[3],-w.q[4]},n);local arm=cross(anchor,bodyN)
     local freeGyro=cross(w.omega,mv(w.tensor,w.omega))
     local angularFree=mv(w.inverse,{torque[1]-freeGyro[1],torque[2]-freeGyro[2],torque[3]-freeGyro[3]});for j=1,3 do angularFree[j]=angularFree[j]-.05*w.omega[j] end
     local angularR=rotate(w.q,cross(angularFree,anchor));local centripetal=rotate(w.q,cross(w.omega,cross(w.omega,anchor)))
     local relativeNormal,relativeSpeed2=0,0
     for j=1,3 do
      local relativeV=ropeVelocity[j]-w.v[j]-rotational[j];relativeSpeed2=relativeSpeed2+relativeV^2
      relativeNormal=relativeNormal+(-.05*ropeVelocity[j]-force[j]/w.mass+.2*(w.v[j]-wind[j])-angularR[j]-centripetal[j])*n[j]
     end
     local inverse=1/ropeMass+1/w.mass;local inverseArm=mv(w.inverse,arm);for j=1,3 do inverse=inverse+arm[j]*inverseArm[j] end
     local tension=length>=ropeLength-.005 and math.max(0,(relativeNormal+relativeSpeed2/ropeLength)/inverse) or 0
     for j=1,3 do
      force[j]=force[j]+tension*n[j];torque[j]=torque[j]+tension*arm[j]
      ropeVelocity[j]=ropeVelocity[j]+dt*(-(j==2 and 11 or 0)-.05*ropeVelocity[j]-tension*n[j]/ropeMass)
      ropePosition[j]=ropePosition[j]+ropeVelocity[j]*dt
     end
     maxStretch=math.max(maxStretch,math.max(0,length-ropeLength))
    end
    local gyro=cross(w.omega,mv(w.tensor,w.omega))
    local angular=mv(w.inverse,{torque[1]-gyro[1],torque[2]-gyro[2],torque[3]-gyro[3]})
    for j=1,3 do w.v[j]=w.v[j]+dt*(force[j]/w.mass-(j==2 and 11 or 0)-.2*(w.v[j]-wind[j]));w.omega[j]=w.omega[j]+dt*(angular[j]-.05*w.omega[j]) end
    w.x=w.x+w.v[1]*dt;w.y=w.y+w.v[2]*dt;w.z=w.z+w.v[3]*dt
    local q=w.q;local ox,oy,oz=w.omega[1],w.omega[2],w.omega[3]
    local dq={-q[2]*ox-q[3]*oy-q[4]*oz,q[1]*ox+q[3]*oz-q[4]*oy,q[1]*oy+q[4]*ox-q[2]*oz,q[1]*oz+q[2]*oy-q[3]*ox}
    local length=0;for j=1,4 do q[j]=q[j]+dq[j]*dt*.5;length=length+q[j]^2 end;for j=1,4 do q[j]=q[j]/math.sqrt(length) end
    if ropeActive then
     anchor={-w.com[1],-1-w.com[2],-w.com[3]}
     local r=rotate(w.q,anchor);local delta={ropePosition[1]-w.x-r[1],ropePosition[2]-w.y-r[2],ropePosition[3]-w.z-r[3]}
     local length=math.sqrt(delta[1]^2+delta[2]^2+delta[3]^2)
     if length>ropeLength then
      local n={delta[1]/length,delta[2]/length,delta[3]/length};local bodyN=rotate({w.q[1],-w.q[2],-w.q[3],-w.q[4]},n);local arm=cross(anchor,bodyN)
      local inverse=1/ropeMass+1/w.mass;local inverseArm=mv(w.inverse,arm);for j=1,3 do inverse=inverse+arm[j]*inverseArm[j] end
      local lambda=(length-ropeLength)/inverse
      w.x=w.x+n[1]*lambda/w.mass;w.y=w.y+n[2]*lambda/w.mass;w.z=w.z+n[3]*lambda/w.mass
      for j=1,3 do ropePosition[j]=ropePosition[j]-n[j]*lambda/ropeMass end
      local x,y,z=inverseArm[1]*lambda,inverseArm[2]*lambda,inverseArm[3]*lambda
      local q=w.q;local nextQ={q[1]-(q[2]*x+q[3]*y+q[4]*z)/2,q[2]+(q[1]*x+q[3]*z-q[4]*y)/2,q[3]+(q[1]*y+q[4]*x-q[2]*z)/2,q[4]+(q[1]*z+q[2]*y-q[3]*x)/2}
      local size=0;for j=1,4 do size=size+nextQ[j]^2 end;for j=1,4 do w.q[j]=nextQ[j]/math.sqrt(size) end
      local rotational=rotate(w.q,cross(w.omega,anchor));local outward=0
      for j=1,3 do outward=outward+(ropeVelocity[j]-w.v[j]-rotational[j])*n[j] end
      local impulse=math.max(0,outward)/inverse
      for j=1,3 do w.v[j]=w.v[j]+n[j]*impulse/w.mass;ropeVelocity[j]=ropeVelocity[j]-n[j]*impulse/ropeMass;w.omega[j]=w.omega[j]+inverseArm[j]*impulse end
     end
    end
   end
   solverSteps=solverSteps+10;frames=step
   record(now,c,phase,info)
   local state={w.x,w.y,w.z,w.v[1],w.v[2],w.v[3],w.q[1],w.q[2],w.q[3],w.q[4]}
   for _,v in ipairs(state) do if not finite(v) then fault='Nonfinite physical state' end end
   if fault then break end
   if w.y<0 or w.y>315 or math.abs(w.x)>5000 or math.abs(w.z)>5000 then fault='Declared simulation envelope crossed (ground y=0 / atmosphere y=315 / horizontal 5000m); no contact modeled';break end
  end
  trace:close();row(events,{name,fault and (fault:match('^ERROR:') and 'ERROR' or 'FAULT') or 'COMPLETE',fault or '',frames,frames*.05,solverSteps})
  print(fixture.id,name,fault or 'COMPLETE',frames)
 end
end
events:close()
