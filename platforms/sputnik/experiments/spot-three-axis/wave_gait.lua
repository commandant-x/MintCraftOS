-- Pure geometric trajectory prototype. No balance, collision, Link or motor writes.
-- The four legs are FL, FR, RL, RR. One leg swings during each quarter cycle.
local M={}
local function finite(v)return type(v)=='number' and v==v and v<math.huge and v>-math.huge end
function M.targets(phase,height,stride,clearance,lateral)
 if not(finite(phase) and finite(height) and finite(stride) and finite(clearance) and finite(lateral)) or height<=0 or stride<=0 or clearance<0 or clearance>=height or lateral<0 then return nil,'invalid input' end
 phase=phase%1
 local targets={}
 for leg=1,4 do
  local p=(phase-(leg-1)/4)%1
  local x,y,down,swing
  if p<.25 then
   local q=p/.25;x=-stride/2+stride*q;y=(leg%2==1 and 1 or -1)*lateral*math.sin(math.pi*q);down=height-clearance*math.sin(math.pi*q);swing=true
  else
   local q=(p-.25)/.75;x=stride/2-stride*q;y=0;down=height;swing=false
  end
  targets[leg]={x=x,y=y,down=down,swing=swing}
 end
 return targets
end
function M.solve(ik,phase,height,stride,clearance,lateral,upper,lower)
 if type(ik)~='table' or type(ik.inverse)~='function' then return nil,'invalid IK' end
 local t,why=M.targets(phase,height,stride,clearance,lateral);if not t then return nil,why end
 local result={}
 for i=1,4 do
  local p=t[i];local angles,reason=ik.inverse(p.x,p.y,p.down,upper,lower)
  if not angles then return nil,'leg '..i..': '..reason end
  result[i]={roll=angles.roll,hip=angles.hip,knee=angles.knee,swing=p.swing}
 end
 return result
end
return M
