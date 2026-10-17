package.path="./?.lua;"..package.path
local now=10
os.clock=function() return now end
os.epoch=function() return 0 end
local events,timer={},0
os.queueEvent=function(name,...) events[#events+1]={name=name,args=table.pack(...)} end
os.startTimer=function() timer=timer+1 return timer end
os.cancelTimer=function() end
os.pullEvent=function(filter) return coroutine.yield(filter) end
parallel={waitForAll=function(...) for _,fn in ipairs({...}) do fn() end end}
local addon=require("system.libraries.addon")
addon.configure({readsPerTick=1000000})
addon.bounded=function(fn) return pcall(fn) end
addon.periodic=function() return {stop=function() end,rescan=function() end} end
package.loaded["system.libraries.log"]={warn=function() end,error=function() end}
package.loaded["system.security.permissions"]={require=function() return true end}
package.loaded["system.services.sabled"]={status=function() return {inSublevel=false} end}
package.loaded["system.services.radarnetd"]={snapshot=function() return {radars={},targets={}} end,configuration=function() return {} end,checkPerimeter=function() end}
local nav={measurements={}}
package.loaded["system.services.avionicsd"]={snapshot=function() return nav end}
local profile={frame="world",headingFrame="world",validated=true,gravity=11,muzzleVelocity=120,minPitch=-10,maxPitch=90,minYaw=0,maxYaw=360}
local settings={profiles={mount=profile},radars={}}
package.loaded["system.libraries.config"]={load=function() return addon.copy(settings) end}
package.loaded["system.libraries.safe_write"]={write=function() return true end}
textutils={serialize=function() return "config" end}
local reports={a={id="old",position={x=0,y=0,z=100},scannedTime=-999999},b=nil}
local calls,fireMode,yaw,pitch={},nil,0,0
local radarType="create_radar:radar_bearing"
local devices={}
for _,id in ipairs({"a","b"}) do
  local name=id
  devices[name]={getTracks=function() return reports[name] and {addon.copy(reports[name])} or {} end,
    getPosition=function() return {x=0,y=0,z=0} end,getRange=function() return 1000 end}
end
devices.mount={getInfo=function() return {assembled=true,x=0,y=0,z=0,yaw=yaw,pitch=pitch} end,
  setComputerControl=function() return true end,setTargetAngles=function(y,p) yaw,pitch=y,p return true end,
  fire=function(value)
    calls[#calls+1]=value
    if fireMode=="disconnect" or fireMode=="timeout" then error(fireMode) end
    if fireMode=="release-mismatch" and not value then return true end
    return value
  end}
peripheral={getNames=function() return {"a","b","mount"} end,
  getType=function(id) return id=="mount" and "cannon_mount" or radarType end,
  getMethods=function(id) local out={} for key in pairs(devices[id]) do out[#out+1]=key end return out end,
  wrap=function(id) return devices[id] end}
local scheduler=require("system.kernel.scheduler").new()
scheduler.processes[1]={pid=1,state="ready",meta={appId="combat"},permissions={},co=coroutine.create(function() coroutine.yield("never") end),filter="never"}
scheduler.nextPid=2
local combat=require("system.services.combatd")
local actor={pid=1}
local function acquire() combat.acquire(false) end
local function flush() while #events>0 do scheduler:dispatch(table.remove(events,1)) end end
local function start() combat.start({scheduler=scheduler}) combat.acquire(true) end
start()
assert(combat.snapshot().targets[1].stale and not combat.solution("mount","old"),"old first observation authorized")
now=14 acquire()
assert(not combat.solution("mount","old"),"duplicate scan proved freshness")
now=16 reports.a.scannedTime=-999998 acquire()
assert(not combat.solution("mount","old"),"progression outside bounded observation interval authorized")
now=16.2 reports.a.scannedTime=-999997 acquire()
assert(combat.solution("mount","old"),"bounded progression failed to authorize")
assert(combat.snapshot().targets[1].observations.a.verified)
reports.a.position.z=500 acquire()
assert(combat.snapshot().targets[1].position.z==100,"duplicate scan changed retained position")
reports.a.position.z=100
reports.a.scannedTime=-1000000 acquire()
assert(not combat.solution("mount","old"),"regressed source scan authorized")
reports.a.scannedTime=-999996 now=16.4 acquire()
assert(combat.solution("mount","old"))
assert(combat.stop()) start()
assert(not combat.solution("mount","old"),"restart reused verification")
now=16.6 reports.a.scannedTime=-999995 acquire()
assert(combat.solution("mount","old"))

-- The older radar cannot erase safety evidence, whichever source carries it.
for _,safe in ipairs({"a","b"}) do
  local other=safe=="a" and "b" or "a"
  reports[safe]={id="old",position={x=0,y=0,z=100},scannedTime=100,friendly=true,synthetic=true}
  reports[other]={id="old",position={x=0,y=0,z=200},scannedTime=1,friendly=false,synthetic=false}
  assert(combat.stop()) start()
  now=now+0.2 reports[safe].scannedTime=101 reports[other].scannedTime=2 acquire()
  local target=combat.snapshot().targets[1]
  assert(target.friendly and target.synthetic and not combat.solution("mount","old"),"conflicting classification cleared safety flag")
  assert(target.position.z==100 and target.radarId==safe and target.scannedTime==101,"older verified source replaced globally newer position")
  local retainedTimestamp=target.timestamp
  now=now+0.1 reports[other].scannedTime=3 acquire()
  target=combat.snapshot().targets[1]
  assert(target.position.z==100 and target.timestamp==retainedTimestamp,"older source refreshed retained target age")
  assert(target.observations[safe].scannedTime==101)
  reports[safe].friendly=false reports[safe].synthetic=false acquire()
  assert(combat.snapshot().targets[1].friendly,"duplicate scan removed friendly evidence")
  reports[safe].scannedTime=102 now=now+0.2 acquire()
  assert(combat.solution("mount","old"),"newer per-source classification could not clear flag")
end

reports.a.friendly=true reports.a.scannedTime=reports.a.scannedTime+1 now=now+0.2 acquire()
reports.a.friendly=false
now=now+6 reports.a.scannedTime=reports.a.scannedTime+1 reports.b.scannedTime=reports.b.scannedTime+1 acquire()
assert(combat.snapshot().targets[1].friendly,"late unverified scan removed friendly evidence")
now=now+0.2 reports.a.friendly=nil reports.a.scannedTime=reports.a.scannedTime+1 reports.b.scannedTime=reports.b.scannedTime+1 acquire()
assert(combat.snapshot().targets[1].friendly,"missing classification removed friendly evidence")
now=now+0.2 reports.a.friendly=false reports.a.scannedTime=reports.a.scannedTime+1 acquire()
assert(combat.solution("mount","old"))
local retained=addon.copy(reports.a)
reports.a=nil reports.b=nil now=now+11 acquire()
assert(#combat.snapshot().targets==0,"expired contact not evicted")
reports.a=retained acquire()
assert(not combat.solution("mount","old"),"evicted contact reused verification")
reports.a.scannedTime=reports.a.scannedTime+1 now=now+0.2 acquire()
assert(combat.solution("mount","old"))
reports.b=addon.copy(reports.a)

-- No 3D mount transform is implemented: require fresh level attitude.
assert(combat.stop()) profile.headingFrame="body" start()
now=now+0.2 reports.a.scannedTime=reports.a.scannedTime+1 reports.b.scannedTime=reports.b.scannedTime+1 acquire()
local function measure(value,stamp) return {value=value,valid=true,timestamp=stamp or now} end
nav.measurements={heading=measure(0)}
local _,why=combat.solution("mount","old") assert(why:find("attitude",1,true))
nav.measurements.pitch=measure(0) nav.measurements.roll=measure(10)
_,why=combat.solution("mount","old") assert(why:find("inclined",1,true))
nav.measurements.roll=measure(0) nav.measurements.pitch=measure(0,now-1)
assert(not combat.solution("mount","old"),"stale attitude authorized")
nav.measurements.pitch=measure(0)
assert(combat.solution("mount","old"),"level fresh attitude blocked")
nav.measurements.roll=measure(0/0) assert(not combat.solution("mount","old"))
nav.measurements.roll=measure(0) nav.measurements.roll.validUntil=now-0.1
assert(not combat.solution("mount","old"),"expired attitude authorized")
nav.measurements.roll=measure(0)

assert(combat.requestAim(actor,"mount","old")) flush()
local function fire()
  local token=assert(combat.prepareFire(actor,"mount","old"))
  assert(combat.requestFire(actor,"mount","old",token)) flush()
end
fire() scheduler:dispatch({name="timer",args={timer}}) flush()
assert(calls[#calls]==false and not combat.status().uncertain.mount,"CBC false release failed")
for _,mode in ipairs({"timeout","disconnect","release-mismatch"}) do
  fireMode=mode local before=#calls fire()
  if mode=="release-mismatch" then scheduler:dispatch({name="timer",args={timer}}) flush() end
  assert(combat.status().uncertain.mount,"output failure not latched")
  local starts=0 for i=before+1,#calls do if calls[i] then starts=starts+1 end end
  assert(starts==1,"fire retried after failure")
  assert(not combat.requestFire(actor,"mount","old",assert(combat.prepareFire(actor,"mount","old"))))
  assert(combat.acknowledge(actor,"mount",true))
end
fireMode=nil
assert(combat.stop())
local adapters=require("system.navigation.combat_adapters")
assert(adapters.fireResult(false,false) and not adapters.fireResult(true,false))
assert(adapters.fireResult(nil,false) and not adapters.fireResult(false,true))
local row={set={getTracks=true,getPosition=true,getScanGeometry=true}}
local stock=adapters.radar(row,"4.x")
local ea=adapters.radar(row,"5.0-EA")
local bridge=adapters.radar(row,"bridge")
assert(stock.methods[2]=="getPosition" and ea.profile=="5.0-EA" and bridge.methods[2]=="getScanGeometry")
assert(not table.concat(stock.methods,","):find("getScanGeometry",1,true),"explicit stock silently used bridge")
assert(adapters.radar({set={getTracks=true}},"auto").evidence:find("not detectable",1,true))
local bridgeReads=0
devices.a.getScanGeometry=function() bridgeReads=bridgeReads+1 error("not a native API") end
settings.radars.a={apiProfile="4.x"}
start()
local radar=combat.snapshot().radars[1]
assert(bridgeReads==0 and radar.apiProfile=="4.x" and not radar.autoGeometry)
local ok,message=combat.autoConfigureRadars(actor)
assert(not ok and message:find("stock 4.x/EA",1,true),"stock radar advertised full auto geometry")
assert(combat.stop()) settings.radars.a.apiProfile="bridge" start()
radar=combat.snapshot().radars[1]
assert(bridgeReads==1 and radar.readErrors.getScanGeometry and not radar.rawPosition,"failed bridge silently fell back to stock")
assert(combat.stop())
radarType="create_radar:plane_radar"
settings.radars.a={apiProfile="5.0-EA",frame="body"}
package.loaded["system.services.sabled"].status=function() return {inSublevel=true} end
package.loaded["system.services.sabled"].snapshot=function() error("EA world position transformed twice") end
start()
radar=combat.snapshot().radars[1]
assert(radar.apiProfile=="5.0-EA" and radar.position and radar.frame=="world","EA fixed-plane normalization unused")
assert(combat.stop())
package.loaded["system.services.sabled"].status=function() return {inSublevel=false} end
settings.radars.a={apiProfile="4.x"}
devices.a.getTracks=function() return {42,false,{id="valid",position={x=0,y=0,z=100},scannedTime=123}} end
start()
local validContact=false
for _,target in ipairs(combat.snapshot().targets) do if target.id=="valid" then validContact=true end end
assert(validContact and table.concat(combat.snapshot().errors,";"):find("malformed track",1,true),"malformed sibling record discarded healthy radar data")
assert(combat.stop())
devices.a.getTracks=function()
  local rows={} for i=1,600 do rows[i]={id="bounded"..i,position={x=i,y=0,z=100},scannedTime=i} end return rows
end
start()
assert(#combat.snapshot().targets<=128 and table.concat(combat.snapshot().errors,";"):find("capped at 512",1,true),"unbounded track response processed")
assert(combat.stop())
print("combat audit: old scans, bounded progression, regression, restart, flags, attitude, CBC state/error/no-retry and adapters passed")
