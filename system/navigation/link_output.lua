local addon=require("system.libraries.addon")
local M={}
local function item(value)
  return type(value)=="string" and #value<=128 and value:match("^[a-z0-9_.-]+:[a-z0-9_./-]+$")~=nil
end
local function key(f)
 if type(f)~='table' or not item(f.first) or not item(f.second) then return end
 for _,c in ipairs({'firstColor','secondColor'}) do if f[c]~=nil and (not addon.finite(f[c]) or f[c]%1~=0 or f[c]<0 or f[c]>16777215) then return end end
 return 'frequency:'..f.first..'@'..tostring(f.firstColor)..'|'..f.second..'@'..tostring(f.secondColor)
end
function M.specs(channel)
 local f=channel.link
 if not key(f) or f.members~=nil and (type(f.members)~='table' or #f.members>15) then return end
 local out,seen={f},{[key(f)]=true}
 for i=1,#(f.members or {}) do
  local s=f.members[i] local k=key(s) if not k or s.members~=nil or seen[k] then return end seen[k]=true out[#out+1]=s
 end
 return out
end
function M.keys(channel)
 local out={}
 for _,f in ipairs(M.specs(channel) or {}) do out[#out+1]=key(f) end
 table.sort(out) return out
end
function M.key(channel)
 if not M.specs(channel) then return end
 local keys=M.keys(channel)
 return #keys==1 and keys[1] or ('group:'..table.concat(keys,';'))
end
function M.combine(specs)
 local map,keys={},{}
 for _,f in ipairs(specs) do
  local k=key(f) if not k or f.members then return nil,'Invalid group member' end
  if not map[k] then map[k]=f keys[#keys+1]=k end
 end
 table.sort(keys)
 if #keys==0 or #keys>16 then return nil,'Group requires 1..16 distinct frequencies' end
 local out=addon.copy(map[keys[1]])
 if #keys>1 then out.members={} for i=2,#keys do out.members[#out.members+1]=addon.copy(map[keys[i]]) end end
 return out
end
function M.receiverKey(r)
 return key({first=r.first.item,second=r.second.item,firstColor=r.first.dyedColor,secondColor=r.second.dyedColor})
end
function M.received(channel,snapshot,expected)
 local values={}
 for _,k in ipairs(M.keys(channel)) do
  local found,value=false,nil
  for _,r in ipairs(snapshot.links or {}) do
   if r.receiver and M.receiverKey(r)==k then
    if not addon.finite(r.signal) or r.signal%1~=0 or r.signal<0 or r.signal>15 or value~=nil and value~=r.signal or expected~=nil and r.signal~=expected then return nil,'Receiver mismatch: '..k end
    found,value=true,r.signal
   end
  end
  if not found then return nil,'Receiver missing: '..k end values[#values+1]=value
 end
 if #values==0 then return nil,'Invalid frequency group' end
 for _,v in ipairs(values) do if v~=values[1] then return nil,'Group receiver signals differ' end end
 return values[1]
end
function M.device(row)
  return row and addon.hasType(row,"redstone_link_bridge") and row.set and row.set.sendLinkSignal
end
function M.write(row,channel,value)
 local specs=M.specs(channel) if not specs then return false,'Invalid frequency group' end
 local branches,errors,uncertain={},{},false
 for _,f in ipairs(specs) do branches[#branches+1]=function()
  local returned,err=addon.call(row.device,'sendLinkSignal',f.first,f.second,value,f.firstColor,f.secondColor)
  if err then uncertain=true end
  if err or returned==false then errors[#errors+1]=key(f)..': '..(err or 'frequency transmitter refused') end
 end end
 if #branches==1 then branches[1]() else parallel.waitForAll(table.unpack(branches)) end
 if uncertain then error(table.concat(errors,'; '),0) end
 return #errors==0,table.concat(errors,'; ')
end
return M
