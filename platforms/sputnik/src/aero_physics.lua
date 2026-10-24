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
