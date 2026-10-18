local M={}
local cache,order={},{}
function M.invalidate() cache,order={},{} end
function M.load(path,size)
  local key=tostring(path)..":"..size
  if cache[key]~=nil then return cache[key] end
  local ok,sprite=pcall(function()
    assert(type(path)=="string" and fs and fs.open,"No bitmap")
    local fine=path:gsub("%.nfp$",".spx")
    if fs.exists(fine) then path=fine end
    local file=assert(fs.open(path,"r"))
    local rows,width={},0
    local read,err=pcall(function()
      for _=1,64 do
        local row=file.readLine() if not row then break end
        row=row:sub(1,64) rows[#rows+1]=row width=math.max(width,#row)
      end
    end)
    file.close() assert(read,err) assert(width>0 and #rows>0,"Empty bitmap")
    local scale=math.min(size/width,size/#rows)
    local w,h=math.max(1,math.floor(width*scale)),math.max(1,math.floor(#rows*scale))
    local result={width=w,height=h,rows={}}
    for y=1,h do
      local source=rows[math.min(#rows,math.floor((y-1)/scale)+1)] local row={}
      for x=1,w do row[x]=string.char(tonumber(source:sub(math.floor((x-1)/scale)+1,math.floor((x-1)/scale)+1),16) or 255) end
      result.rows[y]=table.concat(row)
    end
    return result
  end)
  cache[key]=ok and sprite or false order[#order+1]=key
  if #order>64 then cache[table.remove(order,1)]=nil end
  return cache[key]
end
function M.draw(surface,sprite,x,y)
  if not sprite then return end
  for row=1,sprite.height do
    local data=sprite.rows[row] local first=1
    while first<=#data do
      local transparent=data:find(string.char(255),first,true) or #data+1
      if transparent>first then surface:span(x+first-1,y+row-1,data:sub(first,transparent-1)) end
      first=transparent+1
    end
  end
end
return M
