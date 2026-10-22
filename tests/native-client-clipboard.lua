package.path='./?.lua;'..package.path
keys={a=10,leftCtrl=1,rightCtrl=2,c=3,v=4,escape=5,enter=6,backspace=7,up=8,down=9}
package.loaded['system.services.securityd']={sessionRevision=function() return 1 end,isLocked=function() return false end,authorize=function() return true end}
local clipboard=require('system.graphics.clipboard')
local Client=require('system.graphics.client')
local value,secret='shared field','do not copy'
local app={graphicsActive=true}
local state=Client.attach(app,{model=function() return {fields={{id='plain',value=value},{id='secret',value=secret,secret=true}}} end,
 input=function(id,v) if id=='plain' then value=v else secret=v end end,action=function() end})
local function key(name,v) return app:handlePixelKey({name=name,args={v}}) end
state.field='plain' assert(key('key',keys.leftCtrl)) assert(key('key',keys.c)) assert(clipboard.get()=='shared field')
state.field='secret' assert(key('key',keys.c)) assert(clipboard.get()=='shared field','secret field copied')
assert(clipboard.set('paste text')) assert(key('key',keys.v)) assert(secret=='do not copypaste text')
key('key_up',keys.leftCtrl)
print('native clipboard controls: shared field copy/paste, secret copy rejection and control-key release passed')

state.field='plain' key('key',keys.leftCtrl) key('key',keys.a) key('key_up',keys.leftCtrl)
assert(key('char','replacement')) assert(value=='replacement','Ctrl+A did not replace native field content')
