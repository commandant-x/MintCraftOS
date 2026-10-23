package.path='./?.lua;'..package.path
local A=require('system.libraries.addon')
A.configure({readsPerTick=100000}) A.bounded=function(fn) return pcall(fn) end
A.periodic=function() return {stop=function() end} end
parallel={waitForAll=function(...) for _,f in ipairs({...}) do f() end end}
local now,height,rate,command=10,80,0,7
local allowed,pressed,receiverMissing,foreign,poseMissing,diskFull=true,false,false,false,false,false
local writes=0 local suspended
local plantFactor,plantBias=1,0
os.clock=function() return now end os.epoch=function() return now*1000 end
local stored,serialized,reports={},nil,{}
textutils={serialize=function(v) serialized=A.copy(v) return 'cfg' end}
package.loaded['system.libraries.config']={load=function() return A.copy(stored) end}
package.loaded['system.libraries.safe_write']={write=function(path) if diskFull then return false,'disk full' end if path=='/system/config/navigation-response.cfg' then reports[path]=A.copy(serialized) else stored=A.copy(serialized) end return true end}
package.loaded['system.libraries.log']={warn=function() end,error=function() end}
package.loaded['system.security.permissions']={require=function() return allowed,'denied' end}
redstone={getInput=function() return pressed end}
fs={getFreeSpace=function() return 1000000 end,exists=function() return false end}
A.inventory=function() return {{name='tx',types={'redstone_link_bridge'},set={sendLinkSignal=true},device={sendLinkSignal=function(_,_,value)
 writes=writes+1 command=value if suspended then local fn=suspended suspended=nil fn() end return true
end}}} end
local function pose()
 if poseMissing then return {} end
 return {vehicleId=foreign and 'other' or 'ship',inSublevel=true,frame='world',timestamp=now,identityAt=now,
  logicalPose={position={x=0,y=height,z=0},orientation={x=0,y=0,z=0,w=1}}}
end
package.loaded['system.services.sabled']={pose=pose,snapshot=function() return {timestamp=now} end,status=function() return {inSublevel=true} end}
package.loaded['system.services.avionicsd']={flightTelemetry=function() return {pitch=0,roll=0,heading=0,altitude=height,pitchRate=0,rollRate=0,headingRate=0,altitudeRate=rate,timestamp=now} end}
local raw={schema=1,ok=true,complete=true,readOnly=true,frame='body_plot',vehicleId='ship',revision=0,ageTicks=0,
 units={position='block',mass='kg'},mass=65,centerOfMass={x=0,y=0,z=0},features={},actuators={},links={}}
mintcraft_vehicle={snapshot=function() return A.copy(raw) end}
local B=require('system.services.vehiclebridged')
local F=require('system.services.flightd')
local process={pid=7,state='ready',meta={appId='navigation'},permissions={}}
local ctx={scheduler={processes={[7]=process}}} local actor={pid=7}
local function sample()
 raw.revision=raw.revision+1
 raw.links=receiverMissing and {} or {{id='rx',receiver=true,position={x=0,y=0,z=0},first={item='minecraft:iron_ingot'},second={item='minecraft:gold_ingot'},signal=command}}
 B.acquire()
end
local function tick()
 now=now+.1
 rate=rate+(plantFactor*.8*(command-7)+plantBias-.2*rate)*.1 height=height+rate*.1
 sample() F.step()
end
F.start(ctx) F.step(true) sample()
local cfg=F.configuration()
cfg.mode='full' cfg.channels={{id='assigned',backend='frequency',name='tx',min=6,max=8,neutral=7,rescue=7,
 link={first='minecraft:iron_ingot',second='minecraft:gold_ingot'},mix={}}}
cfg.manualInputs={{axis='altitude',side='front',value=1}}
assert(F.configure(actor,cfg))
for _=1,5 do tick() end
local before=writes
assert(not F.startKnownOutputCalibration(actor,false))
assert(not F.startKnownOutputCalibration({pid=99},true))
assert(not F.startKnownOutputCalibration(actor,true),'unknown neutral hover was invented')
assert(writes==before)
assert(F.calibrate(actor,'hover',nil,true))
diskFull=true assert(not F.startKnownOutputCalibration(actor,true)) diskFull=false
assert(writes==before,'failed session persistence moved an output')
assert(F.startKnownOutputCalibration(actor,true))
assert(not F.startKnownOutputCalibration(actor,true),'concurrent output sequence accepted')
for i=1,3000 do
 tick()
 local status=F.status()
 assert(status.state~='failsafe',status.reason)
 if status.outputCharacterization.state=='complete' then break end
 assert(i<3000,'known output measurement did not finish: '..status.reason)
