package.path='./?.lua;'..package.path
colors=setmetatable({white=1},{__index=function() return 2 end})
local stored={theme='mint',keep='unchanged'}
local fail=false
package.loaded['system.libraries.config']={load=function()
  return {theme=stored.theme,keep=stored.keep}
end,save=function(_,value)
  if fail then return false,'Disk full' end stored=value return true
end}
local theme=require('system.gui.theme')
theme.load() local original=theme.current
fail=true
local ok,err=theme.set('dark')
assert(not ok and err=='Disk full' and theme.currentId=='mint' and theme.current==original and stored.theme=='mint')
fail=false assert(theme.set('dark'))
assert(theme.currentId=='dark' and theme.current~=original and stored.theme=='dark' and stored.keep=='unchanged')
theme.load() assert(theme.currentId=='dark')
print('Theme persistence: failed save preserves active palette; successful save survives reload without losing unrelated fields')
