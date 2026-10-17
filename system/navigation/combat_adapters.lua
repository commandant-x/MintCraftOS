local M={}
local stock={"getTracks","getPosition","getRange","getRotation","getRotationSpeed","getDishCount"}

function M.radar(row,profile,manual)
  profile=profile or "auto"
  local bridge=row.set.getScanGeometry==true
  local selected=profile=="auto" and (bridge and "bridge" or "4.x") or profile
  local methods={}
  if selected=="bridge" then
    methods={"getTracks","getScanGeometry"}
  else
    for _,method in ipairs(stock) do
      if not (manual and method=="getPosition") then methods[#methods+1]=method end
    end
  end
  return {profile=selected,methods=methods,
    evidence=bridge and "getScanGeometry advertised (optional bridge)" or "stock methods; version not detectable",
    origin=selected=="bridge" and "optional source-PC bridge; not native Radar" or "stock Radar API",
    limitation=selected=="bridge" and "requires valid geometry v1 response" or
      selected=="5.0-EA" and "EA selected explicitly; bearing getPosition may fail; fixed plane position is world" or
      "4.x compatibility profile; bearing getPosition may fail; manual setup required"}
end

-- CC:CBC 1.1.1 returns the resulting FIRE_POWERED state, not an ACK.
-- Nil is retained for older void-return adapters; errors are handled by caller.
function M.fireResult(value,requested)
  return value==nil or value==requested
end
return M
