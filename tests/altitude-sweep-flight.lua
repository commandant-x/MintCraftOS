package.path="./?.lua;"..package.path
local addon=require("system.libraries.addon")
addon.bounded=function(fn) return pcall(fn) end addon.configure({readsPerTick=100000})
addon.periodic=function() return {stop=function() end} end
parallel={waitForAll=function(...) for _,f in ipairs({...}) do f() end end}
local worldX,tilt,poseLost,foreignPose=0,0,false,false
local motorSim,worldZ,yaw=false,0,0
local motorSignals={}
local orientationFormat="sable"
local function orientation()
 if motorSim then return {a=math.cos(math.rad(yaw)/2),v={x=0,y=math.sin(math.rad(yaw)/2),z=0}} end
 local x,w=math.sin(math.rad(tilt)/2),math.cos(math.rad(tilt)/2)
 if orientationFormat=="sable" then return {a=w,v={x=x,y=0,z=0}} end
 if orientationFormat=="server" then return {a=0.61198675632476807,v={x=-4.7012736104079522e-7,y=0.79086810350418091,z=-1.1281101037273287e-6}} end
 if orientationFormat=="flat" then return {x=x,y=0,z=0,w=w} end
 if orientationFormat=="array" then return {x,0,0,w} end
 if orientationFormat=="missing" then return {a=w,v={y=0,z=0}} end
 if orientationFormat=="zero" then return {a=0,v={x=0,y=0,z=0}} end
 if orientationFormat=="nan" then return {a=0/0,v={x=0,y=0,z=0}} end
 if orientationFormat=="string" then return {a="1",v={x=0,y=0,z=0}} end
 return {a=w,v=false}
end
local now,z,v,command,pressed,allowed,badReceiver,stale,failWrite=10,100,0,0,false,true,false,false,false
os.clock=function() return now end os.epoch=function() return now*1000 end
local stored,serialized,files={},nil,{}
local onTransmit
local stuckRescue=false
local separateBurners,secondBurnerCommand=false,0
textutils={serialize=function(t) serialized=addon.copy(t) return "cfg" end}
package.loaded["system.libraries.config"]={load=function(path) return addon.copy(path=="/system/config/navigation-calibration.cfg" and files[path] or stored) end}
package.loaded["system.libraries.safe_write"]={write=function(path)
 if failWrite then return false,"disk full" end
 if path=="/system/config/navigation.cfg" then stored=addon.copy(serialized) end
 files[path]=addon.copy(serialized) return true
end}
local space=1000000
fs={getFreeSpace=function() return space end,exists=function(p) return files[p]~=nil end}
package.loaded["system.libraries.log"]={warn=function() end,error=function() end}
package.loaded["system.security.permissions"]={require=function() return allowed,"denied" end}
redstone={getInput=function() return pressed end}
addon.inventory=function() return {{name="tx",types={"redstone_link_bridge"},set={sendLinkSignal=true},device={sendLinkSignal=function(first,_,value)
 if first:find('minecraft:motor_',1,true)==1 then
  local clutch=first:gsub('_gear$','_clutch'):gsub('_reverse$','_clutch')
  if not first:find('_clutch',1,true) and motorSignals[first]~=value then assert(motorSignals[clutch]==15,'shift/reverse while clutch engaged') end
  motorSignals[first]=value
 elseif first=="minecraft:second_burner" then secondBurnerCommand=value
 else command=value end
 if onTransmit then local callback=onTransmit onTransmit=nil callback() end return true end}}} end
package.loaded["system.services.sabled"]={snapshot=function() return {timestamp=now} end,status=function() return {inSublevel=true} end,pose=function() if poseLost then return nil end return {vehicleId=foreignPose and "other" or "ship",inSublevel=true,frame="world",timestamp=now,identityAt=now,logicalPose={position={x=worldX,y=z,z=worldZ},orientation=orientation()}} end}
package.loaded["system.services.avionicsd"]={flightTelemetry=function()
 local stamp=stale and now-1 or now
 return {timestamp=stamp,measurements={altitude={value=z,valid=true,observedAt=stamp,validUntil=stamp+0.5},
 altitudeRate={value=v,valid=true,observedAt=stamp,validUntil=stamp+0.5}}}
end}
local raw={schema=1,ok=true,complete=true,readOnly=true,frame="body_plot",vehicleId="ship",units={position="block"},revision=0,ageTicks=0,
 centerOfMass={x=0,y=0,z=0},features={burners=true},actuators={},links={},burners={}}
for i=1,2 do raw.burners[i]={id="heater"..i,position={x=i,y=0,z=0},signal=0,gasOutput=0,hasBalloon=false,associationSource="heater_membership",associationState="no_balloon_reference"} end
mintcraft_vehicle={snapshot=function() return addon.copy(raw) end}
local bridge=require("system.services.vehiclebridged")
local function sample()
 raw.revision=raw.revision+1
 for i,b in ipairs(raw.burners) do b.signal=(i==1 and stuckRescue and command==0) and 7 or ((i==1 and badReceiver) and 0 or (i==2 and separateBurners and secondBurnerCommand or command)) b.gasOutput=b.signal*10 b.hasBalloon=b.signal>0 b.associationState=b.hasBalloon and "associated" or "no_balloon_reference" end
 for _,r in ipairs(raw.links) do if r.motor then r.signal=motorSignals[r.first.item] or 0 end end
 bridge.acquire()
