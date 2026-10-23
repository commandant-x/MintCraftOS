-- Validate a selected-node sample without refreshing the full inventory's age.
local A=require('system.libraries.addon')
local M={}
function M.selection(snapshot,ids)
 if not snapshot or not snapshot.ok or type(ids)~='table' or #ids<1 or #ids>64 then return nil,'Selected feedback needs 1..64 known nodes' end
 local known={}
 for _,field in ipairs({'links','burners','mechanics','actuators'}) do for _,row in ipairs(snapshot[field] or {}) do known[row.id]=true end end
 local selected,seen={},{}
 for _,id in ipairs(ids) do
  if type(id)~='string' or #id>192 or not known[id] or seen[id] then return nil,'Unknown/duplicate selected feedback node' end
  seen[id]=true selected[#selected+1]=id
 end
 table.sort(selected) return selected
end
function M.normalize(raw,selection,vehicleId,normalize,started,finished,previous)
 if type(raw)~='table' or raw.schema~=1 or raw.ok~=true or raw.readOnly~=true or raw.scope~='selected-known-nodes-not-inventory' or raw.vehicleId~=vehicleId or
  raw.frame~='body_plot' or not A.finite(raw.revision) or not A.finite(raw.observedAtGameTick) or raw.revision~=raw.observedAtGameTick or
  raw.ageTicks~=0 or raw.requested~=#selection or type(raw.missing)~='table' or #raw.missing>64 or
  not A.finite(started) or not A.finite(finished) or finished<started or finished-started>.5 then return nil,'Invalid selected feedback identity/clock/scope' end
 local wanted={} for _,id in ipairs(selection) do wanted[id]=true end
 local seen={}
 for _,field in ipairs({'links','burners','mechanics','actuators'}) do
  if type(raw[field])~='table' or #raw[field]>64 then return nil,'Selected feedback row budget exceeded' end
  local unique={}
  for _,row in ipairs(raw[field]) do
   if type(row)~='table' or not wanted[row.id] or unique[row.id] then return nil,'Unexpected/duplicate selected feedback node' end
   unique[row.id]=true seen[row.id]=true
  end
 end
 for _,id in ipairs(raw.missing) do
  if not wanted[id] or seen[id] then return nil,'Invalid missing-node report' end seen[id]='missing'
 end
 for id in pairs(wanted) do if not seen[id] then return nil,'Selected feedback omitted an unreported node' end end
 local complete=#raw.missing==0
 if raw.selectionComplete~=complete then return nil,'Selected feedback completeness mismatch' end
 local candidate=A.copy(raw)
 candidate.complete=false candidate.centerOfMass=nil
 candidate.features={burners=true,mechanics=true}
 local value,why=normalize(candidate)
 if not value then return nil,why end
 if previous and previous.vehicleId==vehicleId and previous.sourceRevision and raw.revision<previous.sourceRevision then return nil,'Selected feedback clock regressed' end
 local same=previous and previous.vehicleId==vehicleId and previous.sourceRevision==raw.revision
 value.observedAt=same and previous.observedAt or started
 value.validUntil=value.observedAt+.5
 value.ok=complete and finished>=value.observedAt and finished<=value.validUntil
 value.selectionComplete=complete value.scope=raw.scope value.missing=A.copy(raw.missing)
 -- This is a selected read, never a complete geometry/mass observation.
 value.inventoryComplete=false value.complete=false value.centerOfMass=nil
 return value
end
return M
