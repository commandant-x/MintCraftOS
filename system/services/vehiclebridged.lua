local addon=require("system.libraries.addon")
local M={}
local runner
local cached={available=false,ok=false,status="Vehicle bridge not installed",error="mintcraft_vehicle API missing",revision=0}
local serial=0
local function boundedVector(value)
  local v=addon.vec(value)
  if not v or math.max(math.abs(v.x),math.abs(v.y),math.abs(v.z))>1000000 then return nil end
  return v
end
function M.normalize(raw)
  if type(raw)~="table" or raw.schema~=1 or raw.readOnly~=true then return nil,"unsupported bridge schema" end
  if raw.ok~=true then return nil,tostring(raw.error or raw.code or "bridge read failed") end
  if raw.frame~="body_plot" or type(raw.vehicleId)~="string" or #raw.vehicleId>128 or raw.vehicleId=="" then return nil,"unknown vehicle frame/identity" end
  if type(raw.units)~="table" or raw.units.position~="block" then return nil,"unknown geometry units" end
  if not addon.finite(raw.revision) or not addon.finite(raw.ageTicks) or raw.ageTicks<0 then return nil,"missing bridge sample clock" end
  if type(raw.actuators)~="table" or #raw.actuators>256 or type(raw.links)~="table" or #raw.links>256 then return nil,"bridge inventory limit exceeded" end
  local out={available=true,ok=true,vehicleId=raw.vehicleId,name=tostring(raw.name or "Vehicle"):sub(1,128),
    frame=raw.frame,units=addon.copy(raw.units),sourceRevision=raw.revision,ageTicks=raw.ageTicks,
    complete=raw.complete==true,actuators={},links={},burners={},burnerDiscoveryAvailable=type(raw.features)=="table" and raw.features.burners==true,
    centerOfMass=boundedVector(raw.centerOfMass),mass=raw.mass,
    controlBindingsKnown=false}
  local seen={}
  if type(raw.inertia)=="table" and #raw.inertia==3 then
    local matrix,valid={},true
    for i=1,3 do
      matrix[i]={}
      for j=1,3 do
        local v=type(raw.inertia[i])=="table" and raw.inertia[i][j]
        if not addon.finite(v) then valid=false else matrix[i][j]=v end
      end
    end
    if valid then out.inertia=matrix end
  end
  for _,row in ipairs(raw.actuators) do
    if type(row)~="table" or type(row.id)~="string" or #row.id>192 or seen[row.id] then return nil,"invalid/duplicate actuator identity" end
    local position,direction=boundedVector(row.position),boundedVector(row.direction)
    if not position or not direction then return nil,"invalid actuator geometry" end
    local norm=math.sqrt(direction.x^2+direction.y^2+direction.z^2)
    local valid=norm>1e-8
    if not valid then out.complete=false end
    if valid then direction={x=direction.x/norm,y=direction.y/norm,z=direction.z/norm} end
    seen[row.id]=true
    out.actuators[#out.actuators+1]={id=row.id,block=tostring(row.block or "unknown"):sub(1,128),
      position=position,direction=direction,geometryValid=valid,active=row.active==true,
      thrust=addon.finite(row.thrust) and row.thrust or nil,suggestedRole=tostring(row.suggestedRole or "unknown"),
      controlBindingKnown=false}
  end
  for _,row in ipairs(raw.links) do
    if type(row)~="table" or type(row.id)~="string" or #row.id>192 then return nil,"invalid link" end
    local position=boundedVector(row.position)
    if not position then return nil,"invalid link position" end
    local function frequency(value)
      if type(value)~="table" or type(value.item)~="string" or #value.item>128 then return nil end
      return {item=value.item,dyedColor=addon.finite(value.dyedColor) and value.dyedColor or nil}
    end
    local first,second=frequency(row.first),frequency(row.second)
    if not first or not second then return nil,"invalid frequency" end
    out.links[#out.links+1]={id=row.id,position=position,receiver=row.receiver==true,first=first,second=second,
      signal=addon.finite(row.signal) and row.signal or nil,actuatorBindingKnown=false}
  end
  if out.burnerDiscoveryAvailable then
    if type(raw.burners)~="table" or #raw.burners>256 then return nil,"invalid burner inventory" end
    for _,row in ipairs(raw.burners) do
      if type(row)~="table" or type(row.id)~="string" or #row.id>192 or seen[row.id] then return nil,"invalid burner identity" end
      local position=boundedVector(row.position)
      if not position or not addon.finite(row.signal) or row.signal%1~=0 or row.signal<0 or row.signal>15 or not addon.finite(row.gasOutput) then return nil,"invalid burner measurement" end
      seen[row.id]=true
      out.burners[#out.burners+1]={id=row.id,position=position,signal=row.signal,gasOutput=row.gasOutput,
        hasBalloon=row.hasBalloon==true,balloonId=type(row.balloonId)=="string" and row.balloonId:sub(1,192) or nil,
        capacity=addon.finite(row.capacity) and row.capacity or nil,lift=addon.finite(row.lift) and row.lift or nil,
        associationSource=type(row.associationSource)=="string" and row.associationSource:sub(1,64) or "legacy_gas_validity",
        associationState=type(row.associationState)=="string" and row.associationState:sub(1,96) or nil,
        gasActive=row.gasActive==true}
    end
  end
  if not out.centerOfMass then out.complete=false end
  return out
