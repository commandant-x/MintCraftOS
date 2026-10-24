-- Minimal pure-data dependency used by the unchanged navigation mathematics.
local M={}
function M.finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
function M.vec(v)
 if type(v)~='table' then return end
 local x,y,z=v.x or v[1],v.y or v[2],v.z or v[3]
 if M.finite(x) and M.finite(y) and M.finite(z) then return {x=x,y=y,z=z} end
end
function M.copy(value)
 local seen,count={},0
 local function clone(v,depth)
  if type(v)~='table' then return v end
  assert(depth<=24 and not seen[v],'Unsupported cyclic/deep data')
  seen[v]=true local out={}
  for k,item in pairs(v) do count=count+1 assert(count<=32768,'Data budget exceeded') out[k]=clone(item,depth+1) end
  seen[v]=nil return out
 end
 return clone(value,0)
end
return M
