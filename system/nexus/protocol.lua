local crypto=require("system.libraries.password_crypto")
local M={name="mintcraft.nexus.v1",version="0.4.0",maxPayload=8192}
local function integer(x) return type(x)=="number" and x==x and x>=0 and x<2147483647 and x%1==0 end
local function utc() assert(os.epoch,"UTC clock required") return os.epoch("utc") end
function M.hash(text) return (crypto.digest(text):gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
function M.nodeKey(masterKey,id) return crypto.mac(masterKey,"NEXUS node key v1:"..tostring(id)) end
function M.validKey(key) return type(key)=="string" and #key>=32 and #key<=256 end
local function mac(key,payload) return crypto.mac(key,M.name.."\n"..payload) end
function M.sign(key,from,to,kind,id,body)
  assert(M.validKey(key) and integer(from) and integer(to),"Invalid NEXUS credentials")
  assert(type(id)=="string" and #id<=100 and type(kind)=="string" and #kind<=24,"Invalid NEXUS header")
  local payload=textutils.serialize({schema=1,from=from,to=to,kind=kind,id=id,time=utc(),body=body})
  assert(#payload<=M.maxPayload,"NEXUS payload too large")
  return {payload=payload,mac=mac(key,payload)}
end
function M.shape(packet)
  return type(packet)=="table" and type(packet.payload)=="string" and #packet.payload<=M.maxPayload
    and type(packet.mac)=="string" and #packet.mac==64 and packet.mac:match("^%x+$")~=nil
end
function M.verify(key,sender,recipient,packet,seen)
  if not M.validKey(key) or not integer(sender) or not M.shape(packet) then return nil,"Malformed packet" end
  local expected=mac(key,packet.payload)
  local difference=0 for i=1,64 do local d=expected:byte(i)-packet.mac:byte(i) difference=difference+d*d end
  if difference~=0 then return nil,"Authentication failed" end
  local ok,value=pcall(textutils.unserialize,packet.payload)
  if not ok or type(value)~="table" or value.schema~=1 or value.from~=sender or value.to~=recipient
    or type(value.id)~="string" or #value.id>100 or type(value.kind)~="string" or #value.kind>24
    or type(value.body)~="table" or type(value.time)~="number" or value.time~=value.time or math.abs(value.time)==math.huge then return nil,"Invalid signed message" end
  if math.abs(utc()-value.time)>30000 then return nil,"Expired message" end
  if seen and seen[value.id] then return nil,"Duplicate message" end
  if seen then
    local count=0 for id,time in pairs(seen) do if utc()-time>30000 then seen[id]=nil else count=count+1 end end
    if count>=256 then return nil,"Replay window full" end
    seen[value.id]=utc()
  end
  return value
end
function M.inventory()
  local rows,priority={},{}
  local observe=require('system.nexus.observe')
  local names=peripheral.getNames()
  table.sort(names)
  for i=1,math.min(128,#names) do
    local name=names[i]
    local ok,kind=pcall(peripheral.getType,name)
    local category=observe.kind(name) or (require('system.nexus.radar').kind(name) and 'radar')
    local target=category and priority or rows
    target[#target+1]={name=tostring(name):sub(1,64),type=ok and tostring(kind):sub(1,64) or "unavailable",kind=category}
  end
  local result={}
  for _,group in ipairs({priority,rows}) do for _,row in ipairs(group) do if #result<24 then result[#result+1]=row end end end
  return result
end
function M.openModems()
  local count=0
  for _,name in ipairs(peripheral.getNames()) do
    if peripheral.hasType(name,"modem") then
      local ok=pcall(function() if not rednet.isOpen(name) then rednet.open(name) end end)
      if ok then count=count+1 end
    end
  end
  return count
end
return M
