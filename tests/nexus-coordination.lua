package.path='./?.lua;'..package.path
local testRoot=fs and fs.exists('/source/tests/storage-fixture.lua') and '/source/' or ''
local fixture=dofile(testRoot..'tests/storage-fixture.lua')
local wire=require('system.nexus.protocol')
local bootstrap=require('system.nexus.bootstrap')
local agentModule=require('system.nexus.agent')
local store=require('system.nexus.storage')
package.loaded['system.libraries.log']={info=function() end}
package.loaded['system.security.permissions']={require=function() return true end}
require('system.libraries.addon').periodic=function() return {stop=function() end} end
os.epoch=function() return 1700000000000 end
local service=require('system.services.nexusd')
local paths,source,fingerprint={},{},{}
for _,path in ipairs(bootstrap.files) do paths[#paths+1]=path end paths[#paths+1]='system/nexus/bootstrap.lua'
for _,path in ipairs(paths) do
 local h=assert(io.open(testRoot..path,'rb')) local data=h:read('*a') h:close()
 source[path]=data fingerprint[#fingerprint+1]=path..':'..wire.hash(data)
end
local release=wire.hash(table.concat(fingerprint,'\n')):sub(1,40)
local machines={} for id=0,2 do machines[id]=fixture() machines[id].fs=fs end
local current,now=0,100
local function use(id)
 current=id fs=machines[id].fs fs.isReadOnly=function() return false end
 fs.getCapacity=function() return 1000000 end
end
use(0)
os.clock=function() return now end os.epoch=function() return 1700000000000+now*1000 end
os.getComputerID=function() return current end os.getComputerLabel=function() return 'node '..current end
local queue,callback={},nil
peripheral={getNames=function() return {'pc1','pc2','drive','back','chest_0','battery_0'} end,
 getType=function(name) return name:match('^pc') and 'computer' or (name=='drive' and 'drive' or (name=='back' and 'modem' or name)) end,
 hasType=function(name,kind) return (name=='back' and kind=='modem') or (name=='chest_0' and kind=='inventory') or (name=='battery_0' and kind=='energy_storage') end,
 call=function(name,method)
  if name:match('^pc') then if method=='getID' then return tonumber(name:sub(3)) elseif method=='getLabel' then return name elseif method=='isOn' then return true end end
  if name=='chest_0' then if method=='size' then return 27 elseif method=='list' then return {[1]={count=64},[20]={count=8}} end end
  if name=='battery_0' then return method=='getEnergy' and 800 or 1000 end
  error('Unexpected write or power command: '..name..' '..method)
 end}
disk={getMountPath=function() return '/disk' end}
rednet={isOpen=function() return true end,send=function(to,packet,protocol) queue[#queue+1]={sender=current,to=to,packet=packet,protocol=protocol} return true end}
for _,path in ipairs(paths) do machines[0].put('/'..path,source[path]) end
local actor={pid=4}
local ctx={scheduler={processes={[4]={state='ready',meta={appId='nexus'},permissions={}}}},eventBus={on=function(_,_,fn) callback=fn return 1 end,off=function() end}}
service.start(ctx) assert(service.setup(actor,string.rep('m',64),'factory')) assert(service.request(actor,'scan')) service.tick()
for id=1,2 do assert(service.select(actor,id,true,'factory')) end
local agents={}
for id=1,2 do use(id) agents[id]=agentModule.new({role='agent',id=id,master=0,key=wire.nodeKey(string.rep('m',64),id),active=release,group='factory'}) agents[id]:tick() end
now=now+1
for id=1,2 do use(id) agents[id]:tick() end
local function masterDelivery()
 use(0) local pending=queue queue={}
 for _,packet in ipairs(pending) do if packet.to==0 then callback(packet.sender,packet.packet,packet.protocol) else queue[#queue+1]=packet end end
 service.tick()
end
masterDelivery()
assert(service.snapshot().online==2)
assert(service.request(actor,'auto',{group='factory',ids={'1','2'},allowReset=true})) service.tick()
for _=1,8 do
 local pending=queue queue={}
 for _,packet in ipairs(pending) do
  if packet.to~=0 then use(packet.to) agents[packet.to]:receive(packet.sender,packet.packet,packet.protocol) else queue[#queue+1]=packet end
 end
 now=now+0.5 masterDelivery()
end
use(0)
local snapshot=service.snapshot()
assert(#snapshot.assets==2,'Shared endpoints duplicated across agents or missing')
assert(snapshot.resources.items==72 and snapshot.resources.energy==800 and snapshot.resources.live==2,'Fresh fleet totals double-counted or missing')
local owners={}
for _,asset in ipairs(snapshot.assets) do
 owners[asset.owner]=true
 assert(asset.result and asset.result.ok and not asset.stale,'Coordinated observation did not complete')
 if asset.kind=='inventory' then assert(asset.result.items==72) else assert(asset.result.energy==800) end
end
assert(owners[1] and owners[2],'All work stayed on one agent')
local before=#snapshot.jobs
for _=1,5 do now=now+0.5 service.tick() end
assert(#service.snapshot().jobs==before,'Shared endpoint repeatedly rescheduled before refresh interval')
assert(service.request(actor,'pause')) service.tick()
now=now+40 service.tick()
assert(#service.snapshot().jobs==before,'Pause did not stop coordination')
service.start(ctx)
assert(#service.snapshot().assets==2,'Infrastructure reports lost after MASTER restart')
print('NEXUS coordination: automatic shared-device assignment, two active workers, aggregate results, refresh throttling, pause and persistence passed')