end
function M.acquire()
  local api=rawget(_G,"mintcraft_vehicle")
  serial=serial+1
  if type(api)~="table" or type(api.snapshot)~="function" then
    cached={available=false,ok=false,status="Vehicle bridge not installed",error="mintcraft_vehicle API missing",revision=serial}
    return
  end
  local values,errors=addon.read(api,{"snapshot"},0.5,{priority="diagnostics"})
  local nextValue,err=M.normalize(values.snapshot)
  if not nextValue then
    cached={available=true,ok=false,status="Vehicle bridge unavailable",error=errors.snapshot or err,revision=serial}
    return
  end
  local unchanged=cached.vehicleId==nextValue.vehicleId and cached.sourceRevision==nextValue.sourceRevision
  nextValue.observedAt=unchanged and cached.observedAt or os.clock()-nextValue.ageTicks*0.05
  nextValue.validUntil=nextValue.observedAt+2
  nextValue.ok=os.clock()<=nextValue.validUntil
  nextValue.status=nextValue.ok and (nextValue.complete and "Vehicle geometry ready" or "Partial vehicle inventory") or "Vehicle geometry stale"
  nextValue.revision=serial cached=nextValue
end
function M.snapshot()
  local out=addon.copy(cached)
  if out.validUntil and os.clock()>out.validUntil then out.ok=false out.status="Vehicle geometry stale" end
  return out
end
function M.status()
  local s=M.snapshot()
  return {available=s.available,ok=s.ok,status=s.status,error=s.error,revision=s.revision,
    actuatorCount=#(s.actuators or {}),linkCount=#(s.links or {}),complete=s.complete}
end
function M.health() return M.status() end
function M.balloonStatus(setup)
  if not cached.ok or not cached.validUntil or os.clock()>cached.validUntil or not cached.complete then return false,"Balloon discovery stale/incomplete" end
  if not cached.burnerDiscoveryAvailable or cached.vehicleId~=setup.vehicleId then return false,"Balloon vehicle changed" end
  local found={}
  for _,burner in ipairs(cached.burners) do found[burner.id]=burner end
  if type(setup.burnerIds)~="table" or #setup.burnerIds==0 then return false,"Balloon burner group missing" end
  for _,id in ipairs(setup.burnerIds) do
    local burner=found[id]
    local label=id:match("^[^:]+:(.*)$") or id
    if not burner then return false,"Burner missing: "..label end
    if not burner.hasBalloon then
      if burner.associationSource=="legacy_gas_validity" then return false,"Update Vehicle Bridge to 0.2.1: old bridge confuses empty balloon with missing association" end
      return false,"Burner "..label..(burner.signal==0 and ": off; balloon association not confirmed (Initialize in Calibration)" or ": Aeronautics balloon association unavailable; check burner clearance/envelope")
    end
  end
  return true
end
function M.rescan() if runner then runner:rescan() end end
function M.start(ctx)
  M.stop()
  runner=addon.periodic(ctx,"vehiclebridged",1,M.acquire)
  runner.onError=function(err) cached.ok=false cached.error=tostring(err) cached.status="Vehicle bridge worker failed" end
end
function M.stop() if runner then runner:stop() runner=nil end end
return M
