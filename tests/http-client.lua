package.path="./?.lua;"..package.path
package.loaded["system.libraries.log"]={info=function() end,warn=function() end,error=function() end}
local client=require("system.network.http_client")
local closed=0
http={get=function() return {readAll=function() error('closed response') end,close=function() closed=closed+1 end} end}
local response,err=client.get('https://example.com')
assert(not response and err:find('RESPONSE_READ_FAILED',1,true) and closed==1)
http.get=function() return nil,'DNS lookup failed',{close=function() closed=closed+1 end} end
response,err=client.get('https://example.com')
assert(not response and err:find('DNS_ERROR',1,true) and closed==2,'native failure reason/handle lost')
http.get=function() return {readAll=function() return 'ok' end,getResponseCode=function() return 200 end,close=function() closed=closed+1 end} end
response=assert(client.get('https://example.com')) assert(response.body=='ok' and closed==3)
print('HTTP response reads, native failure details and handle cleanup passed')
