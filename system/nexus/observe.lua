local M={}
local function number(value) return type(value)=='number' and value==value and value>=0 and value<1e15 and value or nil end
function M.kind(name)
  for _,kind in ipairs({'inventory','energy_storage','fluid_storage'}) do
    local ok,yes=pcall(peripheral.hasType,name,kind)
    if ok and yes then return kind end
  end
end
function M.read(name)
  assert(type(name)=='string' and #name<=64,'Invalid endpoint')
  local kind=M.kind(name)
  local result={ok=kind~=nil,kind=kind or 'unsupported',name=name,measuredAt=os.epoch('utc')}
  local function call(method)
    local ok,value=pcall(peripheral.call,name,method)
    if ok then return value end
    result.ok=false result.error=tostring(value):sub(1,120)
  end
  if kind=='inventory' then
    result.slots=number(call('size'))
    if result.slots and result.slots<=4096 then
      local items=call('list')
      result.items,result.used=0,0
      if type(items)=='table' then
        local inspected=0
        for _,item in pairs(items) do
          inspected=inspected+1 if inspected>256 then result.partial=true break end
          if type(item)=='table' and number(item.count) then result.used=result.used+1 result.items=result.items+item.count end
        end
      else result.ok=false end
    else result.partial=true end
  elseif kind=='energy_storage' then
    result.energy=number(call('getEnergy')) result.capacity=number(call('getEnergyCapacity'))
    if not result.energy or not result.capacity then result.ok=false end
  elseif kind=='fluid_storage' then
    local tanks=call('tanks') result.amount,result.tanks=0,0
    if type(tanks)=='table' then local inspected=0 for _,tank in pairs(tanks) do
      inspected=inspected+1 if inspected>64 then result.partial=true break end
      if type(tank)=='table' and number(tank.amount) then result.tanks=result.tanks+1 result.amount=result.amount+tank.amount end
    end else result.ok=false end
  else result.error='No supported read-only adapter' end
  return result
end
function M.normalize(value)
  if type(value)~='table' then return {ok=false,error='Invalid observation'} end
  local result={ok=value.ok==true,partial=value.partial==true}
  for _,key in ipairs({'slots','items','used','energy','capacity','amount','tanks','measuredAt'}) do result[key]=number(value[key]) end
  for _,key in ipairs({'kind','name','error'}) do if type(value[key])=='string' then result[key]=value[key]:sub(1,key=='error' and 120 or 64) end end
  return result
end
return M
