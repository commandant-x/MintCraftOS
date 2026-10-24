local Quad=(function()
-- Experimental near-level quad control. Measured local 3x4 response required.
-- World X/Z/Y constant-velocity Kalman filters; Euler rates only near level.
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
local function inverse(a)
 local b={{1,0,0},{0,1,0},{0,0,1}}
 for i=1,3 do
  local p=i for j=i+1,3 do if math.abs(a[j][i])>math.abs(a[p][i]) then p=j end end
  if math.abs(a[p][i])<1e-8 then return nil end
  a[i],a[p]=a[p],a[i] b[i],b[p]=b[p],b[i]
  local div=a[i][i] for j=1,3 do a[i][j]=a[i][j]/div b[i][j]=b[i][j]/div end
  for row=1,3 do if row~=i then
   local f=a[row][i] for j=1,3 do a[row][j]=a[row][j]-f*a[i][j] b[row][j]=b[row][j]-f*b[i][j] end
  end end
 end
 return b
end
function M.model(rows)
 if type(rows)~='table' or #rows~=4 then return nil,'Four measured rotor rows required' end
 local out={rows={},scale={0,0,0}}
 for i,r in ipairs(rows) do
  if type(r)~='table' or #r~=7 then return nil,'Row: trim,min,max,dY,dPitch,dRoll,fallback' end
  for _,v in ipairs(r) do if not finite(v) then return nil,'Nonfinite rotor row' end end
  for _,j in ipairs({1,2,3,7}) do if r[j]%1~=0 or r[j]<0 or r[j]>15 then return nil,'Signals must be integers 0..15' end end
  if r[2]>=r[1] or r[1]>=r[3] or math.abs(r[4])<1e-5 then return nil,'Measured trim must have bidirectional local margin' end
  out.rows[i]={} for j=1,7 do out.rows[i][j]=r[j] end
  for j=1,3 do out.scale[j]=math.max(out.scale[j],math.abs(r[j+3])) end
 end
 for j=1,3 do if out.scale[j]<1e-5 then return nil,'Vertical/pitch/roll authority absent' end end
 local gram={{0,0,0},{0,0,0},{0,0,0}}
 for _,r in ipairs(out.rows) do for i=1,3 do for j=1,3 do gram[i][j]=gram[i][j]+r[i+3]/out.scale[i]*r[j+3]/out.scale[j] end end end
 out.inv=inverse(gram) if not out.inv then return nil,'Measured rotor response lacks rank' end
 local norm=0 for i=1,3 do for j=1,3 do norm=norm+math.abs(out.inv[i][j]) end end
 if norm>1000 then return nil,'Measured response is ill conditioned' end
 return out
end
function M.allocate(model,demand)
 local multiplier={0,0,0}
 for i=1,3 do for j=1,3 do multiplier[i]=multiplier[i]+model.inv[i][j]*demand[j]/model.scale[j] end end
 local values,scale={},1
 for i,r in ipairs(model.rows) do
  local delta=0 for j=1,3 do delta=delta+r[j+3]/model.scale[j]*multiplier[j] end
  values[i]=delta
  if delta>0 then scale=math.min(scale,(r[3]-r[1])/delta)
  elseif delta<0 then scale=math.min(scale,(r[2]-r[1])/delta) end
 end
 for i,r in ipairs(model.rows) do values[i]=r[1]+values[i]*scale end
 return values,scale
end
function M.new(rows,pose,config)
 local model,why=M.model(rows) if not model then return nil,why end
 config=config or {}
 for _,k in ipairs({'tick','x','y','z','pitch','roll','yaw','mass'}) do if not finite(pose[k]) then return nil,'Finite server pose required' end end
 if pose.mass<=0 or type(pose.dimension)~='string' or pose.dimension=='' then return nil,'Server mass/dimension required' end
 if math.abs(pose.pitch)>10 or math.abs(pose.roll)>10 then return nil,'Start near level' end
 local s={model=model,tick=pose.tick,mass=pose.mass,dimension=pose.dimension,filters={},target={x=pose.x,y=pose.y,z=pose.z},integral=0,quant={0,0,0,0},samples=0}
 s.speed=config.speed or 2 s.climb=config.climb or 1 s.tilt=config.tilt or 8
 s.noise=config.noise or .0025 s.process=config.process or 4
 if not finite(s.speed) or s.speed<=0 or s.speed>10 or not finite(s.climb) or s.climb<=0 or s.climb>3 or not finite(s.tilt) or s.tilt<=0 or s.tilt>15 then return nil,'Invalid local control envelope' end
 for _,key in ipairs({'x','y','z','pitch','roll'}) do
  local angle=key=='pitch' or key=='roll'
  s.filters[key]=M.filter(pose[key],angle and .04 or s.noise,angle and 100 or s.process)
  if not s.filters[key] then return nil,'Positive Kalman noise parameters required' end
 end
 function s:step(p,command)
  for _,key in ipairs({'tick','x','y','z','pitch','roll','yaw','mass'}) do if not finite(p[key]) then return nil,'Pose lost/nonfinite' end end
  if p.dimension~=self.dimension or p.mass<=0 then return nil,'Server context changed' end
  local dt=(p.tick-self.tick)/20
  if dt<=0 or dt>.5 then return nil,'Clock repeated/regressed/gapped' end
  if math.abs(p.pitch)>25 or math.abs(p.roll)>25 then return nil,'Near-level attitude envelope exceeded' end
  for _,key in ipairs({'forward','left','vertical'}) do if not finite(command[key]) or math.abs(command[key])>1 then return nil,'Invalid movement command' end end
  local measurement={x=p.x,y=p.y,z=p.z,pitch=p.pitch,roll=p.roll}
  for key,k in pairs(self.filters) do
   local z=measurement[key] if key=='pitch' or key=='roll' then z=k.x+wrap(z-k.x) end
   if math.abs(z-k.x)>((key=='pitch' or key=='roll') and 30 or 20) then return nil,'Pose discontinuity' end
   if not M.update(k,z,dt) then return nil,'Kalman failure' end
  end
  self.tick=p.tick self.samples=self.samples+1
  local k=self.filters local yaw=math.rad(p.yaw)
  -- Minecraft YXZ: body forward +Z maps to (sin yaw, cos yaw) in world X/Z.
  local vx=self.speed*(command.forward*math.sin(yaw)-command.left*math.cos(yaw))
  local vz=self.speed*(command.forward*math.cos(yaw)+command.left*math.sin(yaw))
  if command.forward~=0 or command.left~=0 then self.target.x=k.x.x self.target.z=k.z.x end
  if command.vertical~=0 then self.target.y=self.target.y+command.vertical*self.climb*dt end
  local desiredX=command.forward~=0 or command.left~=0
  local ux=desiredX and vx or clip(.5*(self.target.x-k.x.x),-self.speed,self.speed)
  local uz=desiredX and vz or clip(.5*(self.target.z-k.z.x),-self.speed,self.speed)
  local ax=clip(1.2*(ux-k.x.v),-3,3) local az=clip(1.2*(uz-k.z.v),-3,3)
  local bodyRight=ax*math.cos(yaw)-az*math.sin(yaw)
  local bodyForward=ax*math.sin(yaw)+az*math.cos(yaw)
  local pitchTarget=clip(math.deg(math.atan(bodyForward/9.81)),-self.tilt,self.tilt)
  local rollTarget=clip(-math.deg(math.atan(bodyRight/9.81)),-self.tilt,self.tilt)
  local errorY=self.target.y-k.y.x
  local desiredY=clip(errorY,-self.climb,self.climb)
  local vertical=2*(desiredY-k.y.v)+self.integral
  local up=math.cos(math.rad(k.pitch.x))*math.cos(math.rad(k.roll.x))
  vertical=(vertical+9.81)/math.max(.8,up)-9.81
  local demand={vertical,6*(pitchTarget-k.pitch.x)-4*k.pitch.v,6*(rollTarget-k.roll.x)-4*k.roll.v}
  local values,scale=M.allocate(self.model,demand)
  -- Anti-windup: adapt hover bias in flight, never run a mass-triggered sweep.
  if scale>.99 then self.integral=clip(self.integral+.2*errorY*dt,-3,3) end
  local signals={}
  for i,r in ipairs(self.model.rows) do
   local value=clip(values[i]+self.quant[i],r[2],r[3])
   signals[i]=clip(math.floor(value+.5),r[2],r[3]) self.quant[i]=clip(value-signals[i],-.5,.5)
  end
  return signals,{scale=scale,altitude=k.y.x,targetY=self.target.y,verticalSpeed=k.y.v,pitchTarget=pitchTarget,rollTarget=rollTarget,massChanged=math.abs(p.mass-self.mass)/self.mass>.02,ready=self.samples>=3}
 end
 return s
end
return M

end)()
-- Actual Link actuator adapter. Experimental near-level control, not certified flight.
local s=_G.MintCraftQuad
local names={'Avant gauche','Avant droite','Arriere gauche','Arriere droite'}
if not s then
 s={rotors={},low=0,phase='off',label=ui.label('Quad experimental: modele mesure obligatoire'),
  checked=ui.checkbox('Modele local et reprise physique verifies; essais experimentaux'),
  noise=ui.textfield(140),process=ui.textfield(140),speed=ui.textfield(140),climb=ui.textfield(140),tilt=ui.textfield(140)}
 s.noise.setValue('0.0025') s.process.setValue('4') s.speed.setValue('2') s.climb.setValue('1') s.tilt.setValue('8')
 s.help=ui.label('Bruit position R / acceleration Q / vitesse / montee / inclinaison max')
 for i,name in ipairs(names) do s.rotors[i]={label=ui.label(name..': Link puis trim,min,max,dY,dPitch,dRoll,repli'),a=ui.itempicker(),b=ui.itempicker(),row=ui.textfield(300)} end
 _G.MintCraftQuad=s
