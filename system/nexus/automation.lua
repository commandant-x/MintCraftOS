local M={}
function M.plan(policy,rows,members,release,now)
  if type(policy)~="table" or policy.enabled~=true or type(policy.ids)~="table" or #policy.ids>64 then return nil end
  local complete=true
  for _,id in ipairs(policy.ids) do
    local member=members[tostring(id)]
    local row=rows[id]
    if not member or member.group~=policy.group then return {kind="blocked",message="Authorization changed; renew automatic deployment"} end
    local recovery=(policy.resets or {})[tostring(id)]
    local token=recovery and recovery.release==release and recovery.token or policy.resetToken
    local resetNeeded=token and (not row or row.provisionToken~=token)
    if not row or not row.seenAt or row.age>15 or row.release~=release or resetNeeded then
      complete=false
      local attempt=(policy.attempts or {})[tostring(id)] or {}
      if not (policy.holds or {})[tostring(id)] and row and row.name and (row.release~=release or resetNeeded) and policy.sealedRelease~=release then
        local phase=token and 'reset' or 'update'
        local count=attempt.release==release and (attempt.phase or 'update')==phase and (attempt.count or 0) or 0
        if count<2 and (not attempt.at or now-attempt.at>=60000) then return {kind="deploy",id=id,count=count+1,phase=phase} end
        if count>=2 and phase=='update' and policy.allowReset==true and row.updateFailure==true and now-attempt.at>=60000 then
          return {kind='reset',id=id}
        end
      end
    end
  end
  if complete and #policy.ids>0 and policy.sealedRelease~=release then return {kind="seal"} end
  return {kind="waiting",message=complete and "All scoped agents confirmed" or "Waiting for agents; exhausted retries require approval"}
end
return M
