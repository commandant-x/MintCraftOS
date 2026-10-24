local Physics=(function()
-- Audited defaults: Aeronautics/Simulated 1.3.2 + Sable 2.0.6, small fixed props.
-- No sensor/ownership claims. Geometry, normal thrust direction and defaults confirmed by operator.
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
function M.pressure(y)
 if not finite(y) then return nil end
 -- DimensionPhysics.createDefault: sea=63, min=-64, logicalHeight=384 (Overworld).
 local sea,top=63,320 local smoothing=top-40
 local current=math.max(-64,math.log(1.5)/-.004+sea) local points={}
 for _=1,16 do
  local p=math.exp(-.004*(current-sea)) points[#points+1]={current,p,-.004*p}
  if current>=smoothing then break end
  if current<sea and current+200>=sea then current=sea
  elseif current<smoothing and current+200>=smoothing then current=smoothing
  else current=current+200 end
 end
 local last=points[#points] points[#points+1]={top,0,-2*last[2]/(top-smoothing)}
 if y<points[1][1] then return points[1][2] end
 for i=1,#points-1 do
  local a,b=points[i],points[i+1]
  if y<b[1] then
   local dx,dy=b[1]-a[1],b[2]-a[2] local t=(y-a[1])/dx
   local cubic=(a[3]+b[3])*dx-2*dy
   local quadratic=3*dy-(2*a[3]+b[3])*dx
   return math.max(((cubic*t+quadratic)*t+dx*a[3])*t+a[2],0)
  end
 end
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
function M.rows(spec,pose,velocity)
 if type(spec)~='table' or type(pose)~='table' or pose.dimension~='minecraft:overworld' then return nil,'Default Overworld physics only' end
 for _,key in ipairs({'source','thrust','airflow','armX','armZ','gravity'}) do
  if not finite(spec[key]) or spec[key]<=0 then return nil,'Positive physical parameters required' end
 end
 if not finite(spec.height) or math.abs(spec.height)>32 or spec.armX>32 or spec.armZ>32 or spec.source>256 then return nil,'Unsupported fixed-quad geometry/source RPM' end
 for _,key in ipairs({'mass','ix','iz','y','pitch','roll','yaw'}) do if not finite(pose[key]) then return nil,'Server mass, inertia and pose required' end end
 if pose.mass<=0 or pose.ix<=0 or pose.iz<=0 then return nil,'Positive mass and inertia required' end
 local p,r,yaw=math.rad(pose.pitch),math.rad(pose.roll),math.rad(pose.yaw)
 local up={math.sin(yaw)*math.sin(p)*math.cos(r)-math.cos(yaw)*math.sin(r),math.cos(p)*math.cos(r),math.cos(yaw)*math.sin(p)*math.cos(r)+math.sin(yaw)*math.sin(r)}
 velocity=velocity or {x=0,y=0,z=0,pitch=0,roll=0}
 for _,key in ipairs({'x','y','z','pitch','roll'}) do if not finite(velocity[key]) then return nil,'Finite local airflow velocity required' end end
 local axial=velocity.x*up[1]+velocity.y*up[2]+velocity.z*up[3]
 local locations={{-spec.armX,spec.armZ},{spec.armX,spec.armZ},{-spec.armX,-spec.armZ},{spec.armX,-spec.armZ}}
 local rows={} local diagnostics={rotors={},maxThrust=0,required=pose.mass*spec.gravity,pressure=M.pressure(pose.y),rpmAtZero=M.rpm(spec.source,0)}
 for i,location in ipairs(locations) do
  local x,z=location[1],location[2]
  local height=pose.y+spec.height*up[2]+x*math.sin(r)*math.cos(p)-z*math.sin(p)
  local pressure=M.pressure(height)
  if not pressure or pressure<=0 then return nil,'No atmospheric pressure at a rotor' end
  local v=axial+math.rad(velocity.roll)*x-math.rad(velocity.pitch)*z
  local maxRpm=M.rpm(spec.source,0)
  local maximum=M.force(maxRpm,pressure,v,spec.thrust,spec.airflow)
  diagnostics.maxThrust=diagnostics.maxThrust+maximum
  diagnostics.rotors[i]={pressure=pressure,maximum=maximum,rpm=maxRpm}
  local required=pose.mass*spec.gravity/4
  if not maximum or required>=maximum then return nil,'Insufficient lift at this mass/altitude/inflow',diagnostics end
  local equilibriumRPM=required/(spec.thrust*pressure)+math.max(0,v)/spec.airflow
  local trim=M.signal(spec.source,equilibriumRPM)
  if trim<=0 or trim>=15 then return nil,'No interior lift margin' end
  diagnostics.rotors[i].trim=trim
  local slope=-spec.thrust*pressure*spec.source/(trim<1 and 8 or 16)
  rows[i]={trim,0,15,slope/pose.mass,math.deg(-z*slope/pose.ix),math.deg(x*slope/pose.iz),clamp(math.floor(trim+.5),0,14)}
 end
 return rows,diagnostics
end
return M

end)()
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
function M.model(rows,continuous)
 if type(rows)~='table' or #rows~=4 then return nil,'Four measured rotor rows required' end
 local out={rows={},scale={0,0,0}}
 for i,r in ipairs(rows) do
  if type(r)~='table' or #r~=7 then return nil,'Row: trim,min,max,dY,dPitch,dRoll,fallback' end
  for _,v in ipairs(r) do if not finite(v) then return nil,'Nonfinite rotor row' end end
  for _,j in ipairs({1,2,3,7}) do if (j~=1 or not continuous) and r[j]%1~=0 or r[j]<0 or r[j]>15 then return nil,'Signals must be integers 0..15' end end
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
 config=config or {}
 local diagnostics
 if config.physics then
  if not M.Physics then return nil,'Physics library unavailable' end
  rows,diagnostics=M.Physics.rows(config.physics,pose)
  if not rows then return nil,diagnostics end
 end
 local model,why=M.model(rows,config.physics~=nil) if not model then return nil,why end
 for _,k in ipairs({'tick','x','y','z','pitch','roll','yaw','mass'}) do if not finite(pose[k]) then return nil,'Finite server pose required' end end
 if pose.mass<=0 or type(pose.dimension)~='string' or pose.dimension=='' then return nil,'Server mass/dimension required' end
 if math.abs(pose.pitch)>10 or math.abs(pose.roll)>10 then return nil,'Start near level' end
 local s={model=model,tick=pose.tick,mass=pose.mass,dimension=pose.dimension,filters={},target={x=pose.x,y=pose.y,z=pose.z},integral=0,quant={0,0,0,0},samples=0,
  lastAttitude={pitch=pose.pitch,roll=pose.roll},rates={pitch=0,roll=0}}
 s.physics=config.physics s.gravity=s.physics and s.physics.gravity or 9.81 s.diagnostics=diagnostics
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
  -- The position Kalman velocity lags too much to damp attitude through rotor
  -- spool/radio delays. Derive wrapped Euler rates from fresh measured angles,
  -- with a 50ms low-pass; these are near-level Euler rates, not body gyroscopes.
  for _,key in ipairs({'pitch','roll'}) do
   local measured=wrap(p[key]-self.lastAttitude[key])/dt
   self.rates[key]=self.rates[key]+dt/(.05+dt)*(measured-self.rates[key])
   self.lastAttitude[key]=p[key]
  end
  local measurement={x=p.x,y=p.y,z=p.z,pitch=p.pitch,roll=p.roll}
  for key,k in pairs(self.filters) do
   local z=measurement[key] if key=='pitch' or key=='roll' then z=k.x+wrap(z-k.x) end
   if math.abs(z-k.x)>((key=='pitch' or key=='roll') and 30 or 20) then return nil,'Pose discontinuity' end
   if not M.update(k,z,dt) then return nil,'Kalman failure' end
  end
  if self.physics then
   local velocity={} for _,key in ipairs({'x','y','z','pitch','roll'}) do velocity[key]=self.filters[key].v end
   local rows,info=M.Physics.rows(self.physics,p,velocity)
   if not rows then return nil,info end
   local model,why=M.model(rows,true) if not model then return nil,why end
   self.model=model self.diagnostics=info
  end
  self.tick=p.tick self.samples=self.samples+1
  local k=self.filters local yaw=math.rad(p.yaw)
  -- Minecraft YXZ: body forward +Z maps to (sin yaw, cos yaw) in world X/Z.
  local vx=self.speed*(command.forward*math.sin(yaw)-command.left*math.cos(yaw))
  local vz=self.speed*(command.forward*math.cos(yaw)+command.left*math.sin(yaw))
  if command.forward~=0 or command.left~=0 then self.target.x=k.x.x self.target.z=k.z.x end
  if command.vertical~=0 then self.target.y=self.target.y+command.vertical*self.climb*dt end
  local desiredX=command.forward~=0 or command.left~=0
  -- Keep the translation loop slower than attitude/rotor response. An aggressive
  -- velocity loop fights the delayed tilt correction and sustains oscillation.
  local ux=desiredX and vx or clip(.25*(self.target.x-k.x.x),-self.speed,self.speed)
  local uz=desiredX and vz or clip(.25*(self.target.z-k.z.x),-self.speed,self.speed)
  local ax=clip(.6*(ux-k.x.v),-3,3) local az=clip(.6*(uz-k.z.v),-3,3)
  local bodyRight=ax*math.cos(yaw)-az*math.sin(yaw)
  local bodyForward=ax*math.sin(yaw)+az*math.cos(yaw)
  local pitchTarget=clip(math.deg(math.atan(bodyForward/self.gravity)),-self.tilt,self.tilt)
  local rollTarget=clip(-math.deg(math.atan(bodyRight/self.gravity)),-self.tilt,self.tilt)
  local errorY=self.target.y-k.y.x
  local desiredY=clip(errorY,-self.climb,self.climb)
  local vertical=2*(desiredY-k.y.v)+self.integral
  local up=math.cos(math.rad(k.pitch.x))*math.cos(math.rad(k.roll.x))
  vertical=(vertical+self.gravity)/math.max(.8,up)-self.gravity
  local demand={vertical,2.5*(pitchTarget-k.pitch.x)-3*self.rates.pitch,2.5*(rollTarget-k.roll.x)-3*self.rates.roll}
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
Quad.Physics=Physics
-- Actual Link actuator adapter. Experimental near-level control, not certified flight.
local s=_G.MintCraftQuad
local names={'Avant gauche','Avant droite','Arriere gauche','Arriere droite'}
if not s then
 s={rotors={},low=0,phase='off',label=ui.label('Quad experimental: modele mesure obligatoire'),
  checked=ui.checkbox('Reprise physique et modele/geometrie verifies; essais experimentaux'),
  noise=ui.textfield(140),process=ui.textfield(140),speed=ui.textfield(140),climb=ui.textfield(140),tilt=ui.textfield(140)}
 s.physical=ui.checkbox('Calcul physique: petits rotors verticaux identiques, quad symetrique centre, reglages par defaut verifies')
 s.physicalFields={}
 for _,entry in ipairs({{'source','RPM source avant transmission','256'},{'thrust','Coefficient poussee Aero','1'},{'airflow','Coefficient ecoulement Aero','0.1'},{'armX','Demi-largeur depuis centre de masse (blocs)',''},{'armZ','Demi-longueur depuis centre de masse (blocs)',''},{'height','Hauteur rotors moins hauteur Sputnik (blocs)','0'},{'gravity','Gravite Sable par defaut','11'}}) do
  local f={label=ui.label(entry[2]),value=ui.textfield(140)} f.value.setValue(entry[3]);s.physicalFields[entry[1]]=f
 end
 s.noise.setValue('0.0025') s.process.setValue('4') s.speed.setValue('2') s.climb.setValue('1') s.tilt.setValue('8')
 s.help=ui.label('Bruit position R / acceleration Q / vitesse / montee / inclinaison max')
 for i,name in ipairs(names) do s.rotors[i]={label=ui.label(name..': Link puis trim,min,max,dY,dPitch,dRoll,repli'),a=ui.itempicker(),b=ui.itempicker(),row=ui.textfield(300)} end
 _G.MintCraftQuad=s
end
addElement(s.label) addElement(s.checked) addElement(s.help) addElement(s.physical)
for _,key in ipairs({'source','thrust','airflow','armX','armZ','height','gravity'}) do local f=s.physicalFields[key] addElement(f.label) addElement(f.value) end
for _,key in ipairs({'noise','process','speed','climb','tilt'}) do addElement(s[key]) end
for _,r in ipairs(s.rotors) do addElement(r.label) addElement(r.a) addElement(r.b) addElement(r.row) end
local emit=output
if false then output('Status','string') output('Active',0) output('Altitude',0) output('Target altitude',0) output('Kalman ready',0) output('Flight qualified',0) output('Maximum thrust',0) output('Weight',0) output('Pressure',0) output('Last fault','string') end
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
local ix,iy,iz=read('getInertiaTensor')
local pose={ix=ix,iz=iz,tick=tick,mass=mass,x=x,y=y,z=z,pitch=pitch,yaw=yaw,roll=roll,dimension=dimension}
local server=finite(tick) and tick>0 and finite(mass) and mass>0
local rows,pairs_,seen,parts={}, {},{},{}
local physical=s.physical.isChecked()
local valid=true local problems={}
local function reject(code,why) valid=false problems[#problems+1]=code..': '..why end
if not s.checked.isChecked() then reject('CONFIRM','case reprise/modele non cochee sur serveur') end
if type(transmitWirelessRedstone)~='function' then reject('API','emission Link indisponible') end
-- Reject collisions across keyboard, physical enable and all four rotor outputs.
local function binding(id)
 if type(id)~='string' or #id>386 then return false end
 local a,b=id:match('^([^,]+),([^,]+)$')
 return item(a) and item(b)
end
if not binding(enableBinding) then reject('ENABLE_BIND','fil Binding du levier absent/invalide') else seen[enableBinding]='levier' end
local count=0
if type(keyboardBindings)~='string' or #keyboardBindings>2400 then reject('KEY_BIND','description clavier absente/invalide') else
 for id in keyboardBindings:gmatch('[^|]+') do
  count=count+1
  if not binding(id) then reject('KEY_PAIR','paire clavier '..count..' invalide')
  elseif seen[id] then reject('DUP','clavier '..count..' utilise frequence de '..seen[id]) end
  seen[id]='clavier '..count
 end
end
if count~=6 then reject('KEY_COUNT',tostring(count)..'/6 frequences clavier recues') end
parts[#parts+1]=tostring(keyboardBindings)..':'..tostring(enableBinding)
for i,r in ipairs(s.rotors) do
 local a,b=r.a.getItem(),r.b.getItem() local text=r.row.getValue()
 parts[#parts+1]=tostring(a)..','..tostring(b)..':'..tostring(text)
 local id=tostring(a)..','..tostring(b)
 if not item(a) or not item(b) then reject('ROTOR_'..i,'paire objets absente/invalide')
 elseif seen[id] then reject('DUP_'..i,'rotor '..i..' utilise frequence de '..seen[id]) end
 seen[id]='rotor '..i pairs_[i]={a,b}
 rows[i]={}
 if physical then rows[i]={}
 elseif type(text)~='string' or #text>256 then reject('ROW_'..i,'ligne manuelle invalide') else
  -- Empty fields must not silently shift response columns.
  local count=0 for token in (text..','):gmatch('(.-),') do count=count+1 rows[i][count]=tonumber(token) or false end
  if count~=7 then reject('ROW_'..i,'7 nombres requis ou activer Calcul physique') end
 end
end
local config={}
for _,key in ipairs({'noise','process','speed','climb','tilt'}) do config[key]=tonumber(s[key].getValue()) parts[#parts+1]=tostring(config[key])
 if not finite(config[key]) or config[key]<=0 then reject('PARAM_'..key,'valeur positive requise') end end
local physicsWhy
if physical then
 config.physics={}
 for _,key in ipairs({'source','thrust','airflow','armX','armZ','height','gravity'}) do
  config.physics[key]=tonumber(s.physicalFields[key].value.getValue())
  parts[#parts+1]=tostring(config.physics[key])
  if not finite(config.physics[key]) then reject('PHYS_'..key,'valeur numerique requise') end
 end
 if server then
  local result
  rows,result=Quad.Physics.rows(config.physics,pose)
  if not rows then physicsWhy=result end
 else rows=nil end
end
parts[#parts+1]=tostring(physical)
local model,modelWhy=Quad.model(rows,physical)
modelWhy=physicsWhy or modelWhy
if not model then reject('MODEL',tostring(modelWhy)) end
local rejection=#problems>0 and table.concat(problems,' | ') or nil
if not valid and not s.owner and not s.fault then s.reason=rejection or 'Configuration incomplete' s.phase='off' s.low=0 end
local signature=table.concat(parts,'|')
local function send(values)
 if not s.owner then return false end
 -- No Link ACK is available: RPC success is not proof of rotor response.
 local ok=true
 for i,pair in ipairs(s.owner.pairs) do
  local good=pcall(transmitWirelessRedstone,pair[1],pair[2],values[i]) if not good then ok=false end
 end
 s.lastRequested={} for i,value in ipairs(values) do s.lastRequested[i]=value end
 s.radioOverride=nil
 if type(receiveWirelessRedstone)=='function' then
  for i,pair in ipairs(s.owner.pairs) do
   local good,value=pcall(receiveWirelessRedstone,pair[1],pair[2])
   if good and finite(value) and value%1==0 and value>values[i] and value<=15 then
    s.radioOverride='RADIO_'..i..': demande '..values[i]..' reseau '..value
    break
   end
  end
 end
 return ok
end
local function fallback(why)
 -- Capture the first failure BEFORE sending fallback or discarding the controller.
 if not s.fault then
  local function n(value) return finite(value) and string.format('%.1f',value) or '?' end
  s.fault={cause=tostring(why),tick=tick,mass=mass,pitch=pitch,roll=roll,requested=s.lastRequested,
   target=s.core and s.core.target.y or nil,diagnostics=s.core and s.core.diagnostics or nil}
  s.fault.message='FAULT: '..tostring(why)..' | pitch='..n(pitch)..' roll='..n(roll)..' m='..n(mass)..(s.radioOverride and ' | '..s.radioOverride or '')
 end
 if s.owner then
  local values={} for i,r in ipairs(s.owner.rows) do values[i]=r[7] end
  send(values)
 end
 s.core=nil s.phase='fault' s.low=0 s.reason=s.fault.message
end
local advancing=server and (not s.tick or tick>s.tick)
local gap=server and s.tick and (tick<s.tick or tick-s.tick>10)
if s.owner and s.phase=='active' and (not server or not valid or s.signature~=signature or gap or not finite(enabled) or enabled<0 or enabled>15) then
 local cause
 if not finite(tick) or tick<=0 then cause='CLOCK: horloge serveur absente/invalide'
 elseif not finite(mass) or mass<=0 then cause='MASS: masse serveur absente/invalide'
 elseif not valid then cause=rejection or 'CONFIG: parametres invalides'
 elseif s.signature~=signature then cause='CONFIG_CHANGED: reglages/frequences modifies en vol'
 elseif gap then cause=(tick<s.tick and 'CLOCK_REGRESSION: ' or 'CLOCK_GAP: ')..tostring(s.tick)..' -> '..tostring(tick)
 else cause='ENABLE_VALUE: autorisation hors 0..15' end
 fallback(cause)
end
if server then
 if not finite(enabled) or enabled<0 or enabled>15 then
  if not s.owner and not s.fault then s.reason='ENABLE_VALUE: autorisation non numerique ou hors 0..15' end
 elseif enabled==0 then
  if s.owner and s.phase=='active' then fallback('Desactive: repli configure, pas de coupure des pales') end
  -- Disarming acknowledges a fault even if configuration now needs repair.
  -- Keep refreshing the frozen fallback channels; zero radio is full RPM here.
  if advancing and not gap then s.low=s.low+1 else s.low=0 end
  if s.low>=2 then
   s.fault=nil s.phase=valid and 'ready' or 'off'
   s.reason=valid and 'Pret: activer sans touche' or rejection or 'Configuration incomplete'
  end
 elseif finite(enabled) and enabled>0 and enabled<=15 and valid and not gap then
  local level=finite(pitch) and finite(roll) and math.abs(pitch)<=10 and math.abs(roll)<=10
  if s.phase~='active' then
   if s.fault then s.reason=s.fault.message
   elseif s.phase~='ready' then s.reason='BASELINE: mettre levier a 0 puis activer sans touche'
   elseif keys==1 and (forward~=0 or left~=0 or vertical~=0) then s.reason='KEYS_HELD: relacher touches F='..tostring(forward)..' L='..tostring(left)..' Y='..tostring(vertical)
   elseif not level then s.reason='LEVEL_WAIT: remettre le quad a plat (pitch='..tostring(pitch)..' roll='..tostring(roll)..'; depart +/-10 deg)' end
  end
  -- Permission is binary and independent of keyboard readiness. With no valid
  -- movement command, capture this position and stabilise at neutral demand.
  -- A valid held key still requires release before starting the controller.
  local neutral=keys~=1 or (forward==0 and left==0 and vertical==0)
  if s.phase=='ready' and neutral and level then
   local core,why=Quad.new(rows,pose,config)
   if core then
    s.info=nil s.core=core s.owner={pairs=pairs_,rows=core.model.rows} s.phase='active' s.reason='Boucle experimentale en cours'
    local trims={} for i,r in ipairs(core.model.rows) do trims[i]=math.max(r[2],math.min(r[3],math.floor(r[1]+.5))) end
    if not send(trims) then fallback('Echec transmission initiale') end
   else fallback(why) end
  end
  if s.phase=='active' and advancing and s.core.tick~=tick then
   -- On keyboard invalidity, brake/hold; never turn a missing command into rotor STOP.
   local command=keys==1 and {forward=forward,left=left,vertical=vertical} or {forward=0,left=0,vertical=0}
   local values,info=s.core:step(pose,command)
   if not values then fallback(info)
   elseif not send(values) then fallback('Echec transmission Link; reprise physique')
   else
    s.owner.rows=s.core.model.rows s.info=info
    local function n(value) return finite(value) and string.format('%.1f',value) or '?' end
    -- Requests, not actuator ACKs: expose the whole path on the existing panel.
    s.reason=(s.radioOverride and s.radioOverride..' | ' or '')..'RUN m='..n(mass)..' K='..tostring(keys)..' F='..n(command.forward)..' L='..n(command.left)..' Y='..n(command.vertical)..' R='..table.concat(values,'/')..' h='..n(info.altitude)..'>'..n(info.targetY)
   end
  end
 end
elseif not s.owner and not s.fault then
 s.reason=finite(tick) and tick>0 and ('MASS: masse serveur absente ('..tostring(mass)..'); verifier assemblage simule') or 'CLIENT/CLOCK: contexte client ou horloge serveur absente'
end
if s.owner and s.phase~='active' then
 local values={} for i,r in ipairs(s.owner.rows) do values[i]=r[7] end
 send(values)
end
if server then s.tick=tick end
s.signature=signature
s.label.setText(s.reason or modelWhy or 'Configurer les quatre sorties et le modele mesure')
if not server and not s.owner then
 -- Keep a typed reason available even when mass/clock prerequisites fail.
 emit('Last fault',s.fault and s.fault.message or '')
 emit('Status',s.reason) emit('Active',0) emit('Kalman ready',0) emit('Flight qualified',0)
 return
end
emit('Last fault',s.fault and s.fault.message or '')
local active=s.phase=='active'
emit('Active',active and 1 or 0) emit('Flight qualified',0)
emit('Kalman ready',active and s.info and s.info.ready and 1 or 0)
emit('Altitude',s.info and s.info.altitude or 0) emit('Target altitude',s.core and s.core.target.y or s.fault and s.fault.target or 0)
local diagnostics=s.core and s.core.diagnostics or s.fault and s.fault.diagnostics
emit('Maximum thrust',diagnostics and diagnostics.maxThrust or 0) emit('Weight',diagnostics and diagnostics.required or 0) emit('Pressure',diagnostics and diagnostics.pressure or 0)
emit('Status',s.reason or modelWhy or 'Inactif')
if type(display)=='function' and server then
 display('MC_QUAD',s.reason or 'Inactif')
 if diagnostics and diagnostics.rotors then
  for i,r in ipairs(diagnostics.rotors) do display('MC_ROTOR_'..i,'Fmax '..string.format('%.1f',r.maximum)..' / RPM0 '..string.format('%.1f',r.rpm)..' / signal '..string.format('%.2f',r.trim)) end
 end
 if diagnostics then display('MC_FORCE','Fmax '..string.format('%.1f',diagnostics.maxThrust)..' / poids '..string.format('%.1f',diagnostics.required)..' / P '..string.format('%.3f',diagnostics.pressure)) end
end
