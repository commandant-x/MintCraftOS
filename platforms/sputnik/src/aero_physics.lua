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
-- Effective per-RPM coefficients from actual PropellerBearingBlockEntity.
-- N counts WINDMILL_SAILS blocks, including valid copycat sail materials.
function M.rotor(spec,index)
 if type(spec)~='table' then return nil,'Physical rotor specification required' end
 if not spec.modular then return {thrust=spec.thrust,airflow=spec.airflow,alpha=.15} end
 local n=type(spec.sails)=='table' and spec.sails[index]
 if not finite(n) or n%1~=0 or n<1 or n>4096 then return nil,'Rotor '..tostring(index)..': nombre de blocs de voile entier 1..4096 requis' end
 local thrust,airflow=spec.bearingThrust or .2,spec.bearingAirflow or .05
 if not finite(thrust) or thrust<=0 or not finite(airflow) or airflow<=0 then return nil,'Coefficients du Propeller Bearing positifs requis' end
 return {thrust=n^1.5*thrust,airflow=math.sqrt(n)*airflow,alpha=.4/math.sqrt(n),sails=n}
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
  local rotor,why=M.rotor(spec,i) if not rotor then return nil,why end
  local thrust,airflow=rotor.thrust,rotor.airflow
  local x,z=location[1],location[2]
  local height=pose.y+spec.height*up[2]+x*math.sin(r)*math.cos(p)-z*math.sin(p)
  local pressure=M.pressure(height)
  if not pressure or pressure<=0 then return nil,'No atmospheric pressure at a rotor' end
  local v=axial+math.rad(velocity.roll)*x-math.rad(velocity.pitch)*z
  local maxRpm=M.rpm(spec.source,0)
  local maximum=M.force(maxRpm,pressure,v,thrust,airflow)
  diagnostics.maxThrust=diagnostics.maxThrust+maximum
  diagnostics.rotors[i]={pressure=pressure,maximum=maximum,rpm=maxRpm,thrust=thrust,airflow=airflow,alpha=rotor.alpha,sails=rotor.sails}
  local required=pose.mass*spec.gravity/4
  if not maximum or required>=maximum then return nil,'Insufficient lift at this mass/altitude/inflow',diagnostics end
  local equilibriumRPM=required/(thrust*pressure)+math.max(0,v)/airflow
  local trim=M.signal(spec.source,equilibriumRPM)
  if trim<=0 or trim>=15 then return nil,'No interior lift margin' end
  diagnostics.rotors[i].trim=trim
  local slope=-thrust*pressure*spec.source/(trim<1 and 8 or 16)
  rows[i]={trim,0,15,slope/pose.mass,math.deg(-z*slope/pose.ix),math.deg(x*slope/pose.iz),clamp(math.floor(trim+.5),0,14)}
 end
 return rows,diagnostics
end
return M
