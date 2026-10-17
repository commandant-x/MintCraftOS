-- Visible native runtime; all simulated nodes use in-memory storage.
local realFs=fs
local ok,err=pcall(function()
  shell.setDir('/') assert(shell.run('/source/install.lua'))
  local h=assert(realFs.open('/source/tests/nexus-coordination.lua','r')) local source=h.readAll() h.close()
  assert(load(source,'native coordinated fleet simulation','t',_ENV))()
end)
fs=realFs
local h=assert(realFs.open('/coordination-result.txt','w'))
h.write(ok and 'PASS: automatic two-agent shared-endpoint coordination, bounded polling, pause and persistence with native crypto' or 'FAIL: '..tostring(err))
h.close() os.shutdown()
