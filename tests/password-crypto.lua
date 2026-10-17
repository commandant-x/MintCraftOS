package.path="./?.lua;"..package.path
local crypto=require("system.libraries.password_crypto")
local function hex(value) return (value:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
-- RFC 4231 HMAC-SHA256 cases 1, 2 and 6 (long key).
assert(crypto.mac(string.rep(string.char(0x0b),20),"Hi There")=="b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7")
assert(crypto.mac("Jefe","what do ya want for nothing?")=="5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843")
assert(crypto.mac(string.rep(string.char(0xaa),131),"Test Using Larger Than Block-Size Key - Hash Key First")=="60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54")
-- FIPS 180-4 SHA-256 examples and independently reproducible PBKDF2 vectors.
assert(hex(crypto.digest(""))=="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
assert(hex(crypto.digest("abc"))=="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
assert(hex(crypto.digest("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"))=="248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
assert(hex(crypto.pbkdf2("password","salt",1))=="120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
assert(hex(crypto.pbkdf2("password","salt",2))=="ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43")
assert(hex(crypto.pbkdf2("password","salt",4096))=="c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a")
assert(hex(crypto.pbkdf2("pass\0word","sa\0lt",4096))=="89b69d0516f829893c696226650a86878c029ac13ee276509d5ae58b6466a724")
local calls=0
crypto.pbkdf2("password","salt",101,function(i) assert(i%50==0) calls=calls+1 end)
assert(calls==2)
assert(not crypto.verify("password",{algorithm="unknown"}))
assert(not crypto.verify("password",{algorithm="pbkdf2-hmac-sha256",salt=string.rep("a",32),iterations=0,digest=string.rep("a",64)}))
-- Credential creation/verification is also exercised at the production cost.
local first=crypto.create("production password")
assert(first.iterations==600000 and #first.salt==32 and #first.digest==64)
assert(crypto.verify("production password",first))
first.digest=string.rep("0",64)
assert(not crypto.verify("production password",first))
print("SHA256, PBKDF2 vectors, progress callback, production credentials and malformed records passed")
