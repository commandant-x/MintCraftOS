-- Exact compact/readable FPV contract parity; no mocked IO treated as hardware proof.
local function read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function loadBundle(path)
 local e=setmetatable({},{__index=function(_,k) if k:match('^MintCraft') then return nil end return _G[k] end});e._G=e
 local function field(v) return {getValue=function() return v end,setValue=function(x) v=x end,setText=function() end} end
 e.ui={label=field,textfield=function() return field('') end};e.addElement=function() end;e.input=function() return 0 end;e.output=function() end;e.getUniverseTime=function() return 0 end;e.getShipMass=function() return 0 end
 return assert(load(read(path)..'\nreturn _G.MintCraftFlightModules','fpv','t',e))()
end
local A=loadBundle('platforms/sputnik/dist/mintcraft-autopilot-quad-fpv.lua');local B=loadBundle(assert(MINTCRAFT_FPV_READABLE))
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
local g=groups();g[2].sails=16;assert(not A[10].new(g,pose(100),cfg),'Unvalidated mixed fast profile accepted')
g=groups();g[2].alpha=.2;assert(not A[10].new(g,pose(100),cfg),'Different rotor response accepted as identical')
g=groups();for _,v in ipairs(g) do v.kind='small' end;assert(not A[10].new(g,pose(100),cfg),'Unvalidated small fast profile accepted')
assert(not a:step(pose(300),{forward=0,left=0,vertical=0},sa),'Repeated observation accepted')
print('FPV compact/readable parity, hot target without estimator reset, stale requests/observations and unsupported motor refusals passed')
