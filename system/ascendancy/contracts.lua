-- Real-data interchange contracts, not an autopilot or a source simulator.
local M={schema=1,maxPayloadBytes=262144,maxMapBytes=65536}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function label(v,limit) return type(v)=='string' and #v>0 and #v<=(limit or 256) and not v:find('%c') end
local computer=os.getComputerID and os.getComputerID() or 'unknown-computer'
local hasEpoch,epoch=pcall(function() return os.epoch and os.epoch('utc') end)
local clockId=tostring(computer)..':'..tostring(hasEpoch and epoch or 'unknown-epoch')..':'..tostring({})
function M.clockId() return clockId end
function M.clone(value)
 local count,bytes,seen=0,0,{}
 local function copy(v,depth)
  local kind=type(v)
  if kind=='number' then assert(finite(v),'Nonfinite payload number') return v end
  if kind=='string' then bytes=bytes+#v assert(bytes<=M.maxPayloadBytes,'Payload text budget exceeded') return v end
  if kind=='nil' or kind=='boolean' then return v end
  assert(kind=='table' and depth<=12 and not getmetatable(v),'Unsupported payload value')
  assert(not seen[v],'Cyclic payload') seen[v]=true
  local out={}
  for k,item in pairs(v) do
   count=count+1 assert(count<=32768,'Payload item budget exceeded')
   assert(type(k)=='string' or type(k)=='number' and finite(k),'Unsupported payload key')
   if type(k)=='string' then bytes=bytes+#k assert(bytes<=M.maxPayloadBytes,'Payload key budget exceeded') end
   out[k]=copy(item,depth+1)
  end
  seen[v]=nil return out
 end
 local ok,result=pcall(copy,value,0)
 if ok then return result end
 return nil,tostring(result)
end
function M.fresh(record,now)
 if now==nil then now=os.clock() end
 return type(record)=='table' and record.clock=='local_uptime' and record.clockId==clockId
   and finite(now) and finite(record.observedAt) and finite(record.validUntil)
   and record.observedAt>=0 and record.observedAt<=now and record.validUntil>=record.observedAt and now<=record.validUntil
end
function M.validateObservation(o,now,archive)
 if type(o)~='table' or getmetatable(o)~=nil or o.schema~=1 or o.valid~=true or o.synthetic==true then return false,'Unsupported/non-real observation' end
 if not label(o.source) or not label(o.entityId) or not label(o.field) or not label(o.clockId) or o.clock~='local_uptime'
   or not finite(o.observedAt) or o.observedAt<0 or not finite(o.validUntil) or o.validUntil<o.observedAt then return false,'Observation provenance/clock missing' end
 if o.origin~='observed' and o.origin~='derived' then return false,'Observation origin must be explicit' end
 if o.origin=='derived' and (type(o.parents)~='table' or #o.parents<1) then return false,'Derived observation needs parent provenance' end
 if not archive and not M.fresh(o,now) then return false,'Observation stale, future or different boot clock' end
 if o.kind=='position' then
  if (o.frame~='world' and o.frame~='body_plot') or o.unit~='block' or type(o.value)~='table'
    or getmetatable(o.value)~=nil or not finite(o.value.x) or not finite(o.value.y) or not finite(o.value.z) then return false,'Known position/frame/unit required' end
 elseif o.kind=='scalar' then
  if not finite(o.value) or not label(o.unit,32) then return false,'Scalar value/unit required' end
 elseif o.kind=='status' then
  if type(o.value)~='boolean' and not label(o.value) then return false,'Status value missing' end
 else return false,'Unsupported observation kind' end
 if o.frame=='body_plot' and not label(o.vehicleId,128) then return false,'Body plot needs vessel identity' end
 return true
end
function M.compatible(a,b,now)
 local ok,err=M.validateObservation(a,now) if not ok then return false,err end
 ok,err=M.validateObservation(b,now) if not ok then return false,err end
 if not label(a.namespace) or a.namespace~=b.namespace then return false,'World/dimension namespace unknown or different' end
 if not a.frame or a.frame=='unknown' or a.frame~=b.frame or a.unit~=b.unit or a.entityId~=b.entityId or a.field~=b.field or a.kind~=b.kind then return false,'Incompatible frame/unit/entity/field' end
 if a.frame=='body_plot' and a.vehicleId~=b.vehicleId then return false,'Different body plot identities' end
 return true
end
function M.validateMap(map)
 if type(map)~='table' or getmetatable(map)~=nil or map.schema~=1 or map.type~='atlas-map' or not label(map.namespace) or map.frame~='world' or map.unit~='block'
   or type(map.entries)~='table' or getmetatable(map.entries)~=nil or #map.entries>1024 then return false,'Invalid persistent map schema/frame/namespace' end
 local count=0
 for k,o in pairs(map.entries) do
  count=count+1
  if type(k)~='number' or k%1~=0 or k<1 or k>#map.entries then return false,'Invalid map entry sequence' end
  local ok,err=M.validateObservation(o,nil,true) if not ok then return false,err end
  if o.kind~='position' or o.frame~='world' or o.unit~='block' or o.namespace~=map.namespace then return false,'Map entry namespace/frame mismatch' end
 end
 if count~=#map.entries then return false,'Incomplete map sequence' end
 return true
end
function M.encodeMap(map)
 local ok,err=M.validateMap(map) if not ok then return nil,err end
 local copy,problem=M.clone(map) if not copy then return nil,problem end
 local success,text=pcall(textutils.serialize,copy)
 if not success or type(text)~='string' or #text>M.maxMapBytes then return nil,'Map serialization/size refused' end
 return text
end
function M.decodeMap(text)
 if type(text)~='string' or #text>M.maxMapBytes then return nil,'Map input size refused' end
 local ok,map=pcall(textutils.unserialize,text)
 if not ok then return nil,'Map decoding failed' end
 local valid,err=M.validateMap(map) if not valid then return nil,err end
 return M.clone(map)
end
function M.validateMission(mission)
 local copy,problem=M.clone(mission) if not copy then return false,problem end
 mission=copy
 if type(mission)~='table' or mission.schema~=1 or mission.type~='waypoint-mission' or mission.frame~='world' or mission.unit~='block'
   or not label(mission.namespace) or not label(mission.vehicleId,128) or type(mission.route)~='table'
   or mission.route.verifiedVehicleId~=mission.vehicleId then return false,'Mission namespace/frame/vessel binding required' end
 -- Validation only: the existing flight service owns all authorization/arming.
 return require('system.navigation.autopilot').validate(mission.route)
end
function M.statusFor(envelope,now)
 if now==nil then now=os.clock() end
 if type(envelope)~='table' or envelope.schema~=1 then return {state='unavailable',reason='Unsupported source envelope'} end
 local live=envelope.available==true and M.fresh(envelope,now)
 local result={source=envelope.source,state=live and 'ready' or 'unavailable',reason=live and (envelope.status or 'Fresh source cache') or envelope.reason or 'Source stale or clock unknown',frame=envelope.frame,namespace=envelope.namespace}
 if envelope.clockId==clockId and finite(envelope.observedAt) and finite(now) and now>=envelope.observedAt then result.age=now-envelope.observedAt end
 return result
end
return M
