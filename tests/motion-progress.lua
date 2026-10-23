package.path='./?.lua;'..package.path
local M=require('system.navigation.motion_progress')
local function trajectory(kind)
 local m=M.new()
 for i=1,200 do
  local envelope=kind=='decay' and math.exp(-i/25) or 1
  local angle=i*math.pi/2
  local e=kind=='stuck' and 2 or envelope*math.sin(angle)
  local r=kind=='stuck' and 0 or envelope*math.cos(angle)
  m:observe({e,0,0,0,0,0},{r,0,0,0,0,0},i*.5)
 end
 return m
end
assert(trajectory('oscillate').axes[1]=='nondecaying-oscillation')
assert(trajectory('stuck').axes[1]=='no-measured-convergence')
assert(next(trajectory('decay').axes)==nil,'normal braking/settling treated as a failure')
local m=trajectory('oscillate')
assert(#m.samples==32 and not m:observe({0,0,0,0,0,0},{0,0,0,0,0,0},100),'duplicate interval accepted')
assert(not m:observe({0/0,0,0,0,0,0},{0,0,0,0,0,0},101),'nonfinite sample accepted')
assert(m:observe({0,0,0,0,0,0},{0,0,0,0,0,0},102) and #m.samples==1,'discontinuous history treated as continuous')
assert(m.state==nil,'progress diagnostic granted control authority')
print('Physical progress: bounded observations distinguish persistent oscillation, stalled error and damped settling; gaps/duplicates/nonfinite values cannot grant qualification')