end
addElement(s.label) addElement(s.checked) addElement(s.help)
for _,key in ipairs({'noise','process','speed','climb','tilt'}) do addElement(s[key]) end
for _,r in ipairs(s.rotors) do addElement(r.label) addElement(r.a) addElement(r.b) addElement(r.row) end
local emit=output
if false then output('Status','string') output('Active',0) output('Altitude',0) output('Target altitude',0) output('Kalman ready',0) output('Flight qualified',0) end
local keyboardBindings=input('Keyboard bindings','string')
local enableBinding=input('Enable binding','string')
local enabled=input('Flight Enable') local keys=input('Commands valid')
local forward=input('Forward demand') local left=input('Left demand') local vertical=input('Vertical demand')
local function finite(v) return Quad.finite(v) end
local function item(v) return type(v)=='string' and #v<=192 and v~='minecraft:air' and v:match('^[a-z0-9_.%-]+:[a-z0-9_./%-]+$') end
local function read(name)
 if type(_G[name])~='function' then return end
 local ok,a,b,c=pcall(_G[name]) if ok then return a,b,c end
end
local tick=read('getUniverseTime') local mass=read('getShipMass')
local x,y,z=read('getPosition') local pitch,yaw,roll=read('getOrientation') local dimension=read('getDimension')
local pose={tick=tick,mass=mass,x=x,y=y,z=z,pitch=pitch,yaw=yaw,roll=roll,dimension=dimension}
local server=finite(tick) and tick>0 and finite(mass) and mass>0
local rows,pairs_,seen,parts={}, {},{},{}
local valid=s.checked.isChecked() and type(transmitWirelessRedstone)=='function'
-- Reject collisions across keyboard, physical enable and all four rotor outputs.
local function binding(id)
 if type(id)~='string' or #id>386 then return false end
 local a,b=id:match('^([^,]+),([^,]+)$')
 return item(a) and item(b)
