-- Simplified fixture dynamics only, never a real Sable observation.
local Probe=assert(loadfile('platforms/sputnik/src/bank_probe.lua'))()
local function observation(t,z) return {tick=t,x=0,y=70,z=z or 0,pitch=0,yaw=0,roll=0,mass=100,namespace='fixture:world',spin=0} end
local config={stop=15,test=14,maxProbe=2,maxTravel=8}
local function simulation(mode)
 local obs=observation(100) local job=assert(Probe.new(config,obs)) local velocity=0 local command=job:command()
 local pulses=0 local lastRun=0 local spinTail=0 local seenB=false
 for tick=101,900 do
  obs.tick=tick
  local running=command.run>0
  if running then spinTail=2 else spinTail=math.max(0,spinTail-1) end
  obs.spin=(running or spinTail>0) and 15 or 0
  if mode=='missing-spin' then obs.spin=0 end
  if mode=='stuck-spin' and job.phase=='coastA' then obs.spin=15 end
  local direction=command.direction==15 and -1 or 1
  if mode=='wrong-reverse' then direction=1 end
  local force=running and .8*direction or 0
  velocity=velocity+(force-2*velocity)*.05
  if mode=='blocked' then velocity=0 end
  obs.z=obs.z+velocity*.05
  command=job:step(obs) job:requested(tick)
  if command.run>0 and lastRun==0 then pulses=pulses+1 end lastRun=command.run
  if command.direction==15 then seenB=true end
  if job.failed or job.done then break end
 end
 if mode=='missing-spin' or mode=='blocked' then assert(job.failed and not seenB and command.run==0)
 elseif mode=='wrong-reverse' then assert(job.failed and not job.done and command.run==0)
 elseif mode=='stuck-spin' then assert(not job.done and not seenB and job.phase=='coastA' and command.run==0,'rotation feedback was replaced by a delay')
 else assert(job.done and not job.failed and pulses==2 and job.report.A.spinningObserved and job.report.B.opposition<-.99 and not job.report.flightQualified) end
 return job
end
simulation() simulation('missing-spin') simulation('blocked') simulation('wrong-reverse') simulation('stuck-spin')
for _,change in ipairs({function(o)o.mass=110 end,function(o)o.y=71 end,function(o)o.namespace='other' end,function(o)o.pitch=10 end,function(o)o.tick=99 end,function(o)o.x=0/0 end}) do
 local obs=observation(100) local p=assert(Probe.new(config,obs)) p:step(obs) p:requested(100)
 local bad=observation(101) change(bad) assert(p:step(bad).run==0 and p.failed)
end
local p=assert(Probe.new(config,observation(100))) p:step(observation(100)) p:requested(100)
for _=1,20 do p:step(observation(100)) end assert(p.phase=='restA','duplicate clock generated rest evidence')
assert(p:step(observation(120)).run==0 and p.failed,'source gap accepted')
local malformed=observation(100) malformed.pitch=nil assert(not Probe.new(config,malformed))
assert(not Probe.new({stop=15,test=15,maxProbe=2,maxTravel=8},observation(100)))
print('Bank experiment: opposed movements + shaft spin evidence, real neutral stopping, no timer-only pass, blocked/wrong reverse/no feedback refusal, envelope/mass/world/clock guards and no flight certificate passed')
