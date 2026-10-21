package.path='./?.lua;'..package.path
local captured
local env={assert=assert,print=function() end,load=function(_,name)
  assert(name=='installer')
  return function() return {install=function(files) captured=files return true end} end
end}
assert(loadfile('install.lua','t',env))()
assert(type(captured)=='table','Installer did not expose its bundle to transactional installer')
local count=0
for path,content in pairs(captured) do
  local file=assert(io.open(path,'rb'),'Bundled source missing: '..path)
  local source=file:read('*a'):gsub('\r\n','\n') file:close()
  local decoded=require('system.libraries.packed_source').unpack(content)
  source=require('system.libraries.packed_source').unpack(source)
  assert(source==decoded,'Stale installer payload: '..path..'; regenerate tools/build-installer.ps1')
  count=count+1
end
for _,path in ipairs({'VERSION','boot.lua','startup.lua','system/libraries/installer.lua','apps/devices/main.lua','apps/devices/model.lua','apps/devices/pixel.lua','apps/settings/pixel.lua','system/services/settingsd.lua','apps/messenger/pixel.lua'}) do
  assert(captured[path],'Required release file omitted: '..path)
end
assert(count>100,'Unexpectedly incomplete installer')
assert(captured['apps/editor/editing.lua'] and captured['apps/editor/pixel.lua'],'Required native Editor modules missing')
assert(captured['apps/terminal/pixel.lua'],'Required native Terminal module missing')
print('installer bundle: every embedded source matches the release tree; required Devices/Settings modules present')