end
local process={pid=7,state="ready",meta={appId="navigation"},permissions={}}
local ctx={scheduler={processes={[7]=process}}}
local flight=require("system.services.flightd")
local actor={pid=7}
flight.start(ctx) flight.step(true) sample()
local function prepare()
 pressed,allowed,badReceiver,stale,failWrite=false,true,false,false,false stuckRescue=false process.state="ready"
 worldX,tilt,poseLost,foreignPose=0,0,false,false
 if flight.status().state=="failsafe" then assert(flight.disarm(actor)) end
 local cfg=flight.configuration()
 cfg.mode="altitude" cfg.channels={{id="burners",backend="frequency",name="tx",min=0,max=15,neutral=5,rescue=0,
 link={first="minecraft:white_wool",second="minecraft:white_wool"},mix={altitude=1},actuator={role="buoyancy"}}}
 cfg.balloonSetup={vehicleId="ship",burnerIds={"heater1","heater2"}}
 cfg.manualInputs={{axis="altitude",side="front",value=1}} cfg.gains.altitude.kp=0
 assert(flight.configure(actor,cfg))
 assert(flight.testOutput(actor,"burners",5,true,2)) flight.step()
 now=now+1 sample() flight.step()
 now=now+1.1 flight.step() flight.step() sample()
 assert(flight.calibrate(actor,"channel","burners",true))
 assert(flight.calibrate(actor,"manual",nil,true))
 assert(flight.calibrate(actor,"rescue",nil,true)) flight.step()
 assert(flight.calibrate(actor,"rescueConfirm",nil,true))
 z,v=55,0 sample()
end
local options=require("system.navigation.altitude_sweep").defaults()
options.autoPrepare=false options.autoHold=false options.certify=false
prepare()
local verified=flight.configuration()
local unverified=addon.copy(verified) unverified.manualValidated=false
assert(flight.configure(actor,unverified))
local refused,detail=flight.startSweep(actor,options,true)
assert(not refused and detail:find("Manual OK",1,true) and detail:find("Test rescue, then Rescue OK",1,true) and detail:find("Verify direction",1,true) and detail:find("Initialize (2s)",1,true),"missing sweep prerequisites not identified")
prepare()
assert(not flight.startSweep(actor,options,false)) assert(command==0)
local frozen=flight.configuration() frozen.channels[1].neutral=1
assert(not flight.startSweep(actor,options,true,frozen))
assert(flight.startSweep(actor,options,true,flight.configuration()))
assert(stored.control.sessionActive and command==0,"extended operation not persisted before actuation")
local ticks=0
while flight.status().sweep.state=="running" do
 ticks=ticks+1 assert(ticks<1800)
 now=now+0.1
 v=v+(0.1*(30+5*command-z)-0.6*v)*0.1 z=z+v*0.1
 if ticks%10==0 then sample() end
 flight.step()
end
local result=assert(flight.sweepReport(actor))
assert(result.state=="complete",result.reason)
assert(result.proposal,result.fitError)
assert(command==0 and not stored.control.sessionActive)
assert(flight.configuration().channels[1].neutral==5,"sweep silently applied model")
assert(not flight.applySweep(actor,false))
local saved,path=flight.exportSweep(actor) assert(saved and files[path].samples[1])
space=0 assert(not flight.exportSweep(actor)) space=1000000
assert(flight.applySweep(actor,true))
assert(flight.configuration().channels[1].neutral==11 and flight.configuration().gains.altitude.kp>0)
assert(not flight.configuration().manualValidated and not flight.configuration().hoverValidated and not flight.configuration().rescueValidated)
assert(not flight.arm(actor),"model fit forged physical validation")
-- Captured server rotation: large yaw is not a tilt failure.
orientationFormat="server" prepare()
assert(flight.startSweep(actor,options,true),"captured server quaternion rejected")
assert(flight.stopSweep(actor)) flight.step() assert(flight.disarm(actor))
-- Actual Sable a/v format must retain all tilt and validity guards.
for _,format in ipairs({"sable","flat","array"}) do
 orientationFormat=format prepare()
 assert(flight.startSweep(actor,options,true),format.." quaternion rejected")
 tilt=11 flight.step()
 assert(command==0 and flight.status().sweep.state=="aborted",format.." bypassed tilt guard")
 assert(flight.disarm(actor))
end
for _,format in ipairs({"missing","zero","nan","string","bad-vector"}) do
 orientationFormat=format prepare()
 local ok,err=flight.startSweep(actor,options,true)
 assert(not ok and err:find("Invalid sweep orientation",1,true) and command==0,format.." quaternion accepted")
