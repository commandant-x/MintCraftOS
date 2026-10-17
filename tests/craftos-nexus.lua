-- Visible CraftOS-PC, disposable storage only; eight mocked machines, native Lua/crypto.
local realFs=fs
local saved={}
for _,key in ipairs({'clock','epoch','getComputerID','getComputerLabel'}) do saved[key]=os[key] end
local ok,err=pcall(function()
  shell.setDir('/') assert(shell.run('/source/install.lua'))
  local h=assert(fs.open('/source/tests/nexus.lua','r')) local source=h.readAll() h.close()
  assert(load(source,'native NEXUS eight-computer simulation','t',_ENV))()
end)
fs=realFs
for key,value in pairs(saved) do os[key]=value end
local h=assert(realFs.open('/nexus-result.txt','w'))
h.write(ok and 'PASS: native CC crypto, eight-computer bootstrap/enrollment, independent startup, read-only jobs, replay protection and uninstall' or 'FAIL: '..tostring(err))
h.close()
os.shutdown()
