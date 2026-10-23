-- Synthetic cached map drawing. No source acquisition is allowed during draw.
package.path='./?.lua;'..package.path
local now=10 os.clock=function() return now end
local C=require('system.ascendancy.contracts')
local Pilot=require('apps.navigation.pilot')
local Surface=require('system.graphics.surface')
local p={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8,danger=14}
local saves=0
local panel=Pilot.new({saveMap=function() saves=saves+1 return false,'disk full; maps retained' end})
local pose={timestamp=10,frame='world',vehicleId='ship',logicalPose={position={x=0,y=70,z=0}}}
local clock={clock='local_uptime',clockId=C.clockId(),observedAt=10,validUntil=15}
local page={origin={x=0,y=64,z=0},namespace='minecraft:overworld',cells=string.char(1)..string.rep('\0',63)}
for k,v in pairs(clock) do page[k]=v end
local atlas={available=true,map={type='atlas-static-terrain',frame='world',unit='block',namespace='minecraft:overworld',pages={page}},reason='Static terrain only'}
for k,v in pairs(clock) do atlas[k]=v end
local state={state='disarmed',targets={altitude=65}}
panel:refresh(state,{altitude=70},pose,atlas) panel:action('map')
local surface=Surface.new(400,330) panel:drawPixels(surface,400,330,p)
assert(saves==0 and surface.rows[167]:byte(204)==14,'conservative occupied cell not drawn from cache')
assert(surface.rows[174]:byte(210)==7,'observed static free cell not distinguished from unknown')
now=16 surface=Surface.new(400,330) panel:drawPixels(surface,400,330,p)
assert(surface.rows[174]:byte(210)==15,'stale terrain painted as free')
now=10 page.invalidated=true surface=Surface.new(400,330) panel:drawPixels(surface,400,330,p)
assert(surface.rows[174]:byte(210)==15,'invalidated/unloaded terrain painted as free')
for _,size in ipairs({{156,180},{210,220},{400,330}}) do
 panel:drawPixels(Surface.new(size[1],size[2]),size[1],size[2],p)
 for _,hit in ipairs(panel.hits) do local r=hit.rect assert(r.x>=0 and r.y>=0 and r.x+r.w<=size[1] and r.y+r.h<=size[2]) end
end
panel:action('saveMap') assert(saves==1 and panel.message=='disk full; maps retained','native save dropped refusal reason')
fs=setmetatable({},{__index=function() error('filesystem acquisition in map draw') end}) peripheral=fs mintcraft_terrain=fs
panel:drawPixels(Surface.new(400,330),400,330,p)
assert(saves==1)
print('Atlas native pilot: cached conservative/free/unknown colors, stale/unloaded refusal, responsive STOP/save hits, actual save error and no draw IO passed')
