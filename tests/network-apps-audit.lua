package.path='./?.lua;'..package.path
local now=100
local events,cleanups,requests,files,serialized={},{},{},{},{}
os.clock=function() return now end
os.epoch=function() return now*1000 end
os.queueEvent=function(...) events[#events+1]=table.pack(...) end
os.pullEvent=function(filter) return coroutine.yield(filter) end
local function copy(value)
  if type(value)~='table' then return value end
  local out={} for k,v in pairs(value) do out[k]=copy(v) end return out
end
local function serialize(value)
  local token='data:'..tostring(#serialized+1) serialized[#serialized+1]=copy(value) return token
end
textutils={serialize=serialize,serializeJSON=serialize,unserialize=function(token) return copy(serialized[tonumber(token:match('data:(%d+)'))]) end}
textutils.unserializeJSON=textutils.unserialize
fs={exists=function(path) return files[path]~=nil end,makeDir=function(path) files[path]=true end,
  getSize=function(path) return #files[path] end,getDir=function(path) return path:match('^(.*)/') or '' end,
  combine=function(a,b) return a..'/'..b end,delete=function(path) files[path]=nil end,
  open=function(path,mode)
    if mode=='r' then return {readAll=function() return files[path] end,close=function() end} end
    return {write=function(body) files[path]=body end,close=function() end}
  end}
package.loaded['system.libraries.log']={info=function() end,warn=function() end,error=function() end}
package.loaded['system.libraries.config']={load=function(_,default) return copy(default) end,save=function() return true end}
package.loaded['system.gui.renderer']={}
package.loaded['system.gui.keyboard']={}
package.loaded['system.gui.components']={toolbarHit=function(_,x) return x==1 and 'search' or x==2 and 'details' or x==3 and 'play' end}
package.loaded['system.services.audiod']={playDfPWM=function() return true end}
require('system.libraries.addon').bounded=function(fn) return pcall(fn) end
term={getSize=function() return 80,25 end}
keys={enter=28,backspace=14}
local scheduler=require('system.kernel.scheduler').new()
local app,win
local deniedURL
local ctx={pid=7,appId='audit',permissions={},args={},system={scheduler=scheduler},
  onCleanup=function(fn) cleanups[#cleanups+1]=fn end,
  security={require=function(_,url) return url~=deniedURL,'Permission denied' end},apps={launch=function() return true end},
  windowManager={create=function(_,options) app=options.app win={closed=false} return win end},
  pullEvent=function() coroutine.yield() end}
local function pump()
  while #events>0 do
    local raw=table.remove(events,1) local args={n=raw.n-1}
    for i=2,raw.n do args[i-1]=raw[i] end
    scheduler:dispatch({name=raw[1],args=args,raw=raw})
  end
end
http={get=function(options)
  requests[#requests+1]=copy(options)
  while true do
    local name,url,handle=os.pullEvent('http_success')
    if name=='http_success' and url==options.url then return handle end
  end
end}
local function respond(body,code,headers)
  local offset=1
  local handle={read=function(n) if offset>#body then return nil end local c=body:sub(offset,offset+n-1) offset=offset+#c return c end,
    close=function() end,getResponseCode=function() return code or 200 end,getResponseHeaders=function() return headers or {} end}
  local raw=table.pack('http_success',requests[#requests].url,handle)
  scheduler:dispatch({name=raw[1],args={raw[2],raw[3]},raw=raw}) pump()
end
local function launch(name)
  local thread=coroutine.create(function() require(name).run(ctx) end)
  assert(coroutine.resume(thread)) pump() return thread
end
local browserThread=launch('apps.browser.main')
app.lastW=80
local function navigate(url)
  app.address=url app.keyboard.onEnter() pump()
end
navigate('https://example.com/page')
assert(#requests==1)
respond('<title>First</title>',200,{ETag='v1',['Cache-Control']='max-age=60'})
assert(app.tabs[1].title=='First')
navigate('https://example.com/page') assert(#requests==1,'fresh cache fetched again')
now=161
navigate('https://example.com/page')
assert(#requests==2 and requests[2].headers['If-None-Match']=='v1' and requests[2].redirect==false)
respond('',304,{['Cache-Control']='max-age=60'})
assert(app.tabs[1].title=='First','304 lost cached body')
app:handle({name='mouse_click',args={1,5,2}})
assert(#requests==2,'Reload blocked UI') pump()
assert(#requests==3 and not requests[3].headers['If-None-Match'] and requests[3].headers['Cache-Control']=='no-cache')
respond('<title>Reloaded</title>',200,{['Cache-Control']='no-store'})
navigate('https://example.com/page') assert(#requests==4,'no-store cached')
respond('<title>Private</title>',200,{['Cache-Control']='max-age=60'})
app.tabs[1].private=true
navigate('https://example.com/page') assert(#requests==5,'private tab reused disk cache')
respond('<title>Private</title>')
app.tabs[1].private=false
navigate('https://example.com/modified')
respond('<title>Modified</title>',200,{['Last-Modified']='Wed, 01 Jan 2025 00:00:00 GMT',['Cache-Control']='no-cache'})
navigate('https://example.com/modified')
assert(requests[#requests].headers['If-Modified-Since']=='Wed, 01 Jan 2025 00:00:00 GMT')
respond('',304,{['Cache-Control']='no-cache'})
local prior=#requests
navigate('https://example.com/modified') assert(#requests==prior+1,'no-cache response treated as fresh')
respond('<title>Modified again</title>',200,{['Cache-Control']='no-store'})
local collisionA='https://example.com/a?b=x'
local collisionB='https://example.com/a/b=x'
navigate(collisionA) respond('<title>A</title>',200,{['Cache-Control']='max-age=60'})
prior=#requests navigate(collisionB) assert(#requests==prior+1,'cache key collision leaked different URL body')
respond('<title>B</title>',200,{['Cache-Control']='max-age=60'})
deniedURL='https://denied.test/'
navigate('https://example.com/redirect') prior=#requests
respond('',302,{Location=deniedURL})
assert(#requests==prior and app.tabs[1].page.errorCode=='BRW-003','redirect bypassed permission check')
deniedURL=nil
navigate('https://example.com/oversize')
respond(string.rep('x',524289))
assert(app.tabs[1].page.errorCode=='BRW-002','oversized page bypassed bounded read')
for _,fn in ipairs(cleanups) do fn() end cleanups={}
win.closed=true assert(coroutine.resume(browserThread))
ctx.appId='crafttube'
local base=#requests
local tubeThread=launch('apps.crafttube.main')
app.input='test'
app.keyboard.onEnter()
assert(#requests==base,'search blocked UI') pump() assert(#requests==base+1)
respond(serialize({{videoId='abcdefghijk',title='Example'}}))
assert(#app.rows==1 and app.selected=='abcdefghijk')
app:handle({name='mouse_click',args={1,2,1}})
assert(#requests==base+1,'details blocked UI') pump() assert(#requests==base+2)
respond(serialize({videoId='abcdefghijk',title='Details'}))
assert(app.rows[1].title=='Details')
app:handle({name='mouse_click',args={1,3,1}})
assert(#requests==base+2,'audio blocked UI') pump()
assert(#requests==base+3 and requests[#requests].binary==true)
respond('dfpwm')
assert(app.status=='Playing Details')
app.input='pending' app.keyboard.onEnter() pump()
assert(#requests==base+4)
local before=app.status
for _,fn in ipairs(cleanups) do fn() end
respond(serialize({{videoId='abcdefghijk',title='Late'}}))
assert(app.status==before,'closed worker updated UI')
win.closed=true assert(coroutine.resume(tubeThread))
print('Browser TTL/revalidation/Reload/private cache and CraftTube native async worker regressions passed')
