local s=assert(loadfile('platforms/sputnik/experiments/spot-three-axis/support.lua'))()
local a={{x=-2,z=-1},{x=2,z=-1},{x=2,z=1}}
assert(math.abs(assert(s.triangleMargin(a,0,0)))<1e-10)
assert(assert(s.triangleMargin(a,1,-.25))>0)
assert(assert(s.triangleMargin(a,-1,.75))<0)
local b={a[3],a[2],a[1]};assert(math.abs(s.triangleMargin(a,1,-.25)-s.triangleMargin(b,1,-.25))<1e-10)
assert(s.triangleMargin({a[1],a[1],a[2]},0,0)==nil)
assert(s.triangleMargin(a,0/0,0)==nil)
print('Static support triangle: inside/outside, zero-margin center, orientation and degenerate cases checked; not a balance controller')
