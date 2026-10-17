package.path='./?.lua;'..package.path
local crypto=require('system.libraries.password_crypto')
assert(crypto.mac('Jefe','what do ya want for nothing?')=='5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843')
local addon=require('system.libraries.addon')
local now,computer,decodes=10,1,0
os.clock=function() return now end
os.epoch=function() return (1000000+now)*1000 end
os.getComputerID=function() return computer end
os.getComputerLabel=function() return 'Authenticated station' end
addon.periodic=function() return {stop=function() end,rescan=function() end} end
addon.inventory=function() return {} end
local cfg={enabled=true,publish=true,sharedKey='a sufficiently long shared test key',allowInsecure=false,
  group='world-A',trusted={['2']=true},x=0,y=0,z=0,radius=100,alerts=false}
package.loaded['system.libraries.config']={load=function() return addon.copy(cfg) end}
package.loaded['system.libraries.safe_write']={write=function() return true end}
package.loaded['system.libraries.log']={warn=function(_,message) assert(cfg.sharedKey=='' or not message:find(cfg.sharedKey,1,true)) end}
package.loaded['system.security.permissions']={require=function() return true end}
local function encode(value)
  if type(value)=='string' then return string.format('%q',value) end
  if type(value)~='table' then return tostring(value) end
  local fields={}
  for key,item in pairs(value) do fields[#fields+1]='['..encode(key)..']='..encode(item) end
  table.sort(fields)
  return '{'..table.concat(fields,',')..'}'
end
textutils={serialize=encode,unserialize=function(value)
  decodes=decodes+1
  local chunk=assert(load('return '..value,'test wire','t',{}))
  return chunk()
end}
local net=require('system.services.radarnetd')
local context={scheduler={processes={[7]={state='ready',meta={appId='combat'},permissions={}}}},
  eventBus={on=function() return 1 end,off=function() end}}
net.start(context)
local snapshot={radars={{id='r',position={x=0,y=0,z=0},range=100,timestamp=now}},
  targets={{id='t',radarId='r',position={x=1,y=0,z=0},timestamp=now}}}
computer=2 local envelope=assert(net.publish(snapshot)) computer=1
assert(type(envelope.payload)=='string' and #envelope.mac==64 and envelope.sender==2)
assert(net.receive(2,envelope,net.protocol))
local health=net.snapshot()
assert(health.authenticated and health.encrypted==false and #health.targets==1)
assert(not encode(health):find(cfg.sharedKey,1,true),'shared key leaked through snapshot')
now=now+0.2
assert(not net.receive(2,envelope,net.protocol),'signed replay accepted')
local function signed(packet,sender,key)
  local payload=encode(packet)
  local result={format=envelope.format,sender=sender or 2,payload=payload}
  result.mac=crypto.mac(key or cfg.sharedKey,result.format..'\n'..net.protocol..'\n'..result.sender..'\n'..payload)
  return result
end
local packet=textutils.unserialize(envelope.payload)
packet.session='second-boot' packet.sequence=1
assert(net.receive(2,signed(packet),net.protocol))
now=now+0.2
assert(not net.receive(2,envelope,net.protocol),'session rotation permitted replay')
assert(not net.receive(3,envelope,net.protocol),'sender not bound to MAC')
assert(not net.receive(2,packet,net.protocol),'unsigned downgrade accepted')
local changed=addon.copy(envelope) changed.payload=changed.payload..' '
assert(not net.receive(2,changed,net.protocol),'payload bytes not authenticated')
changed=addon.copy(envelope) changed.mac=string.rep('0',64)
assert(not net.receive(2,changed,net.protocol),'forged MAC accepted')
assert(not net.receive(2,signed(packet,2,'wrong sufficiently long secret'),net.protocol),'wrong shared key accepted')
changed=addon.copy(envelope) changed.payload=string.rep('x',65537)
local before=decodes
assert(not net.receive(2,changed,net.protocol) and decodes==before,'oversize payload decoded')
packet.sequence=2 packet.sentAt=1000000+now-11
assert(not net.receive(2,signed(packet),net.protocol),'expired signed packet accepted')
packet.sentAt=1000000+now+3
assert(not net.receive(2,signed(packet),net.protocol),'future signed packet accepted')
packet.sentAt=1000000+now packet.group='wrong-world'
assert(not net.receive(2,signed(packet),net.protocol),'signed wrong-world packet accepted')
packet.group='world-A' packet.sentAt=1000000+now-4
assert(net.receive(2,signed(packet),net.protocol))
assert(net.snapshot().targets[1].timestamp==now-4,'transport delay rejuvenated target')
local options=net.configuration() options.allowInsecure=true
assert(net.configure({pid=7},options))
assert(not net.receive(2,packet,net.protocol),'allowInsecure downgraded configured key')
local provider=package.loaded['system.libraries.password_crypto']
package.loaded['system.libraries.password_crypto']=nil
package.preload['system.libraries.password_crypto']=function() error('missing provider') end
assert(not net.receive(2,envelope,net.protocol))
assert(not net.publish(snapshot),'missing provider signed or downgraded packet')
assert(#net.snapshot().targets==0,'missing provider exposed stale authenticated measurements')
package.loaded['system.libraries.password_crypto']=provider
cfg.sharedKey='' cfg.allowInsecure=false net.start(context)
assert(not net.receive(2,packet,net.protocol) and not net.publish(snapshot),'implicit insecure networking enabled')
options=net.configuration() assert(not net.configure({pid=7},options),'insecure enabled configuration accepted')
cfg.allowInsecure=true net.start(context)
assert(net.receive(2,packet,net.protocol),'explicit insecure compatibility unavailable')
health=net.snapshot()
assert(not health.authenticated and not health.encrypted and health.warning:find('INSECURE',1,true))
net.stop()
print('Vetted HMAC radar envelopes, replay/freshness, downgrade rejection, explicit insecure mode and secret redaction passed')
