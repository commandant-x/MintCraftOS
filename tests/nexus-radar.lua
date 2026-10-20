package.path='./?.lua;'..package.path
local radar=require('system.nexus.radar') local hub=require('system.nexus.radar_hub')
local now=100 os.epoch=function() return now*1000 end
local scans,calls,bridge=1,{},true
peripheral={hasType=function(name,kind) return (name=='right' or name=='radar_2') and kind=='create_radar:radar_bearing' end,
  getMethods=function() return {'getTracks','getScanGeometry','setTarget','fire','reboot'} end,
  call=function(name,method)
    calls[#calls+1]=method assert(method=='getTracks' or method=='getScanGeometry','unsafe radar probe')
    if method=='getScanGeometry' then
      if not bridge then error('geometry unavailable') end
      return {version=1,positionFrame='world',position={x=10,y=64,z=20},headingFrame='world',heading=35,range=1000,fov=45,running=false}
    end
    local tracks={} for i=1,20 do tracks[i]={id='contact-'..i,name='Player '..i,position={x=i,y=64,z=40},scannedTime=scans,category='player'} end return tracks
  end}
local sample=assert(radar.read('right'))
assert(sample.position.x==10 and sample.heading==35 and sample.fov==45 and sample.running==false)
assert(#sample.targets==12 and sample.partial and sample.total==20)
assert(not radar.read('unknown'))
assert(hub.accept(12,sample,now,now))
local snapshot=hub.snapshot(now)
assert(#snapshot.radars==1 and #snapshot.targets==12 and snapshot.targets[1].remote and snapshot.targets[1].stale)
snapshot.radars[1].position.x=999 assert(hub.snapshot(now).radars[1].position.x==10,'snapshot mutated cache')
assert(not hub.accept(12,sample,now,now),'same sample replay accepted')
scans=2 now=101 sample=assert(radar.read('right')) assert(hub.accept(12,sample,now,now))
assert(hub.snapshot(now).targets[1].freshnessKnown and not hub.snapshot(now).targets[1].stale)
now=107 assert(hub.snapshot(now).targets[1].stale,'stale source remained fresh')
now=112 assert(#hub.snapshot(now).radars==0,'disconnected source retained forever')
bridge=false sample=assert(radar.read('right')) assert(not sample.position and sample.frame=='unknown' and sample.errors.getScanGeometry)
assert(hub.accept(12,sample,now,now)) assert(not hub.snapshot(now).radars[1].position,'fabricated world origin')
hub.restrict({}) assert(#hub.snapshot(now).radars==0,'revoked association retained radar')
sample.measuredAt=now-6 assert(not hub.accept(12,sample,now,now))
sample.measuredAt=now+2 assert(not hub.accept(12,sample,now,now))
sample.measuredAt=now sample.group='world-a' assert(hub.accept(12,sample,now,now))
hub.restrict({['12']={group='world-b'}},'world-b') assert(#hub.snapshot(now).radars==0,'group change retained old coordinate domain')
sample.group='world-b' sample.targets={}
for id=1,16 do for index=1,8 do sample.name='radar_'..index assert(hub.accept(id,sample,now,now)) end end
sample.name='overflow' assert(not hub.accept(17,sample,now,now),'radar cache limit bypassed')
assert(#hub.snapshot(now).radars==128)
hub.clear()
print('NEXUS radar: read-only adapter, source geometry, bounded contacts, scan progression, stale expiry, cache isolation and association revocation passed')
