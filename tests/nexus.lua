package.path="./?.lua;"..package.path
local testRoot=fs and fs.exists('/source/tests/storage-fixture.lua') and '/source/' or ''
local fixture=dofile(testRoot.."tests/storage-fixture.lua")
local source={}
for _,path in ipairs({"system/nexus/protocol.lua","system/nexus/storage.lua","system/nexus/agent.lua","system/nexus/observe.lua","system/nexus/bootstrap.lua","system/libraries/password_crypto.lua","system/nexus/uninstall.lua"}) do
  local h=assert(io.open(testRoot..path,"rb")) source[path]=h:read("*a") h:close()
end
os.epoch=os.epoch or function() return 1700000000000 end
package.loaded["system.libraries.log"]={info=function() end}
package.loaded["system.security.permissions"]={require=function(actor) return actor.pid==4 end}
local addon=require("system.libraries.addon")
addon.periodic=function() return {stop=function() end} end
local service=require("system.services.nexusd")
local bootstrap=require("system.nexus.bootstrap")
local store=require("system.nexus.storage")
local wire=require("system.nexus.protocol")
local agentModule=require("system.nexus.agent")
local machines={}
for id=0,8 do machines[id]=fixture() machines[id].fs=fs end
local current,now=0,100
local function switch(id)
  current=id fs=machines[id].fs
  fs.isReadOnly=function() return false end fs.getCapacity=function() return 1000000 end
