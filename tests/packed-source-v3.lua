package.path='./?.lua;'..package.path
local codec=require('system.libraries.packed_source_v3')
local legacy=require('system.libraries.packed_source')
local cases=require('tests.fixtures.packed-v3')
for _,r in ipairs(cases) do
 assert(codec.decode(r.encoded,#r.source,r.digest)==r.source)
 assert(not pcall(codec.decode,r.encoded,#r.source,'00000000'))
 if #r.source>0 then assert(not pcall(codec.decode,r.encoded,#r.source-1,r.digest)) end
 assert(not pcall(codec.decode,r.encoded:sub(1,-2),#r.source,r.digest))
 assert(not pcall(codec.decode,r.encoded..'22',#r.source,r.digest))
end
local r=cases[6]
local wrapper=codec.prefix..'return assert(load(require("system.libraries.packed_source_v3").decode([['..r.encoded..']],'..#r.source..',"'..r.digest..'"),"fixture","t",_ENV))(...)\n'
assert(legacy.unpack(wrapper)==r.source)
local a,b=assert(load(wrapper,'wrapper','t',_ENV))(41) assert(a==42 and b=='value')
for _,bad in ipairs({'!','22','0000000','~~~~~~~','[[[[[[['}) do assert(not pcall(codec.decode,bad,0,'00000001')) end
assert(not pcall(codec.decode,'',4194305,'00000001'))
for _,r in ipairs(require('tests.fixtures.packed-v2')) do assert(legacy.unpack(r.wrapper or r.source)==(r.wrapper and r.source or r.source)) end
print('DEFLATE source: independent zlib stored/fixed/dynamic/multiple blocks, Unicode/binary/overlapping matches, exact returns, bounds/corruption/trailing refusal and legacy decoding passed')