end
orientationFormat="sable"
-- High measured speed is data, not a configured sweep cutoff.
prepare() v=3
assert(flight.startSweep(actor,options,true),"measured speed blocked sweep start")
flight.step() assert(flight.status().sweep.state=="running")
worldX=10000 z=10000 now=now+0.1 sample() flight.step()
assert(flight.status().sweep.state=="running","world/altitude displacement still stopped sweep")
assert(flight.stopSweep(actor)) flight.step() v=0 assert(flight.disarm(actor))
-- Repeated independent failures must rescue without applying candidate gains.
for _,fault in ipairs({"tilt","pose","identity","sensor","receiver","owner","permission","manual","stop"}) do
 prepare()
 assert(flight.startSweep(actor,options,true)) flight.step()
 if fault=="tilt" then tilt=11 elseif fault=="pose" then poseLost=true elseif fault=="identity" then foreignPose=true
 elseif fault=="sensor" then stale=true elseif fault=="receiver" then badReceiver=true now=now+2.1
 elseif fault=="owner" then process.state="killed" elseif fault=="permission" then allowed=false
 elseif fault=="manual" then pressed=true elseif fault=="stop" then assert(flight.stopSweep(actor)) end
 now=now+0.1 sample() flight.step()
 assert(command==0 and flight.status().sweep.state=="aborted",fault.." did not abort/rescue")
 assert(flight.configuration().gains.altitude.kp==0,fault.." changed gains")
 process.state="ready" allowed=true pressed=false stale=false badReceiver=false v=0
 assert(flight.disarm(actor))
end
prepare()
assert(flight.startSweep(actor,options,true))
onTransmit=function() assert(flight.stopSweep(actor)) end
flight.step()
assert(command==0 and flight.status().sweep.state=="aborted","stop during suspended write was overwritten")
assert(flight.disarm(actor))
prepare() failWrite=true
assert(not flight.startSweep(actor,options,true) and command==0,"failed durable preparation actuated")
failWrite=false
assert(flight.startSweep(actor,options,true)) flight.step()
assert(stored.control.sessionActive)
flight.start(ctx)
assert(flight.status().state=="failsafe" and flight.status().rescuePending and not flight.status().sweep)
flight.step(true) assert(command==0,"boot did not apply interrupted sweep rescue")
print("altitude sweep service: simulated plant/model, explicit start/apply, durable preparation/report, config invalidation, guard failures, owner/manual/permission stop and interrupted boot rescue passed")

prepare()
local limited=require('system.navigation.altitude_sweep').defaults() limited.maxTravel=10
assert(flight.startSweep(actor,limited,true)) flight.step()
worldX=11 now=now+0.1 sample() flight.step()
assert(flight.status().sweep.state=='aborted' and command==0,'operator world limit did not rescue')
print('operator world constraint retains rescue and disarmed defaults passed')

-- One explicit start authorizes actual initialization/rescue tests, measurement,
-- then a session-only vertical hold when independently qualified by real data.
orientationFormat='sable' prepare()
local autoCfg=flight.configuration() autoCfg.manualValidated=false
assert(flight.configure(actor,autoCfg))
local autoOptions=require('system.navigation.altitude_sweep').defaults()
assert(autoOptions.autoPrepare and autoOptions.autoHold)
autoOptions.certify=false
assert(flight.startSweep(actor,autoOptions,true,flight.configuration()))
assert(not flight.status().calibration.initializationConfirmed and command==0)
local autoTicks=0 local sawInit,sawRescue,sawMeasure=false,false,false
while flight.status().sweep.state=='running' do
 autoTicks=autoTicks+1 assert(autoTicks<20000,'automatic measurement did not complete')
 now=now+0.1
 v=v+(0.1*(30+5*command-z)-0.6*v)*0.1 z=z+v*0.1
 if autoTicks%10==0 then sample() end
 flight.step()
 local report=flight.status().sweep
 sawInit=sawInit or report.phase=='initialize'
 sawRescue=sawRescue or report.phase=='rescue'
 sawMeasure=sawMeasure or report.phase=='measure'
end
local autoResult=assert(flight.sweepReport(actor))
assert(sawInit and sawRescue and sawMeasure and autoResult.prepared)
assert(autoResult.proposal,autoResult.fitError)
assert(flight.status().state=='armed' and flight.status().measuredHold,'qualified vertical hold did not start: '..flight.status().reason)
assert(stored.control.sessionActive,'automatic hold was not durably marked')
local physical=flight.configuration()
assert(not physical.channels[1].validated and not physical.manualValidated and not physical.rescueValidated and not physical.hoverValidated,'automatic tests forged physical calibration')
assert(flight.setSetpoint(actor,'altitude',82))
assert(not flight.setSetpoint(actor,'altitude',10000),'automatic hold extrapolated beyond measured heights')
for i=1,1600 do
 now=now+0.1 local heat=separateBurners and (command+secondBurnerCommand)/2 or command
 v=v+(0.1*(30+5*heat-z)-0.6*v)*0.1 z=z+v*0.1
 if i%10==0 then sample() end
 flight.step()
 assert(flight.status().state=='armed','vertical hold failed: '..flight.status().reason)
