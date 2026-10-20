-- Called only after NEXUS membership, HMAC and replay checks. Never an actuator.
local adapter=require('system.nexus.radar')
local M={}
local stations={}
local function copy(value)
  if type(value)~='table' then return value end
  local result={} for key,v in pairs(value) do result[key]=copy(v) end return result
end
local function short(value,max) return type(value)=='string' and #value>0 and #value<=max and not value:find('[%c]') and value or nil end
function M.clear() stations={} end
function M.restrict(members,group)
  for id,node in pairs(stations) do
    local member=members[tostring(id)]
    if not member or group and (type(member)~='table' or member.group~=group) then stations[id]=nil
    elseif group then for name,entry in pairs(node) do if entry.group~=group then node[name]=nil end end end
  end
end
function M.accept(id,body,now,utc)
  if type(body)~='table' or not short(body.name,64) or type(body.targets)~='table' or #body.targets>12
    or not adapter.finite(body.measuredAt) or body.measuredAt>utc+1 or utc-body.measuredAt>5 then return false end
  local node=stations[id]
  if not node then local count=0 for _ in pairs(stations) do count=count+1 end if count>=64 then return false end node={} stations[id]=node end
  local previous=node[body.name]
  if not previous then
    local count=0 for _,station in pairs(stations) do for _ in pairs(station) do count=count+1 end end
    if count>=128 then return false end
  end
  if previous and body.measuredAt<=previous.measuredAt then return false end
  local count=0 for _ in pairs(node) do count=count+1 end
  if not previous and count>=8 then return false end
  local observed=now-math.max(0,utc-body.measuredAt)
  local source='nexus:'..id..':'..body.name
  local radar={id=source,name='Agent '..id..' / '..body.name,remote=true,authenticated=true,station=id,frame='unknown',
    timestamp=observed,readErrors={},positionIssue='World geometry unavailable; source radar needs geometry API',
    range=adapter.finite(body.range) and body.range>0 and body.range or nil,
    rawTrackCount=adapter.finite(body.total) and math.max(0,math.floor(body.total)) or nil,partial=body.partial==true,
    positionSource='source API; operator deployment group (dimension not detected)'}
  if body.frame=='world' then radar.position=adapter.vector(body.position) radar.frame=radar.position and 'world' or 'unknown' end
  if radar.position then radar.positionIssue=nil end
  if adapter.finite(body.heading) then radar.heading=body.heading%360 end
  if adapter.finite(body.fov) and body.fov>0 and body.fov<=360 then radar.fov=body.fov radar.fovSource='source radar API' end
  if type(body.running)=='boolean' then radar.running=body.running end
  for _,method in ipairs({'getTracks','getScanGeometry','getPosition','getRange','getRotation','getDishCount'}) do
    if type(body.errors)=='table' and type(body.errors[method])=='string' then radar.readErrors[method]=body.errors[method]:sub(1,120) end
  end
  local entry={radar=radar,targets={},measuredAt=body.measuredAt,received=now,history={},group=body.group}
  for _,row in ipairs(body.targets) do
    local key=type(row)=='table' and short(row.id,100)
    local position=key and adapter.vector(row.position)
    if position then
      local old=previous and previous.history[key]
      local progressed=old and adapter.finite(row.scannedTime) and adapter.finite(old.scannedTime) and row.scannedTime>old.scannedTime
        and observed-old.received>=0 and observed-old.received<=5
      local same=old and adapter.finite(row.scannedTime) and row.scannedTime==old.scannedTime
      local verified=progressed or same and old.verified or false
      local time=same and old.timestamp or observed
      if same and old.position then position=copy(old.position) end
      local target={id=key,position=position,velocity=adapter.vector(row.velocity),renderName=short(row.name,64),category=short(row.category,24),
        entityType=short(row.entityType,64),radarId=source,station=id,remote=true,authenticated=true,frame='world',
        timestamp=time,freshnessKnown=verified,stale=not verified or now-time>5,
        friendly=row.friendly==true or old and old.friendly==true or nil,synthetic=row.synthetic==true or old and old.synthetic==true or nil}
      entry.targets[#entry.targets+1]=target
      local scannedTime=adapter.finite(row.scannedTime) and row.scannedTime or nil
      if old and adapter.finite(old.scannedTime) and (not scannedTime or scannedTime<old.scannedTime) then scannedTime=old.scannedTime end
      entry.history[key]={scannedTime=scannedTime,timestamp=time,received=observed,position=copy(position),verified=verified,friendly=target.friendly,synthetic=target.synthetic}
    end
  end
  node[body.name]=entry return true
end
function M.snapshot(now)
  local result={radars={},targets={}}
  local ids={} for id in pairs(stations) do ids[#ids+1]=id end table.sort(ids)
  for _,id in ipairs(ids) do
    local node=stations[id] local names={} for name in pairs(node) do names[#names+1]=name end table.sort(names)
    for _,name in ipairs(names) do
      local entry=node[name]
      if now-entry.received>10 then node[name]=nil
      else
        if #result.radars<128 then
          local radar=copy(entry.radar) radar.stale=now-radar.timestamp>5
          result.radars[#result.radars+1]=radar
          for _,row in ipairs(entry.targets) do if #result.targets<128 then
            local target=copy(row) target.stale=row.stale or now-row.timestamp>5
            result.targets[#result.targets+1]=target
          end end
        end
      end
    end
    if not next(node) then stations[id]=nil end
  end
  return result
end
return M
