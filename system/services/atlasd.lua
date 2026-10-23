-- Permission-bound observation worker. UI and planners consume copies only.
local A=require('system.libraries.addon')
local C=require('system.ascendancy.contracts')
local Terrain=require('system.navigation.terrain_map')
local Sable=require('system.services.sabled')
local Permissions=require('system.security.permissions')
local SafeWrite=require('system.libraries.safe_write')
local M={}
local ctx,runner,lease,world,previousContext
local map=Terrain.new()
local reason='Terrain observer idle'
local loadedNamespace,cursor=nil,0
local folder='/system/config/atlas-terrain-v1'
local offsets={{0,0},{1,0},{0,1},{-1,0},{0,-1},{1,1},{-1,1},{-1,-1},{1,-1}}
local function authorize(actor,extra)
 if type(actor)~='table' or getmetatable(actor) or not A.finite(actor.pid) then return false,'Invalid terrain reader actor' end
 local p=ctx and actor and ctx.scheduler.processes[actor.pid]
 if not p or p.state~='ready' then return false,'Terrain reader owner not running' end
 for _,permission in ipairs({'navigation.terrain','sable.read',extra}) do
  local ok,why=Permissions.require({pid=p.pid,appId=p.meta and p.meta.appId,permissions=p.permissions},permission)
  if not ok then return false,why end
 end
 return true
end
local function currentLease(run)
 if lease~=run then return false end
 if os.clock()>run.expiresAt or not authorize({pid=run.owner}) then
  lease=nil world=nil reason='Terrain observer lease/permission lost during read' map:suspend(reason) return false
 end
 return true
end
local function poseFresh(p,now)
 return type(p)=='table' and p.inSublevel==true and p.frame=='world' and A.finite(p.timestamp) and now>=p.timestamp and now-p.timestamp<=.5
end
local function path(namespace)
 if type(namespace)~='string' or #namespace<1 or #namespace>128 then return nil,'Map namespace unavailable' end
 local name=namespace:gsub('[^%w_.%-]',function(c) return string.format('%%%02x',c:byte()) end)
 if #name>240 then return nil,'Map namespace exceeds filename budget' end
 return folder..'/'..name..'.cfg'
end
local function readArchive(namespace)
 local filename,why=path(namespace) if not filename then return nil,why end
 local recovered,problem=SafeWrite.recover(filename) if not recovered then return nil,problem end
 if not fs.exists(filename) then return nil,'No saved terrain for this dimension' end
 if fs.isDir(filename) or fs.getSize(filename)>Terrain.maxBytes then return nil,'Terrain archive input exceeds budget' end
 local h=fs.open(filename,'r') if not h then return nil,'Terrain archive unavailable' end
 local ok,text=pcall(h.readAll) pcall(h.close) if not ok then return nil,'Terrain archive read failed' end
 local restored,err=Terrain.restore(text)
 if restored and restored.namespace~=namespace then return nil,'Terrain archive namespace differs; file retained' end return restored,err
end
local function call(api,method,...)
 local args={...}
 local values,errors=A.read({value=function() return api[method](table.unpack(args)) end},{'value'},.5,{priority='diagnostics'})
 return values.value,errors.value
end
local function failure(raw,why)
 return type(raw)=='table' and tostring(raw.reason or raw.code or why):sub(1,256) or tostring(why or 'Terrain source unavailable'):sub(1,256)
end
function M.request(actor,options)
 if options~=nil and (type(options)~='table' or getmetatable(options)) then return false,'Invalid terrain observation options' end
 local ok,why=authorize(actor) if not ok then return false,why end
 local y=options and options.viewY
 if y~=nil and (not A.finite(y) or math.abs(y)>1000000) then return false,'Finite world map altitude required' end
 local now=os.clock()
 if lease and lease.owner~=actor.pid and lease.expiresAt>=now then return false,'Terrain observer already leased by another owner' end
 if not lease or lease.owner~=actor.pid then lease={owner=actor.pid} cursor=0 end
 lease.expiresAt=now+1 lease.viewY=y return true
end
function M.release(pid)
 if lease and lease.owner==pid then lease=nil reason='Terrain observation released' return true end return false