end
assert(math.abs(z-82)<1,'measured interpolation/duty cycle failed metre target: '..z)
local heatDisplay=flight.status().measuredHold
assert(type(heatDisplay.requestedHeat)=='number' and heatDisplay.heat==command,'cockpit heat readout differs from actual applied command')
-- Damage changes equilibrium; learn a trim without a sweep or target motion.
raw.mass=65 raw.units.mass='kg' sample() flight.step()
local modelBefore=addon.copy(flight.configuration())
local savedReportBefore=files['/system/config/navigation-calibration.cfg']
for _,change in ipairs({{mass=52,zero=60},{mass=72,zero=20}}) do
 raw.mass=change.mass sample() flight.step()
 assert(flight.status().state=='armed' and flight.status().measuredHold.adaptation,'mass event stopped altitude hold')
 for i=1,6000 do
  now=now+0.1 v=v+(0.1*(change.zero+5*command-z)-0.6*v)*0.1 z=z+v*0.1
  if i%10==0 then sample() end
  flight.step()
  local status=flight.status()
  assert(status.state=='armed' and not status.rescuePending,'mass adaptation issued rescue: '..status.reason)
  assert(status.targets.altitude==82,'mass adaptation deliberately moved the altitude target')
  if status.measuredHold.adaptation.phase=='holding' and math.abs(z-82)<0.5 and math.abs(v)<=0.25 then break end
 end
 local status=flight.status()
 assert(math.abs(z-82)<0.5 and math.abs(v)<=0.25,'airborne trim did not recover height: '..z..' / '..v)
 assert(status.measuredHold.adaptation.phase=='holding','stable natural response was not observed: '..status.measuredHold.adaptation.phase..' / '..status.measuredHold.adaptation.samples..' / '..status.measuredHold.adaptation.bias)
 assert(not flight.saveCalibration(actor),'local trim exported a false full calibration')
 if change.mass==52 then assert(status.measuredHold.requestedHeat<7,'damage trim remained trapped above old measured heat range') end
end
-- If lift cannot support the target, keep best available output, never a
-- fabricated stable certificate or an automatic burner-off rescue.
raw.mass=90 sample() flight.step()
for i=1,2000 do
 now=now+0.1 v=v+(0.1*(-10+5*command-z)-0.6*v)*0.1 z=z+v*0.1
 if i%10==0 then sample() end
 flight.step()
 assert(flight.status().state=='armed' and flight.status().targets.altitude==82,'heat saturation triggered rescue or a target excursion')
end
local exhausted=flight.status().measuredHold.adaptation
assert(command==15 and exhausted.saturated and exhausted.phase=='learning','exhausted heat authority was not reported honestly')
assert(files['/system/config/navigation-calibration.cfg']==savedReportBefore and flight.configuration().gains.altitude.kp==modelBefore.gains.altitude.kp,'adaptation replaced stored model or controller gains')
assert(not flight.activateAutomatic(actor,true),'mass adaptation started a new motion sequence in flight')
assert(not flight.startAutoCalibration(actor,true),'airborne trim accepted a motion test sequence')
print('airborne mass adaptation: lighter/heavier actual equilibrium, unchanged height target, stable natural response, no sweep/rescue and no forged calibration passed')
pressed=true now=now+0.1 sample() flight.step()
assert(not flight.status().measuredHold and command==0,'physical takeover failed during measured hold')
pressed=false assert(flight.disarm(actor)) flight.step()
assert(flight.status().state=='disarmed' and not flight.status().measuredHold,'STOP restarted automatic hold')
print('automatic sequence: actual all-burner initialization/rescue feedback, qualified vertical hold, fractional heat metre target in simulated plant, no forged flags and manual-stop/no-restart passed')

for _,fault in ipairs({'initialization','rescue','permission','owner','disk'}) do
 prepare()
 local c=flight.configuration() c.manualValidated=false assert(flight.configure(actor,c))
 local opts=require('system.navigation.altitude_sweep').defaults() opts.autoHold=false opts.certify=false
 if fault=='disk' then failWrite=true assert(not flight.startSweep(actor,opts,true) and command==0) failWrite=false
 else
  assert(flight.startSweep(actor,opts,true)) flight.step()
  if fault=='rescue' then
   now=now+0.1 sample() flight.step() assert(flight.status().sweep.phase=='rescue') stuckRescue=true
  elseif fault=='initialization' then badReceiver=true
  elseif fault=='permission' then allowed=false
  elseif fault=='owner' then process.state='killed' end
  now=now+2.1 sample() flight.step()
  assert(flight.status().sweep.state=='aborted' and command==0,fault..' preparation failure was ignored')
  assert(not flight.configuration().rescueValidated and not flight.configuration().manualValidated)
 end
 failWrite=false allowed=true process.state='ready' badReceiver=false stuckRescue=false
 assert(flight.disarm(actor))
end
print('automatic preparation: wrong/missing receiver at initialization or rescue, revoked permission, lost owner and full disk stop without forged flags passed')

