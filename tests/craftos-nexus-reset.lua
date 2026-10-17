-- Full reset tests use an in-memory filesystem, never the real mounted disk.
local realFs=fs
local ok,err=pcall(function()
  shell.setDir('/') assert(shell.run('/source/install.lua'))
  local h=assert(realFs.open('/source/tests/nexus-reset.lua','r')) local source=h.readAll() h.close()
  assert(load(source,'native reset fault simulation','t',_ENV))()
end)
fs=realFs
local h=assert(realFs.open('/reset-result.txt','w'))
h.write(ok and 'PASS: simulated internal reset, ROM/external mounts retained, selection, payload guards, interruptions and one-shot semantics' or 'FAIL: '..tostring(err))
h.close() os.shutdown()
