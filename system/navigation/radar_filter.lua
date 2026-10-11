local M={}
M.categories={{id="players",label="Players"},{id="mobs",label="Mobs"},{id="vessels",label="Vessels"},{id="projectiles",label="Projectiles"},{id="other",label="Other"}}
function M.category(target)
  local category=tostring(target.category or ""):lower()
  if target.entityType=="minecraft:player" or category=="player" then return "players" end
  if category=="sable" or category=="ship" or category=="contraption" then return "vessels" end
  if category=="mob" or category=="hostile" or category=="animal" then return "mobs" end
  if category=="projectile" or category=="missile" then return "projectiles" end
  -- Legacy 'entity' does not tell us whether this is a mob or an item.
  return "other"
end
function M.visible(target,filters)
  return not filters or next(filters)==nil or filters[M.category(target)]==true
end
function M.toggle(filters,id)
  if id=="all" then for key in pairs(filters) do filters[key]=nil end
  else filters[id]=not filters[id] or nil end
end
function M.targets(rows,filters)
  local out={} for _,row in ipairs(rows or {}) do if M.visible(row,filters) then out[#out+1]=row end end
  return out
end
function M.select(current,id) if current==id then return nil end return id end
return M