end
switch(0)
os.getComputerID=function() return current end
os.getComputerLabel=function() return "node-"..current end
os.clock=function() return now end
os.epoch=function() return 1700000000000+now*1000 end
local powered,queue,callbacks={}, {},{}
local powerEvents={}
local suspendPower,waveStart=false,0
peripheral={
  getNames=function() return {"pc1","pc2","pc3","pc4","pc5","pc6","pc7","drive_0","back"} end,
  getType=function(name) return name:match("^pc") and "computer" or (name=="back" and "modem" or "drive") end,
  hasType=function(name,kind) return name=="back" and kind=="modem" end,
  call=function(name,method)
    local id=tonumber(name:match("pc(%d+)")) assert(id,"Unexpected peripheral")
    if method=="getID" then return id elseif method=="getLabel" then return "node-"..id
    elseif method=="isOn" then return powered[id]==true elseif method=="reboot" or method=="turnOn" then
      powered[id]=true powerEvents[#powerEvents+1]={id=id,at=now}
      if suspendPower then
        os.queueEvent('nexus_power_complete') coroutine.yield('nexus_power_complete')
        assert(#powerEvents-waveStart+1==7,'A yielding power call delayed the other starts')
      end
    elseif method=="shutdown" then powered[id]=false else error("Unexpected control method") end
  end,
}
disk={getMountPath=function(name) if name=="drive_0" then return "/disk" end end}
rednet={isOpen=function() return true end,open=function() end,send=function(to,packet,protocol)
  queue[#queue+1]={sender=current,to=to,packet=packet,protocol=protocol} return true
end}
local actor={pid=4}
local ctx={scheduler={processes={[4]={pid=4,state="ready",meta={appId="nexus"},permissions={}}}},
  eventBus={on=function(_,event,fn) callbacks[event]=fn return event end,off=function() end}}
for path,data in pairs(source) do machines[0].put("/"..path,data) end
service.start(ctx)
assert(not service.setup({pid=99},string.rep("x",32),"factory"))
assert(service.setup(actor,"private-test-key-which-is-not-shared-with-agents", "factory"))
assert(service.request(actor,'setupAuto',{group='factory'})) service.tick()
assert(store.load('/system/config/nexus.cfg').key=='private-test-key-which-is-not-shared-with-agents','Existing MASTER key regenerated')
assert(service.request(actor,"scan")) service.tick()
assert(#service.snapshot().computers==7)
for id=1,7 do assert(service.select(actor,id,true,"factory")) end
assert(not service.select(actor,0,true))
assert(service.request(actor,"deploy",{drive="drive_0",group="factory"})) service.tick()
for id=1,7 do assert(powered[id],"Selected computer not powered on") end
local diskNodes={}
for path,data in pairs(machines[0].nodes) do if path=="/disk" or path:sub(1,6)=="/disk/" then diskNodes[path]=data end end
local agents={}
for id=1,8 do
  switch(id)
  for path,data in pairs(diskNodes) do machines[id].nodes[path]=data end
  local ranLocal=false
  local bootFs=setmetatable({combine=function(a,b) return fs.combine(a,b):gsub('^/+','') end,
    open=function(path,mode) return fs.open('/'..path:gsub('^/+',''),mode) end},{__index=fs})
  local bootEnv=setmetatable({fs=bootFs,package={path='?.lua'},shell={getRunningProgram=function() return 'disk/startup.lua' end,
    run=function(path) assert(path=='/startup.lua') ranLocal=true end},printError=function(err) error(err) end},{__index=_ENV})
  bootEnv.require=function(name)
    assert(name=='system.nexus.bootstrap' and bootEnv.package.path:sub(1,1)=='/','Disk bootstrap uses a relative module path')
    return bootstrap
  end
  assert(load(diskNodes['/disk/startup.lua'],'shared disk startup','t',bootEnv))()
  local ok=fs.exists('/startup.lua')
  if id==8 then assert(not ok and not fs.exists("/startup.lua"),"Bootstrap spread beyond selected IDs")
  else
    assert(ok and ranLocal,"Blank selected computer did not enter local startup")
    local cfg=assert(store.load("/nexus/config.cfg"))
    assert(cfg.id==id and cfg.master==0 and cfg.key~= "private-test-key-which-is-not-shared-with-agents")
    assert(fs.exists("/nexus/versions/"..cfg.active.."/system/nexus/agent.lua"))
    assert(bootstrap.install("/disk"),"Repeated bootstrap not idempotent")
    fs.delete("/disk")
    local entered=false
    local localEnv=setmetatable({package={path='?.lua',loaded={}},printError=function(err) error(err) end},{__index=_ENV})
    localEnv.require=function(name)
      assert(name=='system.nexus.agent' and localEnv.package.path:find('/nexus/versions/'..cfg.active..'/?.lua',1,true)==1)
      return {run=function() entered=true end}
    end
    assert(load(store.read('/startup.lua'),'installed startup','t',localEnv))()
    assert(entered,'Disk-independent startup did not enter the agent')
    agents[id]=agentModule.new(cfg) agents[id]:tick()
  end
end
now=now+5
for id=1,7 do switch(id) agents[id]:tick() end
switch(0)
local function deliverMaster()
  local pending=queue queue={}
  for _,item in ipairs(pending) do if item.to==0 then callbacks.rednet_message(item.sender,item.packet,item.protocol) else queue[#queue+1]=item end end
  service.tick() service.tick()
end
deliverMaster()
assert(service.snapshot().online==7,"Seven agents did not enroll")
assert(not textutils.serialize(service.snapshot()):find("private-test-key",1,true),"MASTER secret leaked in GUI snapshot")
assert(service.request(actor,"mission",{id=1,type="sum",count=100})) service.tick()
local command
local pending=queue queue={}
for _,item in ipairs(pending) do
  if item.to==1 then switch(1) agents[1]:receive(item.sender,item.packet,item.protocol) if wire.verify(store.load('/nexus/config.cfg').key,0,1,item.packet) then command=item end end
end
switch(0) deliverMaster()
local jobs=service.snapshot().jobs
assert(#jobs==1 and jobs[1].state=="completed" and jobs[1].result.value==5050,"Distributed mission failed")
switch(1)
local cfg=store.load("/nexus/config.cfg") agents[1]=agentModule.new(cfg)
local packet=wire.sign(cfg.key,0,1,"mission","retry-after-agent-reboot",{id=jobs[1].id,type="sum",count=999})
assert(agents[1]:receive(0,packet,wire.name))
assert(store.load("/nexus/receipts.cfg")[jobs[1].id].value==5050,"Duplicate mission reran after reboot")
local forged=wire.sign(string.rep("z",32),0,1,"mission","forged",{id="bad",type="inventory"})
assert(not agents[1]:receive(0,forged,wire.name),"Wrong-key command accepted")
local dangerous=wire.sign(cfg.key,0,1,"mission","not-allowed",{id="exec",type="eval",code="error('executed')"})
assert(agents[1]:receive(0,dangerous,wire.name))
assert(store.load('/nexus/receipts.cfg').exec.ok==false,"Arbitrary code mission accepted")
local seen={} local signed=wire.sign(cfg.key,0,1,"mission","unique",{id="probe",type="ping"})
assert(wire.verify(cfg.key,0,1,signed,seen)) assert(not wire.verify(cfg.key,0,1,signed,seen))
now=now+31 assert(not wire.verify(cfg.key,0,1,signed),"Expired packet accepted")
local deadline=os.epoch('utc')+2000
local expiring=wire.sign(cfg.key,0,1,'mission','expires-one',{id='expiring',type='ping',expiresAt=deadline})
assert(agents[1]:receive(0,expiring,wire.name))
now=now+3
local retryExpired=wire.sign(cfg.key,0,1,'mission','expires-two',{id='expiring',type='ping',expiresAt=deadline})
assert(not agents[1]:receive(0,retryExpired,wire.name),'Expired task reran')
local fresh=wire.sign(cfg.key,0,1,'mission','expires-three',{id='fresh',type='ping',expiresAt=os.epoch('utc')+2000})
assert(agents[1]:receive(0,fresh,wire.name))
assert(not store.load('/nexus/receipts.cfg').expiring,'Expired receipt not reclaimed')
switch(0) assert(service.snapshot().online==0,"Offline agents remained online")
assert(service.request(actor,'seal',{drive='drive_0'})) service.tick()
assert(not fs.exists('/disk/nexus/manifest.cfg') and not fs.exists('/disk/nexus/manifest.cfg.backup') and not fs.exists('/disk/startup.lua'),'Provisioning credentials not sealed')
switch(8)
machines[8].put('/startup.lua','print("keep me")')
-- A selected target with an existing startup must still be protected.
local manifest=textutils.unserialize(diskNodes['/disk/nexus/manifest.cfg'])
manifest.nodes['8']={key=string.rep('k',64),group='factory'}
machines[8].config('/disk/nexus/manifest.cfg',manifest)
local ok,why=bootstrap.install('/disk') assert(not ok and why:find('protected',1,true))
assert(store.read('/startup.lua')=='print("keep me")')
switch(1)
machines[1].put('/keep.txt','unrelated user data')
read=function() return 'UNINSTALL' end
assert(load(source['system/nexus/uninstall.lua'],'local uninstall','t',_ENV))()
assert(not fs.exists('/startup.lua') and not fs.exists('/nexus'))
assert(store.read('/keep.txt')=='unrelated user data','Uninstall deleted unrelated files')
switch(0)
for id=1,7 do switch(id) agents[id]:tick() end
switch(0) deliverMaster()
for _=1,8 do service.tick() end
local before=#service.snapshot().jobs
assert(service.request(actor,'groupMission',{group='factory',type='storage'})) service.tick()
assert(#service.snapshot().jobs==before+7,'Collective mission did not cover seven agents: '..#service.snapshot().jobs..' / '..before..' '..service.snapshot().message)
assert(service.request(actor,'assign',{group='factory',type='inventory'})) service.tick()
assert(#service.snapshot().jobs==before+8,'Automatic mission assignment missing')
assert(service.request(actor,'auto',{group='factory'})) service.tick()
assert(service.snapshot().automation.enabled,'Automation consent not persisted')
local policy=store.load('/system/config/nexus.cfg').automation
assert(#policy.ids==7 and policy.drive=='drive_0')
now=now+2 service.tick()
assert(store.load('/system/config/nexus.cfg').automation.sealedRelease,'Matching agents not automatically sealed')
assert(service.request(actor,'shutdown',{id=2})) service.tick()
assert(store.load('/system/config/nexus.cfg').automation.holds['2'],'Maintenance shutdown hold missing')
assert(service.request(actor,'pause')) service.tick()
assert(not service.snapshot().automation.enabled)
service.start(ctx)
assert(not service.snapshot().automation.enabled,'Pause did not survive restart')
assert(service.request(actor,'resetAuto',{group='factory',ids={'1'}})) service.tick()
assert(not service.snapshot().automation.enabled,'Changed reset scope accepted')
assert(service.request(actor,'resetAuto',{group='factory',ids={'1','2','3','4','5','6','7'}})) service.tick()
assert(store.load('/system/config/nexus.cfg').automation.resetToken,'Destructive campaign token not persisted')
now=now+2 service.tick()
local resetManifest=store.load('/disk/nexus/manifest.cfg')
assert(resetManifest.nodes['1'].resetToken and not resetManifest.nodes['0'],'Reset scope did not reach disk or included MASTER')
service.start(ctx)
assert(service.request(actor,'auto',{group='factory',allowReset=true,ids={'1','2','3','4','5','6','7'}})) service.tick()
local function failureReport(label)
 local master=store.load('/system/config/nexus.cfg')
 local packet=wire.sign(wire.nodeKey(master.key,1),1,0,'bootstrap_failure',label,{release=service.release,eligible=true,error='association mismatch'})
 store.save('/disk/nexus/failures/1.cfg',packet)
end
failureReport('failure-first') now=now+2 service.tick()
assert(store.load('/system/config/nexus.cfg').automation.attempts['1'].failure,'Signed failure not retained')
now=now+61 service.tick()
failureReport('failure-second') now=now+2 service.tick()
now=now+61 service.tick()
assert(store.load('/system/config/nexus.cfg').automation.resets['1'],'Failed update did not enter automatic reset')
now=now+2 service.tick()
local recoveryManifest=store.load('/disk/nexus/manifest.cfg')
assert(recoveryManifest.nodes['1'].resetToken and not recoveryManifest.nodes['2'].resetToken,'Recovery erased non-failed agents')
service.start(ctx)
fs.delete('/disk/nexus/payload')
local writes={}
machines[0].hook=function(action,path) if action=='write' and path:find('/disk/nexus/payload/',1,true)==1 then writes[path]=(writes[path] or 0)+1 end end
local firstPower=#powerEvents+1
waveStart=firstPower suspendPower=parallel and parallel.waitForAll and os.queueEvent
assert(service.request(actor,'auto',{group='factory',allowReset=true,ids={'1','2','3','4','5','6','7'}})) service.tick()
suspendPower=false
machines[0].hook=nil
assert(#powerEvents-firstPower+1==7,'Not all seven starts were dispatched in one wave')
assert(powerEvents[firstPower].at==powerEvents[#powerEvents].at,'An artificial inter-start delay remains')
local written=0
for _,count in pairs(writes) do written=written+1 assert(count==1,'Agent payload recopied for every target') end
assert(written==#bootstrap.files+1,'Payload instrumentation did not cover the complete deployment')
machines[0].config('/system/config/nexus.cfg',{role='master',key=string.rep('k',64),group='factory',members={['1']=42}})
service.start(ctx)
assert(service.snapshot().role=='off','Malformed authorization registry did not fail closed')
print('NEXUS: eight computers, seven blank bootstraps, protected outsider/startup, disk-independent agents, HMAC/replay/expiry, durable idempotent missions and offline detection passed')
