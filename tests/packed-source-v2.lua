package.path='./?.lua;'..package.path
local V=require('system.libraries.packed_source_v2')
local C=require('system.libraries.packed_source')
local cases=require('tests.fixtures.packed-v2')
for _,r in ipairs(cases) do
 assert(V.decode(r.encoded,#r.source,r.digest)==r.source,'byte loss: '..r.name)
 assert(not pcall(V.decode,r.encoded,#r.source+1,r.digest))
 assert(not pcall(V.decode,r.encoded,#r.source,'00000000'))
 if r.wrapper then assert(C.unpack(r.wrapper)==r.source and V.unpack(r.wrapper)==r.source) end
 if r.name=='function' then
  local fn=assert(load(r.wrapper,'v2-wrapper','t',_ENV)) local a,b=fn(41) assert(a==42 and b=='value')
 end
end
assert(not pcall(V.decode,']',1,'00000000'))
assert(not pcall(V.decode,string.rep(string.char(126),7),6,'00000000'))
assert(not pcall(V.decode,string.char(1),1,'00000000'))
assert(not pcall(V.decode,string.rep('x',100),1,'00000000'))
assert(not pcall(V.decode,'',math.huge,'00000000'))
assert(not pcall(V.unpack,V.prefix..'invalid wrapper'))
local source='return true\n'..string.rep('-- keep original comments\n',100)
for _,path in ipairs({'system/libraries/packed_source_v2.lua','system/libraries/installer_v2.lua'}) do assert(C.pack(path,source)==source,'standalone recovery dependency packed itself') end
print('Packed source format 2: exact bytes/comments/CRLF, all binary values, 48-bit chunk bounds, corruption refusal, legacy-reader dispatch, return values and readable recovery dependencies passed')
