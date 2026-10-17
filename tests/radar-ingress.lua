package.path='./?.lua;'..package.path
local addon=require('system.libraries.addon')
local crypto=require('system.libraries.password_crypto')
local now,computer,macs,decodes=10,1,0,0
local nativeClock=os.clock
local events={}
os.queueEvent=function(...) events[#events+1]=table.pack(...) end
os.pullEvent=function(filter) return coroutine.yield(filter) end
os.clock=function() return now end
os.epoch=function() return (1000000+now)*1000 end
os.getComputerID=function() return computer end
os.getComputerLabel=function() return 'Ingress test' end
local cfg={enabled=true,publish=false,sharedKey='a sufficiently long shared test key',
  group='world-A',trusted={['2']=true},x=0,y=0,z=0,radius=100,alerts=false}
package.loaded['system.libraries.config']={load=function() return addon.copy(cfg) end}
package.loaded['system.libraries.log']={warn=function() end}
local function encode(value)
  if type(value)=='string' then return string.format('%q',value) end
  if type(value)~='table' then return tostring(value) end
  local fields={}
  for key,item in pairs(value) do fields[#fields+1]='['..encode(key)..']='..encode(item) end
  return '{'..table.concat(fields,',')..'}'
end
textutils={serialize=encode,unserialize=function(value)
  decodes=decodes+1 return assert(load('return '..value,'wire','t',{}))()
end}
local original=crypto.mac
crypto.mac=function(...) macs=macs+1 return original(...) end
local workers,callback,removed={},nil,0
addon.periodic=function(_,name,interval,refresh)
  local worker={interval=interval,stop=function(self) self.stopped=true end,rescan=function() end}
  worker.rawRefresh=refresh
  worker.refresh=function()
    local co=coroutine.create(refresh)
    local previous=macs
    assert(coroutine.resume(co))
    assert(macs-previous<=1,'multiple HMACs before cooperative yield')
    while coroutine.status(co)~='dead' do
      local event=assert(table.remove(events,1),'missing cooperative wake')
      previous=macs
      assert(coroutine.resume(co,table.unpack(event,1,event.n)))
      assert(macs-previous<=1,'multiple HMACs between cooperative yields')
    end
  end
  workers[name]=worker return worker
end
addon.inventory=function() return {} end
local net=require('system.services.radarnetd')
local context={eventBus={on=function(_,_,fn) callback=fn return 1 end,off=function() removed=removed+1 end}}
net.start(context)
local worker=assert(workers['radarnet-ingress'])
assert(worker.interval==0.05)
computer=2 local legit=assert(net.publish({})) computer=1
local invalid=addon.copy(legit) invalid.mac=string.rep('0',64)
local before=macs
-- Invalid signatures and spoofed sender IDs cannot cause inline verification.
for id=3,200 do
  local forged=addon.copy(invalid) forged.sender=id
  callback(id,forged,net.protocol)
end
for i=1,100 do callback(2,invalid,net.protocol) end
assert(macs==before and decodes==0)
local stats=net.status().ingress
assert(stats.pending<=32 and stats.rateDrops>0 and stats.coalesced==7)
assert(#net.snapshot().nodes==0,'unsigned trusted-ID traffic became trusted')
local heartbeat=0
for i=1,20 do
  local previous=macs worker.refresh() heartbeat=heartbeat+1
  assert(macs-previous<=5,'unbounded verification cycle')
end
assert(heartbeat==20 and decodes==0 and net.status().ingress.pending==0)
-- A new admission window recovers, despite ongoing discovery flooding.
now=now+1.1
for id=3,200 do local forged=addon.copy(invalid) forged.sender=id callback(id,forged,net.protocol) end
assert(callback(2,legit,net.protocol),'discovery consumed reserved paired capacity')
worker.refresh() heartbeat=heartbeat+1
assert(net.status().stations==1 and net.status().ingress.accepted==1)
assert(callback(2,legit,net.protocol)) worker.refresh()
assert(net.status().ingress.rejected>0,'replay was not rejected')
-- A status query must not call snapshot or traverse/copy contact histories.
local snapshot=net.snapshot net.snapshot=function() error('status copied snapshot') end
assert(net.status().stations==1) net.snapshot=snapshot
-- Malformed traffic also consumes sender/global admission, before crypto.
now=now+1.1 before=macs
for i=1,100 do callback(2,{},net.protocol) end
assert(not callback(2,legit,net.protocol) and macs==before)
assert(net.status().ingress.shapeDrops==8)
-- Freshness is verified when drained, not frozen at queue admission.
now=now+1.1
computer=2 local expiring=assert(net.publish({})) computer=1
assert(callback(2,expiring,net.protocol))
local accepted=net.status().ingress.accepted
now=now+11
for i=1,20 do worker.refresh() end
assert(net.status().ingress.accepted==accepted,'queued packet escaped UTC expiry')
now=now+1.1 assert(callback(2,legit,net.protocol))
net.stop()
assert(worker.stopped and workers.radarnetd.stopped and removed==1)
assert(net.status().ingress.pending==0)
assert(not callback(2,legit,net.protocol),'stale listener admitted after stop')
-- Sustained synchronized 16-station 5 Hz load with hostile discovery traffic.
cfg.trusted={}
for id=2,17 do cfg.trusted[tostring(id)]=true end
now=100 net.start(context) worker=workers['radarnet-ingress']
local latest={}
local start=now
for step=0,199 do
  now=start+step*0.05
  if step%4==0 then
    for id=2,17 do
      computer=id local packet=assert(net.publish({})) computer=1
      latest[id]=textutils.unserialize(packet.payload).sequence
      assert(callback(id,packet,net.protocol),'healthy 5 Hz publication rate limited')
    end
  end
  local forged=addon.copy(invalid) forged.sender=1000+step
  callback(forged.sender,forged,net.protocol)
  local pending=net.status().ingress
  assert(pending.trustedPending<=16 and pending.discoveryPending<=16)
  before=macs worker.refresh() heartbeat=heartbeat+1
  assert(macs-before<=5)
end
stats=net.status().ingress
assert(stats.accepted==800,'16 x 5 Hz did not sustain 80 accepted packets/s')
assert(stats.trustedPending==0 and stats.highWater<=32)
for _,node in ipairs(net.snapshot().nodes) do
  assert(node.age<=0.201,'paired station starved by discovery')
end
-- Slow worker: one raw slot per sender retains the latest arrival, not backlog.
now=now+1.1
for revision=1,3 do
  for id=2,17 do
    computer=id local packet=assert(net.publish({})) computer=1
    latest[id]=textutils.unserialize(packet.payload).sequence
    assert(callback(id,packet,net.protocol))
  end
end
stats=net.status().ingress
assert(stats.trustedPending==16 and stats.coalesced==32)
for i=1,4 do now=now+0.05 worker.refresh() end
assert(net.status().ingress.accepted==816 and net.status().ingress.pending==0)
-- Every replacement was authenticated and decoded as the last arrival.
now=now+0.3
for id=2,17 do
  computer=id local replay=assert(net.publish({})) computer=1
  local packet=textutils.unserialize(replay.payload)
  packet.sequence=latest[id]
  local payload=encode(packet)
  replay.payload=payload
  replay.mac=original(cfg.sharedKey,replay.format..'\n'..net.protocol..'\n'..id..'\n'..payload)
  assert(not net.receive(id,replay,net.protocol),'latest replacement was not retained')
end
net.stop()
-- Exercise native Lua crypto on maximum-size payloads through the actual raw
-- scheduler. A heartbeat is dispatched at every queued verification boundary.
now=now+1.1 net.start(context) worker=workers['radarnet-ingress']
events={}
for id=2,6 do
  local forged=addon.copy(invalid) forged.sender=id forged.payload=string.rep('x',65536)
  assert(callback(id,forged,net.protocol))
end
local Scheduler=require('system.kernel.scheduler')
local scheduler=Scheduler.new()
local beats=0
local beat=scheduler:spawn('heartbeat',function()
  while true do os.pullEvent('mintcraft_radar_verify') beats=beats+1 end
end,{eventMode='raw'})
scheduler:start(beat)
local pid=scheduler:spawn('verify-test',worker.rawRefresh,{eventMode='raw'})
before=macs local started=nativeClock()
scheduler:start(pid)
assert(macs-before==1 and scheduler.processes[pid].state=='ready')
while #events>0 do
  local raw=table.remove(events,1)
  before=macs
  scheduler:dispatch({name=raw[1],args={raw[2]},raw=raw})
  assert(macs-before<=1)
end
assert(beats==4 and scheduler.processes[pid].state=='stopped')
assert(net.status().ingress.processed==5 and net.status().ingress.accepted==0)
print(string.format('Native Lua 5.2: five 64 KiB invalid HMACs %.3fs; four heartbeat dispatches',nativeClock()-started))
-- Configuration/stop while yielded must not resume work against reset queues.
now=now+1.1
for id=2,3 do local forged=addon.copy(invalid) forged.sender=id assert(callback(id,forged,net.protocol)) end
local pending=coroutine.create(worker.rawRefresh)
assert(coroutine.resume(pending))
local wake=assert(table.remove(events,1))
net.stop() before=macs
assert(coroutine.resume(pending,table.unpack(wake,1,wake.n)))
assert(coroutine.status(pending)=='dead' and macs==before)
print('Radar bounded ingress, invalid flood, reserved capacity, worker budget, heartbeat and stop passed')
