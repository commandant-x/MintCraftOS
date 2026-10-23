-- Synthetic protocol fixtures, never installed world observations.
package.path='./?.lua;'..package.path
local A=require('system.libraries.addon')
local C=require('system.ascendancy.contracts')
local T=require('system.navigation.terrain_map')
local context={schema=1,ok=true,readOnly=true,scope='actual-parent-world-context',frame='world',unit='block',namespace='minecraft:overworld',vehicleId='ship',
 clock='minecraft_game_tick',clockId='server-boot',serverTick=1,observedAtGameTick=100,minimumY=-64,maximumY=320,computerId=7,position={x=8,y=72,z=8}}
local ctx=assert(T.context(context,10,10))
local synthetic=A.copy(context) synthetic.synthetic=true assert(not T.context(synthetic,10,10),'synthetic context laundered into real source')
local raw={schema=1,ok=true,readOnly=true,scope='loaded-world-static-section',frame='world',unit='block',namespace=context.namespace,vehicleId='ship',
 clock='minecraft_game_tick',clockId='server-boot',serverTick=1,observedAtGameTick=100,origin={x=0,y=64,z=0},edge=16,complete=true,dynamicCoverage=false,
 encoding='sparse-runs-start:length:value',runs='0:1:1;',occupied=1}
local map=T.new() assert(map:accept(raw,ctx,10,10))
assert(map:query(0,64,0,10)=='blocked' and map:query(3.9,67.9,3.9,10)=='blocked','small occupied block lost conservative 4m extent')
assert(map:query(4,64,0,10)=='free' and map:query(16,64,0,10)=='unknown')
assert(map:query(4,64,0,15.01)=='unknown' and map:query(1e308,1,0,10)=='unknown')
assert(map:boxFree({x=4,y=64,z=0},{x=8,y=68,z=4},10))
assert(not map:boxFree({x=0,y=64,z=0},{x=4,y=68,z=4},10))
assert(not map:boxFree({x=4,y=64,z=0},{x=20,y=68,z=4},10),'unknown space approved as free')
assert(not map:boxFree({x=1e308,y=1,z=0},{x=1e308,y=2,z=1},10),'unbounded numeric loop accepted')
assert(not map:accept(raw,ctx,11,11),'replay refreshed a page')
for _,change in ipairs({function(p)p.synthetic=true end,function(p)p.valid=false end,function(p)p.scope='body_plot'end,function(p)p.frame='body_plot'end,function(p)p.namespace='minecraft:the_nether'end,
 function(p)p.clockId='other-boot'end,function(p)p.vehicleId='other'end,function(p)p.complete=false end,function(p)p.dynamicCoverage=true end,
 function(p)p.origin.x=1 end,function(p)p.origin.x=256 end,function(p)p.runs='0:2:1;1:1:1;'end,function(p)p.runs='0:4097:1;'end,
 function(p)p.runs='0:1:2;'end,function(p)p.runs='0:1:1;garbage'end,function(p)p.occupied=2 end}) do
 local p=A.copy(raw) p.serverTick=2 change(p)
 local ok,accepted=pcall(map.accept,map,p,ctx,10.1,10.1) assert(ok and not accepted,'invalid world page accepted/crashed')
 assert(map:query(0,64,0,10.1)=='blocked','bad page damaged valid same-world data')
end
local invalid=A.copy(ctx) invalid.minimumY=nil
assert(not map:accept(raw,invalid,10,10),'malformed context accepted')
assert(not T.context(context,10,10,ctx),'duplicate world context clock refreshed')
local copy=map:snapshot(10) copy.pages['0:64:0'].cells=string.rep('\0',64)
assert(map:query(0,64,0,10)=='blocked','public map mutated private occupancy')
map:invalidate(raw.origin,'world chunk unloaded') assert(map:query(4,64,0,10)=='unknown','explicit unloaded result retained free space')
raw.serverTick=2 assert(map:accept(raw,ctx,10.2,10.2))
-- Persistent data are historical even if restored during the same local boot.
assert(loadfile('tests/storage-fixture.lua'))()()
local encoded=assert(T.encode(map:snapshot(10.2)))
local fake=map:snapshot(10.2) fake.synthetic=true assert(not T.encode(fake) and not T.restore(textutils.serialize(fake)),'synthetic archive accepted as real terrain')
local malformed=map:snapshot(10.2) malformed.pages={['0:64:0']=false}
assert(not T.restore(textutils.serialize(malformed)),'malformed archive page crashed or was accepted')
local restored=assert(T.restore(encoded))
assert(restored:query(4,64,0,10.2)=='unknown','restored map was promoted to a live observation')
raw.serverTick=3 assert(restored:accept(raw,ctx,10.3,10.3)) assert(restored:query(4,64,0,10.3)=='free')
assert(not T.restore(string.rep('x',T.maxBytes+1)))
for x=-4,4 do for z=-4,4 do
 local p=A.copy(raw) p.origin.x=x*16 p.origin.z=z*16 p.serverTick=100+x*9+z+50
 assert(restored:accept(p,ctx,10.4,10.4))
end end
assert(restored.count==64 and #assert(T.encode(restored:snapshot(10.4)))<=65536,'terrain cache/storage budget exceeded')
local other=A.copy(context) other.namespace='minecraft:the_nether' other.serverTick=500
local nc=assert(T.context(other,11,11,ctx)) local np=A.copy(raw) np.namespace=other.namespace np.serverTick=500
assert(restored:accept(np,nc,11,11) and restored.count==1,'dimension change mixed world maps')
restored:suspend('permission lost') assert(restored:query(4,64,0,11)=='unknown')
fs=setmetatable({},{__index=function() error('IO in terrain query') end}) peripheral=fs
assert(restored:query(4,64,0,11)=='unknown')
print('Terrain map: actual-world scope/clock/namespace validation, conservative 4m occupancy, stale/unloaded/unknown refusal, bounded volumes/pages/storage, immutable copies, historical restore and no query IO passed')
