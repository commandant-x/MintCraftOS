-- Lossless installed-source encoding. Readable development sources stay in Git.
local M={prefix="-- MintCraft packed source 1\n"}
local alphabet="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~"
local digits={}
for i=1,#alphabet do digits[alphabet:sub(i,i)]=i-1 end
function M.checksum(data)
  local a,b=1,0
  for i=1,#data do a=(a+data:byte(i))%65521 b=(b+a)%65521 end
  return string.format("%08x",b*65536+a)
end
local function ascii85(raw)
  local out={}
  for i=1,#raw,4 do
    local part=raw:sub(i,i+3) local value=0
    for j=1,4 do value=value*256+(part:byte(j) or 0) end
    local chunk={}
    for j=5,1,-1 do local n=value%85 chunk[j]=alphabet:sub(n+1,n+1) value=math.floor(value/85) end
    out[#out+1]=table.concat(chunk):sub(1,#part+1)
  end
  return table.concat(out)
end
function M.encode(data,tick)
  local hits,out,i={}, {},1
  while i<=#data do
    local flags,items=0,{}
    for bit=0,7 do
      if i>#data then break end
      local key=data:sub(i,i+3) local candidates=hits[key] or {}
      local best,distance=0,0
      for c=#candidates,1,-1 do
        local pos=candidates[c]
        if i-pos>65535 then break end
        local length=4
        while length<258 and i+length<=#data and data:byte(pos+length)==data:byte(i+length) do length=length+1 end
        if length>best then best,distance=length,i-pos end
      end
      local count=best>=4 and best or 1
      if best>=4 then
        flags=flags+2^bit items[#items+1]=string.char(math.floor(distance/256),distance%256,best-3)
      else items[#items+1]=data:sub(i,i) end
      for pos=i,i+count-1 do
        local k=data:sub(pos,pos+3)
        local rows=hits[k] or {} hits[k]=rows
        rows[#rows+1]=pos if #rows>32 then table.remove(rows,1) end
      end
      local before=i i=i+count
      if tick and math.floor(before/2048)~=math.floor(i/2048) then tick() end
    end
    out[#out+1]=string.char(flags)..table.concat(items)
  end
  return ascii85(table.concat(out))
end
function M.decode(text,length,digest)
  assert(type(text)=="string" and type(length)=="number" and length>=0 and length%1==0 and length<=4194304,"Invalid packed source bounds")
  assert(#text<=math.max(32,length*4+32),"Oversized packed source")
  local bytes={}
  for i=1,#text,5 do
    local part=text:sub(i,i+4) assert(#part~=1,"Truncated ASCII85")
    local value=0
    for j=1,5 do
      local c=part:sub(j,j) local digit=84
      if j<=#part then digit=assert(digits[c],"Invalid ASCII85") end
      value=value*85+digit
    end
    assert(value<4294967296,"ASCII85 overflow")
    local chunk={}
    for j=4,1,-1 do chunk[j]=string.char(value%256) value=math.floor(value/256) end
    bytes[#bytes+1]=table.concat(chunk):sub(1,#part-1)
  end
  local raw=table.concat(bytes)
  local result,index="",1
  while index<=#raw do
    local flags=raw:byte(index) index=index+1
    for bit=0,7 do
      if index>#raw then break end
      local value
      if math.floor(flags/2^bit)%2==1 then
        local a,b,c=raw:byte(index,index+2)
        assert(c,"Truncated LZSS match")
        local distance,count=a*256+b,c+3 index=index+3
        assert(distance>0 and distance<=#result,"Invalid LZSS offset")
        value=result:sub(#result-distance+1)
        if #value<count then value=string.rep(value,math.ceil(count/#value)) end
        value=value:sub(1,count)
      else value=raw:sub(index,index) index=index+1 end
      assert(#result+#value<=length,"Packed source expands past declared size")
      result=result..value
    end
  end
  assert(#result==length and M.checksum(result)==digest,"Packed source integrity mismatch")
  return result
end
local plain={['boot.lua']=true,['startup.lua']=true,['system/boot/recovery.lua']=true,
  ['system/libraries/safe_write.lua']=true,['system/libraries/installer.lua']=true,['system/libraries/packed_source.lua']=true,['system/libraries/packed_source_v3.lua']=true,['system/libraries/packed_source_v2.lua']=true,['system/libraries/installer_v2.lua']=true}
function M.pack(path,source,tick)
  if plain[path] or not path:match('%.lua$') or source:sub(1,#M.prefix)==M.prefix then return source end
  local packed=M.prefix..'return assert(load(require("system.libraries.packed_source").decode([['..M.encode(source,tick)..']],'
    ..#source..',"'..M.checksum(source)..'"),"@/'..path..'","t",_ENV))(...)\n'
  return #packed<#source and packed or source
end
function M.unpack(source)
  if source:sub(1,#"-- MintCraft packed source 3\n")=="-- MintCraft packed source 3\n" then return require("system.libraries.packed_source_v3").unpack(source) end
  if source:sub(1,#"-- MintCraft packed source 2\n")=="-- MintCraft packed source 2\n" then return require("system.libraries.packed_source_v2").unpack(source) end
  if source:sub(1,#M.prefix)~=M.prefix then return source end
  local encoded,length,digest=source:match('%.decode%(%[%[(.-)%]%],(%d+),"([0-9a-f]+)"%)')
  assert(encoded,"Invalid packed wrapper")
  return M.decode(encoded,tonumber(length),digest)
end
return M
