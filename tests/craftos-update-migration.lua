-- Real previous updater -> current pinned protocol-2 bundle, isolated disk only.
local ok,err=pcall(function()
  shell.setDir('/') assert(shell.run('/old/install.lua'))
  local updated=require('system.services.updated')
  local oldVersion=updated.localVersion()
  local function read(path) local h=assert(fs.open(path,'r')) local data=h.readAll() h.close() return data end
  local installer=read('/source/install.lua') local wanted=read('/source/VERSION'):gsub('%s+$','')
  assert(oldVersion~=wanted,'Previous release fixture is not older')
  local note=assert(fs.open('/home/user/migration-note.txt','w')) note.write('preserve me') note.close()
  local cfg=require('system.libraries.config') cfg.save('/system/config/custom-migration.cfg',{custom=true})
  local sha=string.rep('a',40)
  http={get=function(url)
    local body=url:find('api.github.com',1,true) and textutils.serializeJSON({sha=sha}) or url:find('install.lua',1,true) and installer or wanted
    local offset=1
    return {read=function(n) local part=body:sub(offset,offset+n-1) offset=offset+#part if part~='' then return part end end,
      getResponseCode=function() return 200 end,close=function() end}
  end}
  local before=fs.getFreeSpace('/')
  local installed,message=updated.apply()
  assert(installed,'Migration failed with '..tostring(before)..' free bytes: '..tostring(message))
  assert(updated.localVersion()==wanted and read('/home/user/migration-note.txt')=='preserve me')
  assert(cfg.load('/system/config/custom-migration.cfg',{}).custom==true)
  assert(updated.rollback()) assert(updated.localVersion()==oldVersion,'Previous updater rollback failed')
  assert(read('/home/user/migration-note.txt')=='preserve me')
end)
local h=assert(fs.open('/migration-result.txt','w')) h.write(ok and 'PASS: previous released updater installs current bundle and rolls back while retaining user files/config' or 'FAIL: '..tostring(err)) h.close()
os.shutdown()
