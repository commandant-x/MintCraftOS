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
