-- Format 2 uses a seven-digit/six-byte ASCII alphabet. No CR/LF/NUL or brackets.
local M={prefix='-- MintCraft packed source 2\n'}
local alphabet,digits={},{}
for c=1,126 do
 if c~=9 and c~=10 and c~=11 and c~=12 and c~=13 and c~=27 and c~=91 and c~=93 then
  alphabet[#alphabet+1]=string.char(c) digits[string.char(c)]=#alphabet-1
 end
end
assert(#alphabet==118)
local function checksum(data)
 local a,b=1,0 for i=1,#data do a=(a+data:byte(i))%65521 b=(b+a)%65521 end
 return string.format('%08x',b*65536+a)
end
function M.decode(text,length,digest)
 assert(type(text)=='string' and type(length)=='number' and length>=0 and length%1==0 and length<=4194304,'Invalid packed source bounds')
 assert(#text<=math.max(32,length*4+32),'Oversized packed source')
 local bytes={}
 for i=1,#text,7 do
  local part=text:sub(i,i+6) assert(#part~=1,'Truncated compact ASCII')
  local value=0
  for j=1,#part do value=value*118+assert(digits[part:sub(j,j)],'Invalid compact ASCII') end
  local n=#part-1 assert(value<256^n,'Compact ASCII overflow')
  local chunk={} for j=n,1,-1 do chunk[j]=string.char(value%256) value=math.floor(value/256) end
  bytes[#bytes+1]=table.concat(chunk)
 end
 local raw=table.concat(bytes) local result,index='',1
 while index<=#raw do
  local flags=raw:byte(index) index=index+1
  for bit=0,7 do
   if index>#raw then break end
   local value
   if math.floor(flags/2^bit)%2==1 then
    local a,b,c=raw:byte(index,index+2) assert(c,'Truncated LZSS match')
    local distance,count=a*256+b,c+3 index=index+3
    assert(distance>0 and distance<=#result,'Invalid LZSS offset')
    value=result:sub(#result-distance+1)
    if #value<count then value=string.rep(value,math.ceil(count/#value)) end
    value=value:sub(1,count)
   else value=raw:sub(index,index) index=index+1 end
   assert(#result+#value<=length,'Packed source expands past declared size') result=result..value
  end
 end
 assert(#result==length and checksum(result)==digest,'Packed source integrity mismatch') return result
end
function M.unpack(source)
 if source:sub(1,#M.prefix)~=M.prefix then return source end
 local encoded,length,digest=source:match('%.decode%(%[%[(.-)%]%],(%d+),"([0-9a-f]+)"%)')
 assert(encoded,'Invalid compact packed wrapper') return M.decode(encoded,tonumber(length),digest)
end
return M
