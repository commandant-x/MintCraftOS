local M={}
local function short(value,limit) return tostring(value):sub(1,limit or 256):gsub('[%c]',' ') end
function M.role(row)
  for _,kind in ipairs(row.types or {row.type}) do
    if kind=='monitor' or kind=='terminal' then return 'display' end
    if kind=='modem' then return 'network' end
  end
  local kinds=table.concat(row.types or {row.type},' '):lower()
  for _,pair in ipairs({{'radar','radar'},{'cannon','cbc'},{'mount','cbc'},{'controller','control'},
    {'gimbal','avionics'},{'altitude','avionics'},{'propeller','avionics'},{'navigation_table','avionics'},
    {'throttle','avionics'},{'redstone','redstone'},{'inventory','storage'},{'energy','storage'},{'fluid','storage'}}) do
    if kinds:find(pair[1],1,true) then return pair[2] end
  end
  return 'other'
end
function M.filter(rows,query,category)
  local result={} query=(query or ''):lower()
  for _,row in ipairs(rows) do
    local text=(row.name..' '..table.concat(row.types or {row.type},' ')..' '..row.role):lower()
    if (category=='all' or row.role==category) and text:find(query,1,true) then result[#result+1]=row end
  end
  return result
end
function M.value(value,depth)
  if type(value)~='table' then return short(value) end
  if (depth or 0)>=2 then return '[table]' end
  local parts={} local count,bytes=0,0
  for key,item in pairs(value) do
    count=count+1 if count>12 then parts[#parts+1]='...' break end
    local part=short(key,48)..'='..M.value(item,(depth or 0)+1)
    bytes=bytes+#part
    if bytes>2000 then parts[#parts+1]='...' break end
    parts[#parts+1]=part
  end
  table.sort(parts) return '{'..table.concat(parts,', ')..'}'
end
function M.details(row,methods,probe)
  if not row then return 'No device selected' end
  local lines={row.name,'Role: '..row.role,'Types: '..table.concat(row.types or {row.type},', '),'',
    'Advertised methods (not executed):',methods and table.concat(methods,', ') or 'Not acquired',''}
  local bytes=0 for _,line in ipairs(lines) do bytes=bytes+#line+1 end
  if probe then
    lines[#lines+1]='Read-only Probe #'..tostring(probe.operationId or '?')
    lines[#lines+1]='Completed uptime: '..tostring(probe.completedAt or 'unavailable')
    for _,section in ipairs({'values','errors'}) do
      local keys={} for key in pairs(probe[section] or {}) do if #keys<64 then keys[#keys+1]=key end end table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
      for _,key in ipairs(keys) do
        local line=short(key,64)..(section=='errors' and ' ERROR: ' or ': ')..M.value(probe[section][key])
        bytes=bytes+#line+1
        if bytes>16000 then lines[#lines+1]='[diagnostic truncated]' return table.concat(lines,'\n'):sub(1,16384) end
        lines[#lines+1]=line
      end
    end
  else lines[#lines+1]='No Probe result acquired for this device' end
  return table.concat(lines,'\n'):sub(1,16384)
end
return M
