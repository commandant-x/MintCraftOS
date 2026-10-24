-- Independent rigid-body test plant. Runs the shipped native nodes unchanged.
-- Not a Minecraft/Sable solver: no terrain, collisions, joints or full inertia tensor.
local outDir=assert(MINTCRAFT_TWIN_OUTPUT,'Set MINTCRAFT_TWIN_OUTPUT before loading')
local profile=MINTCRAFT_TWIN_PROFILE or {mass=65,armX=3,armZ=2,height=1,ix=250,iy=400,iz=230}
local function read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function cross(a,b) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
local function dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
local function mul(a,b)
 return {a[1]*b[1]-a[2]*b[2]-a[3]*b[3]-a[4]*b[4],
 a[1]*b[2]+a[2]*b[1]+a[3]*b[4]-a[4]*b[3],
 a[1]*b[3]-a[2]*b[4]+a[3]*b[1]+a[4]*b[2],
 a[1]*b[4]+a[2]*b[3]-a[3]*b[2]+a[4]*b[1]}
end
local function rotate(q,v)
 local t=cross({q[2],q[3],q[4]},v)
 local u=cross({q[2],q[3],q[4]},t)
 return {v[1]+2*(q[1]*t[1]+u[1]),v[2]+2*(q[1]*t[2]+u[2]),v[3]+2*(q[1]*t[3]+u[3])}
end
local function axis(i,angle) local q={math.cos(angle/2),0,0,0};q[i+1]=math.sin(angle/2);return q end
local function orientation(p,y,r) return mul(mul(axis(2,math.rad(y)),axis(1,math.rad(p))),axis(3,math.rad(r))) end
local function euler(q)
 local x,y,z=rotate(q,{1,0,0}),rotate(q,{0,1,0}),rotate(q,{0,0,1})
 return math.deg(math.asin(clamp(-z[2],-1,1))),math.deg(math.atan2(z[1],z[3])),math.deg(math.atan2(x[2],y[2]))
end
-- Pressure from the actual Java Sable oracle, not the controller implementation.
local pressures={}
for line in read('platforms/sputnik/tests/fixtures/sable-pressure.csv'):gmatch('[^\n]+') do
 local h,p=line:match('([^,]+),([^,]+)');pressures[tonumber(h)]=tonumber(p)
end
local function pressure(y)
 if y<=-80 then return 1.5 elseif y>=320 then return 0 end
 local n=math.floor(y);return pressures[n]+(pressures[n+1]-pressures[n])*(y-n)
end
-- Sanity checks independent of the production geometry/allocation code.
for _,angles in ipairs({{7,35,-4},{-9,-160,8},{0,90,0}}) do
 local p,y,r=euler(orientation(angles[1],angles[2],angles[3]))
 assert(math.abs(p-angles[1])<1e-8 and math.abs(y-angles[2])<1e-8 and math.abs(r-angles[3])<1e-8)
