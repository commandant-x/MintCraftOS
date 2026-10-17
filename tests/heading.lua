package.path="./?.lua;"..package.path
local geometry=require("system.navigation.geometry")
for _,degrees in ipairs({0,90,180,270,359}) do
  local angle=math.rad(degrees)/2
  local value=geometry.heading({0,2*math.sin(angle),0,2*math.cos(angle)})
  assert(math.abs(geometry.wrap(value-degrees))<1e-6)
end
assert(not geometry.heading({0,0,0,0}))
assert(not geometry.heading({0/0,0,0,1}))
assert(not geometry.heading({math.sin(math.pi/4),0,0,math.cos(math.pi/4)}),"vertical forward has undefined heading")
print("heading: quaternion convention, normalization, wrap and singularity guards passed")
