local addon = require("system.libraries.addon")
local M = {}

function M.wrap(angle) return (angle + 180) % 360 - 180 end
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

function M.heading(orientation)
  if type(orientation)~="table" then return nil end
  local x,y,z,w=quaternion(orientation)
  if not (addon.finite(x) and addon.finite(y) and addon.finite(z) and addon.finite(w)) then return nil end
  local norm=x*x+y*y+z*z+w*w
  if not addon.finite(norm) or norm<1e-12 then return nil end
  local forwardX,forwardZ=2*(x*z+w*y)/norm,1-2*(x*x+y*y)/norm
  if forwardX*forwardX+forwardZ*forwardZ<1e-8 then return nil end
  return math.deg(M.atan2(forwardX,forwardZ))%360
end

function M.relative(position, origin, heading)
  position, origin = addon.vec(position), addon.vec(origin)
  if not position or not origin then return nil, "world origin/position unavailable" end
  local dx, dy, dz = position.x - origin.x, position.y - origin.y, position.z - origin.z
  local a = math.rad(heading or 0)
  return { x = dx * math.cos(a) - dz * math.sin(a), y = dy, z = dx * math.sin(a) + dz * math.cos(a),
    distance = math.sqrt(dx * dx + dz * dz), bearing = math.deg(M.atan2(dx, dz)) }
end

function M.transform(point, pose)
  point = addon.vec(point)
  if not point or type(pose) ~= "table" then return nil, "unknown pose" end
  local origin = addon.vec(pose.position)
  local q = pose.orientation
  if not origin or type(q) ~= "table" then return nil, "unknown pose convention" end
  local x, y, z, w = quaternion(q)
  if not (addon.finite(x) and addon.finite(y) and addon.finite(z) and addon.finite(w)) then return nil end
  local norm = math.sqrt(x*x + y*y + z*z + w*w)
  if not addon.finite(norm) or norm < 1e-9 then return nil end
  x, y, z, w = x/norm, y/norm, z/norm, w/norm
  local pivot = addon.vec(pose.rotationPoint)
  local scale = addon.vec(pose.scale)
  if not pivot or not scale then return nil,"pose pivot/scale unavailable" end
  local px, py, pz = (point.x-pivot.x)*scale.x, (point.y-pivot.y)*scale.y, (point.z-pivot.z)*scale.z
  local tx, ty, tz = 2*(y*pz-z*py), 2*(z*px-x*pz), 2*(x*py-y*px)
  return { x = origin.x + px + w*tx + y*tz-z*ty,
    y = origin.y + py + w*ty + z*tx-x*tz, z = origin.z + pz + w*tz + x*ty-y*tx }
end

return M
