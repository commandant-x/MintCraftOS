-- Simulated read-only source protocol, permission/lease lifecycle and disk fixture.
package.path='./?.lua;'..package.path
parallel={waitForAll=function(...) for _,f in ipairs({...}) do f() end end}
local A=require('system.libraries.addon')
A.configure({readsPerTick=100000}) A.bounded=function(fn) return pcall(fn) end
A.periodic=function() return {stop=function() end} end
local now,tick,allowed,mapWrite,reads=10,1,true,true,0
os.clock=function() return now end os.getComputerID=function() return 7 end
local state=assert(loadfile('tests/storage-fixture.lua'))()()
local sourceError,pageError,missingPose,afterContext
local namespace='minecraft:overworld'
package.loaded['system.security.permissions']={require=function(_,permission) return allowed and (permission~='navigation.map.write' or mapWrite),'denied' end}
package.loaded['system.services.sabled']={pose=function() return {inSublevel=not missingPose,frame='world',timestamp=now,vehicleId='ship'} end}
local function context()
 reads=reads+1
 if sourceError then return sourceError end
 if afterContext then local fn=afterContext afterContext=nil fn() end
 return {schema=1,ok=true,readOnly=true,scope='actual-parent-world-context',vehicleId='ship',namespace=namespace,frame='world',unit='block',
  position={x=8,y=72,z=8},clock='minecraft_game_tick',clockId='server-boot',serverTick=tick,observedAtGameTick=tick,
  minimumY=-64,maximumY=320,computerId=7}
end
mintcraft_terrain={context=context,terrainPage=function(vehicle,dimension,x,y,z)
 reads=reads+1 assert(vehicle=='ship' and dimension==namespace,'namespace/vehicle guessed rather than observed')
 if pageError then return pageError end
 return {schema=1,ok=true,readOnly=true,scope='loaded-world-static-section',vehicleId=vehicle,namespace=dimension,frame='world',unit='block',origin={x=x,y=y,z=z},
  edge=16,clock='minecraft_game_tick',clockId='server-boot',serverTick=tick,observedAtGameTick=tick,complete=true,dynamicCoverage=false,
  encoding='sparse-runs-start:length:value',runs='',occupied=0}
end}
local D=require('system.services.atlasd')
local actor={pid=7}
local processes={[7]={pid=7,state='ready',meta={appId='navigation'},permissions={}},[8]={pid=8,state='ready',meta={appId='observer'},permissions={}}}
D.start({scheduler={processes=processes}})
D.acquire() assert(reads==0,'idle terrain service probed world')
assert(not D.request({pid=99})) assert(not D.request(actor,true))
assert(D.request(actor,{viewY=72}) and reads==0,'request acquired world data on UI thread')
assert(not D.request({pid=8}),'other owner replaced an active observer lease')
D.acquire() local data=assert(D.snapshot(actor))
assert(reads==2 and data.available and data.namespace==namespace and data.map.freshPages==1,'actual world context/page not observed')
local sourceReads=reads
local common=require('system.ascendancy.sources').read(actor,'atlas.terrain',now)
assert(common.available and common.frame=='world' and common.units.position=='block' and common.payload.map.dynamicCoverage==false)
assert(reads==sourceReads,'common source adapter acquired instead of reading cache')
data.map.pages['0:64:0'].cells=string.rep('\1',64)
assert(D.snapshot(actor).map.pages['0:64:0'].cells==string.rep('\0',64),'public terrain cache mutated private map')
local before=reads
allowed=false assert(not D.snapshot(actor)) D.acquire() assert(reads==before,'permission revocation still called source') allowed=true
assert(D.request(actor)) now=now+.25 tick=tick+5 D.acquire()
assert(D.snapshot(actor).available)
mapWrite=false before=0 for _ in pairs(state.nodes) do before=before+1 end
assert(not D.save(actor)) local count=0 for _ in pairs(state.nodes) do count=count+1 end assert(count==before,'map-write denial mutated disk') mapWrite=true
assert(D.save(actor)) local filename='/system/config/atlas-terrain-v1/minecraft%3aoverworld.cfg'
assert(state.nodes[filename] and #state.nodes[filename]<=65536)
local witness=state.nodes[filename]
-- Context RPC yields back into owner loss: no page read/cache update follows.
now=now+.25 tick=tick+5 afterContext=function() allowed=false end
assert(D.request(actor)) before=reads D.acquire() assert(reads==before+1,'page RPC followed revoked context owner') allowed=true
assert(D.request(actor)) now=now+.25 tick=tick+5 afterContext=function() now=now+2 end
before=reads D.acquire() assert(reads==before+1,'page RPC followed an expired observation lease')
assert(D.request(actor)) now=now+.25 tick=tick+5 sourceError={ok=false,code='BUSY',reason='budget'} D.acquire()
assert(D.status().reason=='budget') sourceError=nil
now=now+2 before=reads D.acquire() assert(reads==before,'expired observer lease still read the world')
assert(D.request(actor)) now=now+.25 tick=tick+5 missingPose=true before=reads D.acquire() assert(reads==before) missingPose=false
assert(D.request(actor)) now=now+.25 tick=tick+5 D.acquire()
assert(D.release(7)) before=reads D.acquire() assert(reads==before,'release continued observation')
assert(D.request(actor)) now=now+.25 tick=tick+5 namespace='minecraft:the_nether' D.acquire()
local nether=D.snapshot(actor) assert(nether.namespace==namespace and nether.map.count==1,'dimension caches mixed')
assert(D.save(actor)) assert(state.nodes[filename]==witness,'new dimension overwrote old map')
for i=1,30 do state.put('/system/config/atlas-terrain-v1/retained-'..i..'.cfg','personal') end
namespace='test:third' assert(D.request(actor)) now=now+.25 tick=tick+5 D.acquire()
assert(#fs.list('/system/config/atlas-terrain-v1')==32)
assert(not D.save(actor) and #fs.list('/system/config/atlas-terrain-v1')==32,'33rd map exceeded archive budget or deleted a retained file')
namespace='minecraft:the_nether'
D.stop() before=reads D.acquire() assert(reads==before)
-- Restart never treats saved observations as fresh and starts no read lease.
D.start({scheduler={processes=processes}}) before=reads D.acquire() assert(reads==before and not D.snapshot(actor).available)
assert(D.request(actor)) now=now+.25 tick=tick+5 pageError={ok=false,code='UNLOADED',reason='not loaded'} D.acquire()
assert(not D.snapshot(actor).available and D.snapshot(actor).map.count==1,'historical map or unloaded page presented as free current terrain')
processes[7].state='dead' before=reads D.acquire() assert(reads==before and not D.snapshot(actor))
print('Atlas service: explicit permission/server contexts, no idle/draw reads, actual dimension/UUID selection, immutable cache, lease/permission/owner guards across RPC yields, bounded per-world saves and historical-only restart passed')
