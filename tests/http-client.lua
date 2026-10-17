package.path="./?.lua;"..package.path
package.loaded["system.libraries.log"]={info=function() end,warn=function() end,error=function() end}
local client=require("system.network.http_client")
local closed=0
http={get=function() return {read=function() error('closed response') end,close=function() closed=closed+1 end} end}
local response,err=client.get('https://example.com')
assert(not response and err:find('RESPONSE_READ_FAILED',1,true) and closed==1)
http.get=function() return nil,'DNS lookup failed',{close=function() closed=closed+1 end} end
response,err=client.get('https://example.com')
assert(not response and err:find('DNS_ERROR',1,true) and closed==2,'native failure reason/handle lost')
local function handle(body,code)
  local offset=1
  return {readAll=function() error('unbounded read forbidden') end,read=function(n)
    assert(n<=8192) if offset>#body then return nil end
    local chunk=body:sub(offset,offset+n-1) offset=offset+#chunk return chunk
  end,getResponseCode=function() return code or 200 end,close=function() closed=closed+1 end}
end
http.get=function(options)
  assert(options.binary==true and options.redirect==false and options.timeout==3)
  return handle('ok')
end
response=assert(client.get('https://example.com',{binary=true,redirect=false,timeout=3})) assert(response.body=='ok' and closed==3)
http.get=function() return handle(string.rep('x',100000)) end
response,err=client.get('https://example.com',{maxBytes=100})
assert(not response and err:find('byte limit',1,true) and closed==4)
http.get=function() return nil,'Not Modified',handle('',304) end
response=assert(client.get('https://example.com',{allowStatus={[304]=true}}))
assert(response.code==304 and closed==5)
local opts={headers={Accept='test'},binary=true}
http.post=function(options) assert(options.body=='payload' and options.method=='POST' and options.binary) return handle('posted') end
assert(client.post('https://example.com','payload',opts).body=='posted' and opts.body==nil)
assert(not client.get('https://example.com',{maxBytes=math.huge}))
local before=closed
assert(client.readResponse(handle('1234'),4).body=='1234')
assert(not client.readResponse(handle('12345'),4))
assert(not client.readResponse({read=function() return false end,close=function() closed=closed+1 end},4))
assert(not client.readResponse({read=function() return nil end,getResponseCode=function() error('metadata failed') end,
  close=function() closed=closed+1 end},4))
assert(closed==before+4, 'shared reader leaked a response')
print('HTTP response reads, native failure details and handle cleanup passed')