end
assert(cross({0,0,2},{0,10,0})[1]==-20)
local scripts={consent=read('platforms/sputnik/dist/mintcraft-test-enable.lua'),keyboard=read('platforms/sputnik/dist/mintcraft-typewriter.lua'),quad=read(MINTCRAFT_TWIN_CONTROLLER or 'platforms/sputnik/dist/mintcraft-quad-control.lua')}
local enable='minecraft:pink_wool,minecraft:pink_wool'
local keyItems={'blue_wool','orange_wool','lime_wool','red_wool','white_wool','black_wool'}
local keyNames={'W','S','Q','D','Space','Shift'}
local rotorItems={'iron_ingot','copper_ingot','gold_ingot','diamond'}
local cases={
 {name='level_hover',seconds=30},
 {name='level_drop_2ms',drop=-2,seconds=30},
 {name='level_drop_5ms',drop=-5,seconds=30},
 {name='cold_rotors',cold=true,seconds=30},
 {name='tilt_pitch_5deg',pitch=5,seconds=30},
 {name='tilt_roll_5deg',roll=5,seconds=30},
 {name='tilt_yaw_90deg',pitch=4,roll=-3,yaw=90,seconds=30},
 {name='space_then_hold',command='Space',seconds=35},
 {name='forward_then_brake',command='W',seconds=40},
 {name='diagonal_then_brake',command='WQ',seconds=40},
 {name='mass_loss_15percent',massLoss=true,seconds=35},
 {name='no_airframe_drag',drag=0,angularDrag=0,command='W',seconds=40},
 {name='radio_delay_2ticks',delay=2,command='W',seconds=40},
 {name='radio_delay_4ticks',delay=4,pitch=5,seconds=40},
 {name='heavy_85kg',mass=85,seconds=30},
 {name='light_40kg',mass=40,seconds=30},
 {name='noise_position_2cm',noise=.02,seconds=35},
 {name='gust_1ms',gust=true,seconds=40},
 {name='inertia_quarter',inertiaScale=.25,pitch=4,roll=-3,seconds=35},
 {name='inertia_fourfold',inertiaScale=4,pitch=4,roll=-3,seconds=35},
 {name='com_offset_10cm',com={.1,0,0},seconds=30,stress=true},
 {name='com_offset_25cm',com={.25,0,0},seconds=30,stress=true},
 {name='rotor_weak_10percent',weak=.9,seconds=30,stress=true},
 {name='swapped_front_rear',swap=true,pitch=3,seconds=15,stress=true},
 {name='competing_tx_15',jam=true,seconds=15,stress=true},
 {name='reversed_transmission',reverse=true,seconds=15,stress=true},
}
local summary=assert(io.open(outDir..'/summary.csv','w'))
summary:write('scenario,stress,status,final_altitude_error_m,max_altitude_error_m,min_altitude_m,max_tilt_deg,final_speed_ms,final_horizontal_error_m,max_rotor_spread,first_fault\n')
for _,case in ipairs(cases) do
 local w={tick=100,pos={0,80,0},v={0,0,0},q=orientation(case.pitch or 0,case.yaw or 0,case.roll or 0),omega={0,0,0},
 mass=case.mass or profile.mass,I={profile.ix*(case.inertiaScale or 1),profile.iy*(case.inertiaScale or 1),profile.iz*(case.inertiaScale or 1)},bus={},tx={},queue={},rpm={},requested={},actual={},com=case.com or {0,0,0},time=0}
 local function sensorPosition()
  local offset=rotate(w.q,{-w.com[1],-w.com[2],-w.com[3]})
  local n=case.noise or 0
  return w.pos[1]+offset[1]+n*math.sin(w.tick*1.71),w.pos[2]+offset[2]+n*math.sin(w.tick*2.13),w.pos[3]+offset[3]+n*math.sin(w.tick*1.37)
 end
 local function env(name)
  local e=setmetatable({},{__index=function(_,key) if type(key)=='string' and key:match('^MintCraft') then return nil end return _G[key] end});e._G=e;e.values={};e.outputs={}
  e.input=function(k) return e.values[k] or 0 end;e.output=function(k,v) e.outputs[k]=v end
  e.ui={label=function() return {setText=function() end} end,
   checkbox=function() local c={v=false};c.isChecked=function() return c.v end;return c end,
   textfield=function() local c={v=''};c.getValue=function() return c.v end;c.setValue=function(v) c.v=v end;return c end,
   itempicker=function() local c={v='minecraft:air'};c.getItem=function() return c.v end;return c end}
  e.addElement=function() end;e.display=function() end
  e.getShipMass=function() return w.mass end;e.getInertiaTensor=function() return w.I[1],w.I[2],w.I[3] end
  e.getPosition=sensorPosition;e.getOrientation=function() return euler(w.q) end
  e.getUniverseTime=function() return w.tick end;e.getDimension=function() return 'minecraft:overworld' end
  e.receiveWirelessRedstone=function(a,b)
   local id=a..','..b;local tx=w.tx[id]
   return math.max(w.bus[id] or 0,tx and w.tick-tx.tick<10 and tx.value or 0)
  end
  e.transmitWirelessRedstone=function(a,b,value)
   assert(name=='quad' and value%1==0 and value>=0 and value<=15)
   local id=a..','..b;w.requested[id]=value
   w.queue[#w.queue+1]={id=id,value=value,due=w.tick+(case.delay or 1)}
  end
  e.run=assert(load(scripts[name],name,'t',e));e.run();return e
 end
 local consent,keyboard,quad=env('consent'),env('keyboard'),env('quad')
 consent.MintCraftConsent.a.v='minecraft:pink_wool';consent.MintCraftConsent.b.v='minecraft:pink_wool'
 for i,name in ipairs(keyNames) do
  local k=keyboard.MintCraftTypewriter.keys[name];k.a.v='minecraft:stick';k.b.v='minecraft:'..keyItems[i]
 end
 keyboard.MintCraftTypewriter.verified.v=true
 local qs=quad.MintCraftQuad;qs.checked.v=true;qs.physical.v=true
 qs.physicalFields.armX.value.v=tostring(profile.armX);qs.physicalFields.armZ.value.v=tostring(profile.armZ);qs.physicalFields.height.value.v=tostring(profile.height)
 local channels={}
 for i,r in ipairs(qs.rotors) do r.a.v='minecraft:paper';r.b.v='minecraft:'..rotorItems[i];channels[i]=r.a.v..','..r.b.v end
 local function graph()
  local c,k=consent.outputs,keyboard.outputs
  -- Snapshot all previous outputs before evaluating any node (native graph order).
  keyboard.values={Enable=c.Enable}
  quad.values={['Flight Enable']=c.Enable,['Enable binding']=c.Binding,['Keyboard bindings']=k.Bindings,['Commands valid']=k['Commands valid'],['Forward demand']=k['Forward demand'],['Left demand']=k['Left demand'],['Vertical demand']=k['Vertical demand']}
  consent.run();keyboard.run();quad.run()
 end
 -- Ground support during explicit OFF and the permission/graph handshake.
 for _=1,8 do w.tick=w.tick+1;graph() end
 w.bus[enable]=15
 for _=1,6 do w.tick=w.tick+1;graph() end
 assert(quad.outputs.Active==1,'fixture cannot arm: '..tostring(quad.outputs.Status))
 local neutral=w.mass*11/(4*pressure(w.pos[2]+profile.height))
 for i=1,4 do w.rpm[i]=case.cold and 0 or neutral end
 w.v[2]=case.drop or 0
 local maxTilt,maxError,minHeight,maxSpread=0,0,80,0
 local firstFault,lastTarget,activeLost=nil,80,false
 local lastTargetX,lastTargetZ=quad.MintCraftQuad.core.target.x,quad.MintCraftQuad.core.target.z
 local trace=assert(io.open(outDir..'/'..case.name..'.csv','w'))
 trace:write('time,x,y,z,target_y,vx,vy,vz,pitch,yaw,roll,tilt,active,mass,r1,r2,r3,r4,rpm1,rpm2,rpm3,rpm4\n')
 local steps=case.seconds*20
 for frame=1,steps do
  w.tick=w.tick+1;w.time=frame/20
  if case.massLoss and frame==120 then w.mass=w.mass*.85;for j=1,3 do w.I[j]=w.I[j]*.85 end end
  for i,name in ipairs(keyNames) do
   local on=case.command and w.time>=4 and w.time<6 and ((case.command=='WQ' and (name=='W' or name=='Q')) or case.command==name)
   w.bus['minecraft:stick,minecraft:'..keyItems[i]]=on and 15 or 0
  end
  if case.jam then w.bus[channels[1]]=15 end
  local pending={}
  for _,tx in ipairs(w.queue) do if tx.due<=w.tick then w.tx[tx.id]={value=tx.value,tick=w.tick} else pending[#pending+1]=tx end end
  w.queue=pending
  graph()
  if quad.MintCraftQuad.core then lastTargetX=quad.MintCraftQuad.core.target.x;lastTargetZ=quad.MintCraftQuad.core.target.z end
  if quad.outputs.Active~=1 then activeLost=true end
  if not firstFault and quad.outputs['Last fault']~='' then firstFault=quad.outputs['Last fault'] end
  lastTarget=quad.outputs['Target altitude'] or lastTarget
  local low,high=15,0
  for i=1,4 do
   local channel=channels[case.swap and ({3,4,1,2})[i] or i]
   local tx=w.tx[channel];local signal=math.max(w.bus[channel] or 0,tx and w.tick-tx.tick<10 and tx.value or 0)
   w.actual[i]=signal;low=math.min(low,signal);high=math.max(high,signal)
   local target=signal==0 and 256 or 256*(15-signal)/16
   if case.reverse and signal>0 then target=signal==15 and 0 or 256*16/(15-signal);if target>256 then target=0 end end
   -- Aeronautics updates propeller rotation once per Minecraft tick (not physics substep).
   w.rpm[i]=w.rpm[i]+.15*(target-w.rpm[i])
  end
  maxSpread=math.max(maxSpread,high-low)
  -- Ten 5ms rigid-body substeps per graph tick; no Euler-angle plant integration.
  for _=1,10 do
   local dt=.005;local up=rotate(w.q,{0,1,0});local force=0;local torque={0,0,0}
   for i,loc in ipairs({{-profile.armX,profile.height,profile.armZ},{profile.armX,profile.height,profile.armZ},{-profile.armX,profile.height,-profile.armZ},{profile.armX,profile.height,-profile.armZ}}) do
    local r={loc[1]-w.com[1],loc[2]-w.com[2],loc[3]-w.com[3]};local rw=rotate(w.q,r)
    local rotational=rotate(w.q,cross(w.omega,r))
    local axial=dot({w.v[1]+rotational[1],w.v[2]+rotational[2],w.v[3]+rotational[3]},up)
    local rpm=w.rpm[i];local f=rpm>1/30 and rpm*pressure(w.pos[2]+rw[2])*clamp(1-axial/(.1*rpm),0,1) or 0
    if i==1 and case.weak then f=f*case.weak end
    force=force+f;local tau=cross(r,{0,f,0});for j=1,3 do torque[j]=torque[j]+tau[j] end
   end
   local iw={w.I[1]*w.omega[1],w.I[2]*w.omega[2],w.I[3]*w.omega[3]};local gyro=cross(w.omega,iw)
   for j=1,3 do
    local gust=case.gust and w.time>=5 and w.time<6 and j==1 and 1 or 0
    local acc=up[j]*force/w.mass-(j==2 and 11 or 0)-(case.drag==nil and .05 or case.drag)*w.v[j]+gust
    w.v[j]=w.v[j]+acc*dt;w.pos[j]=w.pos[j]+w.v[j]*dt
    w.omega[j]=w.omega[j]+((torque[j]-gyro[j])/w.I[j]-(case.angularDrag==nil and .05 or case.angularDrag)*w.omega[j])*dt
   end
   local dq=mul(w.q,{0,w.omega[1],w.omega[2],w.omega[3]});local norm=0
   for j=1,4 do w.q[j]=w.q[j]+.5*dq[j]*dt;norm=norm+w.q[j]^2 end
   for j=1,4 do w.q[j]=w.q[j]/math.sqrt(norm) end
  end
  local p,y,r=euler(w.q);local tilt=math.deg(math.acos(clamp(rotate(w.q,{0,1,0})[2],-1,1)))
  maxTilt=math.max(maxTilt,tilt);maxError=math.max(maxError,math.abs(w.pos[2]-lastTarget));minHeight=math.min(minHeight,w.pos[2])
  local values={w.time,w.pos[1],w.pos[2],w.pos[3],lastTarget,w.v[1],w.v[2],w.v[3],p,y,r,tilt,quad.outputs.Active,w.mass}
  for i=1,4 do values[#values+1]=w.actual[i] end;for i=1,4 do values[#values+1]=w.rpm[i] end
  for j,v in ipairs(values) do values[j]=string.format('%.6f',v) end
  trace:write(table.concat(values,',')..'\n')
  if w.pos[2]<-50 or w.pos[2]>350 then break end -- Test-world boundary, not a controller timeout.
 end
 trace:close()
 local finalError=math.abs(w.pos[2]-lastTarget);local speed=math.sqrt(dot(w.v,w.v))
 local horizontal=math.sqrt((w.pos[1]-lastTargetX)^2+(w.pos[3]-lastTargetZ)^2)
 local pass=not activeLost and finalError<.3 and speed<.2 and horizontal<.3 and maxTilt<25
 local status=pass and 'PASS' or 'FAIL'
 local function csv(s) return '"'..tostring(s):gsub('"','""')..'"' end
 summary:write(string.format('%s,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%s\n',case.name,tostring(case.stress or false),status,finalError,maxError,minHeight,maxTilt,speed,horizontal,maxSpread,csv(firstFault or '')))
 summary:flush()
 print(string.format('%s: %s error=%.3fm tilt=%.2fdeg speed=%.3fm/s fault=%s',case.name,status,finalError,maxTilt,speed,firstFault or 'none'))
end
summary:close()
