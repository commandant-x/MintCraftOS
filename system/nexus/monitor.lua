local M={}
M.defaults={enabled=true,offlineSeconds=15,staleSeconds=60,energyLowPercent=10,diskLowPercent=5,inventoryHighPercent=90}
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<1e15 end
function M.rules(value)
  if type(value)~='table' or type(value.enabled)~='boolean' then return nil,'Invalid monitoring configuration' end
  local result={enabled=value.enabled}
  for key,range in pairs({offlineSeconds={5,120},staleSeconds={10,300},energyLowPercent={0,100},diskLowPercent={0,100},inventoryHighPercent={1,100}}) do
    local n=value[key]
    if not finite(n) or n<range[1] or n>range[2] then return nil,'Invalid threshold: '..key end
    result[key]=n
  end
  return result
end
function M.fresh(asset,rows,now,utc,rules)
  if asset.lastError then return false end
  local row=rows[asset.sampleOwner or asset.owner]
  if not row or not row.seenAt or now-row.seenAt>15 or not finite(asset.receivedAt) then return false end
  local stamp=asset.receivedAt
  if asset.result and finite(asset.result.measuredAt) then stamp=math.min(stamp,asset.result.measuredAt/1000) end
  return utc>=stamp-5 and utc-stamp<=rules.staleSeconds
end
function M.orphaned(job,rows,now)
  if job.type~='observe' then return false end
  local row=rows[job.node]
  if not row or not row.seenAt then return true end
  if now-row.seenAt>15 then return true end
  for _,device in ipairs(row.peripherals or {}) do
    if type(device)=='table' and device.name==job.endpoint and (device.kind=='inventory' or device.kind=='energy_storage' or device.kind=='fluid_storage') then return false end
  end
  return true
end
function M.evaluate(assets,rows,members,rules,previous,now,utc)
  local found={}
  if not rules.enabled then return found end
  local function add(key,kind,source,message)
    found[key]={kind=kind,source=source,message=message}
  end
  local function low(key,source,ratio,limit,label)
    if ratio<=limit or (previous[key] and ratio<math.min(100,limit+2)) then add(key,'warn',source,label..string.format(' %.1f%%',ratio)) end
  end
  for id,row in pairs(rows) do if members[tostring(id)] and row.seenAt then
    local source='Agent '..id
    if now-row.seenAt>rules.offlineSeconds then
      add('agent:'..id..':offline','error',source,'Agent heartbeat lost')
      if previous['agent:'..id..':disk'] then found['agent:'..id..':disk']=previous['agent:'..id..':disk'] end
    elseif finite(row.diskFree) and finite(row.diskCapacity) and row.diskCapacity>0 then
      low('agent:'..id..':disk',source,row.diskFree/row.diskCapacity*100,rules.diskLowPercent,'Internal disk free')
    elseif previous['agent:'..id..':disk'] then found['agent:'..id..':disk']=previous['agent:'..id..':disk']
    end
  end end
  for key,asset in pairs(assets) do if members[tostring(asset.owner)] then
    local source=tostring(asset.endpoint):sub(1,64)
    local prefix='asset:'..key..':'
    if asset.lastError then add(prefix..'fault','error',source,tostring(asset.lastError):sub(1,120)) end
    if not M.fresh(asset,rows,now,utc,rules) then
      if asset.result then add(prefix..'stale','warn',source,'Measurement unavailable or stale') end
      for _,condition in ipairs({'energy','full','fault'}) do if previous[prefix..condition] and not found[prefix..condition] then found[prefix..condition]=previous[prefix..condition] end end
    else
      local data=asset.result
      if data and data.ok==false then
        add(prefix..'fault','error',source,data.error or 'Measurement failed')
        for _,condition in ipairs({'energy','full'}) do if previous[prefix..condition] then found[prefix..condition]=previous[prefix..condition] end end
      elseif data and data.ok then
        if finite(data.energy) and finite(data.capacity) and data.capacity>0 then low(prefix..'energy',source,data.energy/data.capacity*100,rules.energyLowPercent,'Energy remaining')
        elseif previous[prefix..'energy'] then found[prefix..'energy']=previous[prefix..'energy'] end
        if not data.partial and finite(data.used) and finite(data.slots) and data.slots>0 then
          local ratio=data.used/data.slots*100
          if ratio>=rules.inventoryHighPercent or (previous[prefix..'full'] and ratio>math.max(0,rules.inventoryHighPercent-2)) then
            add(prefix..'full','warn',source,string.format('Occupied inventory slots %.1f%%',ratio))
          end
        elseif previous[prefix..'full'] then found[prefix..'full']=previous[prefix..'full']
        end
      end
    end
  end end
  for key,value in pairs(previous) do
    local id=tonumber(key:match('^agent:(%d+):'))
    if id and members[tostring(id)] and (not rows[id] or not rows[id].seenAt) then found[key]=value end
  end
  return found
end
return M
