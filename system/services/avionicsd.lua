local addon = require("system.libraries.addon")
local M = {}
local inventory, runner, revision, slow, slowAt = {}, nil, 0, {}, -math.huge
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
function M.acquire(rescan)
  if rescan then inventory=addon.inventory() slow={} slowAt=-math.huge end
  local now=os.clock()
  local readSlow=now-slowAt>=1
  local snap={ok=true,available=false,status="Create Avionics peripherals missing",devices={},counts={},measurements={},errors={},timestamp=now,frame="world"}
  for _, name in ipairs({"altitude","gimbal","nav","propeller","throttle","analog"}) do snap[name]={} snap.counts[name]=0 end
  local branches={}
  for _, row in ipairs(inventory) do
    local def=definition(row)
    if def then
      snap.available=true
      snap.counts[def.role]=snap.counts[def.role]+1
      snap.devices[#snap.devices+1]={name=row.name,types=addon.copy(row.types),methods=addon.copy(row.methods),roles={[def.role]=true}}
      local entry={name=row.name,types=addon.copy(row.types),data={},ok=false,timestamp=now}
      snap[def.role][#snap[def.role]+1]=entry
      branches[#branches+1]=function()
        if def.slow and not readSlow and slow[row.name] then
          for key,value in pairs(addon.copy(slow[row.name])) do entry[key]=value end
        else
          local methods={}
          for _, method in pairs(def.fields) do methods[#methods+1]=method end
          local values,errors=addon.read(row.device,methods)
          for field,method in pairs(def.fields) do entry.data[field]=addon.copy(values[method]) end
          entry.errors=errors
          entry.ok=next(errors)==nil and next(entry.data)~=nil
          if def.slow then slow[row.name]=addon.copy(entry) end
        end
        for method,err in pairs(entry.errors or {}) do snap.errors[#snap.errors+1]=row.name..":"..method..": "..err end
      end
    end
  end
  if #branches>0 then parallel.waitForAll(table.unpack(branches)) end
  if readSlow then slowAt=now end
  snap.ok=#snap.errors==0
  if snap.available then snap.status=snap.ok and "Create Avionics peripherals ready" or "Avionics telemetry degraded" end
  snap.lastFault=snap.errors[1]
  local function healthy(rows)
    for _,entry in ipairs(rows) do if entry.ok then return entry.data,entry.timestamp end end
    return {},now
  end
  local a=healthy(snap.altitude)
  local g=healthy(snap.gimbal)
  local n=healthy(snap.nav)
  local angle,rate=g.angles or {},g.angularRates or {}
  local fields={altitude={a.height,"m","world"},verticalSpeed={a.verticalSpeed,"m/s","world"},pressure={a.airPressure,"fraction","world"},
    pitch={angle[1],"deg","body"},roll={angle[2],"deg","body"},pitchRate={rate[1],"deg/s","body"},yawRate={rate[2],"deg/s","body"},rollRate={rate[3],"deg/s","body"},heading={n.heading,"deg","world"},gravity={addon.vec(g.gravity),"m/s2","body"}}
  snap.conventions={headingZero="+Z (south)",pitchAxis="body X",rollAxis="body Z"}
  for key,field in pairs(fields) do snap.measurements[key]=addon.measure(field[1],field[2],field[3],"Avionics",now) end
  revision=revision+1 snap.revision=revision cached=snap
end
function M.snapshot() return addon.copy(cached) end
function M.status() return {ok=cached.ok,available=cached.available,status=cached.status,lastFault=cached.lastFault,counts=addon.copy(cached.counts),errors=addon.copy(cached.errors),timestamp=cached.timestamp,revision=cached.revision} end
function M.health()
  local health=M.status()
  health.pid,health.lastSuccess=runner and runner.pid,runner and runner.lastSuccess
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
      local values,errors=addon.read(row.device,methods)
      return {name=name,types=addon.copy(row.types),methods=addon.copy(row.methods),values=values,errors=errors}
    end
  end
  return nil,"unknown Avionics device"
end
function M.start(ctx)
  M.stop()
  runner=addon.periodic(ctx,"avionicsd",0.1,M.acquire)
  runner.onError=function(err)
    revision=revision+1
    cached.ok=false cached.errors={err} cached.lastFault=err
    cached.status="Avionics acquisition failed" cached.revision=revision
  end
  if runner.error then runner.onError(runner.error) end
end
function M.stop() if runner then runner:stop() runner=nil end end
return M
