-- Static 2D support triangle geometry only. No sensor or live balance claim.
local M={}
local function finite(v)return type(v)=='number' and v==v and v<math.huge and v>-math.huge end
function M.triangleMargin(points,x,z)
 if type(points)~='table' or #points~=3 or not(finite(x) and finite(z)) then return nil,'invalid input' end
 for i=1,3 do local p=points[i];if type(p)~='table' or not(finite(p.x) and finite(p.z)) then return nil,'invalid point' end end
 local a,b,c=points[1],points[2],points[3]
 local area=(b.x-a.x)*(c.z-a.z)-(b.z-a.z)*(c.x-a.x)
 if not finite(area) or math.abs(area)<1e-9 then return nil,'degenerate triangle' end
 local sign=area>0 and 1 or -1;local margin=math.huge
 for i=1,3 do
  local p,q=points[i],points[i%3+1];local dx,dz=q.x-p.x,q.z-p.z;local length=math.sqrt(dx*dx+dz*dz)
  if not finite(length) or length<1e-9 then return nil,'invalid edge' end
  local dist=sign*(dx*(z-p.z)-dz*(x-p.x))/length
  if not finite(dist) then return nil,'invalid distance' end
  margin=math.min(margin,dist)
 end
 return margin
end
return M
