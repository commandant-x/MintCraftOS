package.path="./?.lua;"..package.path
local crypto=require("system.libraries.password_crypto")
-- Independent Python hashlib.pbkdf2_hmac vector, ASCII salt as stored by the provider.
local record={algorithm="pbkdf2-hmac-sha256",salt=string.rep("a",32),iterations=15000,
 digest="136d790d1ccc708b89caaf143e3b3135300132685621461000dc7dc534160764"}
assert(crypto.verify("quick password",record))
assert(not crypto.verify("wrong password",record))
record.iterations=14999 assert(not crypto.verify("quick password",record))
local progress=0
local created=crypto.createQuick("quick production password",{progress=function(done,total) assert(total==15000 and done<=total) progress=progress+1 end})
assert(created.iterations==15000 and #created.salt==32 and #created.digest==64 and progress>0)
assert(crypto.verify("quick production password",created))
local cancelled=pcall(crypto.createQuick,"cancelled password",{cancelled=function() return true end})
assert(not cancelled,"quick KDF ignored cancellation")
print("quick PBKDF2: independent 15000-iteration vector, wrong password, minimum cost, creation/progress, verification and cancellation passed")
