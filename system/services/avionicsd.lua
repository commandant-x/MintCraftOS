local addon = require("system.libraries.addon")
local M = {}
local inventory, runner, revision, slow, slowAt = {}, nil, 0, {}, -math.huge
local lastAcquiredAt
local diagnosticRunner,diagnosticsPending,generation=nil,false,0
local cached = {ok=false,available=false,status="waiting for Avionics",devices={},counts={},measurements={},timestamp=0,revision=0}
local definitions = {
  altitude_sensor={role="altitude",fields={height="getHeight",airPressure="getAirPressure",verticalSpeed="getVerticalSpeed"}},
  gimbal_sensor={role="gimbal",fields={angles="getAngles",angularRates="getAngularRates",gravity="getGravity",linearAcceleration="getLinearAcceleration"}},
  navigation_table={role="nav",fields={heading="getHeading",orientation="getOrientation",hasTarget="hasTarget",targetBearing="getBearing",targetDistance="getDistanceToTarget",targetHeight="getVerticalOffsetToTarget"}},
  propeller_bearing={role="propeller",slow=true,fields={thrust="getThrust",active="isActive",rotationSpeed="getRotationSpeed",axis="getAxis",airflow="getAirflow",assembled="isAssembled",thrustVector="getThrustVector"}},
  propeller={role="propeller",slow=true,fields={thrust="getThrust",active="isActive",rotationSpeed="getRotationSpeed",axis="getAxis",airflow="getAirflow"}},
  throttle_lever={role="throttle",slow=true,fields={signal="getSignal"}},
  analog_transmission={role="analog",slow=true,fields={signal="getSignal",outputSpeed="getOutputSpeed",external="isExternallyControlled"}},
}
local function definition(row)
  for _, name in ipairs(row.types) do if definitions[name] then return definitions[name] end end
end
local required={altitude={height=true},gimbal={angles=true},nav={heading=true},propeller={thrust=true},throttle={signal=true},analog={signal=true}}
local function validField(field,value)
  if field=="angles" or field=="angularRates" then
    if type(value)~="table" then return false end
    for i=1,(field=="angles" and 2 or 3) do if not addon.finite(value[i]) then return false end end
    return true
  end
  if field=="gravity" or field=="linearAcceleration" or field=="thrustVector" then return addon.vec(value)~=nil end
  if field=="active" or field=="assembled" or field=="external" or field=="hasTarget" then return type(value)=="boolean" end
  if field=="orientation" then return type(value)=="table" end
  if field=="axis" then return type(value)=="string" end
  return addon.finite(value)
end
local flightFields={pitch={"gimbal","angles",1,"deg","body"},roll={"gimbal","angles",2,"deg","body"},
  altitude={"altitude","height",nil,"m","world"},heading={"nav","heading",nil,"deg","world"},
  pitchRate={"gimbal","angularRates",1,"deg/s","body"},rollRate={"gimbal","angularRates",3,"deg/s","body"},
  headingRate={"gimbal","angularRates",2,"deg/s","body"},altitudeRate={"altitude","verticalSpeed",nil,"m/s","world"},
  gravity={"gimbal","gravity",nil,"m/s2","body"},pressure={"altitude","airPressure",nil,"fraction","world"}}
