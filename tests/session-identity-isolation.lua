package.path='./?.lua;'..package.path
local identity,revision,locked='captain',1,false
package.loaded['system.services.securityd']={sessionIdentity=function() return identity end,sessionRevision=function() return revision end,isLocked=function() return locked end}
package.loaded['system.security.users']={needsEnrollment=function() return false end,authenticationStatus=function() return {retryAfter=0} end}
local killed={}
local scheduler={processes={[7]={windows={{}},meta={appId='editor'}},[8]={windows={},meta={protected=true}}},kill=function(_,pid) killed[#killed+1]=pid end}
local screen=require('system.security.session_screen').new({scheduler=scheduler,pixelWorkspace={deactivate=function() end}})
screen:sync() assert(#killed==0)
locked=true revision=2 screen:sync() assert(#killed==0,'same-user lock discarded working windows')
locked=false revision=3 screen:sync() assert(#killed==0)
identity='guest' revision=4 screen:sync() assert(#killed==1 and killed[1]==7,'sign-out exposed old account windows')
print('session identity: preserve windows during same-user lock/unlock, close account-owned windows on identity change, retain services passed')