for _,fault in ipairs({'receiver','late-stop'}) do
 prepare()
 local c=flight.configuration() c.manualValidated=false assert(flight.configure(actor,c))
 local opts=require('system.navigation.altitude_sweep').defaults() opts.certify=false
 assert(flight.startSweep(actor,opts,true))
 for i=1,20000 do
  now=now+0.1 v=v+(0.1*(30+5*command-z)-0.6*v)*0.1 z=z+v*0.1
  if i%10==0 then sample() end
  flight.step()
  if flight.status().sweep.state~='running' then break end
 end
 assert(flight.status().measuredHold,flight.status().reason)
 if fault=='late-stop' then onTransmit=function() assert(flight.disarm(actor)) end
 else badReceiver=true end
 for i=1,35 do now=now+0.1 sample() flight.step() end
 assert(command==0 and not flight.status().measuredHold and flight.status().state=='failsafe',fault..' hold fault was overwritten or rearmed')
 badReceiver=false assert(flight.disarm(actor))
end
print('measured hold: receiver loss cannot be hidden by fractional modulation, and STOP during a suspended write is rescued without rearming passed')

prepare()
local calibrationConfig=flight.configuration() calibrationConfig.manualValidated=false assert(flight.configure(actor,calibrationConfig))
local completeOptions=require('system.navigation.altitude_sweep').defaults()
assert(flight.startSweep(actor,completeOptions,true))
local calibrationTicks=0
while true do
 calibrationTicks=calibrationTicks+1 assert(calibrationTicks<40000,'closed-loop calibration did not finish')
 now=now+0.1 v=v+(0.1*(30+5*command-z)-0.6*v)*0.1 z=z+v*0.1
 if calibrationTicks%10==0 then sample() end
 flight.step()
 local proof=flight.status().autoCalibration
 assert(proof and proof.state~='aborted',proof and proof.reason or flight.status().reason)
 if proof.state=='complete' then break end
end
local certificate=flight.status().autoCalibration
for _,key in ipairs({'hover','down','up','return','rescue','priority'}) do assert(certificate.checks[key] and certificate.checks[key].passed,key..' has no observed evidence') end
assert(flight.status().measuredHold and flight.status().calibrationSaved)
assert(files['/system/config/navigation-calibration.cfg'].checks.priority.scope:find('physical switch not inferred',1,true))
assert(not flight.configuration().manualValidated and not flight.configuration().rescueValidated,'certificate forged old manual flags')
assert(flight.startAutoCalibration(actor,true))
raw.mass=60 sample() flight.step()
local interrupted=flight.status()
assert(interrupted.state=='armed' and interrupted.measuredHold.adaptation and interrupted.autoCalibration.state=='aborted','mass event during motion tests triggered rescue')
assert(math.abs(interrupted.targets.altitude-z)<1e-6 and not interrupted.rescuePending,'interrupted motion calibration did not hold current height')
assert(flight.stopMission(actor)) flight.step()
assert(command==0 and not flight.status().measuredHold,'pilot STOP did not stop vertical-only control')
assert(flight.disarm(actor))
print('closed-loop calibration: actual hover/down/up/return, physical rescue response, software STOP with receiver proof, durable evidence, no forged switch and vertical STOP regression passed')


