-- Exact compact/readable FPV contract parity; no mocked IO treated as hardware proof.
local function read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function loadBundle(path)
 local e=setmetatable({},{__index=function(_,k) if k:match('^MintCraft') then return nil end return _G[k] end});e._G=e
 local function field(v) return {getValue=function() return v end,setValue=function(x) v=x end,setText=function() end} end
 e.ui={label=field,textfield=function() return field('') end};e.addElement=function() end;e.input=function() return 0 end;e.output=function() end;e.getUniverseTime=function() return 0 end;e.getShipMass=function() return 0 end
 return assert(load(read(path)..'\nreturn _G.MintCraftFlightModules','fpv','t',e))()
end
local A=loadBundle(MINTCRAFT_FPV_DISTRIBUTED or 'platforms/sputnik/dist/mintcraft-autopilot-quad-fpv.lua');local B=loadBundle(assert(MINTCRAFT_FPV_READABLE))
local defs=assert(load(read('platforms/sputnik/src/vehicle_model.lua'),'defaults','t',{Portable=A[1],math=math,type=type,ipairs=ipairs,pairs=pairs,tostring=tostring,tonumber=tonumber}))()
local function groups()
 local gs={};for i=1,4 do local g=defs.defaults(1,i);g.kind='bearing';g.sails=12;g.thrust=.2;g.airflow=.05;g.powerA='minecraft:paper';g.powerB='minecraft:motor_'..i;gs[i]=g end;return gs
end
local function pose(t) return {tick=t,x=0,y=80,z=0,pitch=0,roll=0,yaw=0,vx=0,vy=0,vz=0,mass=32,ix=250,iy=400,iz=230,gravity=11,dimension='minecraft:overworld'} end
local cfg={gravity=11,climb=4,tilt=25,braking=4,margin=8,protected={}}
local a=assert(A[10].new(groups(),pose(100),cfg));local b=assert(B[10].new(groups(),pose(100),cfg))
local sa,sb=a.initialSignals,b.initialSignals
for tick=101,300 do
 local p=pose(tick);p.pitch=.2*math.sin(tick/8);p.roll=.1*math.cos(tick/9)
 if tick==140 then
  local f=a.filters.y;assert(a:apply({revision=1,mode='ALTITUDE',altitude=82,speed=0,heading=0},p));assert(b:apply({revision=1,mode='ALTITUDE',altitude=82,speed=0,heading=0},p));assert(a.filters.y==f)
  assert(not a:apply({revision=1,mode='ALTITUDE',altitude=90,speed=0,heading=0},p))
 end
 local command={forward=tick>180 and tick<200 and 1 or 0,left=0,vertical=tick>220 and tick<240 and 1 or 0}
 local ia,ib;sa,ia=a:step(p,command,sa);sb,ib=b:step(p,command,sb);assert(sa,ia);assert(sb,ib)
 for k,v in pairs(sa) do assert(v==sb[k] and v%1==0 and v>=0 and v<=15,'FPV compaction changed output') end
 assert(math.abs(a.target.y-b.target.y)<1e-10)
end
local passive=assert(A[10].new(groups(),pose(100),cfg))
local p=pose(101);p.vx=1
assert(passive:step(p,{forward=0,left=0,vertical=0},passive.initialSignals))
assert(not passive.quant.trackingFast,'Passive drift was mistaken for an operator acceleration/braking command')
p=pose(102);p.vx=1
assert(passive:step(p,{forward=1,left=0,vertical=0},passive.initialSignals));assert(passive.quant.trackingFast)
p=pose(103);p.vx=1
assert(passive:step(p,{forward=0,left=0,vertical=0},passive.initialSignals));assert(passive.quant.trackingFast,'Release dropped braking flow compensation')
for kind=1,3 do
 local g=groups();if kind==1 then g[2].sails=16 elseif kind==2 then for _,v in ipairs(g) do v.kind='small';v.thrust=1;v.airflow=.1 end else g[2].kind='small';g[2].thrust=1;g[2].airflow=.1 end
 local c=assert(A[10].new(g,pose(100),cfg));assert(c:step(pose(101),{forward=0,left=0,vertical=0},c.initialSignals))
end
local g=groups();g[1].dx=.1;g[1].dy=math.sqrt(.99);assert(not A[10].new(g,pose(100),cfg),'Unsupported tilted motor silently accepted')
-- Impossible moments must not consume the feasible vertical collective.
local p=pose(100);p=assert(A[10].pose(p));local gs=groups()
local model=assert(A[7].matrix(gs,p,{x=0,y=0,z=0},p.mass,{1,1,1,1}))
for _,torque in ipairs({0,100,-100}) do
 local values,proof=A[7].solve(model,{0,0,11,torque,0,torque});assert(values,proof)
 assert(math.abs(proof.actual[3]-11)<1e-8,'Attitude demand destroyed feasible collective')
 for _,v in ipairs(values) do assert(v>=0 and v<=15) end
end
-- Sub-level torque remains physically represented even near equal lift requests.
-- Measure the emitted RPM/force average, independently of the allocator proof.
local physics=A[3]
for _,torque in ipairs({.01,-.01}) do
 local values=assert(A[7].solve(model,{0,0,11,torque,0,0}))
 local _,meta=A[7].matrix(gs,p,{x=0,y=0,z=0},p.mass,{1,1,1,1})
 for i,m in ipairs(meta) do m.column=model.columns[i].response end
 local quant={};local up,moment=0,0
 for frame=1,2048 do
  local out=assert(A[7].signals(meta,values,quant))
  for i,m in ipairs(meta) do
   local rpm=physics.rpm(m.group.source,out[tostring(m.group.id)])
   local force=physics.force(rpm,m.pressure,m.axial,m.thrust,m.airflow)*m.group.members
   up=up+force/p.mass;moment=moment-m.group.z*force/p.ix
  end
 end
 assert(math.abs(up/2048-11)<.05,'Near-hover modulation lost mean lift')
 assert(math.abs(moment/2048-torque)<.003,'Weak signed torque was rounded away near hover')
end
local _,reason=A[7].decode('INVALID_GROUP');assert(reason:find('formulaire',1,true),'Opaque descriptor error returned')
assert(not a:step(pose(300),{forward=0,left=0,vertical=0},sa),'Repeated observation accepted')
print('FPV compact/readable parity, hot target without estimator reset, stale requests/observations and per-rotor models, collective priority and unsupported tilt refusal passed')
