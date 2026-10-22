-- Physical membership follows receiver frequencies and actual kinetic sources.
-- Software left/right banks are separately flight-tested, never wiring claims.
local A=require('system.libraries.addon')
local Link=require('system.navigation.link_output')
local M={}
local roles={'clutch','gear','reverse'}
local function receiver(snapshot,position)
 local specs,ids={},{}
 for _,r in ipairs(snapshot.links or {}) do local p=r.position
  if r.receiver and math.abs(math.abs(p.x-position.x)+math.abs(p.y-position.y)+math.abs(p.z-position.z)-1)<.01 then
   specs[#specs+1]={first=r.first.item,second=r.second.item,firstColor=r.first.dyedColor,secondColor=r.second.dyedColor}
   ids[#ids+1]=r.id
  end
 end
 local spec=Link.combine(specs)
 if not spec or spec.members then return nil,'No unique adjacent receiver frequency' end
 return spec,ids
end
function M.discover(snapshot)
 local out={burners={},motors={},unmappedMotors={},burnerIds={}}
 if not snapshot.ok or snapshot.inventoryComplete~=true then out.burnerError='Fresh complete inventory required' return out end
 local index={}
 for _,b in ipairs(snapshot.burners or {}) do
  local spec,ids=receiver(snapshot,b.position)
  if not spec then out.burnerError='Burner '..b.id..': '..ids else
   local key=Link.key({link=spec}) local g=index[key]
   if not g then g={id=key,link=spec,burnerIds={},receiverIds=ids} index[key]=g out.burners[#out.burners+1]=g end
   g.burnerIds[#g.burnerIds+1]=b.id
  end
  out.burnerIds[#out.burnerIds+1]=b.id
 end
 table.sort(out.burnerIds) table.sort(out.burners,function(a,b)return a.id<b.id end)
 local nodes={} for _,n in ipairs(snapshot.mechanics or {}) do nodes[n.id]=n end
 index={}
 for _,p in ipairs(snapshot.actuators or {}) do if p.geometryValid and math.abs(p.direction.y)<.25 then
  local id,seen,bindings,failed=p.id,{},{},nil
  for step=1,128 do
   if not id then break end
   if seen[id] then failed='Kinetic source cycle' break end seen[id]=true
   local n=nodes[id] if not n then failed='Missing kinetic source' break end
   if n.role and n.role~='other' then
    local spec,err=receiver(snapshot,n.position)
    if not spec then failed=err break end
    if bindings[n.role] and Link.key({link=bindings[n.role]})~=Link.key({link=spec}) then failed='Multiple independent '..n.role..' commands on one source chain' break end
    bindings[n.role]=spec
   end
   id=n.sourceId
   if step==128 and id then failed='Kinetic path limit' end
  end
  local keys={}
  for _,role in ipairs(roles) do local k=bindings[role] and Link.key({link=bindings[role]}) if not k then failed=failed or 'Incomplete clutch/transmission/reverser chain' end keys[#keys+1]=k or '?' end
  if failed then out.unmappedMotors[#out.unmappedMotors+1]={id=p.id,reason=failed}
  else
   local key=table.concat(keys,';') local g=index[key]
   if not g then g={id=key,roles=bindings,actuatorIds={},x=0} index[key]=g out.motors[#out.motors+1]=g end
   g.actuatorIds[#g.actuatorIds+1]=p.id g.x=g.x+p.position.x
  end
 end end
 for _,g in ipairs(out.motors) do g.x=g.x/#g.actuatorIds table.sort(g.actuatorIds) end
 table.sort(out.motors,function(a,b)return a.x==b.x and a.id<b.id or a.x<b.x end)
 return out
end
function M.burnerLink(groups)
 if groups.burnerError then return nil,groups.burnerError end
 local specs={} for _,g in ipairs(groups.burners) do specs[#specs+1]=g.link end
 return Link.combine(specs)
end
function M.drive(groups,name)
 if #groups.unmappedMotors>0 then return nil,'Some motor source chains are incomplete' end
 if #groups.motors<2 then return nil,'Fewer than two independent motor command groups' end
 local banks={left={},right={}}
 local cut=(groups.motors[1].x+groups.motors[#groups.motors].x)/2
 for i,g in ipairs(groups.motors) do
  local side=#groups.motors==2 and (i==1 and 'left' or 'right') or (g.x<cut and 'left' or 'right')
  banks[side][#banks[side]+1]=g
 end
 if #banks.left==0 or #banks.right==0 then return nil,'No distinct X banks; select motor roles once' end
 local d={enabled=true,name=name,clutchOff=15,left={},right={}}
 groups.banks={}
 for _,side in ipairs({'left','right'}) do
  local membership={side=side,actuatorIds={},commandGroups=#banks[side]}
  for _,g in ipairs(banks[side]) do for _,id in ipairs(g.actuatorIds) do membership.actuatorIds[#membership.actuatorIds+1]=id end end
  groups.banks[#groups.banks+1]=membership
  for _,role in ipairs(roles) do
   local specs={} for _,g in ipairs(banks[side]) do specs[#specs+1]=g.roles[role] end
   local combined,err=Link.combine(specs) if not combined then return nil,err end
   d[side][role]=combined
  end
 end
 return d
end
return M
