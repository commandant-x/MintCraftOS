local IK=(function()
-- Mathematical prototype, leg-local coordinates in blocks and degrees.
-- No Minecraft output or actuator commands. Calibrate to the actual mechanism.
local M={}
local function finite(v)return type(v)=='number' and v==v and v<math.huge and v>-math.huge end
local function clamp(v)return math.max(-1,math.min(1,v))end
function M.inverse(x,y,down,upper,lower)
 if not (finite(x) and finite(y) and finite(down) and finite(upper) and finite(lower)) then return nil,'nonfinite' end
 if upper<=0 or lower<=0 or down<=0 then return nil,'invalid geometry' end
 local radial=math.sqrt(y*y+down*down);local distance=math.sqrt(x*x+radial*radial)
 if not(finite(radial) and finite(distance) and finite(upper+lower)) then return nil,'invalid geometry' end
 if distance<1e-8 or distance>upper+lower+1e-9 or distance<math.abs(upper-lower)-1e-9 then return nil,'unreachable' end
 local roll=math.atan2(y,down)
 local knee=math.acos(clamp((distance*distance-upper*upper-lower*lower)/(2*upper*lower)))
 local hip=math.atan2(x,radial)-math.acos(clamp((upper*upper+distance*distance-lower*lower)/(2*upper*distance)))
 local k=180/math.pi
 return {roll=roll*k,hip=hip*k,knee=knee*k}
end
function M.forward(roll,hip,knee,upper,lower)
 if not(finite(roll) and finite(hip) and finite(knee) and finite(upper) and finite(lower)) or upper<=0 or lower<=0 then return nil,'invalid geometry' end
 local k=math.pi/180;roll=roll*k;hip=hip*k;knee=knee*k
 local x=upper*math.sin(hip)+lower*math.sin(hip+knee)
 local radial=upper*math.cos(hip)+lower*math.cos(hip+knee)
 local y,down=radial*math.sin(roll),radial*math.cos(roll)
 if not(finite(x) and finite(y) and finite(down)) then return nil,'invalid geometry' end
 return {x=x,y=y,down=down}
end
return M

end)()
local GAIT=(function()
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

end)()
-- Preview only: desired degrees, no motor writes, no stability claim.
local phase=input('Phase')
local height=input('Standing height')
local stride=input('Stride')
local clearance=input('Foot clearance')
local lateral=input('Lateral amplitude')
local upper=input('Upper leg')
local lower=input('Lower leg')
local angles,reason=GAIT.solve(IK,phase,height,stride,clearance,lateral,upper,lower)
local state=_G.MintSpotPreview
if not state then state={label=ui.label('Apercu geometrique seul; marche non qualifiee')};_G.MintSpotPreview=state end
state.label.setText(angles and 'Apercu geometrique seul; marche non qualifiee' or ('Cible invalide: '..tostring(reason)))
addElement(state.label)
local function value(leg,axis)if angles then return angles[leg][axis] end return 0 end
output('FL roll degrees',value(1,'roll'))
output('FL hip degrees',value(1,'hip'))
output('FL knee degrees',value(1,'knee'))
output('FR roll degrees',value(2,'roll'))
output('FR hip degrees',value(2,'hip'))
output('FR knee degrees',value(2,'knee'))
output('RL roll degrees',value(3,'roll'))
output('RL hip degrees',value(3,'hip'))
output('RL knee degrees',value(3,'knee'))
output('RR roll degrees',value(4,'roll'))
output('RR hip degrees',value(4,'hip'))
output('RR knee degrees',value(4,'knee'))
output('Geometry valid',angles and 1 or 0)
output('Walk qualified',0)
