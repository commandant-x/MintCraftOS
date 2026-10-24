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
 local s={model=model,tick=pose.tick,mass=pose.mass,dimension=pose.dimension,filters={},target={x=pose.x,y=pose.y,z=pose.z},integral=0,quant={0,0,0,0},samples=0}
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
  local ux=desiredX and vx or clip(.5*(self.target.x-k.x.x),-self.speed,self.speed)
  local uz=desiredX and vz or clip(.5*(self.target.z-k.z.x),-self.speed,self.speed)
  local ax=clip(1.2*(ux-k.x.v),-3,3) local az=clip(1.2*(uz-k.z.v),-3,3)
  local bodyRight=ax*math.cos(yaw)-az*math.sin(yaw)
  local bodyForward=ax*math.sin(yaw)+az*math.cos(yaw)
  local pitchTarget=clip(math.deg(math.atan(bodyForward/self.gravity)),-self.tilt,self.tilt)
  local rollTarget=clip(-math.deg(math.atan(bodyRight/self.gravity)),-self.tilt,self.tilt)
  local errorY=self.target.y-k.y.x
  local desiredY=clip(errorY,-self.climb,self.climb)
  local vertical=2*(desiredY-k.y.v)+self.integral
  local up=math.cos(math.rad(k.pitch.x))*math.cos(math.rad(k.roll.x))
  vertical=(vertical+self.gravity)/math.max(.8,up)-self.gravity
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
