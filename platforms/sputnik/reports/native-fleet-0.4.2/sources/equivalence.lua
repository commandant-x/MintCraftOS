local function read(p)local f=assert(io.open(p));local s=f:read('*a');f:close();return s end
local function loadController(p)
 local function field(v)local f={};f.getValue=function()return v end;f.setValue=function(x)v=x end;f.setText=f.setValue;return f end
 local e=setmetatable({},{__index=function(_,k)if type(k)=='string' and k:match('^MintCraft')then return nil end;return _G[k]end});e._G=e;e.ui={label=field,textfield=function()return field('')end};e.input=function()return 0 end;e.output=function()end;e.addElement=function()end;e.getUniverseTime=function()return 0 end;e.getShipMass=function()return 0 end
 return assert(load(read(p)..'\nreturn {Vehicle=MintCraftFlightModules[7],Flight=MintCraftFlightModules[10],Portable=MintCraftFlightModules[1]}','differential','t',e))()
end
local a=loadController('work/fleet-expansion/equivalence/baseline.lua');local b=loadController('platforms/sputnik/dist/mintcraft-autopilot-control.lua')
local defaults=assert(load(read('platforms/sputnik/src/vehicle_model.lua'),'defaults','t',{Portable=a.Portable,math=math,type=type,ipairs=ipairs,pairs=pairs,tostring=tostring,tonumber=tonumber}))().defaults
local function pose(t)return {tick=t,x=2*math.sin(t/20),z=2*math.cos(t/25),y=80+.1*math.sin(t/10),pitch=math.sin(t/15),roll=math.cos(t/15),yaw=math.sin(t/40),mass=t>250 and 28 or 32,ix=250,iy=400,iz=230,gravity=11,dimension='minecraft:overworld'}end
local function equal(x,y,path)
 assert(type(x)==type(y),path..' type');if type(x)=='table'then for k,v in pairs(x)do if k~='reason'then equal(v,y[k],path..'.'..tostring(k))end end;for k in pairs(y)do assert(x[k]~=nil,path..' added key '..tostring(k))end
 elseif type(x)=='number'then assert(math.abs(x-y)<=1e-10*math.max(1,math.abs(x)),path..' numeric mismatch '..x..'/'..y)
 else assert(x==y,path..' mismatch')end
end
for profile=1,5 do
 local g={};for i=1,(profile==3 and 6 or 4)do local v=defaults(profile==5 and 1 or profile,i);v.powerA='minecraft:stone';v.powerB='minecraft:group_'..i;if v.role=='drive'then v.reverseA='minecraft:stick';v.reverseB='minecraft:reverse_'..i end;if profile==5 then v.kind='bearing';v.sails=({8,12,16,20})[i];v.thrust=.2;v.airflow=.05 end;g[i]=v end
 local cfg={gravity=11,climb=1,tilt=8,margin=30,braking=1,protected={}}
 local x=assert(a.Flight.new(g,pose(100),cfg));local y=assert(b.Flight.new(g,pose(100),cfg));local sx,sy=x.initialSignals,y.initialSignals;equal(sx,sy,'initial')
 for t=101,600 do
  local p=pose(t);local c={forward=t%100<20 and .2 or 0,left=t%100<20 and .1 or 0,vertical=0}
  local ix,iy;sx,ix=x:step(a.Portable.copy(p),c,sx);sy,iy=y:step(b.Portable.copy(p),c,sy);equal(sx,sy,'signals');equal(ix,iy,'info');assert(sx)
 end
 print('Profile '..profile..': 500 updates, motor levels and numeric state identical to de8f704; diagnostics text excluded')
end
