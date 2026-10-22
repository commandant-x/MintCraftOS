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

keys={escape=1,enter=2,backspace=3,tab=4,space=5,leftCtrl=6,rightCtrl=7,a=8,c=9,v=10}
local chosen,checked='wired-a',false
local choices=Panel.new({model=function() return {page='detected',actions={},fields={
 {label='Transmitter',options={'wired-a','wired-b'},get=function() return chosen end,set=function(v) chosen=v end},
 {label='Wiring checked',kind='boolean',get=function() return checked end,set=function(v) checked=v end},
 {label='Measured mass',readOnly=true,get=function() return 65.8 end}}} end,action=function() error('field click issued application command') end})
local function draw() choices:drawPixels(Surface.new(400,300),400,300,p) end
local function click(id)
 draw()
 for _,hit in ipairs(choices.state.hits) do if hit.id==id and hit.kind=='choice' then
  return choices:handlePixels({name='mouse_click',args={1,hit.rect.x+1,hit.rect.y+1}})
 end end error('missing choice control')
end
click(1) assert(chosen=='wired-b' and not choices.state.showKeyboard)
choices:handlePixelKey({name='paste',args={'invented-peripheral'}})
choices:handlePixelKey({name='char',args={'x'}})
choices:handlePixelKey({name='key',args={keys.backspace}})
assert(chosen=='wired-b' and not next(choices.buffers),'choice accepted free text')
choices:handlePixelKey({name='key',args={keys.enter}}) assert(chosen=='wired-a')
choices:handlePixelKey({name='key',args={keys.tab}})
choices:handlePixelKey({name='key',args={keys.space}}) assert(checked)
click(2) assert(not checked)
draw() assert(#choices.state.model.fields==2 and #choices.state.model.rows==1,'measurement became editable')
for _,hit in ipairs(choices.state.hits) do assert(hit.kind~='keyboard','choice showed text keyboard') end
print('native choices: detected-value buttons, direct boolean toggles, Tab/Enter/Space, no free-text edits and read-only measurements passed')
local detected=false local manualMass,rescue=1,0
local live=Panel.new({model=function() return {page='connection',fields=detected and {
 {label='Detected mass',readOnly=true,get=function() return 65.8 end},
 {label='Rescue',kind='number',get=function() return rescue end,set=function(v) rescue=v end}} or {
 {label='Manual mass',kind='number',get=function() return manualMass end,set=function(v) manualMass=v end}}} end,action=function() end})
live:drawPixels(Surface.new(400,300),400,300,p)
live.buffers={[1]='999'} live.state.field=1 detected=true
live:handlePixelKey({name='paste',args={'123'}})
assert(not next(live.buffers) and not live.state.field and manualMass==1 and rescue==0,'connection change applied a stale draft to a different field')
print('live discovery: changed field layouts discard stale focus and pending text passed')
