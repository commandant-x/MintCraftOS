-- Native, versioned configuration and physical wrench model. No hardware IO.
local M={schema=1}
local A=Portable
local finite=A.finite
local function clip(v,a,b) return math.max(a,math.min(b,v)) end
M.clip=clip;M.finite=finite;M.copy=A.copy
M.fields={'id','kind','role','x','y','z','dx','dy','dz','source','sails','thrust','airflow','gain','neutral','fallback','members','powerA','powerB','reverseA','reverseB','clutchA','clutchB','run','alpha','bias','support'}
local numeric={}
for _,key in ipairs(M.fields) do if key~='kind' and key~='role' and not key:match('[AB]$') then numeric[key]=true end end
function M.item(v) return type(v)=='string' and #v<=192 and v~='minecraft:air' and v:match('^[a-z0-9_.%-]+:[a-z0-9_./%-]+$')~=nil end
function M.pair(a,b) return M.item(a) and M.item(b) end
function M.encode(g)
 local values={'MCV1'}
 for _,key in ipairs(M.fields) do local value=g[key];values[#values+1]=value==nil and '' or tostring(value) end
 return table.concat(values,';')
end
function M.decode(text)
 if type(text)~='string' or #text>2400 then return nil,'Descriptor absent/oversize' end
 local parts={} for v in (text..';'):gmatch('(.-);') do parts[#parts+1]=v end
 if parts[1]~='MCV1' or #parts~=#M.fields+1 then return nil,'Descriptor schema/field count' end
 local g={}
 for i,key in ipairs(M.fields) do
  local value=parts[i+1]
  if numeric[key] then value=tonumber(value);if not finite(value) then return nil,'Numeric '..key end end
  g[key]=value
 end
 return g
end
function M.defaults(profile,index)
 local g={id=index,kind='small',role='lift',x=0,y=0,z=0,dx=0,dy=1,dz=0,source=256,sails=12,thrust=1,airflow=.1,gain=1,neutral=8,fallback=-1,members=1,run=0,alpha=.15,bias=0,support=1,
  powerA='minecraft:air',powerB='minecraft:air',reverseA='',reverseB='',clutchA='',clutchB=''}
 if profile==1 then g.x=index%2==1 and -3 or 3;g.z=index<=2 and 5 or -5
 elseif profile==2 then
  if index==1 then g.kind='linear';g.role='lift';g.gain=1;g.support=1
  elseif index==2 then g.role='drive';g.dy=0;g.dz=1;g.support=0;g.fallback=15
  else g.kind='surface';g.role=index==3 and 'yaw-left' or 'yaw-right';g.dy=1;g.support=0;g.neutral=0;g.fallback=0;g.gain=1 end
 elseif profile==3 then
  if index<=4 then g.x=index%2==1 and -3 or 3;g.z=index<=2 and 5 or -5
  else g.role='drive';g.dx=0;g.dy=0;g.dz=1;g.x=index==5 and -3 or 3;g.z=-5;g.members=2;g.support=0;g.fallback=15 end
 elseif profile==4 then
  if index==1 then g.kind='bearing';g.thrust=.2;g.airflow=.05
  elseif index==2 then g.role='drive';g.dy=0;g.dz=1;g.support=0;g.fallback=15
  else g.kind='linear';g.role=index==3 and 'yaw-left' or 'yaw-right';g.dy=1;g.support=0;g.neutral=0;g.fallback=0 end
 end
 return g
end
function M.validate(groups,protected)
 if type(groups)~='table' or #groups<1 or #groups>32 then return nil,'1..32 groupes requis' end
 local seen,ids={},{};for _,key in ipairs(protected or {}) do if seen[key] then return nil,'Clavier/Enable duplique' end;seen[key]='commande physique' end
 local lift=false
 for _,g in ipairs(groups) do
  if type(g)~='table' or not finite(g.id) or g.id%1~=0 or g.id<1 or g.id>32 or ids[g.id] then return nil,'Identifiant groupe unique 1..32 requis' end;ids[g.id]=true
  for key in pairs(numeric) do if not finite(g[key]) then return nil,'Groupe '..g.id..': '..key..' invalide' end end
  if g.kind~='small' and g.kind~='bearing' and g.kind~='linear' and g.kind~='surface' then return nil,'Type moteur inconnu' end
  if g.role~='lift' and g.role~='drive' and g.role~='yaw-left' and g.role~='yaw-right' and g.role~='pitch' and g.role~='roll' then return nil,'Role inconnu' end
  if math.abs(g.x)>128 or math.abs(g.y)>128 or math.abs(g.z)>128 then return nil,'Position locale hors domaine' end
  local n=math.sqrt(g.dx^2+g.dy^2+g.dz^2)
  if math.abs(n-1)>.001 then return nil,'Direction de poussee normalisee requise' end
  if g.source<=0 or g.source>256 or g.sails%1~=0 or g.sails<1 or g.sails>4096 or g.thrust<=0 or g.airflow<=0 or g.gain<=0 or g.members%1~=0 or g.members<1 or g.members>32 then return nil,'Moteur invalide' end
  if g.neutral<0 or g.neutral>15 or g.fallback%1~=0 or g.fallback< -1 or g.fallback>15 or g.run~=0 and g.run~=15 or g.alpha<=0 or g.alpha>1 or g.support<0 then return nil,'Neutre/repli/rampe invalide' end
  for _,role in ipairs({'power','reverse','clutch'}) do
   local a,b=g[role..'A'],g[role..'B'];local optional=role~='power' and a=='' and b==''
   if not optional then
    if not M.pair(a,b) then return nil,'Groupe '..g.id..': frequence '..role..' absente' end
    local key=a..','..b;if seen[key] then return nil,'Frequence partagee avec '..seen[key] end;seen[key]='groupe '..g.id..' '..role
   end
  end
  if g.role=='lift' then lift=true end
 end
 if not lift then return nil,'Sustentation requise' end
 return true
end
function M.quaternion(p,y,r)
 p,y,r=math.rad(p)/2,math.rad(y)/2,math.rad(r)/2
 local sp,cp,sy,cy,sr,cr=math.sin(p),math.cos(p),math.sin(y),math.cos(y),math.sin(r),math.cos(r)
 return {x=cy*sp*cr+sy*cp*sr,y=sy*cp*cr-cy*sp*sr,z=cy*cp*sr-sy*sp*cr,w=cy*cp*cr+sy*sp*sr}
end
function M.world(v,q) return Geometry.rotate(v,q) end
function M.attitudeError(actual,target)
 local a,b=actual,target
 local e={x=-b.w*a.x+b.x*a.w-b.y*a.z+b.z*a.y,y=-b.w*a.y+b.x*a.z+b.y*a.w-b.z*a.x,z=-b.w*a.z-b.x*a.y+b.y*a.x+b.z*a.w,w=b.w*a.w+b.x*a.x+b.y*a.y+b.z*a.z}
 if e.w<0 then e.x,e.y,e.z,e.w=-e.x,-e.y,-e.z,-e.w end
 local length=math.sqrt(e.x^2+e.y^2+e.z^2);local f=length<1e-9 and 2 or 2*Geometry.atan2(length,e.w)/length
 return Geometry.bodyVector({x=e.x*f,y=e.y*f,z=e.z*f},a)
end
function M.coefficients(g)
 if g.kind=='bearing' then return g.thrust*g.sails^1.5,g.airflow*math.sqrt(g.sails),.4/math.sqrt(g.sails) end
 return g.thrust,g.airflow,g.alpha
end
-- Response axes match existing navigation.response_model: forward,right,up,pitch,yaw,roll.
function M.matrix(groups,pose,velocity,baseMass,directions)
 local columns,meta,offset={}, {},{0,0,0,0,0,0};local support=0
 for _,g in ipairs(groups) do if g.kind=='linear' and g.role=='lift' then support=support+g.support end end
 local mass=pose.mass;local inertia={pose.ix,pose.iy,pose.iz};local up=M.world({x=0,y=1,z=0},pose.q)
 for i,g in ipairs(groups) do
  local sign=(directions and directions[g.id]) or 1
  local dx,dy,dz=g.dx*sign,g.dy*sign,g.dz*sign
  local height=pose.y+M.world({x=g.x,y=g.y,z=g.z},pose.q).y
  local pressure=Physics.pressure(height);if not pressure or pressure<=0 then return nil,'Atmosphere indisponible' end
  local dir=M.world({x=dx,y=dy,z=dz},pose.q)
  local axial=(velocity.x or 0)*dir.x+(velocity.y or 0)*dir.y+(velocity.z or 0)*dir.z
  local unit,bias,thrust,flow,alpha
  if g.kind=='linear' or g.kind=='surface' then
   unit=g.gain*g.members;bias=g.bias
   if g.kind=='surface' then local sensed=finite(pose.vx) and finite(pose.vy) and finite(pose.vz) and {x=pose.vx,y=pose.vy,z=pose.vz} or velocity;local localV=Geometry.bodyVector(sensed,pose.q);unit=unit*localV.z*math.abs(localV.z) end
   if g.role=='lift' and support>0 then bias=bias+baseMass*pose.gravity*g.support/support-g.neutral*unit end
  else
   thrust,flow,alpha=M.coefficients(g)
   unit=Physics.force(g.source,pressure,axial,thrust,flow)*g.members/15;bias=0
  end
  local vector
  if g.role=='yaw-left' or g.role=='yaw-right' or g.role=='pitch' or g.role=='roll' then
   local axis=g.role=='pitch' and 4 or g.role=='roll' and 6 or 5
   vector={0,0,0,0,0,0};vector[axis]=(g.role=='yaw-left' and -1 or 1)*unit/inertia[axis==4 and 1 or axis==5 and 2 or 3]
  else vector={dz*unit/mass,dx*unit/mass,dy*unit/mass,(g.y*dz-g.z*dy)*unit/pose.ix,(g.z*dx-g.x*dz)*unit/pose.iy,(g.x*dy-g.y*dx)*unit/pose.iz} end
  for j=1,6 do offset[j]=offset[j]+(unit~=0 and vector[j]*bias/unit or 0) end
  columns[i]={id=tostring(g.id),response=vector,low=0,high=15,neutral=0}
  meta[i]={group=g,unit=unit,pressure=pressure,axial=axial,thrust=thrust,airflow=flow,alpha=alpha or g.alpha}
 end
 local model={columns=columns,scale={1,1,1,.1,.1,.1}}
 -- Attitude/vertical carry priority; weak axes are reported rather than amplified.
 return model,meta,offset,up
end
function M.solve(model,wanted)
 local result,why=Response.allocate(model,wanted)
 if not result then return nil,why end
 local selected={} for i,c in ipairs(model.columns) do selected[i]=result.delta[c.id] end
 return selected,result
end
function M.signals(meta,values,quant)
 local qmodel={columns={},scale={1,1,1,.1,.1,.1}};local requested={}
 for i,m in ipairs(meta) do
  local g=m.group;local signal,slope
  if g.kind=='linear' or g.kind=='surface' then signal=values[i];slope=1
  else
   local force=values[i]*m.unit
   local rpm=force<=0 and 0 or force/(g.members*m.thrust*m.pressure)+math.max(0,m.axial)/m.airflow
   rpm=clip(rpm,0,g.source);signal=Physics.signal(g.source,rpm)
   slope=-m.thrust*m.pressure*g.source/(signal<1 and 8 or 16)*g.members/(math.max(1e-12,m.unit))
  end
  requested[tostring(g.id)]=clip(signal,0,15)
  local response={}
  for j=1,6 do response[j]=meta[i].column[j]*slope end
  local neutral=math.floor(requested[tostring(g.id)]+.5)
  qmodel.columns[i]={id=tostring(g.id),neutral=neutral,low=-neutral,high=15-neutral,response=response}
 end
 -- Coupled error diffusion, exact in blocks of eight; fixed work for 32 groups.
 local target={};for j=1,6 do target[j]=quant.error and quant.error[j] or 0 end
 local choices,selected={},{}
 for i,c in ipairs(qmodel.columns) do
  local wanted=requested[c.id];choices[i]={math.floor(wanted),math.ceil(wanted)};selected[c.id]=math.floor(wanted+.5)
  for j=1,6 do target[j]=target[j]+c.response[j]/qmodel.scale[j]*(wanted-selected[c.id]) end
 end
 for first=1,#meta,8 do
  local last=math.min(#meta,first+7);local base={}
  for j=1,6 do base[j]=target[j] end
  for i=first,last do local c=qmodel.columns[i];for j=1,6 do base[j]=base[j]+c.response[j]/qmodel.scale[j]*(selected[c.id]-c.neutral) end end
  local best,bestError,bestCost
  for mask=0,2^(last-first+1)-1 do
   local residual={};for j=1,6 do residual[j]=base[j] end
   local values={};local cost=0
   for i=first,last do local c=qmodel.columns[i]
    local value=choices[i][math.floor(mask/2^(i-first))%2+1];values[c.id]=value
    cost=cost+1e-10*(value-requested[c.id])^2
    for j=1,6 do residual[j]=residual[j]-c.response[j]/qmodel.scale[j]*(value-c.neutral) end
   end
   for j=1,6 do cost=cost+residual[j]^2 end
   if not bestCost or cost<bestCost then best,bestError,bestCost=values,residual,cost end
  end
  for id,value in pairs(best) do selected[id]=value end;target=bestError
 end
 quant.clipped=false
 for j=1,6 do if math.abs(target[j])>64 then quant.clipped=true end;target[j]=clip(target[j],-64,64) end
 quant.error=target;quant.scale=qmodel.scale
 return selected
end
function M.capabilities(model,groups)
 local caps={}
 local centered={columns={},scale=model.scale}
 for i,c in ipairs(model.columns) do centered.columns[i]={id=c.id,response=c.response,low=-7,high=8,neutral=7} end
 for axis,name in ipairs(Response.axes) do
  local positive,negative=0,0
  for _,c in ipairs(model.columns) do positive=positive+math.max(0,c.response[axis]);negative=negative+math.max(0,-c.response[axis]) end
  local independent=true
  for _,sign in ipairs({-1,1}) do local demand={0,0,0,0,0,0};demand[axis]=sign*.1*model.scale[axis];local result=Response.allocate(centered,demand);if not result or result.normalizedResidual>.005 then independent=false end end
  caps[name]={positive=positive,negative=negative,independent=independent,available=independent and (axis==3 and positive>1e-6 or positive>1e-6 and negative>1e-6)}
 end
 for _,g in ipairs(groups or {}) do
  if g.role=='drive' then caps.drive=true;if g.reverseA~='' then caps.reverse=true end end
  if g.kind=='surface' then caps.surface=true end
 end
 caps.travel=caps.drive or caps.pitch.available and caps.roll.available
 return caps
end
return M
