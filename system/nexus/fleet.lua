local tasks=require('system.nexus.tasks')
local M={}
local sides={left=true,right=true,front=true,back=true,top=true,bottom=true}
function M.plan(rows,members,jobs,policy,assets,now,utc)
  if not policy or not policy.enabled then return end
  local candidates,pending,loads,assigned={},{},{},{}
  for _,asset in pairs(assets) do if asset.owner then assigned[asset.owner]=(assigned[asset.owner] or 0)+1 end end
  for _,job in ipairs(jobs) do if job.state=='queued' or job.state=='sent' then
    loads[job.node]=(loads[job.node] or 0)+1
    if job.asset then pending[job.asset]=true end
  end end
  local count=0 for _ in pairs(assets) do count=count+1 end
  for _,id in ipairs(policy.ids or {}) do
    local row=rows[id] local member=members[tostring(id)]
    if row and member and member.group==policy.group and row.seenAt and now-row.seenAt<=15 and tasks.capable(row,'observe') and (loads[id] or 0)<2 then
      local score=(loads[id] or 0)*129+(assigned[id] or 0)
      for index,device in ipairs(row.peripherals or {}) do
        if index>24 then break end
        if type(device)=='table' and type(device.name)=='string' and #device.name<=64
          and (device.kind=='inventory' or device.kind=='energy_storage' or device.kind=='fluid_storage') then
          local key=(sides[device.name] and tostring(id)..':' or 'net:')..device.name
          local asset=assets[key]
          local previous=candidates[key]
          if not pending[key] and (asset or count<128) and (not asset or utc-(asset.attemptAt or 0)>=30)
            and (not previous or score<previous.load or (score==previous.load and id<previous.node)) then
            candidates[key]={asset=key,node=id,endpoint=device.name,kind=device.kind,load=score,at=asset and asset.attemptAt or 0}
          end
        end
      end
    end
  end
  local chosen
  for _,candidate in pairs(candidates) do
    if not chosen or candidate.at<chosen.at or (candidate.at==chosen.at and candidate.asset<chosen.asset) then chosen=candidate end
  end
  return chosen
end
return M
