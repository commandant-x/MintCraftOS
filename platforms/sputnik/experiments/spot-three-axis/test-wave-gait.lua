local ik=assert(loadfile('platforms/sputnik/experiments/spot-three-axis/leg_ik.lua'))()
local gait=assert(loadfile('platforms/sputnik/experiments/spot-three-axis/wave_gait.lua'))()
for step=0,1000 do
 local phase=step/1000;local t=assert(gait.targets(phase,3,.8,.4,.3));local a=assert(gait.solve(ik,phase,3,.8,.4,.3,2,2));local swing=0
 for i=1,4 do
  if t[i].swing then swing=swing+1 end
  local q=assert(ik.forward(a[i].roll,a[i].hip,a[i].knee,2,2))
  assert(math.abs(q.x-t[i].x)<1e-8 and math.abs(q.down-t[i].down)<1e-8 and math.abs(q.y-t[i].y)<1e-8)
 end
 assert(swing==1)
end
local left=assert(gait.targets(.25-1e-9,3,.8,.4,.3));local right=assert(gait.targets(.25+1e-9,3,.8,.4,.3))
for i=1,4 do assert(math.abs(left[i].x-right[i].x)<1e-7 and math.abs(left[i].y-right[i].y)<1e-7 and math.abs(left[i].down-right[i].down)<1e-7) end
assert(gait.solve(ik,.2,100,.8,.4,.3,2,2)==nil)
assert(gait.targets(0,3,.8,4,.3)==nil)
local lateral=assert(gait.solve(ik,.125,3,.8,.4,.3,2,2));assert(lateral[1].roll>1 and lateral[2].roll==0)
local other=assert(gait.solve(ik,.375,3,.8,.4,.3,2,2));assert(other[2].roll< -1)
print('Four-leg wave trajectory: 1001 abstract samples, 12 angle outputs, continuity and reach checked; no physical gait validation')
