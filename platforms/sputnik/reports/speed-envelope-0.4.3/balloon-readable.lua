if not _G.MintCraftFlightModules then
local Portable=(function()
-- Minimal pure-data dependency used by the unchanged navigation mathematics.
local M={}
function M.finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
function M.vec(v)
 if type(v)~='table' then return end
 local x,y,z=v.x or v[1],v.y or v[2],v.z or v[3]
 if M.finite(x) and M.finite(y) and M.finite(z) then return {x=x,y=y,z=z} end
end
function M.copy(value)
 local seen,count={},0
 local function clone(v,depth)
  if type(v)~='table' then return v end
  assert(depth<=24 and not seen[v],'Unsupported cyclic/deep data')
  seen[v]=true local out={}
  for k,item in pairs(v) do count=count+1 assert(count<=32768,'Data budget exceeded') out[k]=clone(item,depth+1) end
  seen[v]=nil return out
 end
 return clone(value,0)
end
return M

end)()
local Geometry=(function()
local addon = Portable
local M = {}

function M.atan2(y, x)
  if x > 0 then return math.atan(y / x) end
  if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
  return y > 0 and math.pi / 2 or y < 0 and -math.pi / 2 or 0
end

-- Same convention as Avionics NavTable: rotate body +Z, atan2(world X,Z).
local function quaternion(q)
  if type(q)~="table" then return end
  if q.a~=nil or q.v~=nil then
    if type(q.v)~="table" then return end
    return q.v.x,q.v.y,q.v.z,q.a
  end
  return q.x or q[1],q.y or q[2],q.z or q[3],q.w or q[4]
end
-- Rotation utilities share the exact supported Sable quaternion encodings.
function M.orientation(value)
 local x,y,z,w=quaternion(value)
 if not (addon.finite(x) and addon.finite(y) and addon.finite(z) and addon.finite(w)) then return nil end
 local n=math.sqrt(x*x+y*y+z*z+w*w)
 if not addon.finite(n) or n<1e-9 then return nil end
 return {x=x/n,y=y/n,z=z/n,w=w/n}
end
function M.angularVelocity(previous,current,dt)
 if not addon.finite(dt) or dt<=0 then return nil end
 local a,b=M.orientation(previous),M.orientation(current) if not a or not b then return nil end
 -- current * conjugate(previous): axis-angle in WORLD axes, radians/second.
 local x=-b.w*a.x+b.x*a.w-b.y*a.z+b.z*a.y
 local y=-b.w*a.y+b.x*a.z+b.y*a.w-b.z*a.x
 local z=-b.w*a.z-b.x*a.y+b.y*a.x+b.z*a.w
 local w=b.w*a.w+b.x*a.x+b.y*a.y+b.z*a.z
 if w<0 then x,y,z,w=-x,-y,-z,-w end
 if w<1e-3 then return nil,'Rotation interval near 180 degrees is ambiguous' end
 local n=math.sqrt(x*x+y*y+z*z)
 local factor=n<1e-9 and 2/dt or 2*M.atan2(n,w)/(n*dt)
 return {x=x*factor,y=y*factor,z=z*factor}
end
function M.rotate(value,orientation)
 local v=addon.vec(value) local q=M.orientation(orientation)
 if not v or not q then return nil end
 local tx,ty,tz=2*(q.y*v.z-q.z*v.y),2*(q.z*v.x-q.x*v.z),2*(q.x*v.y-q.y*v.x)
 return {x=v.x+q.w*tx+q.y*tz-q.z*ty,y=v.y+q.w*ty+q.z*tx-q.x*tz,z=v.z+q.w*tz+q.x*ty-q.y*tx}
end
function M.bodyVector(value,orientation)
 local q=M.orientation(orientation) if not q then return nil end
 return M.rotate(value,{x=-q.x,y=-q.y,z=-q.z,w=q.w})
end

return M

end)()
local Physics=(function()
-- Audited defaults: Aeronautics/Simulated 1.3.2 + Sable 2.0.6, small fixed props.
-- No sensor/ownership claims. Geometry, normal thrust direction and defaults confirmed by operator.
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
-- Frozen Hermite coefficients of the audited default Sable Overworld curve.
local curves={
 {-38.366277027041093,63,1.5,-0.60819766216224658,0.12186043243265754,-0.013662770270410851},
 {63,263,1,-0.80000000000000004,0.30745006364544203,-0.058121099528220421},
 {263,280,0.44932896411722156,-0.030554369559971067,0.001038458967571973,-2.2762716708216169e-05},
 {280,320,0.41979029080811425,-0.067166446529298277,-0.28545739774951751,-0.067166446529298374},
}
function M.pressure(y)
 if not finite(y) then return nil end
 if y<curves[1][1] then return 1.5 end
 for _,c in ipairs(curves) do if y<c[2] then
  local t=(y-c[1])/(c[2]-c[1])
  return math.max(((c[6]*t+c[5])*t+c[4])*t+c[3],0)
 end end
 return 0
end
function M.rpm(source,signal)
 if not finite(source) or source<=0 or not finite(signal) or signal<0 or signal>15 then return nil end
 -- Actual propagation bypasses the ratio at signal 0 (full source RPM).
 -- Fractional 0..1 denotes a blend of adjacent INTEGER commands, not a
 -- fractional redstone level sent to the mod. There is no 240-RPM state.
 if signal<1 then return source*(1-signal/8) end
 return source*(15-signal)/16
end
function M.signal(source,rpm)
 if not finite(source) or source<=0 or not finite(rpm) or rpm<0 or rpm>source then return nil end
 if rpm>=source*14/16 then return (source-rpm)/(source/8) end
 return 15-16*rpm/source
end
function M.force(rpm,pressure,axialVelocity,thrust,airflow)
 if not finite(rpm) or rpm<0 or not finite(pressure) or pressure<0 or not finite(axialVelocity) or not finite(thrust) or thrust<=0 or not finite(airflow) or airflow<=0 then return nil end
 if rpm<=1/30 then return 0 end
 -- magnitude of BlockEntityPropeller.getScaledThrust for upward fixed props.
 local flow=airflow*rpm
 return thrust*rpm*pressure*clamp((flow-axialVelocity)/flow,0,1)
end
return M

end)()
local Response=(function()
local A=Portable
local M={}
M.axes={'forward','right','vertical','pitch','yaw','roll'}
local function vector(v)
 if type(v)~='table' or #v~=6 then return end
 local out={} for i=1,6 do if not A.finite(v[i]) then return end out[i]=v[i] end return out
end
local function sequence(t,limit)
 if type(t)~='table' or getmetatable(t) or #t<1 or #t>limit then return false end
 local n=0 for k in pairs(t) do if type(k)~='number' or k%1~=0 or k<1 or k>#t then return false end n=n+1 end
 return n==#t
end
local function id(s) return type(s)=='string' and #s>0 and #s<=192 and not s:find('%c') end
-- Coordinate descent solves the normalized box-constrained least-squares
-- problem. The iteration budget is fixed; a residual is always returned.
function M.allocate(model,wanted)
 wanted=vector(wanted)
 if not wanted or type(model)~='table' or not sequence(model.columns,32) or not vector(model.scale) then return nil,'Invalid allocation input' end
 local normalized,residual,outputs,columns,seen={},{},{},{},{}
 for i=1,6 do
  if model.scale[i]<=0 then return nil,'Invalid response scale' end
  normalized[i]=wanted[i]/model.scale[i] residual[i]=normalized[i]
  if not A.finite(normalized[i]) then return nil,'Allocation magnitude outside numeric domain' end
 end
 for j,c in ipairs(model.columns) do
  if type(c)~='table' then return nil,'Malformed actuator column' end
  local values=vector(c.response)
  if not values or not id(c.id) or seen[c.id] or not A.finite(c.low) or not A.finite(c.high) or c.low>0 or c.high<0 or c.high-c.low>15 then return nil,'Invalid actuator bounds' end
  seen[c.id]=true
  local v={} local norm=0
  for i=1,6 do v[i]=values[i]/model.scale[i] norm=norm+v[i]^2 end
  if not A.finite(norm) then return nil,'Response magnitude outside numeric domain' end
  columns[j]={v=v,norm=norm,low=c.low,high=c.high} outputs[j]=0
 end
 -- A regularized six-axis least-squares seed preserves collective directions
 -- when torque columns dwarf translation (e.g. low-inertia multicopters).
 -- Box projection plus the existing descent still enforces actuator bounds.
 local gram,peak={},0
 for i=1,6 do gram[i]={};for k=1,6 do local sum=0;for _,c in ipairs(columns) do sum=sum+c.v[i]*c.v[k] end;gram[i][k]=sum;peak=math.max(peak,math.abs(sum)) end;gram[i][7]=normalized[i] end
 if not A.finite(peak) then return nil,'Response Gram overflow' end
 -- Preserve the established descent solution when the collective is already
 -- well conditioned; a different null-space seed can worsen heterogeneous PWM.
 if gram[3][3]>0 and peak/gram[3][3]>100 then
 for i=1,6 do gram[i][i]=gram[i][i]+math.max(1,peak)*1e-10 end
 for i=1,6 do
  local pivot=i;for row=i+1,6 do if math.abs(gram[row][i])>math.abs(gram[pivot][i]) then pivot=row end end
  gram[i],gram[pivot]=gram[pivot],gram[i]
  local divisor=gram[i][i];for k=i,7 do gram[i][k]=gram[i][k]/divisor end
  for row=1,6 do if row~=i then local factor=gram[row][i];for k=i,7 do gram[row][k]=gram[row][k]-factor*gram[i][k] end end end
 end
 for j,c in ipairs(columns) do local value=0;for i=1,6 do value=value+c.v[i]*gram[i][7] end;outputs[j]=math.max(c.low,math.min(c.high,value));for i=1,6 do residual[i]=residual[i]-c.v[i]*outputs[j] end end
 end
 for _=1,96 do
  local largest=0
  for j,c in ipairs(columns) do
   local dot=0 for i=1,6 do dot=dot+c.v[i]*residual[i] end
   local old=outputs[j]
   local value=c.norm>1e-12 and math.max(c.low,math.min(c.high,old+dot/c.norm)) or 0
   local delta=value-old outputs[j]=value largest=math.max(largest,math.abs(delta))
   for i=1,6 do residual[i]=residual[i]-c.v[i]*delta end
  end
  if largest<1e-8 then break end
 end
 local actual,signals={},{} local error=0 local saturated=false
 for i=1,6 do
  actual[i]=0 for j,c in ipairs(model.columns) do actual[i]=actual[i]+c.response[i]*outputs[j] end
  if not A.finite(actual[i]) then return nil,'Allocated response outside numeric domain' end
  error=math.max(error,math.abs(residual[i]))
 end
 for j,c in ipairs(model.columns) do
  signals[c.id]=outputs[j]
  if math.abs(outputs[j]-c.low)<1e-6 or math.abs(outputs[j]-c.high)<1e-6 then saturated=true end
 end
 return {delta=signals,actual=actual,normalizedResidual=error,saturated=saturated}
end

return M
end)()
local Progress=(function()
-- Fixed-memory physical progress evidence; never a stabilization timeout.
local A=Portable
local M={}
function M.new()
 local self={samples={},last=nil,diagnostic='Collecte progres',axes={}}
 function self:observe(error,rates,at)
  if not A.finite(at) or self.last and at<=self.last then return false end
  for i=1,6 do if not A.finite(error and error[i]) or not A.finite(rates and rates[i]) then return false end end
  if self.last and at-self.last<.5-1e-8 then return false end
  if self.last and at-self.last>1 then self.samples={} end self.last=at
  self.samples[#self.samples+1]={error=A.copy(error),rates=A.copy(rates)}
  if #self.samples>32 then table.remove(self.samples,1) end
  self.axes={}
  if #self.samples<32 then self.diagnostic='Collecte progres' return true end
  for axis=1,6 do
   local first,last,turns,sign=0,0,0,0
   for j,sample in ipairs(self.samples) do
    local e=sample.error[axis] local r=sample.rates[axis]
    if j<=16 then first=first+e*e else last=last+e*e end
    local threshold=axis<=3 and .05 or .5
    local current=r>threshold and 1 or r< -threshold and -1 or 0
    if current~=0 then if sign~=0 and current~=sign then turns=turns+1 end sign=current end
   end
   local rms=math.sqrt(last/16) local threshold=axis<=3 and .25 or 3
   if rms>threshold and last>=first*.9 and math.sqrt(first/16)-rms<(axis<=3 and .1 or 1) then
    self.axes[axis]=turns>=6 and 'nondecaying-oscillation' or 'no-measured-convergence'
   end
  end
  self.diagnostic=next(self.axes) and 'Pas de convergence' or 'Progres observe'
  return true
 end
 function self:status() return {samples=#self.samples,capacity=32,axes=A.copy(self.axes),reason=self.diagnostic} end
 return self
end
return M

end)()
local Filter=(function()
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function clip(v,a,b) return math.max(a,math.min(b,v)) end
local function wrap(v) return (v+180)%360-180 end
M.finite=finite
function M.filter(x,r,q)
 if not finite(x) or not finite(r) or r<=0 or not finite(q) or q<=0 then return nil end
 return {x=x,v=0,a=r,b=0,c=1,r=r,q=q}
end
function M.update(k,z,dt)
 if not k or not finite(z) or not finite(dt) or dt<=0 or dt>.5 then return nil end
 local a=k.a+2*dt*k.b+dt*dt*k.c+k.q*dt^4/4
 local b=k.b+dt*k.c+k.q*dt^3/2 local c=k.c+k.q*dt*dt
 local innovation=z-(k.x+k.v*dt) local denom=a+k.r
 local gx,gv=a/denom,b/denom
 k.x=k.x+k.v*dt+gx*innovation k.v=k.v+gv*innovation
 -- Joseph covariance update avoids cancellation and preserves nonnegative variances.
 k.a=(1-gx)^2*a+gx*gx*k.r
 k.b=(1-gx)*(b-gv*a)+gx*gv*k.r
 k.c=c-2*gv*b+gv*gv*a+gv*gv*k.r
 if not finite(k.x) or not finite(k.v) or k.a<0 or k.c<0 then return nil end
 return k.x,k.v
end

return M
end)()
local Vehicle=(function()
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

end)()
local Mission=(function()
-- Local declared-map navigation. Unknown terrain is never declared clear.
local M={schema=1,maxPoints=64,maxZones=16}
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
M.distance=distance
function M.parse(text,zones)
 if type(text)~='string' or #text>12000 then return nil,'Liste trop longue/invalide' end
 local out={};local width=zones and 6 or 4
 for line in text:gmatch('[^;\r\n]+') do
  local row={} for v in (line..','):gmatch('(.-),') do row[#row+1]=tonumber(v) or false end
  if not zones and #row==3 then row[4]=0 end
  if #row~=width then return nil,'Point x,y,z[,vitesse] / zone xmin,ymin,zmin,xmax,ymax,zmax' end
  for _,v in ipairs(row) do if not finite(v) or math.abs(v)>30000000 then return nil,'Coordonnee invalide' end end
  if zones then
   if row[1]>=row[4] or row[2]>=row[5] or row[3]>=row[6] then return nil,'Boite interdite invalide' end
   out[#out+1]=row
  else if row[4]<0 then return nil,'Vitesse positive ou 0 automatique' end;out[#out+1]={x=row[1],y=row[2],z=row[3],speed=row[4]} end
  if #out>(zones and M.maxZones or M.maxPoints) then return nil,'Budget de points/zones depasse' end
 end
 return out
end
function M.blocked(a,b,zones,margin)
 for _,box in ipairs(zones) do
  local low,high=0,1
  for i,key in ipairs({'x','y','z'}) do
   local d=b[key]-a[key];local minimum,maximum=box[i]-margin,box[i+3]+margin
   if math.abs(d)<1e-9 then if a[key]<minimum or a[key]>maximum then low=2;break end
   else local t1,t2=(minimum-a[key])/d,(maximum-a[key])/d;if t1>t2 then t1,t2=t2,t1 end;low=math.max(low,t1);high=math.min(high,t2) end
  end
  if low<=high and high>=0 and low<=1 then return true end
 end
 return false
end
-- Incremental visibility search: at most 64 candidate edges per control tick.
function M.planner(start,goal,zones,margin)
 local nodes={start,goal};local distances={[1]=0};local previous,closed={},{}
 for _,box in ipairs(zones) do for mask=0,7 do
  local p={};for i,key in ipairs({'x','y','z'}) do p[key]=box[math.floor(mask/2^(i-1))%2==0 and i or i+3]+(math.floor(mask/2^(i-1))%2==0 and -1 or 1)*(margin+.05) end
  nodes[#nodes+1]=p
 end end
 local s={nodes=nodes,done=false,reason='Calcul route: terrain non observe',current=nil,next=1}
 function s:step()
  for _=1,64 do
   if not self.current then
    local best,cost
    for i,p in ipairs(nodes) do if not closed[i] and distances[i] and (not cost or distances[i]+distance(p,goal)<cost) then best,cost=i,distances[i]+distance(p,goal) end end
    if not best then self.done=true;self.failed=true;self.reason='Aucune route parmi les zones declarees';return end
    if best==2 then
     local path={};local i=2;while i do table.insert(path,1,nodes[i]);i=previous[i] end
     self.path=path;self.done=true;self.reason='Route calculee sur zones declarees uniquement';return
    end
    self.current=best;closed[best]=true;self.next=1
   end
   local j=self.next;self.next=j+1
   if j>#nodes then self.current=nil
   elseif not closed[j] and j~=self.current and not M.blocked(nodes[self.current],nodes[j],zones,margin) then
    local d=distances[self.current]+distance(nodes[self.current],nodes[j])
    if not distances[j] or d<distances[j] then distances[j]=d;previous[j]=self.current end
   end
  end
 end
 return s
end
function M.new(route,zones,margin,home)
 local s={route=route,zones=zones,margin=margin,home=home,index=1,phase='PREFLIGHT',trace={},events={},paused=false,completed=false}
 function s:event(text) self.events[#self.events+1]=text;if #self.events>64 then table.remove(self.events,1) end end
 function s:pause(why) self.paused=true;self:event(why or 'Pause');self.phase='HOLDING' end
 function s:resume() if not self.completed then self.paused=false;self:event('Reprise demandee') end end
 function s:step(p,v)
  if #self.trace==0 or distance(p,self.trace[#self.trace])>=.5 then self.trace[#self.trace+1]={x=p.x,y=p.y,z=p.z};if #self.trace>256 then table.remove(self.trace,1) end end
  if self.paused or self.completed then return nil end
  local goal=self.route[self.index]
  if not goal then self.completed=true;self.phase='MISSION_COMPLETE';self:event('Arrivee: maintien, pas atterrissage');return nil end
  if not self.planner then self.planner=M.planner(p,goal,self.zones,self.margin);self.segment=2 end
  if not self.planner.done then self.planner:step();self.phase='PREFLIGHT';return nil end
  if self.planner.failed then self:pause(self.planner.reason);return nil end
  local target=self.planner.path[self.segment]
  if not target then self.index=self.index+1;self.planner=nil;return nil end
  if M.blocked(p,target,self.zones,self.margin) then self.planner=nil;self:event('Recalcul depuis position observee');self.phase='PREFLIGHT';return nil end
  local d=distance(p,target);local speed=math.sqrt(v.x^2+v.y^2+v.z^2)
  if d<=.5 and speed<=.1 then self.segment=self.segment+1;return nil end
  self.phase=math.abs(target.y-p.y)>1 and 'CLIMB' or d<3 and 'APPROACH' or 'CRUISE'
  local origin=self.planner.path[self.segment-1]
  local heading
  if self.surface then
   local base=Geometry.atan2(target.x-origin.x,target.z-origin.z)
   local cross=(target.x-p.x)*math.cos(base)-(target.z-p.z)*math.sin(base)
   heading=d<2 and math.deg(Geometry.atan2(target.x-p.x,target.z-p.z)) or math.deg(base)+math.max(-30,math.min(30,math.deg(math.atan(cross/2))))
  end
  return {x=target.x,y=target.y,z=target.z,speed=goal.speed,heading=heading}
 end
 return s
end
return M

end)()
local Calibration=(function()
-- Motion-based functional commissioning, not a radio ACK or hardware identity.
local M={schema=1}
function M.hash(g)
 local n=0;local text=Vehicle.encode(g);for i=1,#text do n=(n*33+text:byte(i))%2147483647 end;return n
end
function M.archive(s,mass)
 local lines={'MCAL1,'..tostring(mass)}
 for _,g in ipairs(s.groups) do local r=s.results[g.id];if r then lines[#lines+1]=table.concat({g.id,M.hash(g),r.dx,r.dy,r.dz,r.pitch,r.roll,r.yaw},',') end end
 return table.concat(lines,'\n')
end
function M.new(groups,pose,caps,saved)
 local s={mass=pose.mass,phase='BASELINE',index=1,stable=0,window={},results={},groups=groups,home={x=pose.x,y=pose.y,z=pose.z},heading=pose.yaw,paused=false,last=nil,reason='Repos mesure requis',samples=0}
 local function point(x,y,z,h) return {x=s.home.x+(x or 0),y=s.home.y+(y or 0),z=s.home.z+(z or 0),heading=h} end
 s.priors={}
 if type(saved)=='string' and #saved<=12000 then
  local mass=tonumber(saved:match('^MCAL1,([^\n]+)'))
  if mass and mass>0 and math.abs(mass-pose.mass)/mass<=.02 then
   for line in saved:gmatch('[^\n]+') do local id,hash=line:match('^(%d+),(%d+),');id,hash=tonumber(id),tonumber(hash);if id then for _,g in ipairs(groups) do if g.id==id and M.hash(g)==hash then s.priors[id]=line end end end end
  end
 end
 function s:pause(why) self.paused=true;self.reason=why or 'Pause operateur' end
 function s:resume() self.paused=false;self.stable=0;self.window={} end
 function s:step(p,v,omega,active)
  if self.last and p.tick<=self.last then return nil end
  if self.last and p.tick-self.last>2 then self.stable=0;self.window={} end;self.last=p.tick
  if self.paused or self.phase=='COMPLETE' then return nil end
  if not active then self:pause('Maintien indisponible');return nil end
  if math.abs(p.pitch)>15 or math.abs(p.roll)>15 then self:pause('Assiette hors domaine; maintien');return nil end
  local target=self.home
  if self.phase=='UP' then target=point(0,.5)
  elseif self.phase=='DOWN' then target=point()
  elseif self.phase=='FORWARD' then local bearing=math.rad(self.heading-(caps.surface and 5 or 0));local extent=caps.surface and 3 or 1;target=point(extent*math.sin(bearing),0,extent*math.cos(bearing),caps.surface and self.heading-5 or nil)
  elseif self.phase=='RETURN' then target=point(0,0,0,caps.surface and self.heading or nil)
  elseif self.phase=='BACK' then target=point(-math.sin(math.rad(self.heading)),0,-math.cos(math.rad(self.heading)),caps.surface and self.heading or nil)
  elseif self.phase=='BACK_RETURN' then target=point(0,0,0,caps.surface and self.heading or nil)
  elseif self.phase=='YAW_LEFT' then target=point(0,0,0,self.heading-10)
  elseif self.phase=='YAW_RETURN' then target=point(0,0,0,self.heading) end
  local horizontal=math.sqrt(v.x^2+v.z^2)
  if caps.surface and horizontal>.2 and target.heading and math.abs(target.heading-self.heading)>=2 then local delta=(p.yaw-self.heading+180)%360-180;if delta*(target.heading-self.heading)>0 and math.abs(delta)>=2 and math.abs(delta-(target.heading-self.heading))<5 then self.surfaceYawObserved=true end end
  local stable=math.abs(v.y)<=.1 and horizontal<=.1 and math.abs(omega.x)<=math.rad(2) and math.abs(omega.y)<=math.rad(2) and math.abs(omega.z)<=math.rad(2) and math.abs(p.y-target.y)<=.2
  if caps.travel then stable=stable and Mission.distance(p,target)<=(caps.surface and .8 or .3) end
  if target.heading and not caps.surface then stable=stable and math.abs((p.yaw-target.heading+180)%360-180)<=1 end
  self.window[#self.window+1]={p.y,p.pitch,(p.yaw-self.heading+180)%360-180,p.roll};if #self.window>20 then table.remove(self.window,1) end
  local bounded=true
  for axis=1,4 do local lo,hi=math.huge,-math.huge;for _,sample in ipairs(self.window) do lo=math.min(lo,sample[axis]);hi=math.max(hi,sample[axis]) end;if hi-lo>(axis==1 and .2 or 1) then bounded=false end end
  if stable and bounded then self.stable=self.stable+1 else self.stable=0 end
  self.samples=self.samples+1
  self.reason=self.phase..': stabilite '..math.min(20,self.stable)..'/20, |Vy|='..string.format('%.3f',math.abs(v.y))..' Vh='..string.format('%.2f',horizontal)..' Wy='..string.format('%.1f',math.deg(omega.y))..'; aucun timeout valide'
  if self.phase=='PROBE' then
   local g=self.groups[self.index]
   self.probeSamples=(self.probeSamples or 0)+1
   self.probeResponse=self.probeResponse or {vx=v.x,vy=v.y,vz=v.z,p=p.pitch,r=p.roll,yaw=p.yaw}
   if self.probeSamples>=4 then
    local a=self.probeResponse
    self.results[g.id]={kind='motion-candidate',priorRechecked=self.priors[g.id]~=nil,samples=4,dx=v.x-a.vx,dy=v.y-a.vy,dz=v.z-a.vz,pitch=p.pitch-a.p,roll=p.roll-a.r,yaw=p.yaw-a.yaw,rxConfirmed=false}
    self.phase='RECOVER';self.stable=0;self.window={};self.probeSamples=0;self.probeResponse=nil
   else return target,{index=self.index,delta=.2} end
  elseif self.stable>=20 then
   self.stable=0;self.window={}
   if self.phase=='BASELINE' then self.phase='PROBE'
   elseif self.phase=='RECOVER' then self.index=self.index+1;self.phase=self.index<=#self.groups and 'PROBE' or 'UP'
   elseif self.phase=='UP' then self.phase='DOWN'
   elseif self.phase=='DOWN' then self.verticalVerified=true;self.phase=caps.travel and 'FORWARD' or 'COMPLETE'
   elseif self.phase=='FORWARD' then self.phase='RETURN'
   elseif self.phase=='RETURN' then if caps.surface and not self.surfaceYawObserved then self:pause('Gouverne non observee en mouvement');return target end;self.horizontalVerified=true;self.phase=caps.reverse and 'BACK' or caps.yaw and caps.yaw.available and 'YAW_LEFT' or 'COMPLETE'
   elseif self.phase=='BACK' then self.phase='BACK_RETURN'
   elseif self.phase=='BACK_RETURN' then self.reverseVerified=true;self.phase=caps.yaw and caps.yaw.available and 'YAW_LEFT' or 'COMPLETE'
   elseif self.phase=='YAW_LEFT' then self.phase='YAW_RETURN'
   elseif self.phase=='YAW_RETURN' then self.yawVerified=true;self.phase='COMPLETE' end
   if self.phase=='COMPLETE' then self.reason='Essais termines; aucun ACK materiel';self.complete=true end
  end
  return target
 end
 return s
end
return M

end)()
local Flight=(function()
-- Server-independent flight controller. Native adapter alone owns all Link writes.
local M={schema=1}
local V=Vehicle
local clip,finite=V.clip,V.finite
local function wrap(x) return (x+180)%360-180 end
local function vec(x,y,z) return {x=x,y=y,z=z} end
function M.pose(p)
 for _,key in ipairs({'tick','x','y','z','pitch','yaw','roll','mass','ix','iy','iz'}) do if not finite(p[key]) then return nil,'Télémétrie '..key..' absente' end end
 if p.tick<=0 or p.mass<=0 or p.ix<=0 or p.iy<=0 or p.iz<=0 or p.dimension~='minecraft:overworld' then return nil,'Physique Overworld requise' end
 p.q=V.quaternion(p.pitch,p.yaw,p.roll);p.gravity=p.gravity or 11
 return p
end
function M.new(groups,p,config)
 local valid,why=V.validate(groups,config.protected);if not valid then return nil,why end
 p,why=M.pose(p);if not p then return nil,why end
 if math.abs(p.pitch)>10 or math.abs(p.roll)>10 then return nil,'Depart a plat +/-10 deg' end
 local s={groups=V.copy(groups),config=V.copy(config),referenceMass=p.mass,tick=p.tick,previous=p,velocity=vec(0,0,0),omega=vec(0,0,0),angularAcceleration=vec(0,0,0),acceleration=vec(0,0,0),
  filters={},target=vec(p.x,p.y,p.z),home=vec(p.x,p.y,p.z),mode='HOLD',phase='HOLDING',directions={},shifts={},spool={},quant={},events={},revision=0,integral=0,angleBias=vec(0,0,0),course=p.yaw,heading=p.yaw,progress=Progress.new(),samples=0}
 for _,axis in ipairs({'x','y','z'}) do s.filters[axis]=Filter.filter(p[axis],.0025,4);s.velocity[axis]=finite(p['v'..axis]) and p['v'..axis] or 0;s.filters[axis].v=s.velocity[axis] end
 for _,g in ipairs(groups) do s.directions[g.id]=1;s.spool[g.id]=(g.kind=='linear' or g.kind=='surface') and g.neutral or Physics.rpm(g.source,g.neutral) end
 local initial,metadata,offset=V.matrix(s.groups,p,s.velocity,p.mass,s.directions)
 if not initial then return nil,metadata end
 local gravity=Geometry.bodyVector(vec(0,p.gravity,0),p.q)
 local wanted={gravity.z-offset[1],gravity.x-offset[2],gravity.y-offset[3],-offset[4],-offset[5],-offset[6]}
 local allocation,result=V.solve(initial,wanted);if not allocation then return nil,result end
 if math.abs(result.actual[3]-wanted[3])>math.max(.5,p.gravity*.1) then return nil,'Portance initiale insuffisante' end
 if math.max(math.abs(result.actual[4]-wanted[4]),math.abs(result.actual[5]-wanted[5]),math.abs(result.actual[6]-wanted[6]))>.1 then return nil,'Equilibre portance invalide' end
 for i,m in ipairs(metadata) do m.column=initial.columns[i].response end
 s.initialSignals=V.signals(metadata,allocation,s.quant)
 if not s.initialSignals then return nil,'Niveaux initiaux invalides' end
 s.capabilities=V.capabilities(initial,s.groups)
 function s:event(reason)
  self.events[#self.events+1]={tick=self.tick,reason=reason};if #self.events>64 then table.remove(self.events,1) end
 end
 function s:apply(c,p)
  if type(c)~='table' or not finite(c.revision) or c.revision%1~=0 or c.revision<=self.revision then return false,'Commande perimee' end
  local modes={HOLD=true,ALTITUDE=true,HEADING=true,ROUTE=true,PAUSE=true,RESUME=true,CANCEL=true,RETURN=true,CALIBRATE=true,CAL_PAUSE=true,CAL_RESUME=true,CAL_ABORT=true,MANUAL=true}
  if not modes[c.mode] then return false,'Mode inconnu' end
  for _,key in ipairs({'altitude','speed','heading'}) do if not finite(c[key]) then return false,'Consigne '..key..' invalide' end end
  if c.speed<0 then return false,'Vitesse positive ou 0 libre requise' end
  local route,zones,why
  if c.mode=='ROUTE' or c.mode=='RETURN' then
   if not self.capabilities.travel then return false,'Guidage horizontal indisponible' end
   if not self.calibration or not self.calibration.complete or not self.calibration.horizontalVerified then return false,'Essais aller-retour requis' end
   route,why=Mission.parse(c.route or '');if not route then return false,why end
   zones,why=Mission.parse(c.zones or '',true);if not zones then return false,why end
   if c.mode=='RETURN' then route={{x=self.home.x,y=self.home.y,z=self.home.z,speed=c.speed}} end
   if #route==0 then return false,'Route vide' end
  end
  if c.mode=='HOLD' or c.mode=='ALTITUDE' or c.mode=='HEADING' or c.mode=='MANUAL' or c.mode=='CALIBRATE' then if self.mission then self.mission:pause('Consigne directe prioritaire') end end
  if c.mode~='CALIBRATE' and c.mode~='CAL_RESUME' and c.mode~='CAL_PAUSE' and self.calibration and not self.calibration.complete then self.calibration:pause('Consigne directe prioritaire') end
  if c.mode=='PAUSE' then if self.mission then self.mission:pause('Pause operateur') end
  elseif c.mode=='RESUME' then if not self.mission or self.mission.completed then return false,'Aucune mission a reprendre' end;self.mission:resume()
  elseif c.mode=='CANCEL' then self.mission=nil
  elseif c.mode=='ROUTE' or c.mode=='RETURN' then self.mission=Mission.new(route,zones,self.config.margin or 1,self.home);self.mission.surface=self.capabilities.surface
  elseif c.mode=='CALIBRATE' then self.calibration=Calibration.new(self.groups,p,self.capabilities or {},self.snapshot or self.config.candidate)
  elseif c.mode=='CAL_PAUSE' then if self.calibration then self.calibration:pause() end
  elseif c.mode=='CAL_RESUME' then if self.calibration and self.calibration.aborted then return false,'Essais abandonnes: relancer' end;if self.calibration then self.calibration:resume() end
  elseif c.mode=='CAL_ABORT' then if self.calibration then self.calibration:pause('Abandon, mesures conservees');self.calibration.aborted=true;self.calibration.phase='ABORTED' end
  end
  self.revision=c.revision;self.archived=nil;self.accepted=V.copy(c)
  self.mode=c.mode=='RESUME' and 'ROUTE' or c.mode=='RETURN' and 'ROUTE' or c.mode
  local previousY=self.target.y;self.target=vec(p.x,p.y,p.z)
  if c.mode~='HOLD' and c.mode~='CALIBRATE' and c.mode~='ROUTE' and c.mode~='RETURN' then self.target.y=previousY end
  if c.mode=='ALTITUDE' or c.mode=='HEADING' then self.target.y=c.altitude end
  self.speed=c.speed;self.heading=wrap(c.heading);self.navigationHeading=p.yaw;self.progress=Progress.new();self:event('Consigne acceptee '..c.revision..' '..c.mode)
  return true
 end
 function s:step(p,command,lastSignals,feedback)
  local cfg=self.config
  local pending=self.shifts
  local groupList=self.groups
  local mass0=self.referenceMass
  local cal=self.calibration
  local mission=self.mission
  local omegaNow=self.omega
  local accelNow=self.angularAcceleration
  local why;p,why=M.pose(p);if not p then return nil,why end
  if p.dimension~=self.previous.dimension then return nil,'Dimension modifiee' end
  local dt=(p.tick-self.tick)/20;if dt<=0 or dt>.5 then return nil,'Horloge repetee/regressee/perdue' end
  for _,key in ipairs({'forward','left','vertical'}) do if not finite(command[key]) or math.abs(command[key])>1 then return nil,'Commande clavier invalide' end end
  local oldV=V.copy(self.velocity)
  for _,axis in ipairs({'x','y','z'}) do
   local k=self.filters[axis]
   if math.abs(p[axis]-k.x-k.v*dt)>20 then return nil,'Pose discontinue' end
   if not Filter.update(k,p[axis],dt) then return nil,'Estimateur perdu' end
   self.velocity[axis]=k.v;self.acceleration[axis]=self.acceleration[axis]+dt/(.1+dt)*((k.v-oldV[axis])/dt-self.acceleration[axis])
  end
  local worldRate=Geometry.angularVelocity(self.previous.q,p.q,dt);if not worldRate then return nil,'Rotation absente' end
  local rate=Geometry.bodyVector(worldRate,p.q)
  for _,axis in ipairs({'x','y','z'}) do local old=omegaNow[axis];omegaNow[axis]=old+dt/(.05+dt)*(rate[axis]-old);accelNow[axis]=accelNow[axis]+dt/(.1+dt)*((omegaNow[axis]-old)/dt-accelNow[axis]) end
  self.tick=p.tick;self.samples=self.samples+1
  local v=self.velocity;local speed=math.sqrt(v.x^2+v.z^2);local yaw=math.rad(p.yaw)
  local forward,left=command.forward,command.left
  local manual=forward~=0 or left~=0 or command.vertical~=0
  if manual and not self.wasManual then self.heading=p.yaw;self.course=p.yaw end
  self.wasManual=manual
  if manual then
   if mission and not mission.paused then mission:pause('Priorite clavier: reprise explicite requise') end
   if cal and not cal.complete and not cal.paused then cal:pause('Priorite clavier; reprise essais explicite') end
   self.target=vec(p.x,self.target.y,p.z);self.target.y=self.target.y+command.vertical*(cfg.climb or 1)*dt
  end
  local provisional=V.matrix(groupList,p,v,mass0,nil)
  if not provisional then return nil,'Modele indisponible' end
  local caps=V.capabilities(provisional,groupList)
  local drive,yawAvailable=caps.drive,caps.yaw.available
  self.capabilities=caps;self.bodyYawControlled=yawAvailable
  -- Passive stop measurements: motion evidence, not an RX/shaft acknowledgement.
  self.brakeSamples=self.brakeSamples or {}
  local phase=cal and cal.phase or ''
  local measuring=manual or phase=='FORWARD' or phase=='RETURN' or phase=='BACK' or phase=='BACK_RETURN' or mission and not mission.paused
  if speed>.3 and (measuring or self.brakeTrial) then
   if not self.brakeTrial or speed>self.brakeTrial.speed+.03 then self.brakeTrial={speed=speed,x=p.x,z=p.z,distance=0,tick=p.tick,ux=v.x/speed,uz=v.z/speed}
   else local t=self.brakeTrial;if (t.ux*v.x+t.uz*v.z)/math.max(.001,speed)<.96 then t.invalid=true end;t.distance=t.distance+math.sqrt((p.x-t.x)^2+(p.z-t.z)^2);t.x,t.z=p.x,p.z;if not t.reaction and speed<t.speed*.95 then t.reaction=(p.tick-t.tick)/20 end end
  elseif speed<=.1 and self.brakeTrial then
   local t=self.brakeTrial;self.brakeTrial=nil
   if t.distance>.02 and not t.invalid then
    self.brakeSamples[#self.brakeSamples+1]={deceleration=t.speed^2/(2*t.distance),speed=t.speed,reaction=t.reaction or 0}
    if #self.brakeSamples>8 then table.remove(self.brakeSamples,1) end
    if #self.brakeSamples>=2 then local a,r=math.huge,0;for _,sample in ipairs(self.brakeSamples) do a=math.min(a,sample.deceleration);r=math.max(r,sample.reaction) end;cfg.braking=math.min(cfg.braking or a,a);self.reaction=r end
   end
  end
  local desired=nil;local probe
  if cal and not cal.paused and not cal.complete and not manual then desired,probe=cal:step(p,v,omegaNow,true);self.phase='CALIBRATING'
  elseif mission and not manual then desired=mission:step(p,v);self.phase=mission.phase
  else self.phase='HOLDING' end
  local worldAx,worldAz=0,0;local desiredYaw=p.yaw;local aligning=false
  local tilt=(cfg.tilt or 8)*(self.scale or 1);local acceleration=p.gravity*math.tan(math.rad(tilt))
  if desired then
   if Mission.distance(desired,self.target)>0 then self.progressKey=nil end
   self.target=vec(desired.x,desired.y,desired.z)
   local dx,dz=desired.x-p.x,desired.z-p.z;local distance=math.sqrt(dx*dx+dz*dz)
   local brake=cfg.braking or acceleration;local reaction=self.reaction or .5
   local requestedSpeed=math.min(.6*distance,math.sqrt((brake*reaction)^2+2*brake*math.max(0,distance-.05))-brake*reaction)
   if desired.speed and desired.speed>0 then requestedSpeed=math.min(requestedSpeed,desired.speed) end
   if caps.surface and not yawAvailable and distance>.5 and math.abs(dx*math.sin(yaw)+dz*math.cos(yaw))<.2*distance then forward=1 end
   local tx,tz=distance>.01 and dx/distance*requestedSpeed or 0,distance>.01 and dz/distance*requestedSpeed or 0
   worldAx,worldAz=1.2*(tx-v.x),1.2*(tz-v.z)
   if caps.surface and not yawAvailable and distance>.5 and math.abs(dx*math.sin(yaw)+dz*math.cos(yaw))<.2*distance then worldAx,worldAz=acceleration*.3*math.sin(yaw),acceleration*.3*math.cos(yaw) end
   if desired.heading and (yawAvailable or caps.surface) then desiredYaw=desired.heading;if caps.surface and caps.reverse and math.abs(wrap(desiredYaw-(self.navigationHeading or p.yaw)))>90 then desiredYaw=wrap(desiredYaw+180) end;self.navigationHeading=desiredYaw;left=clip(-wrap(desiredYaw-p.yaw)/45,-1,1);forward=0
   elseif yawAvailable or caps.surface then
    if distance>.5 then local bearing=math.deg(Geometry.atan2(dx,dz));if caps.reverse and math.abs(wrap(bearing-(self.navigationHeading or p.yaw)))>90 then bearing=wrap(bearing+180) end;self.navigationHeading=bearing end
    desiredYaw=self.navigationHeading or self.heading;left=clip(-wrap(desiredYaw-p.yaw)/45,-1,1);forward=clip((tx*math.sin(yaw)+tz*math.cos(yaw)-(v.x*math.sin(yaw)+v.z*math.cos(yaw)))*.5,-1,1) end
   if drive and yawAvailable and not caps.surface and math.abs(wrap(desiredYaw-p.yaw))>20 then
    aligning=true;self.phase='ALIGNING';worldAx,worldAz=-1.2*v.x,-1.2*v.z
   end
  elseif forward~=0 or left~=0 then
   if (yawAvailable or caps.surface) and cfg.steering~=false then self.heading=wrap(self.heading-left*30*dt);desiredYaw=self.heading
   elseif cfg.steering~=false then
    if speed>.3 then self.course=self.course-left*math.deg(acceleration/math.max(.3,speed))*dt end
    local angle=math.rad(self.course)
    worldAx=acceleration*forward*math.sin(angle)-left*acceleration*math.cos(angle)
    worldAz=acceleration*forward*math.cos(angle)+left*acceleration*math.sin(angle)
    if forward==0 and speed<.3 then worldAx,worldAz=0,0 end
   end
   if yawAvailable or caps.surface or cfg.steering==false then worldAx=acceleration*(forward*math.sin(yaw)-left*math.cos(yaw));worldAz=acceleration*(forward*math.cos(yaw)+left*math.sin(yaw)) end
  elseif not manual and self.mode=='HEADING' then
   desiredYaw=(yawAvailable or caps.surface) and self.heading or p.yaw
   local angle=math.rad(self.heading);local request=self.speed or 0
   worldAx=1.2*(request*math.sin(angle)-v.x);worldAz=1.2*(request*math.cos(angle)-v.z)
   forward=clip((request*math.cos(angle-yaw)-(v.x*math.sin(yaw)+v.z*math.cos(yaw)))*.5,-1,1)
   left=yawAvailable and clip(-wrap(self.heading-p.yaw)/45,-1,1) or 0
  else
   desiredYaw=(yawAvailable or caps.surface) and self.heading or p.yaw
   if speed>.12 then
    -- Three-rotor tilt craft need more lead while attitude catches up.
    -- Keep the existing law for the other architectures and mixed quads.
    local lead=#groupList==3 and not drive and .8 or .4
    self.braking=true;worldAx=-1.2*(v.x+lead*self.acceleration.x);worldAz=-1.2*(v.z+lead*self.acceleration.z);self.target.x=p.x;self.target.z=p.z
   else
    self.braking=false;worldAx=.3*(self.target.x-p.x)-.9*v.x;worldAz=.3*(self.target.z-p.z)-.9*v.z
   end
   if drive then forward=clip((worldAx*math.sin(yaw)+worldAz*math.cos(yaw))*.5,-1,1) end
  end
  if not caps.travel or self.verticalLimited then worldAx,worldAz=0,0;forward,left=0,0 end
  local length=math.sqrt(worldAx^2+worldAz^2);if length>acceleration then worldAx,worldAz=worldAx*acceleration/length,worldAz*acceleration/length end
  local up=V.world(vec(0,1,0),p.q)
  if up.y<=.1 then return nil,'Sustentation retournee' end
  local recovering=math.acos(clip(up.y,-1,1))>math.rad(math.max(12,tilt+5))
  if recovering then
   worldAx,worldAz=0,0;forward,left=0,0;self.phase='DEGRADED';self.recovering=true
   if mission then mission:pause('Recuperation assiette') end
   if cal then cal:pause('Recuperation assiette') end
  elseif self.recovering and math.acos(clip(up.y,-1,1))<math.rad(5) then self.recovering=false;self:event('Assiette recuperee') end
  local pitchTarget,rollTarget=0,0
  if not drive and caps.pitch.available and caps.roll.available then
   pitchTarget=math.deg(math.atan((worldAx*math.sin(yaw)+worldAz*math.cos(yaw))/p.gravity))
   rollTarget=-math.deg(math.atan((worldAx*math.cos(yaw)-worldAz*math.sin(yaw))/p.gravity));worldAx,worldAz=0,0
  end
  local error=V.attitudeError(p.q,V.quaternion(pitchTarget,desiredYaw,rollTarget))
  local px,pz,modular,dedicatedYaw=3,3,false,false
  for _,g in ipairs(groupList) do dedicatedYaw=dedicatedYaw or g.role=='yaw-left' or g.role=='yaw-right' end
  local dr,da=modular and 8 or 4.5,modular and 1.2 or .6
  local yawDemand=dedicatedYaw and 6*error.y-8*omegaNow.y-1.2*accelNow.y or .5*error.y-3*omegaNow.y-accelNow.y
  local angular=vec(clip(px,4,40)*error.x-dr*omegaNow.x-da*accelNow.x,yawDemand,clip(pz,4,40)*error.z-dr*omegaNow.z-da*accelNow.z)
  -- Adapt only after a measured mass change, during holding/baseline; never
  -- turn a tracking transient or a commissioning pulse into a learned trim.
  if math.abs(p.mass-mass0)>mass0*1e-6 then self.massAdapted=true end
  for _,axis in ipairs({'x','z'}) do
   local capable=axis=='x' and caps.pitch.available or axis=='z' and caps.roll.available
   if self.massAdapted and capable and not manual and (not desired or cal and cal.phase=='BASELINE') and not probe and not recovering and not self.verticalLimited and math.abs(error[axis])>.00175 and math.abs(error[axis])<.1 and math.abs(omegaNow[axis])<.1 and (not self.info or self.info.residual<.5) then self.angleBias[axis]=clip(self.angleBias[axis]+2*error[axis]*dt,-2,2) end
   angular[axis]=angular[axis]+self.angleBias[axis]
  end
  if not caps.pitch.available then angular.x=0 end;if not yawAvailable and not caps.surface then angular.y=0 end;if not caps.roll.available then angular.z=0 end
  local yError=self.target.y-self.filters.y.x
  local desiredVy=clip(.5*yError,-(cfg.climb or 1),cfg.climb or 1)
  local ay=16*(desiredVy-v.y)+self.integral-10*self.acceleration.y
  local body=Geometry.bodyVector(vec(worldAx,0,worldAz),p.q)
  if not caps.right.available then body.x=0 end
  if not drive and not caps.forward.available then body.z=0 end
  local right=V.world(vec(1,0,0),p.q);local front=V.world(vec(0,0,1),p.q)
  body.y=(ay+p.gravity-body.x*right.y-body.z*front.y)/up.y
  local reversing={}
  local driveCount,arms=0,vec(0,0,0)
  for _,g in ipairs(groupList) do if g.role=='drive' then driveCount=driveCount+1;arms.x=arms.x+(g.y*g.dz-g.z*g.dy)^2;arms.y=arms.y+(g.z*g.dx-g.x*g.dz)^2;arms.z=arms.z+(g.x*g.dy-g.y*g.dx)^2 end end
  for _,g in ipairs(groupList) do
   local alpha=select(3,V.coefficients(g));local previous=lastSignals and lastSignals[tostring(g.id)] or g.neutral
   local rpm=(g.kind=='linear' or g.kind=='surface') and previous or Physics.rpm(g.source,previous)
   self.spool[g.id]=self.spool[g.id]+(1-(1-alpha)^(dt*20))*(rpm-self.spool[g.id])
   if g.role=='drive' and g.reverseA~='' then
    local intention=p.mass*(body.x*g.dx+body.y*g.dy+body.z*g.dz)/math.max(1,driveCount)
    if arms.x>1e-9 then intention=intention+(g.y*g.dz-g.z*g.dy)*angular.x*p.ix/arms.x end
    if arms.y>1e-9 then intention=intention+(g.z*g.dx-g.x*g.dz)*angular.y*p.iy/arms.y end
    if arms.z>1e-9 then intention=intention+(g.x*g.dy-g.y*g.dx)*angular.z*p.iz/arms.z end
    local sign=intention<-.05 and -1 or intention>.05 and 1 or self.directions[g.id]
    if not pending[g.id] and sign~=self.directions[g.id] then pending[g.id]={d=sign,t=p.tick} end
    local shift=pending[g.id]
    if shift then
     reversing[g.id]=true
     local sample=feedback and feedback[g.id]
     local valid=sample and sample.tick<=p.tick and p.tick-sample.tick<=2 and finite(sample.rpm) and sample.rpm>=0
     local observed=valid and sample.tick>shift.t
     local stopped=observed and sample.rpm<=.5 or not valid and self.spool[g.id]<=.5 and p.tick>shift.t
     if stopped then self.directions[g.id]=shift.d;pending[g.id]=nil;if observed then self.spool[g.id]=sample.rpm end;self:event(observed and 'Inversion: arret observe' or 'Inversion: arret estime') end
    end
   end
  end
  local model,meta,offset=V.matrix(groupList,p,v,mass0,self.directions)
  if not model then return nil,meta end
  for i,m in ipairs(meta) do
   if reversing[m.group.id] then for j=1,6 do model.columns[i].response[j]=0 end end
   m.column=model.columns[i].response
  end
  local wanted={body.z,body.x,body.y,angular.x,angular.y,angular.z}
  for j=1,6 do wanted[j]=wanted[j]-offset[j] end
  local values,allocation=V.solve(model,wanted);if not values then return nil,allocation end
  if probe then values[probe.index]=clip(values[probe.index]+probe.delta,0,15) end
  local signals,why=V.signals(meta,values,self.quant);if not signals then return nil,why end
  for _,g in ipairs(groupList) do if reversing[g.id] then signals[tostring(g.id)]=g.kind=='linear' and 0 or 15 end end
  if math.abs(allocation.actual[3]-wanted[3])<.1 then self.integral=clip(self.integral+.01*yError*dt,-3,3) end
  self.verticalLimited=math.abs(allocation.actual[3]-wanted[3])>math.max(1,math.abs(wanted[3])*.25)
  if self.verticalLimited then self.phase='DEGRADED';if mission then mission:pause('Reserve verticale insuffisante') end end
  local key=cal and not cal.complete and cal.phase or mission and tostring(mission.index)..':'..tostring(mission.segment) or self.mode
  if key~=self.progressKey then self.progress=Progress.new();self.progressKey=key end
  self.progress:observe({mission and Mission.distance(p,self.target) or self.target.z-p.z,mission and 0 or self.target.x-p.x,yError,math.deg(error.x),math.deg(error.y),math.deg(error.z)},{v.z,v.x,v.y,math.deg(omegaNow.x),math.deg(omegaNow.y),math.deg(omegaNow.z)},p.tick/20)
  local progress=self.progress:status()
  local stalled=aligning and progress.axes[5] or not aligning and (progress.axes[1] or progress.axes[2])
  if mission and not mission.completed and not mission.paused and Mission.distance(p,self.target)>.5 and stalled then mission:pause('Aucun progres; maintien') end
  if cal and not cal.complete and not cal.paused and stalled then cal:pause('Pas de convergence mesuree; resultats conserves') end
  self.previous=p
  local info={phase=self.phase,mode=self.mode,targetY=self.target.y,altitude=p.y,verticalSpeed=v.y,speed=speed,bodyYaw=p.yaw,course=self.course,bodyYawControlled=yawAvailable,
   capabilities=caps,residual=allocation.normalizedResidual,saturated=allocation.saturated,pitchTarget=pitchTarget,rollTarget=rollTarget,mass=p.mass,
   massChanged=self.massAdapted==true,rxConfirmed=false,shaftConfirmed=false,reason=cal and not cal.complete and cal.reason or mission and (mission.paused and mission.events[#mission.events] or mission.phase) or 'Modele declare; non qualifie'}
  info.reversing=reversing;self.info=info;return signals,info
 end
 return s
end
return M

end)()

_G.MintCraftFlightModules={Portable,Geometry,Physics,Response,Progress,Filter,Vehicle,Mission,Calibration,Flight}
end
local __modules=_G.MintCraftFlightModules
local Portable,Geometry,Physics,Response,Progress,Filter,Vehicle,Mission,Calibration,Flight=__modules[1],__modules[2],__modules[3],__modules[4],__modules[5],__modules[6],__modules[7],__modules[8],__modules[9],__modules[10]
-- Sole physical writer in the universal graph. No client-side actuation.
local s=_G.MintCraftPilot
if not s then s={label=ui.label('Autopilote: montage puis OFF'),archive=ui.textfield(500),low=0,phase='DISARMED',requestSeen=''};s.archive.setValue('');_G.MintCraftPilot=s end
addElement(s.label);addElement(s.archive)
local emit=output
if false then output('Status','string') output('Acknowledged revision',0) output('Active',0) output('Altitude',0) output('Target altitude',0) output('Capabilities','string') output('Report','string') output('Geometry','string') output('Telemetry','string') output('Body yaw controlled',0) output('Flight qualified',0) output('Route','string') output('Position','string') output('Trace','string') end
local settings=input('Settings','string');local request=input('Request','string')
local enable=input('Enable');local enableBinding=input('Enable binding','string');local keyboard=input('Keyboard bindings','string');local keys=input('Commands valid')
local command={forward=input('Forward demand'),left=input('Left demand'),vertical=input('Vertical demand')}
local cut=input('Mechanical cut');local stop=input('Stop horizontal')
local feedback={}
for _,text in ipairs({input('Observations A','string'),input('Observations B','string')}) do
 if type(text)=='string' and #text<=4096 then for line in text:gmatch('[^\n]+') do
  local id,rpm,at=line:match('^([^,]+),([^,]+),([^,]+)$');id,rpm,at=tonumber(id),tonumber(rpm),tonumber(at)
  if id and id%1==0 and id>=1 and id<=32 and rpm and rpm>=0 and rpm<100000 and at then feedback[id]={rpm=rpm,tick=at} end
 end end
end
local liveBinding=s.core and s.activeEnableBinding or enableBinding
if type(liveBinding)=='string' and type(receiveWirelessRedstone)=='function' then
 local a,b=liveBinding:match('^([^,]+),([^,]+)$');local ok,value=pcall(receiveWirelessRedstone,a,b)
 enable=ok and value or -1
else enable=-1 end
local descriptors={}
for _,text in ipairs({input('Groups A','string'),input('Groups B','string')}) do
 if type(text)=='string' and #text<=38432 then for line in text:gmatch('[^\n]+') do descriptors[#descriptors+1]=line end
 elseif type(text)=='string' and text~='' then descriptors[#descriptors+1]='INVALID_OVERSIZE' end
end
local function read(name) if type(_G[name])=='function' then local ok,a,b,c=pcall(_G[name]);if ok then return a,b,c end end end
local tick=read('getUniverseTime');local mass=read('getShipMass')
local x,y,z=read('getPosition');local pitch,yaw,roll=read('getOrientation');local ix,iy,iz=read('getInertiaTensor')
local vx,vy,vz=read('getVelocity')
local pose={vx=vx,vy=vy,vz=vz,tick=tick,mass=mass,x=x,y=y,z=z,pitch=pitch,yaw=yaw,roll=roll,ix=ix,iy=iy,iz=iz,dimension=read('getDimension')}
local finite,copy=Vehicle.finite,Vehicle.copy
local server=finite(tick) and tick>0 and finite(mass) and mass>0
local function pieces(text,sep,max)
 if type(text)~='string' or #text>(max or 16000) then return {} end
 local out={};for value in (text..sep):gmatch('(.-)'..sep) do out[#out+1]=value end;return out
end
local function config()
 local p=pieces(settings,';',1024)
 if (#p~=10 and #p~=11) or p[1]~='MCU1' then return nil,'Reglages montage absents' end
 local c={profile=tonumber(p[2]),gravity=tonumber(p[3]),climb=tonumber(p[4]),tilt=tonumber(p[5]),margin=tonumber(p[6]),braking=tonumber(p[7]),released=p[10]=='1',steering=p[11]~='0',protected={}}
 for _,key in ipairs({'profile','gravity','climb','tilt','margin','braking'}) do if not finite(c[key]) then return nil,'Reglage '..key..' invalide' end end
 if c.profile%1~=0 or c.profile<1 or c.profile>5 or c.gravity<=0 or c.gravity>100 or c.climb<=0 or c.climb>5 or c.tilt<=0 or c.tilt>20 or c.margin<0 or c.braking<=0 then return nil,'Domaine reglages invalide' end
 if p[8]~='1' or p[9]~='1' then return nil,'Confirmer montage/reprise et zone degagee' end
 local a,b
 if type(enableBinding)=='string' then a,b=enableBinding:match('^([^,]+),([^,]+)$') end
 if not Vehicle.pair(a,b) then return nil,'Frequence Enable absente' end;c.protected[1]=enableBinding
 if type(keyboard)=='string' and keyboard~='' then
  local count=0;for pair in keyboard:gmatch('[^|]+') do local ka,kb=pair:match('^([^,]+),([^,]+)$');if not Vehicle.pair(ka,kb) then return nil,'Frequence clavier invalide' end;count=count+1;c.protected[#c.protected+1]=pair end
  if count~=6 then return nil,'Clavier: 6 paires ou vide' end
 end
 local groups={};local signature={settings,enableBinding,tostring(keyboard)}
 for _,text in ipairs(descriptors) do
  if type(text)=='string' and text~='' then local g,why=Vehicle.decode(text);if not g then return nil,why end;groups[#groups+1]=g;signature[#signature+1]=Vehicle.encode(g) end
 end
 local ok,why=Vehicle.validate(groups,c.protected);if not ok then return nil,why end
 for _,g in ipairs(groups) do if g.x^2+g.y^2+g.z^2>c.margin^2 then return nil,'Rayon de coque insuffisant' end end
 return c,groups,table.concat(signature,'|')
end
local function pairKey(g) return table.concat({g.powerA,g.powerB,g.reverseA,g.reverseB,g.clutchA,g.clutchB},',') end
local function sameMappings(groups)
 if not s.owner then return true end
 if #groups~=#s.owner then return false end
 for i,g in ipairs(groups) do if pairKey(g)~=pairKey(s.owner[i]) then return false end end
 return true
end
local function send(signals,mechanical)
 if not s.owner or type(transmitWirelessRedstone)~='function' then return false end
 local ok,sent=true,{}
 local function tx(a,b,value) if a~='' then if not pcall(transmitWirelessRedstone,a,b,value) then ok=false end end end
 for _,g in ipairs(s.owner) do
  local signal=mechanical and ((g.kind=='linear' or g.kind=='surface') and 0 or 15) or signals and signals[tostring(g.id)] or g.fallback
  if not finite(signal) or signal%1~=0 or signal<0 or signal>15 then signal=g.fallback;ok=false end
  tx(g.powerA,g.powerB,signal);sent[tostring(g.id)]=signal
  local direction=s.core and s.core.directions[g.id] or s.directions and s.directions[g.id] or 1
  tx(g.reverseA,g.reverseB,direction<0 and 15 or 0)
  local stopped=mechanical or g.role=='drive' and signal==((g.kind=='linear' or g.kind=='surface') and 0 or 15)
  tx(g.clutchA,g.clutchB,stopped and 15-g.run or g.run)
 end
 s.lastSignals=sent
 return ok
end
local function fail(why)
 if not s.firstFault then s.firstFault=tostring(why) end
 if s.core then s.directions=copy(s.core.directions);s.savedEvents=copy(s.core.events) end
 s.core=nil;s.phase='DEGRADED';s.low=0;s.reason='Defaut: '..tostring(why)..'; repli configure, OFF requis';send(nil,s.cutLatched)
end
local c,groups,signature=config()
local valid=c~=nil
local advancing=server and (not s.tick or tick>s.tick)
local gap=server and s.tick and (tick<s.tick or tick-s.tick>10)
if server then
 if cut~=0 then
  if s.core then s.directions=copy(s.core.directions) end
  s.core=nil;s.cutLatched=true;s.phase='MECHANICAL_CUT';s.low=0;send(nil,true);s.reason='Coupure mecanique; altitude non maintenue'
 elseif not finite(enable) or enable<0 or enable>15 then fail('Enable invalide')
 elseif gap then fail('Horloge perdue/regressee')
 elseif enable==0 then
  if s.core then s.directions=copy(s.core.directions);s.core=nil end
  s.phase='DISARMED';send(nil,s.cutLatched)
  if valid and not c.released then s.releaseConsumed=false end
  if advancing then s.low=s.low+1 end
  if s.low>=2 then if valid then s.readySignature=signature end;s.firstFault=nil;s.reason=valid and 'Pret: activer sans touche' or tostring(groups) end
 elseif not s.core then
  if not valid then s.reason=tostring(groups)
  elseif s.low<2 or s.readySignature~=signature then s.reason='Armement: OFF physique requis'
  elseif keys==1 and (command.forward~=0 or command.left~=0 or command.vertical~=0) then s.reason='Armement: relacher touches'
  elseif not sameMappings(groups) and (not c.released or s.releaseConsumed) then s.reason='Remappage: confirmer anciens recepteurs retires'
  else
   c.candidate=s.archive.getValue();pose.gravity=c.gravity
   local core,why=Flight.new(groups,pose,c)
   if not core then s.reason=why
   else if sameMappings(groups) and s.owner and s.directions then for i,g in ipairs(groups) do core.directions[g.id]=s.directions[s.owner[i].id] or 1 end end;s.cutLatched=false;s.releaseConsumed=c.released;s.core=core;s.activeKeyboard=keyboard;s.activeEnableBinding=enableBinding;s.owner=copy(groups);for _,g in ipairs(s.owner) do if g.fallback==-1 then g.fallback=core.initialSignals[tostring(g.id)] end end;s.signature=signature;s.settings=settings;s.phase='HOLDING';s.low=0;s.lastSignals=copy(core.initialSignals);s.requestSeen=request;s.reason='Maintien initialise; montage non certifie' end
  end
 end
 if s.core and advancing then
  pose.gravity=s.core.config.gravity
  if type(request)=='string' and request~='' and request~=s.requestSeen then
   s.requestSeen=request;local r=pieces(request,'|',25000)
   if #r==8 and r[1]=='MCC1' then
    local accepted,why=s.core:apply({revision=tonumber(r[2]),mode=r[3],altitude=tonumber(r[4]),speed=tonumber(r[5]),heading=tonumber(r[6]),route=r[7],zones=r[8]},pose)
    s.commandError=not accepted and why or nil
   else s.commandError='Format de consigne invalide' end
  end
  local tune=input('Stability request','string');local at,factor
  if type(tune)=='string' then at,factor=tune:match('^MCSUP1,(%d+),([^,]+)$') end
  at,factor=tonumber(at),tonumber(factor)
  s.core.scale=finite(at) and at<=tick and tick-at<=2 and finite(factor) and factor>=.5 and factor<=1 and factor or s.core.scale or 1
  if stop~=0 then if s.core.calibration and not s.core.calibration.complete then s.core.calibration:pause('STOP horizontal') end;if s.core.mission then s.core.mission:pause('STOP horizontal') end;s.core.mode='HOLD';command={forward=0,left=0,vertical=0} end
  if keys~=1 then command={forward=0,left=0,vertical=0} end
  -- Sample validated keyboard channels directly: avoid an extra graph stage.
  if keys==1 and type(receiveWirelessRedstone)=='function' then
   local levels={};for pair in (s.activeKeyboard or keyboard):gmatch('[^|]+') do local a,b=pair:match('^([^,]+),([^,]+)$');local ok,value=pcall(receiveWirelessRedstone,a,b);if not ok or not finite(value) or value<0 or value>15 or value%1~=0 then levels={};break end;levels[#levels+1]=value>0 and 1 or 0 end
   if #levels==6 then command={forward=levels[1]-levels[2],left=levels[3]-levels[4],vertical=levels[5]-levels[6]} else command={forward=0,left=0,vertical=0} end
  end
  if stop~=0 then command={forward=0,left=0,vertical=0} end
  -- A new core starts at this tick; first control update is the following tick.
  if s.core.tick~=tick then
   local ok,signals,info=pcall(s.core.step,s.core,pose,command,s.lastSignals,feedback)
   if not ok then fail('Erreur calcul: '..tostring(signals))
   elseif not signals then fail(info)
   elseif not send(signals) then fail('Emission Link en echec')
   else
    s.info=info;s.phase=info.phase;s.reason=info.phase..' h='..y..'>'..info.targetY..' | '..info.reason
   end
  else send(s.lastSignals) end
 end
 if s.owner and not s.core then send(nil,s.cutLatched) end
 s.tick=tick
elseif s.owner then fail('Contexte serveur/masse perdu') else s.reason='Client: voir serveur' end
local reason=s.reason or 'Configurer le montage'
if s.core and signature~=s.signature then reason=reason..' | Montage en attente OFF' end
if s.commandError then reason=reason..' | '..s.commandError end
if s.firstFault then reason=reason..' | FIRST='..s.firstFault end
s.label.setText(reason)
local core=s.core;local cal=core and core.calibration;local caps={};if core and core.capabilities then for _,name in ipairs(Response.axes) do caps[#caps+1]=name..'='..tostring(core.capabilities[name].available) end end
-- MCF1 is a single writer observation; '?' means unavailable, not zero.
local report='MCREPORT1 | '..reason..'\n'..table.concat({'MCF1',tick or '?',mass or '?',ix or '?',iy or '?',iz or '?',x or '?',y or '?',z or '?',pitch or '?',yaw or '?',roll or '?',vx or '?',vy or '?',vz or '?',core and core.target.y or '?',core and 1 or 0,command.forward or '?',command.left or '?',command.vertical or '?',s.info and s.info.residual or '?',s.info and s.info.saturated and 1 or 0,s.info and s.info.loadBias or '?',read('getDimension') or '?',core and core.mode or '-',core and core.revision or 0,core and s.settings or '?',core and core.scale or 1},',')
for _,g in ipairs(core and core.groups or s.owner or {}) do report=report..'\nG,'..g.id..','..tostring(s.lastSignals and s.lastSignals[tostring(g.id)] or '?')..','..tostring(core and core.spool[g.id] or '?')..','..Calibration.hash(g) end
if server and cal and (cal.complete or cal.paused) and not core.archived then core.snapshot=Calibration.archive(cal,cal.mass);core.archived=true end
if server and core and core.snapshot then s.archive.setValue(core.snapshot) end
local geometry={};for _,g in ipairs(s.owner or {}) do geometry[#geometry+1]=table.concat({g.x,g.y,g.z},',') end
emit('Status',reason);emit('Active',core and 1 or 0);emit('Report',report)
if server then
 emit('Acknowledged revision',core and core.revision or 0);emit('Altitude',y or 0);emit('Target altitude',core and core.target.y or 0)
 local route,trace={},{}
 if core and core.mission then for _,p in ipairs(core.mission.route) do route[#route+1]=table.concat({p.x,p.y,p.z},',') end;for _,p in ipairs(core.mission.trace) do trace[#trace+1]=table.concat({p.x,p.y,p.z},',') end end
 emit('Route',table.concat(route,';'));emit('Position',table.concat({x,y,z},','));emit('Trace',table.concat(trace,';'))
 emit('Capabilities',table.concat(caps,' '));emit('Geometry',table.concat(geometry,';'));emit('Telemetry',reason);emit('Body yaw controlled',core and core.bodyYawControlled and 1 or 0);emit('Flight qualified',0)
 if type(display)=='function' then pcall(display,'MC_AUTOPILOT',reason);pcall(display,'MC_CAPABILITIES',table.concat(caps,' ')) end
end
