package.path='./?.lua;'..package.path
keys={} for i,name in ipairs({'enter','tab','up','down','left','right','home','end','delete','backspace','escape','pageUp','pageDown','leftCtrl','rightCtrl','c','l','u'}) do keys[name]=i end
colors={white=1,gray=2,black=3,lightGray=4}
local suggestions=0
package.loaded['system.gui.renderer']={writeAt=function() end,crop=function(text,w) return text:sub(1,w) end,button=function() end}
package.loaded['system.gui.keyboard']={height=function() return 8 end,draw=function() end}
package.loaded['system.libraries.log']={error=function() end}
package.loaded['system.services.securityd']={}
package.loaded['system.dev.autocomplete']={prefix=function(text,col) return text:sub(1,col-1):match('([%w_]+)$') or '' end,
  suggest=function() suggestions=suggestions+1 return nil end}
package.loaded['system.libraries.auth_worker']={new=function() return {submit=function() return true end} end}
term={getSize=function() return 100,40 end}
local app,release,cleanup,unhooked
local ctx={pid=7,security={require=function() return true end,audit=function() end},
  windowManager={create=function(_,opts) app=opts.app return {closed=false} end},pullEvent=function() coroutine.yield() end,
  system={eventBus={on=function(_,_,fn) release=fn return 1 end,off=function() unhooked=true end}},onCleanup=function(fn) cleanup=fn end}
assert(coroutine.resume(coroutine.create(function() require('apps.terminal.main').run(ctx) end)))
app.keyboard.onText('pwd') app.cursor=2 app.keyboard.onText('X') assert(app.input=='pXwd' and app.cursor==3)
app.keyboard.onBackspace() assert(app.input=='pwd' and app.cursor==2)
app.keyboard.onEnter() assert(app.lines[#app.lines]==app.cwd and app.history[#app.history]=='pwd')
for i=1,110 do app.input='pwd' app.keyboard.onEnter() end
assert(#app.lines==200 and #app.lineIds==200 and #app.lineColors==200)
app.selection={first=app.lineIds[199],last=app.lineIds[200]} app:action('copy') assert(app.clipboard:find(app.cwd,1,true))
local completion=package.loaded['system.dev.autocomplete'] local clock=os.clock local now=1000 os.clock=function() return now end
completion.suggest=function() return {label='first',insert='first',kind='command'} end
completion.apply=function(_,_,suggestion) assert(suggestion.label=='first','Tab replaced displayed suggestion') return 'first',6 end
app.input='' app.cursor=nil app.keyboard.onText('fi') now=1002
completion.suggest=function() return {label='second',insert='second',kind='command'} end
app.keyboard.onTab() assert(app.input=='first') os.clock=clock
completion.suggest=function() suggestions=suggestions+1 return nil end
app.input='unlock ' app.cursor=nil local n=suggestions app.keyboard.onText('SECRET')
assert(suggestions==n and not app.suggestion)
local shown,private=app:visibleInput() assert(private and shown=='unlock ***')
local before=suggestions app:draw(60,22) assert(suggestions==before,'draw acquired autocomplete')
app:clearOutput() assert(#app.lines==0 and #app.lineIds==0 and #app.lineColors==0 and not app.selection)
app.input='' app.cursor=nil app.keyboard.onText(string.rep('x',5000)..'\nignored') assert(#app.input==4096)
package.loaded['system.dev.autocomplete'].suggest=function() error('broken completion provider') end
app.input='' app.cursor=nil app.keyboard.onText('still editable') assert(app.completionError and app.input=='still editable')
app.controlHeld=true release(keys.leftCtrl) assert(not app.controlHeld) cleanup() assert(unhooked)
print('Terminal input: cursor editing, metadata rollover, local output copy, private completion exclusion, cache-only draw and cleanup passed')