end
if not binding(enableBinding) then valid=false else seen[enableBinding]=true end
local count=0
if type(keyboardBindings)~='string' or #keyboardBindings>2400 then valid=false else
 for id in keyboardBindings:gmatch('[^|]+') do
  count=count+1
  if not binding(id) or seen[id] then valid=false end seen[id]=true
 end
end
if count~=6 then valid=false end
parts[#parts+1]=tostring(keyboardBindings)..':'..tostring(enableBinding)
for i,r in ipairs(s.rotors) do
 local a,b=r.a.getItem(),r.b.getItem() local text=r.row.getValue()
 parts[#parts+1]=tostring(a)..','..tostring(b)..':'..tostring(text)
 if not item(a) or not item(b) or seen[tostring(a)..','..tostring(b)] then valid=false end
 seen[tostring(a)..','..tostring(b)]=true pairs_[i]={a,b}
 rows[i]={}
 if type(text)~='string' or #text>256 then valid=false else
  -- Empty fields must not silently shift response columns.
  local count=0 for token in (text..','):gmatch('(.-),') do count=count+1 rows[i][count]=tonumber(token) or false end
  if count~=7 then valid=false end
 end
end
local config={}
for _,key in ipairs({'noise','process','speed','climb','tilt'}) do config[key]=tonumber(s[key].getValue()) parts[#parts+1]=tostring(config[key])
 if not finite(config[key]) or config[key]<=0 then valid=false end end
local model,modelWhy=Quad.model(rows) if not model then valid=false end
local signature=table.concat(parts,'|')
local function send(values)
 if not s.owner then return false end
 -- No Link ACK is available: RPC success is not proof of rotor response.
 local ok=true
 for i,pair in ipairs(s.owner.pairs) do
  local good=pcall(transmitWirelessRedstone,pair[1],pair[2],values[i]) if not good then ok=false end
 end
 return ok
end
local function fallback(why)
 if s.owner then
  local values={} for i,r in ipairs(s.owner.rows) do values[i]=r[7] end
  send(values)
 end
 s.core=nil s.phase='fault' s.low=0 s.reason=why
end
local advancing=server and (not s.tick or tick>s.tick)
local gap=server and s.tick and (tick<s.tick or tick-s.tick>10)
if s.owner and (not server or not valid or s.signature~=signature or gap or not finite(enabled) or enabled<0 or enabled>15) then
 fallback('Configuration/contexte/horloge perdu; repli mesure, reprise physique')
end
if server then
 if enabled==0 then
  if s.owner and s.phase=='active' then fallback('Desactive: repli configure, pas de coupure des pales') end
  if advancing and valid and not gap then s.low=s.low+1 else s.low=0 end
  if s.low>=2 then s.phase='ready' s.reason='Pret: activer sans touche' end
 elseif finite(enabled) and enabled>0 and enabled<=15 and valid and not gap then
  if s.phase=='ready' and keys==1 and forward==0 and left==0 and vertical==0 then
   local core,why=Quad.new(rows,pose,config)
   if core then
    s.info=nil s.core=core s.owner={pairs=pairs_,rows=model.rows} s.phase='active' s.reason='Stabilisation experimentale active'
    local trims={} for i,r in ipairs(model.rows) do trims[i]=r[1] end
    if not send(trims) then fallback('Echec transmission initiale') end
   else fallback(why) end
  end
  if s.phase=='active' and advancing and s.core.tick~=tick then
   -- On keyboard invalidity, brake/hold; never turn a missing command into rotor STOP.
   local command=keys==1 and {forward=forward,left=left,vertical=vertical} or {forward=0,left=0,vertical=0}
   local values,info=s.core:step(pose,command)
   if not values then fallback(info)
   elseif not send(values) then fallback('Echec transmission Link; reprise physique')
   else s.info=info s.reason=info.massChanged and 'Masse modifiee: adaptation du trim en vol' or keys~=1 and 'Clavier indisponible: freinage/maintien demande' or 'Stabilisation experimentale active' end
  end
 end
elseif not s.owner then s.reason='Configuration client; etat serveur via MC_QUAD' end
if s.owner and s.phase~='active' then
 local values={} for i,r in ipairs(s.owner.rows) do values[i]=r[7] end
 send(values)
end
if server then s.tick=tick end
s.signature=signature
s.label.setText(s.reason or modelWhy or 'Configurer les quatre sorties et le modele mesure')
if not server and not s.owner then return end
local active=s.phase=='active'
emit('Active',active and 1 or 0) emit('Flight qualified',0)
emit('Kalman ready',active and s.info and s.info.ready and 1 or 0)
emit('Altitude',s.info and s.info.altitude or 0) emit('Target altitude',s.core and s.core.target.y or 0)
emit('Status',s.reason or modelWhy or 'Inactif')
if type(display)=='function' and server then display('MC_QUAD',s.reason or 'Inactif') end
