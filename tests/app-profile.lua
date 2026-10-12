package.path="./?.lua;"..package.path
pocket={}
package.loaded["system.libraries.config"]={load=function() return {mode="auto",apps={}} end}
local saved,fail
textutils={serialize=function(value) saved=value return "settings" end}
package.loaded["system.libraries.safe_write"]={write=function() return not fail,"write refused" end}
local profile=require("system.libraries.profile")
assert(profile.mode()=="pocket" and profile.appEnabled("messenger") and not profile.appEnabled("combat"))
assert(not profile.serviceEnabled("combatd") and not profile.serviceEnabled("flightd"))
local cfg=profile.configuration() cfg.apps.combat=true assert(profile.configure(cfg))
assert(profile.appEnabled("combat") and profile.serviceEnabled("sabled") and profile.serviceEnabled("radarnetd"))
cfg.apps.settings=false assert(not profile.configure(cfg),"essential settings disabled")
cfg.apps.settings=nil cfg.apps.combat=false fail=true assert(not profile.configure(cfg))
assert(profile.appEnabled("combat"),"failed write changed live choices")
fail=false cfg.mode="desktop" cfg.apps={} assert(profile.configure(cfg))
assert(profile.appEnabled("combat") and profile.appEnabled("browser"))
cfg.mode="auto" assert(profile.configure(cfg)) pocket=nil
assert(profile.mode()=="desktop" and profile.appEnabled("navigation"))
print("app profiles, essential apps, saved choices, pocket detection and service selection passed")
