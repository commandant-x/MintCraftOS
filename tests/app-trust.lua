package.path="./?.lua;"..package.path
package.loaded["system.libraries.log"]={warn=function() end}
package.loaded["system.security.permissions"]={}
package.loaded["system.libraries.profile"]={appEnabled=function() return true end}
local ran=false
package.preload["packages.evil.main"]=function() ran=true return {run=function() ran=true end} end
local apps=require("system.libraries.apps")
apps.setContext({})
assert(apps.registerBuiltin("settings","Settings","apps.settings.main",{}))
assert(not apps.register("settings","Replacement","packages.evil.main",{}))
assert(apps.get("settings").module=="apps.settings.main")
apps.register("evil","Untrusted","packages.evil.main",{})
local ok,why=apps.launch("evil")
assert(not ok and why:find("Third-party execution disabled",1,true) and not ran)
print("untrusted import blocked before execution and built-in app IDs protected")
