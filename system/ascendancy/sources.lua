-- Explicit, read-only cache collection. Never probes peripherals or starts work.
local contracts=require('system.ascendancy.contracts')
local M={}
local definitions={
 ['sable.pose']={module='system.services.sabled',method='pose',permission='sable.read',age=0.5,stamp='timestamp',ready=function(d,now)
  local pose=d.logicalPose
  local position=type(pose)=='table' and require('system.libraries.addon').vec(pose.position or pose.pos)
  return type(position)=='table' and d.frame=='world' and d.inSublevel==true and type(d.vehicleId)=='string' and #d.vehicleId>0 and #d.vehicleId<=128
    and type(d.identityAt)=='number' and d.identityAt==d.identityAt and d.identityAt>=0 and d.identityAt<=now and now-d.identityAt<=0.5
 end,units={position='block'}},
 ['avionics.flight']={module='system.services.avionicsd',method='flightTelemetry',permission='avionics.read',age=0.5,stamp='timestamp',ready=function(d,now)
  for _,m in pairs(d.measurements or {}) do if m.valid==true and type(m.validUntil)=='number' and now<=m.validUntil then return true end end return false
 end},
 ['vehicle.inventory']={module='system.services.vehiclebridged',method='snapshot',permission='sable.read',age=2,stamp='observedAt',ready=function(d) return d.available==true and d.ok==true end},
 ['combat.contacts']={module='system.services.combatd',method='snapshot',permission='combat.read',age=1,stamp='timestamp',ready=function(d) return d.available==true and d.ok==true end},
}
function M.list()
 local out={} for id,d in pairs(definitions) do out[#out+1]={id=id,permission=d.permission,method=d.method} end
 table.sort(out,function(a,b) return a.id<b.id end) return out
end
function M.read(actor,id,now)
 if now==nil then now=os.clock() end
 local validId=type(id)=='string' and #id>0 and #id<=128 and not id:find('%c')
 local envelope={schema=1,type='source-snapshot',source=validId and id or nil,available=false,clock='local_uptime',clockId=contracts.clockId(),collectedAt=now}
 if not validId then envelope.reason='Invalid source ID' return envelope end
 if type(now)~='number' or now~=now or math.abs(now)==math.huge or now<0 then envelope.collectedAt=nil envelope.reason='Invalid collection clock' return envelope end
 local def=definitions[id]
 if not def then envelope.reason='No real source adapter registered' return envelope end
 local checked,allowed,denied=pcall(function() return require('system.security.permissions').require(actor,def.permission,id) end)
 if not checked or allowed~=true then envelope.reason=checked and denied or 'Source authorization unavailable' return envelope end
 local ok,data=pcall(function() return require(def.module)[def.method]() end)
 if not ok or type(data)~='table' then envelope.reason='Source cache unavailable' return envelope end
 if data.synthetic==true then envelope.reason='Synthetic source cache refused' return envelope end
 local observed=data[def.stamp]
 if type(observed)~='number' or observed~=observed or math.abs(observed)==math.huge then envelope.reason='Source observation time unavailable' return envelope end
 envelope.observedAt=observed envelope.validUntil=observed+def.age
 if data.validUntil~=nil then
  if type(data.validUntil)~='number' or data.validUntil~=data.validUntil or math.abs(data.validUntil)==math.huge then envelope.reason='Invalid source validity window' return envelope end
  envelope.validUntil=math.min(envelope.validUntil,data.validUntil)
 end
 local function text(value,limit) if type(value)=='string' and #value<=limit then return value end end
 envelope.frame=text(data.frame,32) envelope.vehicleId=text(data.vehicleId,128) envelope.namespace=text(data.namespace or data.dimension,256)
 local units=data.units or def.units
 if units~=nil then envelope.units=contracts.clone(units) end
 if type(data.revision)=='number' and data.revision==data.revision and math.abs(data.revision)<math.huge then envelope.revision=data.revision end
 envelope.status=text(data.status,1024)
 local ready,live=pcall(def.ready,data,now)
 if not contracts.fresh(envelope,now) then envelope.reason='Source observation stale, future or different clock' return envelope end
 if not ready or not live then envelope.reason=envelope.status or 'Source not ready' return envelope end
 local copy,err=contracts.clone(data)
 if not copy then envelope.reason=err return envelope end
 envelope.payload=copy envelope.available=true return envelope
end
function M.collect(actor,ids,now)
 local out={schema=1,type='source-collection',sources={}}
 if ids==nil then ids={} for _,row in ipairs(M.list()) do ids[#ids+1]=row.id end end
 if type(ids)~='table' or #ids>16 then return nil,'At most 16 explicit source IDs' end
 local count=0
 for key in pairs(ids) do count=count+1 if type(key)~='number' or key%1~=0 or key<1 or key>#ids then return nil,'Invalid source sequence' end end
 if count~=#ids then return nil,'Incomplete source sequence' end
 for _,id in ipairs(ids) do
  if type(id)~='string' or #id>128 then return nil,'Invalid source ID' end
  if out.sources[id] then return nil,'Duplicate source ID' end
  out.sources[id]=M.read(actor,id,now)
 end
 return out
end
return M