local function normalized(snap,ids)
  local out={}
  for key,spec in pairs(flightFields) do
    local m={valid=false,error="sensor unavailable",frame=spec[5],unit=spec[4]}
    local rows=snap[spec[1]] or {}
    local requested=ids and ids[spec[1]]
    if requested=="" then requested=nil end
    if ids and not requested and #rows>1 then m.error="multiple sensors: select one in Sensors" end
    for _,entry in ipairs(rows) do
      if (requested and entry.name==requested) or (ids and not requested and #rows==1) or (not ids and entry.measurements and entry.measurements[spec[2]].valid) then
        m=addon.copy(entry.measurements[spec[2]])
        m.unit,m.frame=spec[4],spec[5]
        if spec[3] then
          local value=type(m.value)=="table" and m.value[spec[3]] or nil
          m.valid=addon.finite(value) m.value=value
          if m.valid then m.error=nil end
        end
        if m.valid and key=="gravity" then m.value=addon.vec(m.value) end
        m.valid=m.valid and os.clock()<=m.validUntil
        if not m.valid then m.value=nil end
        break
      end
    end
    out[key]=m
  end
  out.verticalSpeed=addon.copy(out.altitudeRate) out.yawRate=addon.copy(out.headingRate)
  return out
end
function M.flightTelemetry(sensorIds)
  local out={measurements=normalized(cached,sensorIds or {}),timestamp=math.huge,revision=cached.revision}
  for key in pairs(flightFields) do
    local m=out.measurements[key]
    if m.valid then out[key]=addon.copy(m.value) end
    if key~="gravity" and key~="pressure" and m.observedAt then out.timestamp=math.min(out.timestamp,m.observedAt) end
  end
  if out.timestamp==math.huge then out.timestamp=0 end
  return out
end
function M.acquire(rescan,diagnosticsOnly)
  if rescan and not diagnosticsOnly then inventory=addon.inventory(true) slow={} slowAt=-math.huge generation=generation+1 end
  local acquiredGeneration=generation
  local now=os.clock()
  local readSlow=now-slowAt>=1
  local snap={ok=true,available=false,status="Create Avionics peripherals missing",devices={},counts={},measurements={},errors={},timestamp=now,frame="world"}
  for _, name in ipairs({"altitude","gimbal","nav","propeller","throttle","analog"}) do snap[name]={} snap.counts[name]=0 end
  local branches,diagnosticBranches={},{}
  for _, row in ipairs(inventory) do
    local def=definition(row)
    if def then
      snap.available=true
      snap.counts[def.role]=snap.counts[def.role]+1
      snap.devices[#snap.devices+1]={name=row.name,types=addon.copy(row.types),methods=addon.copy(row.methods),roles={[def.role]=true}}
      local entry={name=row.name,types=addon.copy(row.types),data={},ok=false,timestamp=now}
      if def.slow and slow[row.name] then entry=addon.copy(slow[row.name]) end
      snap[def.role][#snap[def.role]+1]=entry
      local queue=def.slow and diagnosticBranches or branches
      if (diagnosticsOnly and def.slow) or (not diagnosticsOnly and not def.slow) then queue[#queue+1]=function()
        if def.slow and not readSlow and slow[row.name] then
          for key,value in pairs(addon.copy(slow[row.name])) do entry[key]=value end
        else
          local methods={}
          for _, method in pairs(def.fields) do methods[#methods+1]=method end
          local started=os.clock()
          local values,errors,timings=addon.read(row.device,methods,0.15,{priority=def.slow and "diagnostics" or "flight"})
          entry.measurements={} entry.errors={} entry.ok=true
          entry.timestamp=started
          for field,method in pairs(def.fields) do
            local present=type(row.device[method])=="function"
            local valid=validField(field,values[method]) and errors[method]==nil
            local err=errors[method] or (not present and "method unavailable" or "unexpected value type")
            local timing=timings and timings[method] or {}
            local observed=timing.startedAt or started
            local measure={valid=valid,source=row.name,method=method,timestamp=observed,observedAt=observed,receivedAt=timing.receivedAt or os.clock(),validUntil=observed+(def.slow and 1 or 0.5)}
            if valid then entry.data[field]=addon.copy(values[method]) measure.value=addon.copy(values[method]) else measure.error=err end
            if (field=="angles" or field=="angularRates") and type(values[method])=="table" and not errors[method] then
              measure.value=addon.copy(values[method])
            end
            entry.measurements[field]=measure
            local nullableAxis=field=="axis" and addon.hasType(row,"propeller_bearing") and values[method]==nil and not errors[method]
            measure.required=(required[def.role] or {})[field]==true
            measure.available=present and not nullableAxis
            if nullableAxis then measure.error="axis unavailable" end
            if not valid and not nullableAxis and (present or measure.required) then entry.errors[method]=err end
            if not valid and (required[def.role] or {})[field] then entry.ok=false end
          end
          if def.slow and generation==acquiredGeneration then slow[row.name]=addon.copy(entry) end
        end
      end
      end
    end
  end
  local function publish(partial)
    snap.errors={}
    for role in pairs(required) do
      for _,entry in ipairs(snap[role]) do
        for method,err in pairs(entry.errors or {}) do snap.errors[#snap.errors+1]=entry.name..":"..method..": "..err end
      end
    end
    snap.ok=#snap.errors==0
    snap.diagnosticsPending=partial
    if snap.available then snap.status=snap.ok and "Create Avionics peripherals ready" or "Avionics telemetry degraded" end
    snap.lastFault=snap.errors[1]
    snap.conventions={headingZero="+Z (south)",pitchAxis="body X",rollAxis="body Z"}
    snap.measurements=normalized(snap)
    revision=revision+1 snap.revision=revision
    cached=snap
  end
  if diagnosticsOnly then
    if readSlow and #diagnosticBranches>0 then
      diagnosticsPending=true
      addon.parallel(diagnosticBranches)
      if acquiredGeneration==generation then slowAt=now end
      diagnosticsPending=false
    end
    return
  end
  if #branches>0 then addon.parallel(branches) end
  publish(diagnosticsPending)
  lastAcquiredAt=os.clock()
end
function M.acquireDiagnostics() return M.acquire(false,true) end
function M.snapshot() return addon.copy(cached) end
function M.status() return {ok=cached.ok,available=cached.available,status=cached.status,lastFault=cached.lastFault,counts=addon.copy(cached.counts),errors=addon.copy(cached.errors),timestamp=cached.timestamp,revision=cached.revision} end
function M.health()
  local health=M.status()
  local now=os.clock()
  health.readiness={}
  for role in pairs(required) do
    for _,entry in ipairs(cached[role] or {}) do health.readiness[entry.name]=addon.copy(entry.measurements) end
  end
  health.pid,health.lastSuccess=runner and runner.pid,runner and runner.lastSuccess
  health.lastSuccess=health.lastSuccess or lastAcquiredAt
  health.lastSuccessAge=health.lastSuccess and math.max(0,now-health.lastSuccess) or nil
  health.acquisitionStale=health.lastSuccessAge==nil or health.lastSuccessAge>0.5
  health.staleFast=false
  health.fastReadiness={}
  health.flightReady=true
  for role in pairs({gimbal=true,altitude=true,nav=true}) do
    for _,entry in ipairs(cached[role] or {}) do
      local measurements=normalized(cached,{[role]=entry.name})
      local fields={}
      for key,spec in pairs(flightFields) do
        if spec[1]==role and key~="gravity" and key~="pressure" then
          local m=measurements[key]
          local raw=entry.measurements and entry.measurements[spec[2]] or {}
          local acquired=raw.valid==true
          if spec[3] then acquired=type(raw.value)=="table" and addon.finite(raw.value[spec[3]]) end
          local stale=m.validUntil~=nil and now>m.validUntil and (acquired or raw.required==true)
          fields[key]={valid=m.valid,stale=stale,observedAt=m.observedAt,validUntil=m.validUntil,error=m.error}
          health.staleFast=health.staleFast or stale
          health.flightReady=health.flightReady and m.valid
        end
      end
      health.fastReadiness[entry.name]=fields
    end
  end
  if not next(health.fastReadiness) then health.flightReady=false end
  health.degraded=not health.ok or health.staleFast or health.acquisitionStale
  if health.degraded then
    health.ok=false
    health.status="Avionics telemetry degraded"
  end
  return health
end
function M.list() return addon.copy(cached.devices) end
function M.rescan() if runner then runner:rescan() end end
function M.probe(name)
  for _,row in ipairs(inventory) do
    if row.name==name then
      local def=definition(row)
      local methods={}
      for _,method in pairs(def and def.fields or {}) do methods[#methods+1]=method end
      local values,errors=addon.read(row.device,methods,0.15,{priority="diagnostics"})
      return {name=name,types=addon.copy(row.types),methods=addon.copy(row.methods),values=values,errors=errors}
    end
  end
  return nil,"unknown Avionics device"
end
function M.start(ctx)
  M.stop()
  lastAcquiredAt=nil
  runner=addon.periodic(ctx,"avionicsd",0.1,M.acquire)
  runner.onError=function(err)
    revision=revision+1
    cached.ok=false cached.errors={err} cached.lastFault=err
    cached.status="Avionics acquisition failed" cached.revision=revision
  end
  if runner.error then runner.onError(runner.error) end
  diagnosticRunner=addon.periodic(ctx,"avionicsd-diagnostics",1,M.acquireDiagnostics)
  diagnosticRunner.onError=function() diagnosticsPending=false end
end
function M.stop()
  if runner then runner:stop() runner=nil end
  if diagnosticRunner then diagnosticRunner:stop() diagnosticRunner=nil end
  diagnosticsPending=false generation=generation+1
end
return M
