-- Format 3: raw DEFLATE, bounded output and Adler-32; formats 1/2 stay readable.
local M={prefix='-- MintCraft packed source 3\n'}
local digits={}
local count=0
for c=1,126 do if c~=9 and c~=10 and c~=11 and c~=12 and c~=13 and c~=27 and c~=91 and c~=93 then digits[string.char(c)]=count count=count+1 end end
assert(count==118)
local function ascii(text)
 local out={}
 for i=1,#text,7 do
  local part=text:sub(i,i+6) assert(#part~=1,'Truncated compact ASCII') local value=0
  for j=1,#part do value=value*118+assert(digits[part:sub(j,j)],'Invalid compact ASCII') end
  local n=#part-1 assert(value<256^n,'Compact ASCII overflow')
  local bytes={} for j=n,1,-1 do bytes[j]=string.char(value%256) value=math.floor(value/256) end out[#out+1]=table.concat(bytes)
 end
 return table.concat(out)
end
local function tree(lengths,maximum)
 local counts,codes,nodes={},{},{} local symbols=0
 for _,length in ipairs(lengths) do assert(length>=0 and length<=maximum and length%1==0,'Invalid Huffman length') if length>0 then counts[length]=(counts[length] or 0)+1 symbols=symbols+1 end end
 local code,left=0,1
 for length=1,maximum do
  left=left*2-(counts[length] or 0) assert(left>=0,'Oversubscribed Huffman tree')
  code=(code+(counts[length-1] or 0))*2 codes[length]=code nodes[length]={}
 end
 assert(symbols>0 and (left==0 or symbols==1),'Incomplete Huffman tree')
 for symbol,length in ipairs(lengths) do if length>0 then
  local value=codes[length] local reversed=0
  for _=1,length do reversed=reversed*2+value%2 value=math.floor(value/2) end
  nodes[length][reversed]=symbol-1 codes[length]=codes[length]+1
 end end
 return nodes
end
local lengthBase={3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
local lengthBits={0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
local distanceBase={1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
local distanceBits={0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}
local order={17,18,19,1,9,8,10,7,11,6,12,5,13,4,14,3,15,2,16}
function M.decode(text,length,digest)
 assert(type(text)=='string' and type(length)=='number' and length>=0 and length%1==0 and length<=4194304,'Invalid packed source bounds')
 assert(#text<=math.max(32,length*4+32),'Oversized packed source')
 local raw=ascii(text) local index,buffer,bits=1,0,0
 local function read(n)
  while bits<n do local byte=raw:byte(index) assert(byte,'Truncated DEFLATE stream') buffer=buffer+byte*2^bits bits=bits+8 index=index+1 end
  local value=buffer%2^n buffer=math.floor(buffer/2^n) bits=bits-n return value
 end
 local function symbol(nodes)
  local code=0
  for n=1,15 do code=code+read(1)*2^(n-1) local value=nodes[n] and nodes[n][code] if value~=nil then return value end end
  error('Invalid Huffman symbol')
 end
 -- Byte array supports overlapping 32 KiB matches without quadratic strings.
 local output={} local size=0 local a,b=1,0
 local function emit(byte)
  assert(size<length,'Packed source expands past declared size')
  size=size+1 output[size]=byte a=(a+byte)%65521 b=(b+a)%65521
 end
 local final=0
 repeat
  final=read(1) local kind=read(2)
  if kind==0 then
   buffer,bits=0,0 local n=read(16) assert(read(16)==65535-n,'Invalid stored block length')
   for _=1,n do emit(read(8)) end
  elseif kind==1 or kind==2 then
   local literal,distance
   if kind==1 then
    literal={} distance={}
    for i=0,287 do literal[i+1]=i<=143 and 8 or i<=255 and 9 or i<=279 and 7 or 8 end
    for i=1,32 do distance[i]=5 end
   else
    local nl,nd,nc=read(5)+257,read(5)+1,read(4)+4
    assert(nl<=286 and nd<=32,'Invalid dynamic tree bounds')
    local codeLengths={} for i=1,19 do codeLengths[i]=0 end
    for i=1,nc do codeLengths[order[i]]=read(3) end
    local decoder=tree(codeLengths,7) local all={}
    while #all<nl+nd do
     local value=symbol(decoder)
     if value<16 then all[#all+1]=value
     else
      local repeatCount,previous
      if value==16 then assert(#all>0,'Missing repeated code length') repeatCount=read(2)+3 previous=all[#all]
      elseif value==17 then repeatCount=read(3)+3 previous=0
      elseif value==18 then repeatCount=read(7)+11 previous=0
      else error('Invalid code-length symbol') end
      assert(#all+repeatCount<=nl+nd,'Code-length repeat overflow')
      for _=1,repeatCount do all[#all+1]=previous end
     end
    end
    literal={} distance={} for i=1,nl do literal[i]=all[i] end for i=1,nd do distance[i]=all[nl+i] end
    assert(literal[257] and literal[257]>0,'Missing end-of-block symbol')
   end
   local literals=tree(literal,15)
   local any=false for _,n in ipairs(distance) do if n>0 then any=true end end
   local distances=any and tree(distance,15) or nil
   while true do
    local value=symbol(literals)
    if value==256 then break
    elseif value<256 then emit(value)
    else
     assert(value<=285 and distances,'Invalid length or missing distance tree') local slot=value-256
     local n=lengthBase[slot]+read(lengthBits[slot]) local d=symbol(distances)+1
     assert(d<=30,'Reserved distance symbol') local offset=distanceBase[d]+read(distanceBits[d])
     assert(offset<=size and offset<=32768,'Invalid DEFLATE offset')
     for _=1,n do emit(output[size-offset+1]) end
    end
   end
  else error('Reserved DEFLATE block') end
 until final==1
 assert(index==#raw+1 and buffer==0,'Trailing DEFLATE bytes/bits')
 assert(size==length and string.format('%08x',b*65536+a)==digest,'Packed source integrity mismatch')
 local chunks={} for i=1,size,4096 do local chars={} for j=i,math.min(size,i+4095) do chars[#chars+1]=string.char(output[j]) end chunks[#chunks+1]=table.concat(chars) end
 return table.concat(chunks)
end
function M.unpack(source)
 if source:sub(1,#M.prefix)~=M.prefix then return source end
 local encoded,length,digest=source:match('%.decode%(%[%[(.-)%]%],(%d+),"([0-9a-f]+)"%)')
 assert(encoded,'Invalid DEFLATE packed wrapper') return M.decode(encoded,tonumber(length),digest)
end
return M
