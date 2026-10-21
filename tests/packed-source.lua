package.path='./?.lua;'..package.path
local codec=require('system.libraries.packed_source')
for _,text in ipairs({'','x','aaaa',string.rep('abcde',2000),string.char(0,255,1)..'\r\n',string.rep('local function f(x) return x+1 end\n',800)}) do
 local encoded=codec.encode(text)
 assert(codec.decode(encoded,#text,codec.checksum(text))==text)
 if #text>0 then assert(not pcall(codec.decode,encoded,#text-1,codec.checksum(text))) end
 assert(not pcall(codec.decode,encoded,#text,'00000000'))
end
local source='local x=... return x+1, "value"\n'..string.rep('-- exact comments retained\n',200)
local packed=codec.pack('system/test.lua',source)
assert(#packed<#source and codec.unpack(packed)==source)
local fn=assert(load(packed,'packed','t',_ENV)) local a,b=fn(41) assert(a==42 and b=='value')
for _,path in ipairs({'boot.lua','startup.lua','system/boot/recovery.lua','system/libraries/safe_write.lua','system/libraries/installer.lua','system/libraries/packed_source.lua'}) do assert(codec.pack(path,source)==source) end
assert(not pcall(codec.decode,'?????',100,'ffffffff'))
print('packed source: lossless bytes/comments/binary, bounds, corruption refusal, varargs/returns and readable rescue files passed')
