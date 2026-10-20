-- Standalone agent adapter. Only these advertised read methods may be called.
local M={}
local types={['create_radar:radar']=true,['create_radar:radar_bearing']=true,['create_radar:plane_radar']=true}
local reads={'getTracks','getScanGeometry','getPosition','getRange','getRotation','getDishCount'}
function M.finite(value) return type(value)=='number' and value==value and math.abs(value)<1e15 end
function M.vector(value)
  if type(value)=='table' and M.finite(value.x) and M.finite(value.y) and M.finite(value.z) then return {x=value.x,y=value.y,z=value.z} end
end
local function text(value,length) return type(value)=='string' and value:gsub('[%c]',' '):sub(1,length) or nil end
local function identifier(value)
  if type(value)=='number' and M.finite(value) then value=tostring(value) end
  return type(value)=='string' and #value>0 and #value<=100 and not value:find('[%c]') and value or nil
end
function M.kind(name)
  for kind in pairs(types) do local ok,yes=pcall(peripheral.hasType,name,kind) if ok and yes then return kind end end
end
function M.read(name)
  local kind=M.kind(name) if not kind then return nil,'Unsupported radar type' end
  local ok,methods=pcall(peripheral.getMethods,name)
  if not ok or type(methods)~='table' then return nil,'Radar methods unavailable' end
  local available={} for i=1,math.min(#methods,128) do available[methods[i]]=true end
  local values,errors={},{}
  local measuredAt=os.epoch('utc')/1000
  for _,method in ipairs(reads) do
    if available[method] then
      local good,value=pcall(peripheral.call,name,method)
      if good then values[method]=value else errors[method]=tostring(value):sub(1,120) end
    end
  end
  local scan=type(values.getScanGeometry)=='table' and values.getScanGeometry.version==1 and values.getScanGeometry or nil
  local result={name=name,kind=kind,measuredAt=measuredAt,errors=errors,targets={},frame='unknown'}
  if scan then
    if scan.positionFrame=='world' then result.position=M.vector(scan.position) result.frame=result.position and 'world' or 'unknown' end
    if scan.headingFrame=='world' and M.finite(scan.heading) then result.heading=scan.heading%360 end
    if M.finite(scan.fov) and scan.fov>0 and scan.fov<=360 then result.fov=scan.fov end
    result.range=M.finite(scan.range) and scan.range>0 and scan.range or nil
    if type(scan.running)=='boolean' then result.running=scan.running end
  else
    -- A stock bearing can expose plot/block coordinates or fail getPosition.
    -- Do not guess world placement, heading or cone geometry for it.
    result.rawPosition=M.vector(values.getPosition)
    result.range=M.finite(values.getRange) and values.getRange>0 and values.getRange or nil
    result.rawRotation=M.finite(values.getRotation) and values.getRotation or nil
  end
  local tracks=type(values.getTracks)=='table' and values.getTracks or {}
  result.total=#tracks result.partial=#tracks>12
  for i=1,math.min(512,#tracks) do
    if #result.targets>=12 then break end
    local row=tracks[i]
    if type(row)=='table' and identifier(row.id) and M.vector(row.position) then
      result.targets[#result.targets+1]={id=identifier(row.id),position=M.vector(row.position),velocity=M.vector(row.velocity),
        name=text(row.name or row.displayName,64),category=text(row.category,24),entityType=text(row.entityType,64),
        scannedTime=M.finite(row.scannedTime) and row.scannedTime or nil,
        friendly=type(row.friendly)=='boolean' and row.friendly or nil,synthetic=type(row.synthetic)=='boolean' and row.synthetic or nil}
    end
  end
  return result
end
return M
