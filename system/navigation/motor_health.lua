-- Read-only qualification from existing probes; never sends an exploratory signal.
local A=require('system.libraries.addon')
local Link=require('system.navigation.link_output')
local Contract=require('system.ascendancy.contracts')
local M={}
local function label(v) return type(v)=='string' and #v>0 and #v<=192 and not v:find('%c') end
local function signature(d)
 if type(d)~='table' or d.enabled~=true or not label(d.name) or (d.clutchOff~=0 and d.clutchOff~=15) then return end
 local parts={#d.name..':'..d.name,tostring(d.clutchOff)}
 for _,side in ipairs({'left','right'}) do for _,role in ipairs({'clutch','gear','reverse'}) do
  if type(d[side])~='table' then return end
  local ok,keys=pcall(Link.keys,{link=d[side][role]})
  if not ok or #keys<1 or #keys>16 then return end
  for _,key in ipairs(keys) do parts[#parts+1]=#key..':'..key end
  parts[#parts+1]=';'
 end end
 return table.concat(parts,'|')
end
local function index(snapshot)
 local nodes={}
 for i,n in ipairs(snapshot.mechanics or {}) do if i>1024 then return nodes,true end if label(n.id) then nodes[n.id]=n end end
 return nodes,false
end
local function path(nodes,id)
 local ids,seen={},{}
 for _=1,128 do
  if not label(id) or seen[id] or not nodes[id] then return ids,false end
  seen[id]=true ids[#ids+1]=id local nextId=nodes[id].sourceId
  if nextId==nil then return ids,true end id=nextId
 end
 return ids,false
end
local function pattern(d,values)
 if type(values)~='table' then return end
 local active,on={},{}
 for _,side in ipairs({'left','right'}) do
  local base='drive-'..side..'-' local clutch,gear,reverse=values[base..'clutch'],values[base..'gear'],values[base..'reverse']
  if (clutch~=0 and clutch~=15) or not A.finite(gear) or gear<0 or gear>15 or gear%1~=0 or (reverse~=0 and reverse~=15) then return end
  on[side]=clutch~=d.clutchOff active[side]=on[side] and gear>0
 end
 return on.left and (on.right and 'both' or 'left') or on.right and 'right' or 'off',active
end
local function qualified(record)
 local off,left,right=record.off,record.left,record.right
 if not off or not left or not right or off.n<2 or left.n<2 or right.n<2 or off.bits~=1 then return end
 if left.bits==2 and right.bits==1 then return 'left' end
 if left.bits==1 and right.bits==2 then return 'right' end
end
function M.new(vehicleId,d)
 local self={vehicleId=vehicleId,binding=signature(d),records={},paths={},order={},mapped={},faultCounts={},truncated=false,
  reason='Waiting for three acknowledged clutch patterns and physical source paths'}
 local function current(snapshot,control,values,after,ack,now)
  self.lastReadValid=false
  if self.invalid then return end
  if signature(control)~=self.binding or not self.binding then self.invalid=true self.reason='Motor bindings changed or unavailable; fresh qualification required' return end
  if type(snapshot)~='table' then return end
  if snapshot.vehicleId~=self.vehicleId or not label(self.vehicleId) or #self.vehicleId>128 then self.invalid=true self.reason='Vehicle identity changed; qualification invalidated' return end
  if type(snapshot.mechanics)~='table' or #snapshot.mechanics==0 or type(snapshot.actuators)~='table' or #snapshot.actuators==0 or snapshot.ok~=true or snapshot.inventoryComplete~=true or snapshot.frame~='body_plot' or not A.finite(now) or not A.finite(snapshot.observedAt) or snapshot.observedAt>now or now-snapshot.observedAt>2 or
   not A.finite(snapshot.validUntil) or snapshot.validUntil<now or ack~=true or not A.finite(after) or after<0 or snapshot.observedAt<=after+.05 then return end
  if self.latest and snapshot.observedAt<self.latest then self.invalid=true self.reason='Mechanical observation clock regressed' return end
  local p,active=pattern(control,values) if not p then return end
  self.lastReadValid=true self.latest=snapshot.observedAt self.validUntil=math.min(snapshot.validUntil,snapshot.observedAt+2)
  return p,active
 end
 local function rebuild()
  local sides={} for id,r in pairs(self.records) do sides[id]=qualified(r) end
  self.mapped={}
  for _,id in ipairs(self.order) do
   local candidate,ambiguous
   for _,side in ipairs({'left','right'}) do
    local ids=(self.paths[id] or {})[side]
    if ids then
     local clutches,other={},false
     for _,node in ipairs(ids) do if sides[node] then if sides[node]==side then clutches[#clutches+1]=node else other=true end end end
     if #clutches>0 and not other then
      if candidate then ambiguous=true else candidate={id=id,side=side,clutches=clutches} end
     end
    end
   end
   if candidate and not ambiguous then self.mapped[#self.mapped+1]=candidate end
  end
  self.clutchSides=sides
 end
 function self:learn(snapshot,control,values,after,ack,now)
  local p=current(snapshot,control,values,after,ack,now)
  if not p or p=='both' or self.lastLearn and snapshot.observedAt-self.lastLearn<.5 then return end self.lastLearn=snapshot.observedAt
  local nodes,truncated=index(snapshot) self.truncated=self.truncated or truncated
  local count=0 for _ in pairs(self.records) do count=count+1 end
  for i,n in ipairs(snapshot.mechanics or {}) do
   if i>1024 then self.truncated=true break end
   if n.block=='create:clutch' and n.role=='clutch' and type(n.disengaged)=='boolean' and label(n.id) then
    local record=self.records[n.id]
    if not record and count<64 then record={} self.records[n.id]=record count=count+1 end
    if record then
     local r=record[p] or {n=0,bits=0} record[p]=r
     r.n=math.min(4,r.n+1) local bit=n.disengaged and 1 or 2
     if r.bits~=bit then r.bits=r.bits==0 and bit or 3 end
    else self.truncated=true end
   end
  end
  if p~='off' then
   for i,a in ipairs(snapshot.actuators or {}) do
    if i>32 then self.truncated=true break end
    local root=nodes[a.id]
    if root and A.finite(root.rpm) and root.rpm~=0 and not root.overstressed then
     local ids,complete=path(nodes,a.id)
     local healthy=complete
     for _,id in ipairs(ids) do if nodes[id].overstressed then healthy=false end end
     if healthy then
      if not self.paths[a.id] and #self.order<32 then self.paths[a.id]={} self.order[#self.order+1]=a.id end
      if self.paths[a.id] then self.paths[a.id][p]=ids else self.truncated=true end
     end
    end
   end
  end
  rebuild()
  self.reason=#self.mapped>0 and 'Observed clutch/source subset qualified in this session; not complete bank coverage' or 'Insufficient or inconsistent physical clutch/source observations; motion guardian remains available'
 end
 function self:check(snapshot,control,values,after,ack,now,expected)
  if self.fault then return self.fault.reason end
  local _,active=current(snapshot,control,values,after,ack,now)
  if not active or self.lastCheck and snapshot.observedAt-self.lastCheck<.5 then return end
  if self.lastCheck and snapshot.observedAt-self.lastCheck>2 then self.faultCounts={} end self.lastCheck=snapshot.observedAt
  local nodes=index(snapshot)
  local strong=expected and A.finite(expected.forward) and A.finite(expected.yaw) and (math.abs(expected.forward)>=.02 or math.abs(expected.yaw)>=.5)
  for _,root in ipairs(self.mapped) do
   local kind
   if active[root.side] then
    local ids,complete=path(nodes,root.id) local seen={} for _,id in ipairs(ids) do seen[id]=true end
    if not complete then kind='source_feedback_lost' end
    for _,id in ipairs(root.clutches) do
     local n=nodes[id]
     if not n or not seen[id] or type(n.disengaged)~='boolean' then kind='source_feedback_lost' break end
     if n.disengaged then kind='clutch_disengaged' break end
    end
    if not kind then
     for _,id in ipairs(ids) do local n=nodes[id]
      if n.overstressed then kind='overstress' break end
      if A.finite(n.rpm) and A.finite(n.theoreticalRPM) and n.rpm==0 and n.theoreticalRPM~=0 then kind='rpm_incoherent' end
     end
    end
    if not kind and strong and nodes[root.id] and nodes[root.id].rpm==0 then kind='rotation_missing' end
   end
   local previous=self.faultCounts[root.id]
   local n=kind and previous and previous.kind==kind and previous.n+1 or kind and 1 or 0
   self.faultCounts[root.id]=kind and {kind=kind,n=math.min(8,n)} or nil
   if kind and n>=(kind=='rotation_missing' and 8 or 2) then
    self.fault={kind=kind,side=root.side,observedAt=snapshot.observedAt,reason='Qualified motor source '..root.side..': '..kind..'; horizontal response requires revalidation'}
    return self.fault.reason
   end
  end
 end
 function self:status(now)
  local banks={left={roots=0,clutches=0},right={roots=0,clutches=0}} local unique={left={},right={}}
  for _,root in ipairs(self.mapped) do banks[root.side].roots=banks[root.side].roots+1
   for _,id in ipairs(root.clutches) do if not unique[root.side][id] then unique[root.side][id]=true banks[root.side].clutches=banks[root.side].clutches+1 end end
  end
  local available=not self.invalid and self.lastReadValid==true and #self.mapped>0 and A.finite(now) and self.latest and now>=self.latest and self.validUntil and now<=self.validUntil
  return {schema=1,scope='observed-source-subset-not-axis-certificate',source='Vehicle Bridge physical clutch and kinetic source observations',
   clock='local_uptime',clockId=Contract.clockId(),available=available==true,observedAt=self.latest,validUntil=self.validUntil,
   banks=banks,truncated=self.truncated,reason=self.invalid and self.reason or self.fault and self.fault.reason or not available and 'Mechanical qualification unavailable or stale' or 'Current feedback from an observed source subset; not complete bank coverage',
   fault=A.copy(self.fault),qualifiedRoots=#self.mapped}
 end
 return self
end
return M
