package.path='./?.lua;'..package.path
local keygen=require('system.nexus.keygen')
local closed=0
http={get=function(options)
 assert(options.url:match('^https://www.random.org/integers/') and options.redirect==false and options.timeout==8)
 return {getResponseCode=function() return 200 end,read=function(n) assert(n==4096) return string.rep('af\n',32) end,close=function() closed=closed+1 end}
end}
local key=keygen.generate()
assert(#key==64 and key:match('^[0-9a-f]+$') and closed==1)
http.get=function() return {getResponseCode=function() return 200 end,read=function() return 'HTML error' end,close=function() closed=closed+1 end} end
assert(not pcall(keygen.generate) and closed==2,'Invalid entropy accepted or handle leaked')
http=nil
assert(not pcall(keygen.generate),'Weak offline fallback generated a key')
print('NEXUS keygen: HTTPS, validated entropy, closed handles and no weak fallback passed')
