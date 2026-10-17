local wire=require('system.nexus.protocol')
local M={}
function M.generate()
  assert(http and http.get,'Automatic key creation needs HTTPS; enable HTTP or enter a private key')
  local response,err=http.get({url='https://www.random.org/integers/?num=32&min=0&max=255&col=1&base=16&format=plain&rnd=new',timeout=8,redirect=false})
  assert(response,'Random source unavailable: '..tostring(err))
  local ok,value=pcall(function()
    assert(response.getResponseCode()==200,'Random source returned an error')
    local data=response.read(4096)
    assert(type(data)=='string' and #data<4096,'Invalid random response')
    local bytes={}
    for token in data:gmatch('%S+') do
      assert(#token<=2 and token:match('^[0-9a-fA-F]+$'),'Invalid random response')
      bytes[#bytes+1]=string.char(tonumber(token,16))
    end
    assert(#bytes==32,'Invalid random response')
    data=table.concat(bytes)
    local localBytes={}
    for i=1,32 do localBytes[i]=string.char(math.random(0,255)) end
    return wire.hash('NEXUS master v1:'..data..table.concat(localBytes))
  end)
  response.close()
  assert(ok,value)
  return value
end
return M
