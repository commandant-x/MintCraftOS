local M={}
M.allowed={ping=true,inventory=true,storage=true,sum=true,observe=true}
function M.capable(row,kind)
  if type(row.capabilities)~="table" then return false end
  for _,cap in ipairs(row.capabilities) do if cap==kind then return true end end
  return false
end
function M.targets(rows,members,jobs,group,kind,now,all)
  local candidates={}
  for id,row in pairs(rows) do
    local member=members[tostring(id)]
    if member and member.group==group and row.seenAt and now-row.seenAt<=15 and M.capable(row,kind) then
      local load=0
      for _,job in ipairs(jobs) do if job.node==id and (job.state=="queued" or job.state=="sent") then load=load+1 end end
      candidates[#candidates+1]={id=id,load=load}
    end
  end
  table.sort(candidates,function(a,b) return a.load==b.load and a.id<b.id or a.load<b.load end)
  local result={}
  for _,candidate in ipairs(candidates) do result[#result+1]=candidate.id if not all then break end end
  return result
end
function M.prune(jobs,limit)
  local kept,archived={},{}
  for _,job in ipairs(jobs) do
    if job.state=="queued" or job.state=="sent" then kept[#kept+1]=job else archived[#archived+1]=job end
  end
  local recent=math.max(0,limit-#kept)
  local first=math.max(1,#archived-recent+1)
  for i=first,#archived do kept[#kept+1]=archived[i] end
  local removed={} for i=1,first-1 do removed[#removed+1]=archived[i] end
  return kept,removed
end
return M
