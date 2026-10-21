package.path='./?.lua;'..package.path
local logs={}
package.loaded['system.libraries.log']={warn=function(_,message) logs[#logs+1]=message end,info=function() end}
local permissions=require('system.security.permissions')
local actor={appId='test',permissions={'filesystem.read','system.security.admin'}}
package.loaded['system.services.securityd']=nil
package.preload['system.services.securityd']=function() error('private provider diagnostic') end
assert(not permissions.has(actor,'filesystem.read'))
assert(not permissions.require(actor,'filesystem.read','/home/user/note'))
package.loaded['system.services.securityd']={}
assert(not permissions.has(actor,'filesystem.read'))
package.loaded['system.services.securityd']={authorize=function() error('private authorization data') end}
assert(not permissions.require(actor,'filesystem.read'))
package.loaded['system.services.securityd']={authorize=function() return 'yes' end}
assert(not permissions.has(actor,'filesystem.read'))
local calls=0 local admin=false
package.loaded['system.services.securityd']={authorize=function(_,permission) calls=calls+1 return permission~='system.security.admin' or admin end}
assert(permissions.has(actor,'filesystem.read','/home/user/note'))
for _,path in ipairs({'/system/security/users.db','/system/security/users.db.mintcraft-save/previous','/system/config/nexus.cfg','/home/../system/config/nexus.cfg','\\system\\config\\security.cfg','/var/backups/update/1/system/security/users.db','/var/tmp/mintcraft-install/backup/system/config/nexus.cfg'}) do
 assert(not permissions.has(actor,'filesystem.read',path),path)
end
admin=true assert(permissions.has(actor,'filesystem.read','/system/config/nexus.cfg'))
assert(not permissions.has({permissions={'filesystem.read'}},'filesystem.read','/system/config/nexus.cfg'))
assert(not permissions.has({permissions='*'},'filesystem.read'))
assert(not permissions.has('invalid','filesystem.read'))
package.loaded['system.services.securityd'].authorize=function() calls=calls+1 return false,'session locked' end
calls=0 assert(not permissions.require(actor,'filesystem.read') and calls==1,'authorization was evaluated twice')
package.loaded['system.libraries.log'].warn=function() error('disk full') end
assert(not permissions.require(actor,'filesystem.read'),'logging failure changed denial')
for _,line in ipairs(logs) do assert(not line:find('private',1,true),'provider exception leaked into logs') end
assert(permissions.has(nil,'filesystem.read') and permissions.has({system=true},'filesystem.read'),'trusted internal actor contract changed')
print('permissions: unavailable/error/malformed provider denies, declared+session rights required, normalized sensitive reads protected, no diagnostic leak')
