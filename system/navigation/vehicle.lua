local addon=require("system.libraries.addon")
local M={}
M.types={"unknown","monocopter","bicopter","tricopter","quadcopter","hexacopter","octocopter","multirotor","helicopter","airship","fixed-wing","ground","hybrid"}
M.roles={"unknown","lift","propulsion","stabilization","yaw","strafe","mixed"}
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
-- Body frame: +X right, +Y up, +Z forward. Torque is r cross F.
-- Geometry alone is not a measured transfer function or a PID tuning.
function M.analyze(profile,channels)
  profile=M.profile(profile)
  local out={rows={},warnings={},frame="body: +X right / +Y up / +Z forward"}
  if profile.type=="unknown" then out.warnings[#out.warnings+1]="Vehicle type missing" end
  if profile.massKg<=0 then out.warnings[#out.warnings+1]="Mass missing; force estimates unavailable" end
  if not profile.comVerified then out.warnings[#out.warnings+1]="Body-frame COM unverified; torque unavailable" end
  for _,channel in ipairs(channels or {}) do
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
