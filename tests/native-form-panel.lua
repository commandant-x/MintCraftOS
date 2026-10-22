package.path='./?.lua;'..package.path
local Panel=require('system.graphics.form_client')
local Surface=require('system.graphics.surface')
local value,flag,commands,errorText=4,false,{},nil
local p={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
local panel=Panel.new({urgent={id='stop',label='STOP'},error=function(s) errorText=s end,
 model=function() return {page='fields',fields={{label='Gain',kind='number',get=function() return value end,set=function(v) value=v end},{label='Validated',kind='boolean',get=function() return flag end,set=function(v) flag=v end}},actions={{id='save',label='Save'}}} end,
 action=function(id) commands[#commands+1]=id end})
panel:drawPixels(Surface.new(300,240),300,240,p)
panel.buffers={[1]='invalid',[2]='true'} assert(not panel.commit() and value==4 and not flag and errorText)
assert(panel:handlePixels({name='mouse_click',args={1,5,5}})) assert(commands[1]=='stop' and value==4,'bad input blocked STOP')
panel.buffers={[1]='5.5',[2]='true'} assert(panel.commit() and value==5.5 and flag)
print('native form panel: numeric/boolean controls, atomic validation and always-visible STOP independent of edits passed')

keys={escape=1}
panel.buffers={[1]='bad'}
assert(panel:handlePixelKey({name='key',args={keys.escape}}))
assert(not next(panel.buffers),'Escape did not discard invalid native draft')
