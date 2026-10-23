package.path='./?.lua;'..package.path
local R=require('system.navigation.response_model')
local A=require('system.libraries.addon')
local provenance={vehicleId='ship',frame='body_orientation_at_neutral_reference',translationUnit='block/s2',rotationUnit='deg/s2'}
local function fit(columns,minimum,maximum,neutral)
 local channels,rows={},{}
 for j,col in ipairs(columns) do
  local id='motor-'..j channels[j]={id=id,min=minimum or 0,max=maximum or 15,neutral=neutral or 7,rescue=0}
  for _,sign in ipairs({-1,1}) do
   local signal=channels[j].neutral+sign
   if signal>=channels[j].min and signal<=channels[j].max then
    local values={} for i=1,6 do values[i]=col[i]*sign end
    rows[#rows+1]={id=id,signal=signal,response=values,noise={0,0,0,0,0,0},samples=8,baselineSamples=8,
     after=10,first=10.2,last=11,vehicleId='ship',singleCommand=true,otherOutputsChanged=false}
   end
  end
 end
 return R.fit(channels,rows,provenance),channels,rows
end
local basis={}
for j=1,6 do basis[j]={0,0,0,0,0,0} basis[j][j]=j end
local model=assert(fit(basis))
for _,axis in ipairs(R.axes) do assert(model.axes[axis].allocatable) end
local wanted={.2,-.3,.5,1,-1,.4}
local result=assert(R.allocate(model,wanted))
assert(result.normalizedResidual<1e-7)
for i=1,6 do assert(math.abs(result.actual[i]-wanted[i])<1e-6) end
local large=assert(R.allocate(model,{100,0,0,0,0,0}))
assert(large.saturated and large.delta['motor-1']==1 and large.normalizedResidual>90,'unmeasured output extrapolated')
-- A balloon and a differential ship retain their actual subsets.
local balloon=assert(fit({{0,0,1,0,0,0}}))
assert(balloon.axes.vertical.allocatable and not balloon.axes.forward.allocatable)
local ship=assert(fit({{1,0,0,0,-2,0},{1,0,0,0,2,0}}))
assert(ship.axes.forward.allocatable and ship.axes.yaw.allocatable and not ship.axes.roll.allocatable)
-- Four vertical rotors provide thrust and torques, not instantaneous lateral
-- translation. A tilt strategy needs additional measured motion qualification.
local rotor=assert(fit({{0,0,1,-1,1,-1},{0,0,1,-1,-1,1},{0,0,1,1,-1,-1},{0,0,1,1,1,1}}))
assert(rotor.axes.vertical.allocatable and rotor.axes.pitch.allocatable and rotor.axes.roll.allocatable and rotor.axes.yaw.allocatable)
assert(not rotor.axes.forward.allocatable and not rotor.axes.right.allocatable)
local coupled=assert(fit({{1,0,0,0,2,0}}))
assert(not coupled.axes.forward.allocatable and not coupled.axes.yaw.allocatable,'one coupled command became two axes')
-- Algebraic span alone cannot certify bidirectional unipolar authority.
local oneWay=assert(fit({{0,0,1,0,0,0}},0,15,0))
assert(oneWay.authority.axes.vertical.independent and not oneWay.axes.vertical.allocatable)
-- Asymmetric hardware and shifted mass: the fitted columns incorporate actual
-- measured accelerations, not nominal motor ratings or a guessed mass ratio.
local asymmetric=assert(fit({{.4,0,0,0,-2,0},{1.2,0,0,0,1,0}}))
assert(asymmetric.axes.forward.allocatable and asymmetric.axes.yaw.allocatable)
local mass=assert(fit({{.2,0,0,0,-1,0},{.6,0,0,0,.5,0}}))
assert(R.allocate(mass,{.05,0,0,0,0,0}).normalizedResidual<.005)
-- Contradictory signed tests and noisy or missing observations never become a
-- controller certificate. Models remain local allocations until actual trials.
local _,channels,rows=fit(basis)
rows[2].response[1]=-rows[2].response[1]
local partial=assert(R.fit(channels,rows,provenance))
assert(not partial.axes.forward.allocatable and #partial.rejected==1)
rows[3].vehicleId='foreign' assert(not R.fit(channels,rows,provenance)) rows[3].vehicleId='ship'
rows[3].first=9 assert(not R.fit(channels,rows,provenance)) rows[3].first=10.2
rows[3].otherOutputsChanged=true assert(not R.fit(channels,rows,provenance)) rows[3].otherOutputsChanged=false
for _,r in ipairs(rows) do r.noise={100,100,100,100,100,100} end
partial=assert(R.fit(channels,rows,provenance))
for _,axis in ipairs(R.axes) do assert(not partial.axes[axis].allocatable) end
assert(not R.allocate(model,{0/0,0,0,0,0,0}))
print('Measured response model: six-axis coupled allocation, signed feasibility, local nonextrapolated bounds, nine architecture/fault domains, units/identity/ACK evidence and noise rejection passed')
