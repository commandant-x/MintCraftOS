-- Run from CraftOS after STOP. Restore older code without expanding equivalent sources.
local sha=...
assert(type(sha)=='string' and #sha==40 and sha:match('^[0-9a-fA-F]+$'),'Usage: rollback-compatible <40-character commit SHA>')
local core='/system/libraries/installer_v2.lua'
assert(fs.exists(core) and not fs.isDir(core),'Install MintCraft 0.18.87 or newer before using compatible rollback')
local installer=assert(loadfile(core))()
assert(type(installer)=='table' and installer.equivalentSourcePreparation==true,'Compatible transaction implementation missing')
local base='https://raw.githubusercontent.com/commandant-x/MintCraftOS/'
local function fetch(url)
 local response,problem,failure=http.get(url,nil,false)
 if not response and failure then pcall(failure.close) end
 assert(response,tostring(problem))
 local ok,data=pcall(function()
  assert(type(response.read)=='function','Bounded HTTP reads unavailable')
  local chunks,size={},0
  while true do
   local chunk=response.read(math.min(8192,4194304-size+1))
   if chunk==nil or chunk=='' then break end
   if type(chunk)=='number' then chunk=string.char(chunk) end
   assert(type(chunk)=='string','Invalid HTTP body') size=size+#chunk
   assert(size<=4194304,'Rollback download oversized') chunks[#chunks+1]=chunk
  end
  return table.concat(chunks)
 end) pcall(response.close)
 assert(ok and type(data)=='string','Rollback download unavailable or oversized') return data
end
sha=sha:lower()
local data=fetch(base..sha..'/install.lua')
assert(data:find('-- MintCraft installer protocol: 2',1,true),'Unsupported rollback installer protocol')
-- Capture a generated payload in a restricted environment. Never execute its old installer.
local captured
local environment={assert=assert,print=function() end,load=function()
 return function() return {install=function(files) assert(not captured,'Duplicate payload') captured=files end} end
end}
assert(load(data,'@rollback-payload','t',environment))()
assert(type(captured)=='table' and type(captured.VERSION)=='string' and #captured.VERSION<128 and captured.VERSION:match('^%d+%.%d+%.%d+%s*$'),'Invalid rollback payload/version')
-- The published 0.18.86 flight loop exceeds Cobalt's 60-capture limit. Its
-- pinned compatibility artifact only groups private dependencies/state; it
-- restores 0.18.86 behaviour while retaining that interpreter fix.
if sha=='623e07685788b15b811440da3474ca440191fe6e' then
 assert(captured.VERSION:gsub('%s+$','')=='0.18.86' and type(captured['system/services/flightd.lua'])=='string','Unexpected compatibility target')
 local compatible=fetch(base..'a793160126533187717f1ee8795a234b0221e79c/tools/compat/flightd-0.18.86.packed')
 assert(compatible:sub(1,#'-- MintCraft packed source 2\n')=='-- MintCraft packed source 2\n','Invalid Cobalt compatibility artifact')
 captured['system/services/flightd.lua']=compatible
 print('Keeping the Cobalt-compatible 0.18.86 flight loop.')
end
-- Format-3 code retains compatible additive loaders and the transaction engine.
-- Application bodies revert; decoder support must survive their compact wrappers.
if fs.exists('/system/libraries/packed_source_v3.lua') then
 assert(installer.retainsEquivalentPackedSources==true,'Use the current MintCraft installer before this rollback')
 for _,path in ipairs({'system/libraries/packed_source.lua','system/libraries/packed_source_v3.lua','system/libraries/installer_v2.lua'}) do
  local h=assert(fs.open('/'..path,'r')) captured[path]=h.readAll() h.close()
 end
 print('Keeping compatible compact-source loaders and recovery transactions.')
end
print('Restoring code '..captured.VERSION:gsub('%s+$','')..'; personal files are preserved.')
local phase
assert(installer.install(captured,{onProgress=function(name)
 if name~=phase then phase=name print(name) end
end}))
print('Code restored. Reboot to load the restored version.')
