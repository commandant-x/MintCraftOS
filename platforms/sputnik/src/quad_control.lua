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
  lastAttitude={pitch=pose.pitch,roll=pose.roll},rates={pitch=0,roll=0},angularAcceleration={pitch=0,roll=0},
  motion='HOLD',lastVelocity={x=0,z=0},linearAcceleration={x=0,z=0},steering=config.steering==true,course=pose.yaw}
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
   local previousRate=self.rates[key]
   self.rates[key]=self.rates[key]+dt/(.05+dt)*(measured-self.rates[key])
   -- Filter acceleration separately: damping the actuator lag must not amplify
   -- a single noisy angular sample into a large motor command.
   self.angularAcceleration[key]=self.angularAcceleration[key]+dt/(.05+dt)*((self.rates[key]-previousRate)/dt-self.angularAcceleration[key])
   self.lastAttitude[key]=p[key]
  end
  local measurement={x=p.x,y=p.y,z=p.z,pitch=p.pitch,roll=p.roll}
  for key,k in pairs(self.filters) do
   local z=measurement[key] if key=='pitch' or key=='roll' then z=k.x+wrap(z-k.x) end
   local angle=key=='pitch' or key=='roll'
   -- Position discontinuities are innovations, not travelled distance: a
   -- correctly tracked high speed must not become an implicit speed ceiling.
   local reference=angle and k.x or k.x+k.v*dt
   if math.abs(z-reference)>(angle and 30 or 20) then return nil,'Pose discontinuity' end
   if not M.update(k,z,dt) then return nil,'Kalman failure' end
  end
  if self.physics then
   local velocity={} for _,key in ipairs({'x','y','z','pitch','roll'}) do velocity[key]=self.filters[key].v end
   -- Keep passive rotational airflow damping. Feeding an inverse of that
   -- damping through delayed propellers can sustain an attitude oscillation.
   -- Translation/vertical inflow and per-rotor altitude remain in the model;
   -- the independent plant still applies the full rotational airflow.
   velocity.pitch=0;velocity.roll=0
   local rows,info=M.Physics.rows(self.physics,p,velocity)
   if not rows then return nil,info end
   local model,why=M.model(rows,true) if not model then return nil,why end
   self.model=model self.diagnostics=info
  end
  self.tick=p.tick self.samples=self.samples+1
  local k=self.filters local yaw=math.rad(p.yaw)
  for _,key in ipairs({'x','z'}) do
   local acceleration=(k[key].v-self.lastVelocity[key])/dt
   self.linearAcceleration[key]=self.linearAcceleration[key]+dt/(.1+dt)*(acceleration-self.linearAcceleration[key])
   self.lastVelocity[key]=k[key].v
  end
  if command.vertical~=0 then self.target.y=self.target.y+command.vertical*self.climb*dt end
  local horizontalSpeed=math.sqrt(k.x.v^2+k.z.v^2)
  local moving=command.forward~=0 or (command.left~=0 and (not self.steering or horizontalSpeed>.3))
  local accelerationLimit=self.gravity*math.tan(math.rad(self.tilt))
  local ax,az
  if moving then
   -- A held key requests thrust, not a capped horizontal speed.
   self.motion='TRAVEL'
   local norm=math.max(1,math.sqrt(command.forward^2+command.left^2))
   if self.steering then
    -- Fixed vertical propellers have no independent body-yaw channel. Steer
    -- the FLIGHT PATH with centripetal acceleration, never pretend to yaw it.
    local course=math.rad(self.course)
    local along=k.x.v*math.sin(course)+k.z.v*math.cos(course)
    local direction=along<0 and -1 or 1
    local observed=self.course
    if horizontalSpeed>.3 then
     observed=wrap(math.deg(math.atan2(k.x.v,k.z.v))+(direction<0 and 180 or 0))
    end
    local error=wrap(self.course-observed)
    local turnRate=-clip(accelerationLimit*command.left/norm/math.max(.3,horizontalSpeed),-math.rad(30),math.rad(30))
    -- Do not wind the requested course ahead of an aircraft that cannot follow.
    if math.abs(error)>15 and error*turnRate>0 then turnRate=0 end
    self.course=wrap(self.course+math.deg(turnRate)*dt)
    error=math.rad(wrap(self.course-observed))
    course=math.rad(observed)
    local tangent=accelerationLimit*command.forward/norm
    local normal=-direction*horizontalSpeed*(turnRate+.7*error)
    ax=tangent*math.sin(course)-normal*math.cos(course)
    az=tangent*math.cos(course)+normal*math.sin(course)
   else
    -- Optional classic body-relative strafe, retained for existing users/SDK.
    ax=accelerationLimit*(command.forward*math.sin(yaw)-command.left*math.cos(yaw))/norm
    az=accelerationLimit*(command.forward*math.cos(yaw)+command.left*math.sin(yaw))/norm
   end
   self.target.x=k.x.x self.target.z=k.z.x
  else
   if self.motion=='TRAVEL' then self.motion='BRAKE' end
   if self.motion=='BRAKE' then
    -- Start levelling before speed crosses zero: rotor/radio lag otherwise
    -- carries the braking tilt into a reverse acceleration and a pendulum.
    ax=-.9*(k.x.v+.4*self.linearAcceleration.x)
    az=-.9*(k.z.v+.4*self.linearAcceleration.z)
    self.target.x=k.x.x self.target.z=k.z.x
    if math.sqrt(k.x.v^2+k.z.v^2)<.12 and math.abs(p.pitch)<1.5 and math.abs(p.roll)<1.5 and math.abs(self.rates.pitch)<2 and math.abs(self.rates.roll)<2 then self.motion='HOLD' end
   end
   if self.motion=='HOLD' then
    -- Capture the stopping point instead of pulling back to the release point.
    local ux=clip(.3*(self.target.x-k.x.x),-self.speed,self.speed)
    local uz=clip(.3*(self.target.z-k.z.x),-self.speed,self.speed)
    ax=.9*(ux-k.x.v) az=.9*(uz-k.z.v)
   end
  end
  local norm=math.sqrt(ax^2+az^2)
  if norm>accelerationLimit then ax=ax*accelerationLimit/norm az=az*accelerationLimit/norm end
  local bodyRight=ax*math.cos(yaw)-az*math.sin(yaw)
  local bodyForward=ax*math.sin(yaw)+az*math.cos(yaw)
  local function attitude(scale)
   return math.atan(bodyForward*scale/self.gravity),-math.atan(bodyRight*scale/self.gravity)
  end
  local attitudeScale=1
  if self.physics then
   -- No arbitrary airspeed ceiling. Reduce tilt only when the predicted maximum
   -- thrust cannot support weight at this velocity/pressure. A 10% reserve
   -- leaves room for attitude corrections and the lag of the measured angle.
   local spec=self.physics
   local function supported(scale)
    local pitch,roll=attitude(scale)
    local upX=math.sin(yaw)*math.sin(pitch)*math.cos(roll)-math.cos(yaw)*math.sin(roll)
    local upY=math.cos(pitch)*math.cos(roll)
    local upZ=math.cos(yaw)*math.sin(pitch)*math.cos(roll)+math.sin(yaw)*math.sin(roll)
    local inflow=k.x.v*upX+k.y.v*upY+k.z.v*upZ
    local maximum=0
    for _,rotor in ipairs(self.diagnostics.rotors) do maximum=maximum+M.Physics.force(spec.source,rotor.pressure,inflow,spec.thrust,spec.airflow) end
    return maximum*upY>=p.mass*self.gravity*1.10
   end
   if not supported(1) then
    local lo,hi=0,1
    for _=1,10 do local middle=(lo+hi)/2;if supported(middle) then lo=middle else hi=middle end end
    attitudeScale=lo
   end
  end
  local pitchTarget,rollTarget=attitude(attitudeScale)
  pitchTarget=math.deg(pitchTarget) rollTarget=math.deg(rollTarget)
  local errorY=self.target.y-k.y.x
  local desiredY=clip(errorY,-self.climb,self.climb)
  local vertical=2*(desiredY-k.y.v)+self.integral
  local up=math.cos(math.rad(k.pitch.x))*math.cos(math.rad(k.roll.x))
  vertical=(vertical+self.gravity)/math.max(.8,up)-self.gravity
  local pitchGain,rollGain=10,10
  if self.physics then
   -- Approximate the two rising rotors' passive airflow damping per inertia.
   -- More damping requires more proportional authority to track a tilt promptly.
   local spec=self.physics;local flowSlope=spec.thrust*self.diagnostics.pressure/spec.airflow
   pitchGain=clip(3+6*spec.armZ^2*flowSlope/p.ix,4,40)
   rollGain=clip(3+6*spec.armX^2*flowSlope/p.iz,4,40)
  end
  -- Fresh measured angles avoid another position-estimator delay. Rate and
  -- acceleration feedback damp the lagged rotors; all actuator bounds remain.
  local demand={vertical,pitchGain*(pitchTarget-p.pitch)-4.5*self.rates.pitch-.6*self.angularAcceleration.pitch,rollGain*(rollTarget-p.roll)-4.5*self.rates.roll-.6*self.angularAcceleration.roll}
  local values,scale=M.allocate(self.model,demand)
  -- Anti-windup: adapt hover bias in flight, never run a mass-triggered sweep.
  if scale>.99 then self.integral=clip(self.integral+.2*errorY*dt,-3,3) end
  local signals={}
  for i,r in ipairs(self.model.rows) do
   local value=clip(values[i]+self.quant[i],r[2],r[3])
   signals[i]=clip(math.floor(value+.5),r[2],r[3]) self.quant[i]=clip(value-signals[i],-.5,.5)
  end
  return signals,{scale=scale,altitude=k.y.x,targetY=self.target.y,verticalSpeed=k.y.v,horizontalSpeed=horizontalSpeed,pitchTarget=pitchTarget,rollTarget=rollTarget,motion=self.motion,steering=self.steering,course=self.course,liftLimited=attitudeScale<.99,massChanged=math.abs(p.mass-self.mass)/self.mass>.02,ready=self.samples>=3}
 end
 return s
end
return M