-- Exact user topology: two independent clutch / 16-state gearbox / reverser groups.
motorSim=true worldZ,yaw=0,0
prepare()
local motorConfig=flight.configuration()
motorConfig.manualValidated=false
motorConfig.drivetrain={enabled=true,name='tx',clutchOff=15,left={},right={}}
for _,side in ipairs({'left','right'}) do for i,role in ipairs({'clutch','gear','reverse'}) do
 local name='minecraft:motor_'..side..'_'..role
 motorSignals[name]=role=='clutch' and 15 or 0
 motorConfig.drivetrain[side][role]={first=name,second='minecraft:iron_ingot'}
 raw.links[#raw.links+1]={id=name,receiver=true,motor=true,position={x=side=='left' and -2 or 2,y=0,z=i},first={item=name},second={item='minecraft:iron_ingot'},signal=motorSignals[name]}
end end
raw.mass=65 raw.units.mass='kg'
local duplicateId=addon.copy(motorConfig) duplicateId.channels[1].id='drive-left-clutch'
assert(not flight.configure(actor,duplicateId),'logical command collision with motor chain accepted')
assert(flight.configure(actor,motorConfig)) sample()
assert(flight.startSweep(actor,require('system.navigation.altitude_sweep').defaults(),true))
local velocityX,velocityZ,yawVelocity=0,0,0
local motorBlocked=false
local function plantTick(i)
 local function force(side)
  if motorBlocked then return 0 end
  local prefix='minecraft:motor_'..side..'_'
  if motorSignals[prefix..'clutch']~=0 then return 0 end
  return (motorSignals[prefix..'gear'] or 0)/15*(motorSignals[prefix..'reverse']==15 and -1 or 1)
 end
 local l,r=force('left'),force('right') local a=math.rad(yaw)
 velocityX=velocityX+(0.3*(l+r)*math.sin(a)-0.8*velocityX)*0.1
 velocityZ=velocityZ+(0.3*(l+r)*math.cos(a)-0.8*velocityZ)*0.1
 yawVelocity=yawVelocity+(2*(r-l)-1.2*yawVelocity)*0.1 yaw=(yaw+yawVelocity*0.1)%360
 worldX=worldX+velocityX*0.1 worldZ=worldZ+velocityZ*0.1
 now=now+0.1 v=v+(0.1*(30+5*command-z)-0.6*v)*0.1 z=z+v*0.1
 if i%10==0 then sample() end
 flight.step()
end
for i=1,40000 do
 plantTick(i)
 local proof=flight.status().autoCalibration
 assert(proof and proof.state~='aborted',proof and proof.reason or flight.status().reason)
 if proof.state=='complete' then break end
 assert(i<40000,'motor calibration never finished: '..proof.phase..' '..proof.horizontal)
end
assert(flight.status().differentialReady,flight.status().autoCalibration.horizontal)
assert(flight.status().authority.rank==2 and flight.status().authority.frame=='heading_horizontal','measured response authority not integrated')
assert(flight.status().predictiveBraking and flight.status().predictiveBraking.samples>=2,'actual neutral-stop envelope missing')
assert(flight.kinematics().available and flight.kinematics().response and not flight.status().authority.axes.roll,'six-axis observations either missing or falsely certified new axes')
local catalogue=assert(flight.commands(actor))
assert(catalogue.available and #catalogue.commands==7,'actual cached motor/burner inventory unavailable')
catalogue.commands[1].neutral=-1 assert(flight.commands(actor).commands[1].neutral~=-1,'catalogue consumer modified configuration')
allowed=false assert(not flight.commands(actor),'catalogue bypassed read permissions') allowed=true
assert(not flight.commands({pid=99}),'foreign owner read private Navigation command API')

local motorReport=files['/system/config/navigation-calibration.cfg']
assert(motorReport.drivetrain and #motorReport.motorTests==60,'motor proof was not saved')
assert(motorReport.motorExperiments and #motorReport.motorExperiments.groups<=4 and #motorReport.motorExperiments.axes==6,'bounded six-axis experiment record missing')
local usableExperiments=0
for _,experiment in ipairs(motorReport.motorExperiments.groups) do
 if experiment.usable then
  usableExperiments=usableExperiments+1
  assert(experiment.samples>=3 and experiment.baselineSamples>=4 and #experiment.response==6 and #experiment.noiseStdDev==6 and experiment.notControlCertificate,'incomplete experiment was called usable')
 end
end
assert(usableExperiments>0,'actual acknowledged probes yielded no six-axis experiments')

assert(not flight.configuration().manualValidated,'motor qualification forged physical switch validation')
local route=require('system.navigation.autopilot').defaults()
route.points={{x=worldX+4,y=z,z=worldZ+4}} route.clearRouteConfirmed=true
assert(flight.startMission(actor,route,true),'measured airship route rejected')
for i=1,8000 do
 plantTick(i)
 assert(flight.status().state=='armed','differential route failed: '..flight.status().reason)
 if flight.status().autopilot.state=='holding' then break end
 assert(i<8000,'differential route never settled')
end
local requested=flight.status().targets.altitude
assert(flight.setFlightTargets(actor,{altitude=requested,speed=0.2,heading=90}))
assert(flight.status().pilot.heading==90 and not flight.status().autopilot.state:match('following'))
local before=flight.status().targets.altitude
assert(not flight.setFlightTargets(actor,{altitude=999999,speed=0.1,heading=0}))
assert(flight.status().pilot.heading==90 and flight.status().targets.altitude==before,'invalid cockpit target changed active guidance')
assert(not flight.setFlightTargets({pid=99},{altitude=requested,speed=0.1,heading=0}))
assert(not flight.setFlightTargets(actor,{altitude=requested,speed=9999,heading=0}))
for i=1,30 do plantTick(i) assert(flight.status().state=='armed',flight.status().reason) end
assert(flight.status().pilot,'cockpit demand lost during guidance')
raw.mass=50 sample() plantTick(1)
local damaged=flight.status()
assert(damaged.state=='armed' and damaged.measuredHold and damaged.measuredHold.adaptation and not damaged.rescuePending,'mass event rescued a flying motor vessel')
assert(not damaged.pilot and not damaged.differentialReady and damaged.targets.altitude==requested,'damaged mass kept stale horizontal model or changed altitude')
assert(motorSignals['minecraft:motor_left_clutch']==15 and motorSignals['minecraft:motor_right_clutch']==15,'mass event did not disengage horizontal motors')
assert(command>0,'mass event cut burner to rescue')
raw.mass=65 sample() plantTick(1)
assert(not flight.status().differentialReady,'returning mass silently restored old horizontal certificate')
assert(flight.stopMission(actor)) flight.step()
assert(command==0 and motorSignals['minecraft:motor_left_clutch']==15 and motorSignals['minecraft:motor_right_clutch']==15,'STOP did not disengage both motors')
assert(not flight.status().measuredHold and not flight.status().pilot)
print('two-motor automatic calibration: 60 gearbox/reverser modes, actual receiver feedback, neutral braking, disengage-shift-engage sequencing, service-owned differential route evidence, actual waypoint settling and STOP passed')

-- Single-button activation after restart: only the saved model is reused;
-- every electrical and closed-loop test is repeated against fresh measurements.
assert(flight.disarm(actor))
local fingerprint=string.rep('a',64)
motorReport.structureFingerprint=fingerprint
files['/system/config/navigation-calibration.cfg']=addon.copy(motorReport)
mintcraft_vehicle.geometryPage=function(page,token)
 return {schema=1,ok=true,readOnly=true,vehicleId='ship',frame='body_plot',units='block',token='automatic-survey',page=0,pages=1,
  origin={x=0,y=0,z=0},startedTick=100,observedTick=100,coverageComplete=true,palette={},runs='',structureHash=fingerprint}
end
flight.start(ctx) flight.step(true) sample()
assert(not flight.activateAutomatic(actor,false),'automatic activation ran without confirmation')
allowed=false assert(not flight.activateAutomatic(actor,true)) allowed=true
assert(flight.activateAutomatic(actor,true))
assert(not flight.status().measuredHold and not flight.status().autoCalibration,'activation skipped survey')
bridge.acquireGeometry() flight.step()
assert(flight.status().automatic.reused,'matching saved model not selected: '..flight.status().automatic.reason)
for i=1,40000 do
 plantTick(i)
 local status=flight.status()
 assert(status.automatic.state~='blocked',status.automatic.reason)
 if status.automatic.state=='active' then break end
 assert(i<40000,'automatic activation did not finish')
end
local active=flight.status()
assert(active.measuredHold and active.differentialReady and active.sweep.count==0,'reused model either repeated the sweep or skipped actual qualification')
for _,name in ipairs({'hover','down','up','rescue','priority','horizontal'}) do assert(active.autoCalibration.checks[name].passed,'missing fresh '..name) end
assert(files['/system/config/navigation-calibration.cfg'].structureFingerprint==fingerprint)
assert(#files['/system/config/navigation-calibration.cfg'].freshMotorChecks==4,'unchanged motors repeated all 60 probes')
assert(files['/system/config/navigation-calibration.cfg'].motorExperiments.historical and files['/system/config/navigation-calibration.cfg'].freshMotorExperiments,'reuse lost old observations or invented fresh six-axis proof')
local changedOptions=require('system.navigation.altitude_sweep').defaults() changedOptions.first=8
assert(not flight.activateAutomatic(actor,true,changedOptions),'active pilot silently accepted different calibration options')
assert(flight.status().measuredHold,'option refusal stopped an active pilot')
assert(flight.setFlightTargets(actor,{altitude=active.targets.altitude,speed=.2,heading=yaw}))
motorBlocked=true velocityX,velocityZ,yawVelocity=0,0,0
for i=1,800 do
 plantTick(i)
 local status=flight.status()
 assert(status.state=='armed' and status.measuredHold and not status.rescuePending,'horizontal stall cut verified vertical hold')
 if status.horizontalDiagnostic.issue then break end
 assert(i<800,'acknowledged motor stall never degraded horizontal control')
end
local jammed=flight.status()
assert(not jammed.differentialReady and not jammed.pilot and jammed.horizontalDiagnostic.noResponseSamples>=8,'stall evidence did not latch degraded authority')
assert(command>0 and motorSignals['minecraft:motor_left_clutch']==15 and motorSignals['minecraft:motor_right_clutch']==15,'stall failed to disengage motors while preserving heat')
assert(not flight.setFlightTargets(actor,{altitude=active.targets.altitude,speed=.2,heading=yaw}),'stalled motor model could be reused without revalidation')
motorBlocked=false
assert(flight.disarm(actor)) flight.step()
-- Explicit burner options are immutable, and a different range cannot reuse old data.
local selected=require('system.navigation.altitude_sweep').defaults() selected.first=8 selected.last=12
local invalid=addon.copy(selected) invalid.autoHold=false
assert(not flight.activateAutomatic(actor,true,invalid),'automatic activation ignored incompatible options')
sample() assert(flight.activateAutomatic(actor,true,selected))
selected.first=1 selected.last=3
bridge.acquireGeometry() flight.step()
local selectedStatus=flight.status()
assert(selectedStatus.automatic.options.first==8 and selectedStatus.automatic.options.last==12,'activation options changed after confirmation')
assert(not selectedStatus.automatic.reused,'saved model replaced selected burner range')
assert(selectedStatus.sweep.options.first==8 and selectedStatus.sweep.options.last==12,'selected burner levels not passed to sweep')
assert(flight.disarm(actor)) flight.step()
-- Changed structure triggers a fresh sweep, rather than trusting old evidence.
fingerprint=string.rep('b',64) sample()
assert(flight.activateAutomatic(actor,true)) bridge.acquireGeometry() flight.step()
assert(not flight.status().automatic.reused,'changed hull reused saved calibration')
assert(flight.disarm(actor)) flight.step() local cancelled=flight.status().automatic
assert(cancelled.state=='blocked')
for i=1,20 do plantTick(i) end
assert(not flight.status().measuredHold and flight.status().automatic.state=='blocked','STOP restarted automatic preparation')
-- Closing the window while a survey is pending is also cancellation.
assert(flight.disarm(actor)) sample() assert(flight.activateAutomatic(actor,true))
flight.release(actor.pid,'closed during survey') flight.step()
assert(flight.status().automatic.state=='blocked')
print('one-button activation: explicit confirmation/permission, restart revalidation without repeat sweep, real motor/route evidence, changed-structure fallback and STOP/close cancellation passed')

-- One burner and one propeller must still get real vertical calibration.
assert(flight.disarm(actor)) flight.step() assert(flight.disarm(actor))
raw.burners={raw.burners[1]}
raw.actuators={{id='single-propeller',position={x=0,y=0,z=2},direction={x=0,y=0,z=1},active=false,thrust=0}}
local singleConfig=flight.configuration()
singleConfig.drivetrain=nil singleConfig.balloonSetup.burnerIds={'heater1'}
singleConfig.mode='full'
singleConfig.channels[2]=addon.copy(singleConfig.channels[1]) singleConfig.channels[2].id='legacy-duplicate'
assert(flight.configure(actor,singleConfig)) sample()
assert(flight.activateAutomatic(actor,true)) bridge.acquireGeometry() flight.step()
assert(flight.configuration().mode=='altitude' and #flight.configuration().channels==1,'single collective channel not repaired')
for i=1,40000 do
 plantTick(i)
 local status=flight.status()
 assert(status.automatic.state~='blocked',status.automatic.reason..' at '..i..' z='..z..' v='..v..' cmd='..command)
 if status.automatic.state=='active' then break end
 assert(i<40000,'single burner altitude calibration did not finish')
end
local single=flight.status()
assert(single.measuredHold and not single.differentialReady and not flight.configuration().drivetrain,'single motor invented independent steering')
assert(single.autoCalibration.checks.hover.passed and single.autoCalibration.checks.rescue.passed)
assert(single.automatic.reason:find('one propeller',1,true),'partial authority not explained')
assert(flight.disarm(actor)) flight.step()
print('single burner + one motor: duplicate legacy collective channels repaired, complete real vertical calibration/hold, no invented steering and STOP passed')

-- A new second burner has its own Link frequency. Activation groups both,
-- verifies every heater, then applies the same fractional heat to both outputs.
assert(flight.disarm(actor)) sample()
separateBurners=true secondBurnerCommand=0
raw.burners[2]={id='heater2',position={x=4,y=0,z=0},signal=0,gasOutput=0,hasBalloon=false,associationSource='heater_membership',associationState='no_balloon_reference'}
raw.links={
 {id='heater-rx1',receiver=true,position={x=1,y=1,z=0},first={item='minecraft:white_wool'},second={item='minecraft:white_wool'},signal=0},
 {id='heater-rx2',receiver=true,position={x=4,y=1,z=0},first={item='minecraft:second_burner'},second={item='minecraft:second_burner'},signal=0}}
sample() assert(flight.activateAutomatic(actor,true)) bridge.acquireGeometry() flight.step()
local grouped=flight.configuration()
assert(#grouped.channels==1 and #grouped.channels[1].link.members==1 and #grouped.balloonSetup.burnerIds==2,'automatic activation did not include both burner frequency groups')
for i=1,40000 do
 plantTick(i)
 local status=flight.status()
 assert(status.automatic.state~='blocked',status.automatic.reason)
 if status.automatic.state=='active' then break end
 assert(i<40000,'grouped burner hold did not finish')
end
assert(flight.status().measuredHold and command==secondBurnerCommand and command>0)
assert(#flight.status().automatic.groups.burners==2)
assert(flight.disarm(actor)) flight.step()
assert(command==0 and secondBurnerCommand==0,'STOP did not rescue every burner frequency')
print('multi-frequency burner service: automatic grouping includes added burner, real all-heater initialization, stable measurement/hold, collective fractional output and STOP on both frequencies passed')

-- A custom channel beginning with drive- is still a configured output, not
-- an internal gear/reverser role: its actual rescue must not be skipped.
assert(flight.disarm(actor))
local labelled=flight.configuration() labelled.channels[1].id='drive-custom-lift' labelled.altitudeModel=nil
assert(flight.configure(actor,labelled))
assert(flight.testOutput(actor,'drive-custom-lift',7,true,2)) flight.step()
assert(command==7 and secondBurnerCommand==7)
assert(flight.disarm(actor)) flight.step()
assert(command==0 and secondBurnerCommand==0,'STOP classified a user channel by its name instead of actual motor membership')
local savedReport=files['/system/config/navigation-calibration.cfg']
assert(loadfile('tests/storage-fixture.lua'))()()
local motorBytes=#textutils.serialize(motorReport,{compact=true})
assert(motorBytes<38000,'deduplicated motor report exceeds 1 MB transaction budget')
assert(require('system.navigation.automatic_setup').motorCandidate(motorReport),'summary report lost reconstructible raw motor data')
print('compact motor calibration report upper-bound encoding: '..motorBytes..' bytes')
local compactReport=textutils.serialize(savedReport,{compact=true})
assert(#compactReport<65536,'real calibration report exceeds persistence budget')
print('compact persisted calibration report upper-bound encoding: '..#compactReport..' bytes')
