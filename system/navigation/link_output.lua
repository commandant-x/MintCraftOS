local addon=require("system.libraries.addon")
local M={}
local function item(value)
  return type(value)=="string" and #value<=128 and value:match("^[a-z0-9_.-]+:[a-z0-9_./-]+$")~=nil
end
function M.key(channel)
  local f=channel.link
  if type(f)~="table" or not item(f.first) or not item(f.second) then return nil end
  for _,color in ipairs({"firstColor","secondColor"}) do
    if f[color]~=nil and (not addon.finite(f[color]) or f[color]%1~=0 or f[color]<0 or f[color]>16777215) then return nil end
  end
  return "frequency:"..f.first.."@"..tostring(f.firstColor).."|"..f.second.."@"..tostring(f.secondColor)
end
function M.device(row)
  return row and addon.hasType(row,"redstone_link_bridge") and row.set and row.set.sendLinkSignal
end
function M.write(row,channel,value)
  local f=channel.link
  local returned,err=addon.call(row.device,"sendLinkSignal",f.first,f.second,value,f.firstColor,f.secondColor)
  if err then error(err) end
  return returned~=false,returned==false and "frequency transmitter refused" or nil
end
return M