end
function M.acquire()
 local run=lease local now=os.clock()
 if not run then return end
 local allowed,why=authorize({pid=run.owner})
 if not allowed or now>run.expiresAt then
  lease=nil world=nil map:suspend(why or 'Terrain observation lease expired') reason=why or 'Terrain observation lease expired' return
 end
 local api=rawget(_G,'mintcraft_terrain')
 if type(api)~='table' or type(api.context)~='function' or type(api.terrainPage)~='function' then
  world=nil reason='Vehicle Bridge 0.4 terrain API unavailable' map:suspend(reason) return
 end
 local pose=Sable.pose()
 if not poseFresh(pose,now) then
  world=nil reason='Fresh containing Sable pose required for world terrain observation' map:suspend(reason) return
 end
 local started=os.clock() local raw,err=call(api,'context') local finished=os.clock()
 if not currentLease(run) then return end
 if type(raw)~='table' or raw.ok~=true then
  reason=failure(raw,err)
  if type(raw)~='table' or raw.code~='BUSY' then world=nil map:suspend(reason) end return
 end
 local current,problem=Terrain.context(raw,started,finished,previousContext)
 if not current or current.vehicleId~=pose.vehicleId or os.getComputerID and current.computerId~=os.getComputerID() then
  reason=problem or 'World context computer/vehicle identity differs' world=nil map:suspend(reason) return
 end
 world,previousContext=current,current
 if loadedNamespace~=current.namespace then
  local historical,issue=readArchive(current.namespace)
  map=historical or Terrain.new() loadedNamespace=current.namespace cursor=0
  if issue then reason=issue end
 end
 local y=run.viewY or current.position.y
 local oy=math.floor(y/16)*16 local ox,oz=math.floor(current.position.x/16)*16,math.floor(current.position.z/16)*16
 local index=cursor%#offsets+1 local offset=offsets[index]
 local origin={x=ox+offset[1]*16,y=oy,z=oz+offset[2]*16}
 if not currentLease(run) then return end
 started=os.clock() raw,err=call(api,'terrainPage',current.vehicleId,current.namespace,origin.x,origin.y,origin.z) finished=os.clock()
 if not currentLease(run) then return end
 if type(raw)=='table' and raw.ok==true then
  local accepted,issue=map:accept(raw,current,started,finished)
  reason=accepted and map.reason or issue
 else
  reason=failure(raw,err)
  if type(raw)~='table' or raw.code~='BUSY' then map:invalidate(origin,reason) end
  if type(raw)=='table' and (raw.code=='FORBIDDEN' or raw.code=='DIMENSION_CHANGED' or raw.code=='VEHICLE_CHANGED') then world=nil map:suspend(reason) end
 end
 if type(raw)~='table' or raw.code~='BUSY' then cursor=cursor+1 end
end
function M.snapshot(actor)
 local ok,why=authorize(actor) if not ok then return nil,why end
 local now=os.clock() local data=map:snapshot(now) local pose=Sable.pose()
 local live=world~=nil and C.fresh(world,now) and poseFresh(pose,now) and pose.vehicleId==world.vehicleId and data.vehicleId==world.vehicleId and data.namespace==world.namespace and data.sourceClockId==world.sourceClockId
 return {schema=1,source='atlasd real-terrain-cache',available=data.available and live==true,
  frame='world',unit='block',units={position='block'},namespace=data.namespace,vehicleId=data.vehicleId,
  clock='local_uptime',clockId=C.clockId(),observedAt=now,validUntil=now+.5,
  context=world and C.fresh(world,now) and A.copy(world) or nil,map=data,reason=reason,ownerPid=lease and lease.owner}
end
function M.save(actor)
 local ok,why=authorize(actor,'navigation.map.write') if not ok then return false,why end
 if map.count<1 then return false,'No real world terrain observations to save: '..reason end
 local data=map:snapshot(os.clock()) local content,err=Terrain.encode(data) if not content then return false,err end
 local filename,problem=path(data.namespace) if not filename then return false,problem end
 local recovered,issue=SafeWrite.recover(filename) if not recovered then return false,issue end
 if fs.exists(filename) then
  local previous,problem=readArchive(data.namespace) if not previous then return false,problem end
 end
 local total=0
 if fs.exists(folder) then
  if not fs.isDir(folder) then return false,'Terrain map folder conflicts with retained file' end
  local entries=fs.list(folder) if #entries>32 or #entries==32 and not fs.exists(filename) then return false,'Terrain archive file-count budget exceeded; files retained' end
  for _,name in ipairs(entries) do
   local item=folder..'/'..name
   if fs.isDir(item) then return false,'Pending or unrecognized terrain data retained' end
   if item~=filename then total=total+fs.getSize(item) end
  end
 end
 local free=fs.getFreeSpace('/')
 if total+#content>Terrain.maxBytes or free~='unlimited' and (type(free)~='number' or free<2*#content+2048) then return false,'Terrain storage budget/full disk; existing maps retained' end
 return SafeWrite.write(filename,content)
end
function M.status() return {state=lease and 'observing' or 'idle',reason=reason,pages=map.count,period=.25,controlWrites=false} end
function M.health() return M.status() end
function M.start(context)
 ctx=context lease=nil world=nil previousContext=nil loadedNamespace=nil cursor=0 map=Terrain.new() reason='Terrain observer idle'
 runner=A.periodic(ctx,'atlasd',.25,M.acquire,{priority='diagnostics'})
end
function M.stop()
 if runner then runner:stop() runner=nil end lease=nil world=nil map:suspend('Terrain observer stopped') reason='Terrain observer stopped'
end
return M
