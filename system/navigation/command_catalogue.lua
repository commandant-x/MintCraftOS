-- Cached-read-only catalogue. Configured mappings are not physical certificates.
local A=require('system.libraries.addon')
local Link=require('system.navigation.link_output')
local Drive=require('system.navigation.drivetrain')
local Contract=require('system.ascendancy.contracts')
local M={}
local function label(value) return type(value)=='string' and #value>0 and #value<=192 and not value:find('%c') end
function M.build(control,snapshot,endpoints,now)
 local sides={top=true,bottom=true,left=true,right=true,front=true,back=true}
 local setup=type(control.balloonSetup)=='table' and control.balloonSetup or {}
 local vehicle=type(control.vehicle)=='table' and control.vehicle or {}
 local out={schema=1,type='command-catalogue',clock='local_uptime',clockId=Contract.clockId(),source='flightd-config/vehicle-cache',frame='body_plot',
  observedAt=snapshot.observedAt or 0,validUntil=snapshot.validUntil or (snapshot.observedAt or 0)+2,collectedAt=now,
  vehicleId=snapshot.vehicleId,available=snapshot.ok==true and snapshot.inventoryComplete==true,commands={},equipment={},warnings={}}
 out.available=out.available and A.finite(now) and A.finite(out.validUntil) and A.finite(out.observedAt) and out.observedAt<=now and now<=out.validUntil and now-out.observedAt<=2 and snapshot.frame=='body_plot' and label(snapshot.vehicleId)
 local named={}
 for _,e in ipairs(endpoints or {}) do if label(e.backend) and label(e.name) then named[e.backend..':'..e.name]=true end end
 local bound=setup.vehicleId or vehicle.bridgeVehicleId
 if not label(bound) then bound=nil end
 local associated=bound~=nil and bound==snapshot.vehicleId
 out.budget={commands=38,equipment=64,frequencies=256,burnerIds=64}
 out.configuredBurners={vehicleId=bound,ids={},count=#(type(setup.burnerIds)=='table' and setup.burnerIds or {})}
 for i,id in ipairs(type(setup.burnerIds)=='table' and setup.burnerIds or {}) do
  if i>64 then out.configuredBurners.truncated=true out.truncated=true break end
  if label(id) then out.configuredBurners.ids[#out.configuredBurners.ids+1]=id end
 end
 out.frequencyCount=0 out.frequenciesPublished=0
 local seen,receivers,physical={},{},{}
 for _,r in ipairs(snapshot.links or {}) do
  if r.receiver and type(r.first)=='table' and type(r.second)=='table' then
   local key=Link.receiverKey(r)
   if key then receivers[key]=receivers[key] or {} receivers[key][#receivers[key]+1]=r end
  end
 end
 local function add(c,role)
  if #out.commands>=38 then out.truncated=true return end
  if type(c)~='table' or not label(c.id) or seen[c.id] then out.warnings[#out.warnings+1]='Invalid/duplicate configured command ID' return end
  seen[c.id]=true
  local actuator=type(c.actuator)=='table' and c.actuator or {}
  local mix=type(c.mix)=='table' and c.mix or {}
  local backend=c.backend local mapped=backend=='redstone' and sides[c.side]==true or named[tostring(backend)..':'..tostring(c.name)]==true
  if backend=='relay' and not sides[c.side] then mapped=false end
  local valuesValid=true
  for _,key in ipairs({'min','max','neutral','rescue'}) do if not A.finite(c[key]) or c[key]%1~=0 or c[key]<0 or c[key]>15 then valuesValid=false end end
  if valuesValid and (c.min>c.max or c.neutral<c.min or c.neutral>c.max or c.rescue<c.min or c.rescue>c.max) then valuesValid=false end
  local keys=backend=='frequency' and Link.keys(c) or nil
  if keys and #keys==0 then mapped=false end
  local row={id=c.id,backend=backend,endpoint=label(c.name) and c.name or nil,side=c.side,role=role or (label(actuator.role) and actuator.role or 'unknown'),
   configuredVehicleId=bound,association=associated and 'configured-scope' or 'unverified-or-different-vehicle',
   validationScope='mapping-only; current flightd authority required',source='operator-or-saved-mapping',min=valuesValid and c.min or nil,max=valuesValid and c.max or nil,
   neutral=valuesValid and c.neutral or nil,rescue=valuesValid and c.rescue or nil,frequencies=keys and {},frequencyCount=keys and #keys or 0,
   endpointAvailable=mapped,rangeValid=valuesValid,physicalDirectionChecked=c.validated==true,
   declaredMix={},independentAxes={},feedback={available=false,reason='No verified readback in this cache'}}
  for _,key in ipairs(keys or {}) do
   out.frequencyCount=out.frequencyCount+1
   if out.frequenciesPublished<256 then row.frequencies[#row.frequencies+1]=key out.frequenciesPublished=out.frequenciesPublished+1
   else row.frequenciesTruncated=true out.truncated=true end
  end
  for _,axis in ipairs({'pitch','roll','altitude','heading','routeForward','routeReverse','routeLeft','routeRight'}) do
   if A.finite(mix[axis]) then row.declaredMix[axis]=mix[axis] end
  end
  if role=='clutch' or role=='reverse' then row.values={0,15} end
  if role=='gear' or role=='reverse' then row.rescue=nil row.rescuePolicy='preserve-observed; clutch disengages' end
  if backend=='frequency' then
   local matches={}
   for _,key in ipairs(keys or {}) do
    if physical[key] then
     row.bindingAmbiguous=true physical[key].bindingAmbiguous=true
     physical[key].feedback={available=false,reason='Frequency shared by configured commands'}
    else physical[key]=row end
    for _,receiver in ipairs(receivers[key] or {}) do matches[#matches+1]=receiver end
   end
   if row.bindingAmbiguous then row.feedback.reason='Frequency shared by configured commands'
   elseif out.available and associated then
    local signal,why=Link.received(c,{links=matches})
    row.feedback={available=signal~=nil,signal=signal,observedAt=out.observedAt,validUntil=out.validUntil,source='Vehicle Bridge receiver cache',reason=why}
   end
  end
  if actuator.role=='buoyancy' then
   row.configuredBurnerGroup='configuredBurners'
  elseif role then row.responseContext='conditional-clutch-gear-reverser-chain; no independent axis claim' end
  if label(actuator.bridgeId) then row.configuredActuatorId=actuator.bridgeId end
  out.commands[#out.commands+1]=row
 end
 for i,c in ipairs(control.channels or {}) do if i>32 then out.truncated=true break end add(c) end
 for _,c in ipairs(Drive.channels(type(control.drivetrain)=='table' and control.drivetrain or nil)) do add(c,c.id:match('%-([a-z]+)$')) end
 local total=0
 for _,group in ipairs({{'burner',snapshot.burners},{'actuator',snapshot.actuators},{'mechanism',snapshot.mechanics}}) do
  for _,e in ipairs(group[2] or {}) do
   total=total+1
   if #out.equipment<64 then out.equipment[#out.equipment+1]={id=e.id,kind=group[1],block=e.block,role=e.role,
    position=A.vec(e.position),sourceId=e.sourceId,rpm=e.rpm,overstressed=e.overstressed,disengaged=e.disengaged,
    commandBinding='not-inferred-from-geometry'} else out.truncated=true end
  end
 end
 out.equipmentCount=total out.complete=out.available and not out.truncated
 out.warnings[#out.warnings+1]='Declared axes and geometry do not certify controllability; unmapped devices are never probed'
 return out
end
return M