end
local status=F.status()
assert(status.state=='disarmed' and command==7 and not stored.control.sessionActive,'measurement did not apply configured rescue and clear session')
assert(not status.outputCharacterization.axes.pitch.allocatable,'vertical thrust invented attitude control')
local report=assert(F.characterizationReport(actor))
assert(report.model and #report.observations==2 and report.model.axes.vertical.allocatable,'real command/pose response failed to identify measured vertical domain')
assert(not F.configuration().channels[1].validated,'characterization forged closed-loop direction proof')
assert(not F.arm(actor),'algebraic allocation silently armed a flight controller')
report.model.axes.vertical.allocatable=false
assert(F.characterizationReport(actor).model.axes.vertical.allocatable,'client mutated service-private response evidence')
assert(report.clockId==require('system.ascendancy.contracts').clockId() and report.observations[1].clockId==report.clockId,'lost derivative clock provenance')
assert(F.saveCharacterizationReport(actor))
assert(reports['/system/config/navigation-response.cfg'].validity:find('never restores outputs',1,true))
diskFull=true assert(not F.saveCharacterizationReport(actor)) diskFull=false
allowed=false assert(not F.characterizationReport(actor)) assert(not F.saveCharacterizationReport(actor)) allowed=true
-- Every guard applies the actual configured rescue; no new pulse follows STOP.
for _,failure in ipairs({'receiver','owner','permission','manual','pose','identity','mass','stop','yield'}) do
 rate=0 command=7 poseMissing,foreign,receiverMissing,pressed=false,false,false,false allowed=true process.state='ready' raw.mass=65
 sample() for _=1,6 do tick() end
 if F.status().state=='failsafe' then assert(F.disarm(actor)) end
 assert(F.startKnownOutputCalibration(actor,true))
 for i=1,100 do tick() if command~=7 then break end assert(i<100,'no pulse before fault injection') end
 if failure=='receiver' then receiverMissing=true
 elseif failure=='owner' then process.state='dead'
 elseif failure=='permission' then allowed=false
 elseif failure=='manual' then pressed=true
 elseif failure=='pose' then poseMissing=true
 elseif failure=='identity' then foreign=true
 elseif failure=='mass' then raw.mass=50
 elseif failure=='stop' then assert(F.disarm(actor))
 else
  -- Interrupt the return-to-neutral write, then prove it cannot rearm itself.
  suspended=function() assert(F.disarm(actor)) end
 end
 for _=1,40 do tick() end
 assert(F.status().state=='failsafe' and command==7 and F.status().outputCharacterization.state=='aborted','guard failed to apply actual rescue: '..failure)
 assert(not F.characterizationReport(actor),'aborted experiment exported a valid report: '..failure)
 local stopped=writes for _=1,20 do tick() end assert(writes==stopped,'stopped sequence emitted a later pulse: '..failure)
end
print('Known-output flight integration: actual isolated signals and pose derivatives, signed response, neutral settling, configured rescue, immutable evidence, no false arming and nine failure/STOP paths passed')

-- The automatic path must actually qualify closed-loop motion before holding.
rate=0 command=7 poseMissing,foreign,receiverMissing,pressed=false,false,false,false allowed=true process.state='ready' raw.mass=65
sample() for _=1,6 do tick() end
assert(F.disarm(actor))
assert(not F.activateAutomatic(actor,true),'automatic generic flight bypassed physical manual/rescue prerequisites')
assert(F.calibrate(actor,'manual',nil,true))
assert(F.calibrate(actor,'rescue',nil,true))
for _=1,5 do tick() end
assert(F.calibrate(actor,'rescueConfirm',nil,true))
assert(F.activateAutomatic(actor,true))
for i=1,10000 do
 tick()
 local status=F.status()
 assert(status.state~='failsafe',status.reason)
 if status.knownOutputHold then break end
 assert(i<10000,'known-output closed-loop qualification did not finish: '..status.reason)
end
local active=F.status()
assert(active.state=='armed' and active.knownOutputHold.axes.vertical and not active.knownOutputHold.axes.pitch)
assert(active.outputCharacterization.qualification.state=='complete' and #active.outputCharacterization.qualification.checks==3,'local hold bypassed actual positive/negative/return checks')
local target=active.knownOutputHold.position.y+.1
assert(F.setFlightTargets(actor,{altitude=target}))
for _=1,1500 do tick() assert(F.status().state=='armed',F.status().reason) end
assert(math.abs(height-target)<.15 and math.abs(rate)<.1,'qualified output controller did not hold the requested height')
assert(not F.setFlightTargets(actor,{altitude=100000}),'unobserved altitude domain accepted')
assert(F.characterizationReport(actor).model)
raw.mass=72 plantFactor=.9 plantBias=-.02
local preserved=F.status().targets.altitude
for _=1,2500 do tick()
 assert(F.status().state=='armed' and not F.status().rescuePending,'mass change alone rescued measured output hold')
 assert(F.status().targets.altitude==preserved,'passive adaptation changed the altitude target')
end
assert(F.status().outputCharacterization.massAdaptation and math.abs(height-preserved)<.15 and math.abs(rate)<.1,'measured local mass trim did not settle')
assert(not F.characterizationReport(actor),'passive mass adaptation exported a false recalibration')
F.release(actor.pid,'closed during measured known-output hold') tick()
assert(F.status().state=='failsafe' and command==7 and not F.status().knownOutputHold,'close did not apply actual configured rescue')
print('Known-output automatic flight: measured signed columns, actual closed-loop up/down/return qualification, private local altitude hold and target, no unqualified axes and real close rescue passed')
