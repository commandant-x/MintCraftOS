package.path='./?.lua;'..package.path
for _,name in ipairs({'system.gui.renderer','system.gui.keyboard','system.gui.components','system.dev.autocomplete'}) do package.loaded[name]={} end
package.loaded['system.libraries.log']={warn=function() end,error=function() end,info=function() end}
package.loaded['system.libraries.auth_worker']={new=function() return {} end}
local admin=false
package.loaded['system.services.securityd']={authorize=function(_,permission) return permission~='system.security.admin' or admin end}
local permissions=require('system.security.permissions')
local actor={appId='terminal',permissions={'filesystem.read','filesystem.write','system.security.admin'}}
term={getSize=function() return 51,19 end}
local opened,copied,written,deleted=0,0,0,0
local names=require('system.libraries.file_names')
fs={combine=function(a,b) return names.absolute(b:sub(1,1)=='/' and b or a..'/'..b) end,
 exists=function(path) return not path:match('output$') end,
 isDir=function(path) return path=='/system' or path=='/system/config' end,
 list=function(path) if path=='/system' then return {'config'} elseif path=='/system/config' then return {'nexus.cfg'} else return {} end end,
 open=function() opened=opened+1 return {readAll=function() return 'sensitive fixture' end,close=function() end} end,
 copy=function() copied=copied+1 end,makeDir=function() written=written+1 end,delete=function() deleted=deleted+1 end}
local app
local ctx={windowManager={create=function(_,opts) app=opts.app return {closed=false} end},pullEvent=function() coroutine.yield() end,
 security={require=function(permission,target) return permissions.require(actor,permission,target) end,audit=function() end}}
local co=coroutine.create(function() require('apps.terminal.main').run(ctx) end)
assert(coroutine.resume(co))
local function command(line) app.input=line app.keyboard.onEnter() end
command('cat ../../system/config/nexus.cfg')
command('type /system/security/users.db')
command('cp /system/config/nexus.cfg /home/user/output')
command('cp /system /home/user/output')
assert(opened==0 and copied==0,'protected read/copy reached filesystem')
admin=true command('cat /system/config/nexus.cfg') assert(opened==1,'authorized admin could not read config')
command('cp /home/user/note /system/config/output')
command('mkdir /system/config/output')
command('rm /var/backups') command('yes')
command('rm /var/tmp') command('yes')
assert(copied==0 and written==0 and deleted==0,'Terminal bypassed protected destination/checkpoint guard')
command('cp /home/user/note /home/user/output') assert(copied==1,'normal personal file copy failed')
print('Terminal data security: resolved sensitive reads, recursive copy preflight, admin access, protected writes/checkpoints and ordinary copy passed')
