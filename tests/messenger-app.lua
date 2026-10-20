package.path='./?.lua;'..package.path
keys={escape=1,tab=2,enter=3,backspace=4,pageUp=5,pageDown=6}
colors={black=1,lightGray=2,red=3,white=4,gray=5}
package.loaded['system.gui.renderer']={writeAt=function() end,crop=function(text,w) return text:sub(1,w) end,button=function() end}
package.loaded['system.gui.keyboard']={height=function() return 8 end,draw=function() end,handle=function() return false end}
local reads,sends,opens=0,0,0 local packets={} local sequence=0
package.loaded['system.services.messaged']={snapshot=function(after)
  reads=reads+1 local rows={} for _,row in ipairs(packets) do if row.sequence>after then rows[#rows+1]=row end end
  return {sequence=sequence,messages=rows,status='ready',securityWarning='Public insecure'}
end,open=function() opens=opens+1 return true,'left' end,send=function(text) sends=sends+1 return true,'sent' end}
local perform,finished,request,cleanup
package.loaded['system.libraries.app_worker']={new=function(_,_,work,done)
  perform,finished=work,done return {submit=function(_,value) request=value return true end}
end}
term={getSize=function() return 100,40 end}
local permitted=true local app
local ctx={pid=7,appId='messenger',permissions={'rednet.send','rednet.receive'},
  security={require=function(permission,target) assert(type(permission)=='string' and target=='Messenger') return permitted,'permission denied' end},system={},
  onCleanup=function(fn) cleanup=fn end,startTimer=function() return 1 end,cancelTimer=function() end,
  windowManager={create=function(_,opts) app=opts.app return {closed=true} end}}
require('apps.messenger.main').run(ctx)
assert(request.action=='rescan' and sends==0 and opens==0,'startup did synchronous transport')
local function finish() local job=request request=nil local result=table.pack(pcall(perform,job)) finished(job,table.unpack(result,1,result.n)) end
finish() assert(opens==1 and not app.busy)
local before=reads app:draw(60,22) assert(reads==before,'draw acquired inbox')
sequence=1 packets={{sequence=1,from='Remote',text='hello'}} app:sync() app:sync() assert(#app.messages==1,'cached message duplicated')
app.input='first draft' app:action('send') assert(app.busy and sends==0)
app.input='edited while pending' finish()
assert(sends==1 and app.input=='edited while pending' and app.messages[2].text=='first draft','in-flight send destroyed draft or changed payload')
app.input='second' app:action('send') permitted=false finish()
assert(sends==1 and app.input=='second' and app.operationError,'queued permission revocation ignored')
permitted=true app:action('clear') assert(#app.messages==0) app:sync() assert(#app.messages==0,'clear replayed old inbox')
for i=1,100 do app:append('sender','bounded') end assert(#app.messages==80)
app.keyboard.onText(string.rep('x',5000)) assert(#app.input==4096)
cleanup()
print('Messenger app: worker-only transport, cache-only draw, stable receive cursor, retained concurrent draft, permissions and bounds passed')
