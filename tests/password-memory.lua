package.path="./?.lua;"..package.path
local crypto=require("system.libraries.password_crypto")
local verify=crypto.memoryVerifier("session password")
assert(verify("session password") and not verify("wrong password"))
assert(not verify(0) and not verify(string.rep("x",1025)))
assert(not verify("session password\0") and not verify("Session password"))
local other=crypto.memoryVerifier("other session password")
assert(other("other session password") and not other("session password"))
assert(verify("session password"),"new verifier changed another session's check")
-- Detect accidental captures of the plaintext password in the returned closure.
if debug and debug.getupvalue then
 local i=1
 while true do local name,value=debug.getupvalue(verify,i) if not name then break end
  assert(value~="session password","plaintext captured in volatile verifier") i=i+1
 end
end
print("volatile HMAC verifier: correct/wrong passwords, bounded inputs, independent closures and no plaintext upvalue passed")
