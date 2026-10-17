local addon=require("system.libraries.addon")
local M={}
M.types={"unknown","monocopter","bicopter","tricopter","quadcopter","hexacopter","octocopter","multirotor","helicopter","airship","fixed-wing","ground","hybrid"}
M.roles={"unknown","lift","buoyancy","propulsion","stabilization","yaw","strafe","mixed"}
local function contains(values,value)
  for _,item in ipairs(values) do if item==value then return true end end
end
local function bounded(vector)
  return math.max(math.abs(vector.x),math.abs(vector.y),math.abs(vector.z))<=1000000
end
function M.profile(value)
  local p=type(value)=="table" and addon.copy(value) or {}
  p.type=contains(M.types,p.type) and p.type or "unknown"
  p.name=type(p.name)=="string" and p.name or "Vehicle"
  p.massKg=addon.finite(p.massKg) and p.massKg or 0
  p.rotorCount=addon.finite(p.rotorCount) and math.max(0,math.min(32,math.floor(p.rotorCount))) or 0
  p.comVerified=p.comVerified==true
  p.com=addon.vec(p.com) or {x=0,y=0,z=0}
  return p
end
function M.actuator(value)
  local a=type(value)=="table" and addon.copy(value) or {}
  a.role=contains(M.roles,a.role) and a.role or "unknown"
  a.position=addon.vec(a.position) or {x=0,y=0,z=0}
  a.direction=addon.vec(a.direction) or {x=0,y=0,z=0}
  a.geometryVerified=a.geometryVerified==true
  return a
end
function M.import(profile,snapshot)
  if type(snapshot)~="table" or not snapshot.ok or not snapshot.complete or snapshot.frame~="body_plot" or not addon.vec(snapshot.centerOfMass) then
    return nil,"Complete fresh body-frame bridge geometry required"
  end
  local p=M.profile(profile)
  p.com=addon.copy(snapshot.centerOfMass) p.comVerified=true
  p.bridgeVehicleId=snapshot.vehicleId p.bridgeFrame=snapshot.frame
  p.bridgeUnits=addon.copy(snapshot.units) p.bridgeRevision=snapshot.sourceRevision
  p.bridgeInertia=addon.copy(snapshot.inertia)
  p.bridgeMass=snapshot.mass p.bridgeLinks=addon.copy(snapshot.links)
  p.bridgeBurners=addon.copy(snapshot.burners or {})
  p.bridgeActuators={}
  local lift=0
  for _,row in ipairs(snapshot.actuators) do
    if row.geometryValid then
      if row.suggestedRole=="lift" then lift=lift+1 end
      p.bridgeActuators[#p.bridgeActuators+1]={id=row.id,block=row.block,
        actuator={role=row.suggestedRole,position=addon.copy(row.position),direction=addon.copy(row.direction),
          geometryVerified=true,source="mintcraft_vehicle",controlBindingKnown=false}}
    end
  end
  p.rotorCount=lift
  if p.type=="unknown" then
    p.type=#p.bridgeBurners>0 and "airship" or (({[1]="monocopter",[2]="bicopter",[3]="tricopter",[4]="quadcopter",[6]="hexacopter",[8]="octocopter"})[lift] or "unknown")
    p.typeSource="orientation-based suggestion; confirm vehicle forward axes"
  end
  if p.name=="Vehicle" then p.name=snapshot.name end
  -- Raw game units are not silently relabelled as kilograms.
  if snapshot.units.mass=="kg" and addon.finite(snapshot.mass) then p.massKg=snapshot.mass end
  return p
end
-- Body frame: +X right, +Y up, +Z forward. Torque is r cross F.
-- Geometry alone is not a measured transfer function or a PID tuning.
function M.analyze(profile,channels)
  profile=M.profile(profile)
  local out={rows={},warnings={},frame="body: +X right / +Y up / +Z forward"}
  if profile.type=="unknown" then out.warnings[#out.warnings+1]="Vehicle type missing" end
  if profile.massKg<=0 then out.warnings[#out.warnings+1]="Mass missing; force estimates unavailable" end
  if not profile.comVerified then out.warnings[#out.warnings+1]="Body-frame COM unverified; torque unavailable" end
  local geometry=profile.bridgeActuators or channels or {}
  if profile.bridgeActuators then
    out.frame="Sable plot axes; vehicle forward not inferred"
    out.warnings[#out.warnings+1]="Imported physical model; command bindings remain unverified"
  end
  for _,channel in ipairs(geometry) do
    local a=M.actuator(channel.actuator)
    local row={id=channel.id,role=a.role,frequency=channel.frequency,verified=a.geometryVerified}
    if a.role=="unknown" then out.warnings[#out.warnings+1]=tostring(channel.id)..": role missing" end
    local d=a.direction
    local length=math.sqrt(d.x*d.x+d.y*d.y+d.z*d.z)
    if not a.geometryVerified or length<1e-8 or not addon.finite(length) or not profile.comVerified or not bounded(a.position) or not bounded(d) or not bounded(profile.com) then
      out.warnings[#out.warnings+1]=tostring(channel.id)..": geometry unverified"
    else
      local x,y,z=a.position.x-profile.com.x,a.position.y-profile.com.y,a.position.z-profile.com.z
      local fx,fy,fz=d.x/length,d.y/length,d.z/length
      row.force={x=fx,y=fy,z=fz}
      row.torque={pitch=y*fz-z*fy,yaw=z*fx-x*fz,roll=x*fy-y*fx}
      row.position=addon.copy(a.position)
    end
    out.rows[#out.rows+1]=row
  end
  if #out.rows==0 then out.warnings[#out.warnings+1]="No mapped actuators" end
  out.warnings[#out.warnings+1]="PID needs measured response; Kalman needs sensor/noise model"
  return out
end
return M
