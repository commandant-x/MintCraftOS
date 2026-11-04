local M=assert(loadfile('platforms/sputnik/experiments/spot-three-axis/leg_ik.lua'))()
local tested=0
for _,l1 in ipairs({2,3,4}) do for _,l2 in ipairs({2,3,4}) do
 for _,x in ipairs({-1,0,1}) do for _,y in ipairs({-1,0,1}) do for _,z in ipairs({2,3,4,5}) do
  local a=M.inverse(x,y,z,l1,l2)
  if a then local p=M.forward(a.roll,a.hip,a.knee,l1,l2);assert(math.abs(p.x-x)<1e-8 and math.abs(p.y-y)<1e-8 and math.abs(p.down-z)<1e-8);tested=tested+1 end
 end end end
end end
assert(tested>100)
assert(M.inverse(99,0,1,2,2)==nil)
assert(M.inverse(0,0,1,10,1)==nil)
assert(M.inverse(0,0,-1,2,2)==nil)
assert(M.inverse(0/0,0,1,2,2)==nil)
assert(M.inverse(0,0,1,0,2)==nil)
assert(M.inverse(1e308,0,1,1e308,1e308)==nil)
assert(M.forward(0,0,0,1e308,1e308)==nil)
print('3-axis leg inverse/forward geometry: '..tested..' targets checked; unreachable and invalid inputs rejected; no physical gait validation')
