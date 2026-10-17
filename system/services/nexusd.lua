local addon=require("system.libraries.addon")
local wire=require("system.nexus.protocol")
local store=require("system.nexus.storage")
local bootstrap=require("system.nexus.bootstrap")
local automation=require("system.nexus.automation")
local tasks=require("system.nexus.tasks")
local keygen=require("system.nexus.keygen")
local permissions=require("system.security.permissions")
local log=require("system.libraries.log")
local M={version=wire.version}
local context,runner,listener,config={},nil,nil,{role="off",members={}}
local rows,drives,jobs,incoming,actions={}, {},{}, {},{}
local serial,revision,lastScan=0,0,-math.huge
local boot=tostring(os.epoch("utc"))
local seen,admission={}, {at=0,count=0}
local notice="MASTER not configured"
local autoMessage="Automatic deployment disabled"
local function ownId() return os.getComputerID() end
local function validId(id) return type(id)=="number" and id>=0 and id<2147483647 and id%1==0 end
local function actorAllowed(actor)
  local process=context.scheduler and actor and context.scheduler.processes[actor.pid]
  if not process or process.state~="ready" or not process.meta or process.meta.appId~="nexus" then return false,"NEXUS window not running" end
  return permissions.require({pid=actor.pid,appId="nexus",permissions=process.permissions},"system.security.admin")
end
local function saveConfig(value) store.save("/system/config/nexus.cfg",value) config=value end
local function publish(message)
  notice=tostring(message):sub(1,300) revision=revision+1
  pcall(log.info,"nexus",notice)
end
local function nextId()
  serial=serial+1 return ownId()..":"..boot..":"..serial
end
local function send(id,kind,body)
  if not config.members[tostring(id)] then return false end
  local packet=wire.sign(wire.nodeKey(config.key,id),ownId(),id,kind,nextId(),body)
  local ok,sent=pcall(rednet.send,id,packet,wire.name)
  return ok and sent==true
end
local function scan()
  if config.role=="master" then wire.openModems() end
  local found,newDrives={},{}
  local names=peripheral.getNames() table.sort(names)
  for i=1,math.min(256,#names) do
    local name=names[i]
    local ok,kind=pcall(peripheral.getType,name)
    if ok and (kind=="computer" or kind=="turtle") then
      local okId,id=pcall(peripheral.call,name,"getID")
      if okId and validId(id) and id~=ownId() then
        local _,label=pcall(peripheral.call,name,"getLabel")
        local okOn,on=pcall(peripheral.call,name,"isOn")
        local old=rows[id] or {}
        found[id]={id=id,name=name,label=type(label)=="string" and label:sub(1,64) or "Computer "..id,
          powered=okOn and on==true,seenAt=old.seenAt,version=old.version,peripherals=old.peripherals,
          error=old.error,capabilities=old.capabilities,deployAt=old.deployAt,deployRelease=old.deployRelease,release=old.release,provisionToken=old.provisionToken}
      end
    elseif ok and kind=="drive" then
      local okPath,path=pcall(disk.getMountPath,name)
      newDrives[#newDrives+1]={name=name,mount=okPath and path or nil}
    end
  end
  for id,row in pairs(rows) do if not found[id] and config.members[tostring(id)] then row.name=nil found[id]=row end end
  for id in pairs(config.members) do
    local number=tonumber(id)
    if validId(number) and not found[number] then found[number]={id=number,label="Agent "..id} end
  end
  rows,drives=found,newDrives lastScan=os.clock() revision=revision+1
end
function M.setup(actor,key,group)
  local ok,err=actorAllowed(actor) if not ok then return false,err end
  if type(group)~="string" or not group:match("^[%w_-]+$") or #group>32 then return false,"Use a short group name" end
  if config.role=="master" then
    if key~="" then return false,"MASTER key already set; leave key empty to change deployment group" end
    local nextValue=addon.copy(config) nextValue.group=group
    local saved,problem=pcall(saveConfig,nextValue) if not saved then return false,tostring(problem) end
    publish("Default deployment group changed; existing authorizations retained") return true
  end
  if not wire.validKey(key) then return false,"Use a private key of 32..256 characters" end
  local saved,problem=pcall(saveConfig,{schema=1,role="master",key=key,group=group,members={}})
  if not saved then return false,tostring(problem) end
  publish("MASTER configured; select owned computers")
  return true
end
function M.select(actor,id,enabled,group)
  local ok,err=actorAllowed(actor) if not ok then return false,err end
  if config.role~="master" or not validId(id) or id==ownId() or not rows[id] then return false,"Select a discovered computer, not the MASTER" end
  local nextValue=addon.copy(config)
  if enabled then
    local count=0 for _ in pairs(config.members) do count=count+1 end
    if not config.members[tostring(id)] and count>=64 then return false,"Maximum 64 managed computers" end
    group=group or config.group
    if type(group)~="string" or #group>32 or not group:match("^[%w_-]+$") then return false,"Invalid group" end
    nextValue.members[tostring(id)]={group=group}
  else nextValue.members[tostring(id)]=nil seen[id]=nil end
  local saved,problem=pcall(saveConfig,nextValue) if not saved then return false,tostring(problem) end
  publish(enabled and "Computer explicitly authorized: "..id or "Authorization removed: "..id)
  return true
end
local function selectedIds(group)
  local ids={}
  for id,member in pairs(config.members) do if not group or group==member.group then ids[#ids+1]=tonumber(id) end end
  table.sort(ids) return ids
end
local diskStartup=bootstrap.marker.."\n"..[=[
local mount='/'..fs.getDir(shell.getRunningProgram()):gsub('^/+','')
local h=fs.open(fs.combine(mount,'nexus/manifest.cfg'),'r')
local manifest=h and textutils.unserialize(h.readAll()) if h then h.close() end
local selected=type(manifest)=='table' and type(manifest.nodes)=='table' and manifest.nodes[tostring(os.getComputerID())]
if selected and manifest.master~=os.getComputerID() then
  package.path='/'..fs.combine(mount,'nexus/payload/?.lua'):gsub('^/+','')..';'..package.path
  local ok,result,err=pcall(function() return require('system.nexus.bootstrap').install(mount) end)
  if not ok or not result then
    local reason=tostring(ok and err or result)
    printError('NEXUS bootstrap: '..reason)
    pcall(function()
      local wire=require('system.nexus.protocol') local store=require('system.nexus.storage')
      local eligible=reason:find('Existing NEXUS association protected',1,true) or reason:find('Existing startup protected',1,true)
        or reason:find('Existing installation protected',1,true) or reason:find('Installed payload corrupt',1,true) or reason:find('Installed payload missing',1,true)
      local id=os.getComputerID()
      store.save(fs.combine(mount,'nexus/failures/'..id..'.cfg'),wire.sign(selected.key,id,manifest.master,'bootstrap_failure',
        'failure:'..id..':'..os.epoch('utc'),{release=manifest.release,eligible=not not eligible,error=reason:sub(1,200)}))
    end)
  end
end
if fs.exists('/startup.lua') then shell.run('/startup.lua') end
]=]
local function prepare(driveName,ids,resetToken,resets)
  assert(config.role=="master","Configure MASTER first")
  assert(#ids>0,"No authorized computers in this group")
  local mount
  for _,drive in ipairs(drives) do if drive.name==driveName then mount=drive.mount end end
  assert(mount,"Select a data disk visible on the wired network")
  assert(not fs.isReadOnly(mount),"Bootstrap disk is read-only")
  local startupPath=fs.combine(mount,"startup.lua")
  local previous=store.read(startupPath)
  assert(not fs.exists(fs.combine(mount,"startup")),"Existing disk startup directory protected")
  assert(not previous or previous:sub(1,#bootstrap.marker)==bootstrap.marker,"Existing disk startup protected")
  local manifest={schema=1,master=ownId(),nodes={},hashes={}}
  for _,id in ipairs(ids) do
    local member=assert(config.members[tostring(id)],"Computer not authorized")
    assert(id~=ownId(),"Cannot deploy on MASTER")
    manifest.nodes[tostring(id)]={group=member.group,key=wire.nodeKey(config.key,id),resetToken=resetToken}
  end
  local paths=addon.copy(bootstrap.files) paths[#paths+1]="system/nexus/bootstrap.lua"
  for _,path in ipairs(paths) do
    local data=assert(store.read("/"..path),"Missing installed NEXUS module: "..path)
    manifest.hashes[path]=wire.hash(data)
    store.write(fs.combine(mount,"nexus/payload/"..path),data)
  end
  local fingerprint={}
  for _,path in ipairs(paths) do fingerprint[#fingerprint+1]=path..":"..manifest.hashes[path] end
  manifest.release=wire.hash(table.concat(fingerprint,"\n")):sub(1,40)
  for id,node in pairs(manifest.nodes) do
    local recovery=resets and resets[id]
    if recovery and recovery.release==manifest.release then node.resetToken=recovery.token end
  end
  store.save(fs.combine(mount,"nexus/manifest.cfg"),manifest)
  store.write(fs.combine(mount,"nexus/reassociate.lua"),[=[
local mount='/'..fs.getDir(fs.getDir(shell.getRunningProgram())):gsub('^/+','')
package.path='/'..fs.combine(mount,'nexus/payload/?.lua'):gsub('^/+','')..';'..package.path
local h=assert(fs.open(fs.combine(mount,'nexus/manifest.cfg'),'r'),'Prepare the NEXUS disk first')
local manifest=textutils.unserialize(h.readAll()) h.close()
local id=os.getComputerID()
assert(type(manifest)=='table' and type(manifest.nodes)=='table' and manifest.nodes[tostring(id)] and manifest.master~=id,'This agent is not selected')
local phrase='REASSOCIATE '..id..' MASTER '..manifest.master
print('Local reassociation replaces the agent key; old association is backed up.')
print('Only continue if you own this computer and trust this disk.')
print('Type exactly: '..phrase)
local confirmation=read()
if confirmation~=phrase then print('Cancelled; no changes') return end
local ok,err=require('system.nexus.bootstrap').install(mount,{confirmation=confirmation})
assert(ok,err) print('Association replaced. Eject the disk, then reboot.')
]=])
  store.write(startupPath,diskStartup)
  return manifest
end
function M.request(actor,action,args)
  local ok,err=actorAllowed(actor) if not ok then return false,err end
  if #actions>=8 then return false,"NEXUS action queue full" end
  if action~="scan" and action~="prepare" and action~="deploy" and action~="seal" and action~="mission" and action~="groupMission" and action~="assign" and action~="reboot" and action~="shutdown" and action~="auto" and action~="resetAuto" and action~="setupAuto" and action~="pause" then return false,"Unknown NEXUS action" end
  if action~="scan" and action~="setupAuto" and config.role~="master" then return false,"Configure MASTER first" end
  args=type(args)=="table" and addon.copy(args) or {}
  actions[#actions+1]={actor={pid=actor.pid},action=action,args=args}
  return true,"Queued: "..action
end
local function power(id,method)
  assert(config.members[tostring(id)] and id~=ownId(),"Computer not authorized")
  local row=assert(rows[id],"Computer unavailable")
  assert(row.name,"Computer not reachable as a wired peripheral")
  local ok,err=pcall(peripheral.call,row.name,method)
  assert(ok,tostring(err)) row.error=nil
end
local function mission(args)
  local id=args.id
  assert(validId(id) and config.members[tostring(id)],"Agent not authorized")
  assert(tasks.allowed[args.type],"Read-only mission type required")
  if #jobs>=96 then
    local kept,removed=tasks.prune(jobs,64)
    if #removed>0 then
      local archive=store.load("/var/nexus/job-history.cfg",{})
      for _,job in ipairs(removed) do archive[#archive+1]={id=job.id,node=job.node,type=job.type,state=job.state} end
      while #archive>128 do table.remove(archive,1) end
      store.save("/var/nexus/job-history.cfg",archive)
      jobs=kept
    end
  end
  assert(#jobs<128,"Mission history full")
  local job={id=nextId(),type=args.type,node=id,state="queued",priority=1,capability=args.type,count=args.count or 100,
    createdAt=os.epoch("utc"),expiresAt=os.epoch("utc")+120000,lastAttempt=-1000000000,attempts=0}
  jobs[#jobs+1]=job store.save("/var/nexus/jobs.cfg",jobs)
end
local function execute(action)
  local permitted,err=actorAllowed(action.actor) assert(permitted,err)
  local args=action.args
  if action.action=="setupAuto" then
    if config.role=="master" then
      local ok,err=M.setup(action.actor,"",args.group or config.group) assert(ok,err)
    else
      local key=keygen.generate()
      local ok,err=M.setup(action.actor,key,args.group or "factory") assert(ok,err)
    end
  elseif action.action=="auto" or action.action=="resetAuto" then
    scan()
    local ids=selectedIds(args.group or config.group)
    assert(#ids>0,"Authorize owned computers first")
    if action.action=="resetAuto" or args.allowReset==true then
      assert(type(args.ids)=='table' and #args.ids==#ids,'Reset selection changed; confirm again')
      for i,id in ipairs(ids) do assert(tostring(args.ids[i])==tostring(id),'Reset selection changed; confirm again') end
    end
    local drive=args.drive
    if not drive then
      for _,value in ipairs(drives) do if value.mount and not fs.isReadOnly(value.mount) then
        assert(not drive,"Several disks found; choose a provisioning disk") drive=value.name
      end end
    end
    assert(drive,"Insert a writable provisioning disk")
    local nextValue=addon.copy(config)
    nextValue.automation={enabled=true,ids=ids,group=args.group or config.group,drive=drive,attempts={},holds={}}
    nextValue.automation.allowReset=args.allowReset==true
    if action.action=="resetAuto" then
      nextValue.automation.resetToken=wire.hash(config.key..":reset:"..nextId()):sub(1,40)
    end
    saveConfig(nextValue) publish("Automatic deployment enabled for "..#ids.." explicitly authorized computers")
  elseif action.action=="pause" then
    local nextValue=addon.copy(config)
    nextValue.automation=nextValue.automation or {} nextValue.automation.enabled=false
    saveConfig(nextValue) autoMessage="Automatic deployment paused" publish(autoMessage)
  elseif action.action=="scan" then scan() publish("Wired discovery refreshed")
  elseif action.action=="prepare" or action.action=="deploy" then
    scan()
    local ids=selectedIds(args.group)
    local manifest=prepare(args.drive,ids)
    if action.action=="deploy" then
      for _,id in ipairs(ids) do
        local ok,problem=pcall(power,id,"reboot")
        local row=rows[id]
        if row then row.deployAt=os.clock() row.deployRelease=manifest.release row.error=not ok and tostring(problem) or nil end
      end
    end
    publish("Disk prepared for "..#ids.." authorized computers; "..manifest.release)
  elseif action.action=="seal" then
    local mount
    for _,drive in ipairs(drives) do if drive.name==args.drive then mount=drive.mount end end
    assert(mount,"Bootstrap disk missing")
    local path=fs.combine(mount,"startup.lua")
    local startup=assert(store.read(path),"No bootstrap on this disk")
    assert(startup:sub(1,#bootstrap.marker)==bootstrap.marker,"Non-NEXUS disk protected")
    for _,suffix in ipairs({"",".backup",".pending"}) do
      local manifest=fs.combine(mount,"nexus/manifest.cfg"..suffix)
      if fs.exists(manifest) then fs.delete(manifest) end
    end
    fs.delete(path)
    for _,suffix in ipairs({".backup",".pending"}) do
      local old=path..suffix if fs.exists(old) then fs.delete(old) end
    end
    publish("Provisioning credentials removed from this disk; installed agents are independent")
  elseif action.action=="groupMission" or action.action=="assign" then
    assert(tasks.allowed[args.type],"Read-only mission type required")
    local ids=tasks.targets(rows,config.members,jobs,args.group or config.group,args.type,os.clock(),action.action=="groupMission")
    assert(#ids>0,"No online authorized agent advertising this capability")
    local active=0 for _,job in ipairs(jobs) do if job.state=="queued" or job.state=="sent" then active=active+1 end end
    assert(active+#ids<=128,"Too many active missions; wait for results")
    for _,id in ipairs(ids) do mission({id=id,type=args.type,count=args.count}) end
    publish(#ids.." read-only missions assigned to available agents in "..(args.group or config.group))
  elseif action.action=="mission" then mission(args) publish("Read-only mission queued")
  else
    if config.automation then
      local nextValue=addon.copy(config) nextValue.automation.holds=nextValue.automation.holds or {}
      nextValue.automation.holds[tostring(args.id)]=action.action=="shutdown" or nil
      saveConfig(nextValue)
    end
    power(args.id,action.action) publish(action.action.." requested for "..args.id)
  end
end
local function automaticTick()
  local policy=config.automation
  if type(policy)~="table" or not policy.enabled then return end
  local paths=addon.copy(bootstrap.files) paths[#paths+1]="system/nexus/bootstrap.lua"
  if not M.release then
    local values={}
    for _,path in ipairs(paths) do values[#values+1]=path..":"..wire.hash(assert(store.read("/"..path),"Missing agent payload")) end
    M.release=wire.hash(table.concat(values,"\n")):sub(1,40)
  end
  local view={}
  for id,row in pairs(rows) do view[id]=addon.copy(row) view[id].age=row.seenAt and os.clock()-row.seenAt or math.huge end
  if policy.allowReset then
    local mount
    for _,drive in ipairs(drives) do if drive.name==policy.drive then mount=drive.mount end end
    if mount then for _,id in ipairs(policy.ids) do
      local attempt=(policy.attempts or {})[tostring(id)]
      if view[id] then view[id].updateFailure=attempt and attempt.release==M.release and attempt.failure==true or false end
      local packet=store.load(fs.combine(mount,'nexus/failures/'..id..'.cfg'))
      if packet and view[id] then
        -- Bind the report to the current release and a recently attempted boot.
        local message=wire.verify(wire.nodeKey(config.key,id),id,ownId(),packet)
        local failure=message and message.kind=='bootstrap_failure' and message.body.release==M.release
          and message.body.eligible==true and attempt and message.time>=attempt.at or false
        if failure and not attempt.failure then
          local nextValue=addon.copy(config) nextValue.automation.attempts[tostring(id)].failure=true
          saveConfig(nextValue) policy=config.automation
          view[id].updateFailure=true
        end
      end
    end end
    for _,id in ipairs(policy.ids) do
      local row=view[id]
      if row and row.release and row.release~=M.release and row.age<=15 and row.deployAt and row.seenAt>=row.deployAt then
        row.updateFailure=true
      end
    end
  end
  local step=automation.plan(policy,view,config.members,M.release,os.epoch("utc"))
  if not step then return end
  if step.kind=='reset' then
    local nextValue=addon.copy(config)
    nextValue.automation.resets=nextValue.automation.resets or {}
    nextValue.automation.resets[tostring(step.id)]={release=M.release,token=wire.hash(config.key..':recovery:'..nextId()):sub(1,40)}
    saveConfig(nextValue)
    publish('Update failed for agent '..step.id..'; authorized internal reset scheduled')
    autoMessage='Recovery reset queued for agent '..step.id
  elseif step.kind=="deploy" then
    local manifest=prepare(policy.drive,policy.ids,policy.resetToken,policy.resets)
    local nextValue=addon.copy(config)
    nextValue.automation.attempts=nextValue.automation.attempts or {}
    nextValue.automation.attempts[tostring(step.id)]={release=manifest.release,count=step.count,at=os.epoch("utc"),phase=step.phase}
    -- Persist before power: an interrupted call must not cause a reboot loop.
    saveConfig(nextValue)
    local row=rows[step.id]
    power(step.id,row.powered and "reboot" or "turnOn")
    row.deployAt=os.clock() row.deployRelease=manifest.release
    autoMessage="Installing agent "..step.id.."; attempt "..step.count.."/2"
  elseif step.kind=="seal" then
    local mount
    for _,drive in ipairs(drives) do if drive.name==policy.drive then mount=drive.mount end end
    assert(mount,"Agents ready; insert provisioning disk to seal credentials")
    local path=fs.combine(mount,"startup.lua") local data=store.read(path)
    assert(not data or data:sub(1,#bootstrap.marker)==bootstrap.marker,"Foreign disk startup protected")
    for _,base in ipairs({"nexus/manifest.cfg","startup.lua"}) do
      for _,suffix in ipairs({"",".backup",".pending"}) do
        local target=fs.combine(mount,base..suffix) if fs.exists(target) then fs.delete(target) end
      end
    end
    local nextValue=addon.copy(config) nextValue.automation.sealedRelease=M.release saveConfig(nextValue)
    autoMessage="All scoped agents verified; provisioning credentials sealed"
  else autoMessage=step.message end
end
local function enqueue(sender,packet,protocol)
  if config.role~="master" or protocol~=wire.name or not validId(sender) or not config.members[tostring(sender)] or not wire.shape(packet) then return end
  if os.clock()-admission.at>=1 then admission={at=os.clock(),count=0} end
  if admission.count>=16 or #incoming>=32 then return end
  admission.count=admission.count+1 incoming[#incoming+1]={sender=sender,packet={payload=packet.payload,mac=packet.mac}}
end
local function receive(item)
  local id=item.sender
  if not config.members[tostring(id)] then return end
  seen[id]=seen[id] or {}
  local message=wire.verify(wire.nodeKey(config.key,id),id,ownId(),item.packet,seen[id])
  if not message then return end
  local body=message.body
  if message.kind=="heartbeat" and type(body.version)=="string" and type(body.peripherals)=="table" and #body.peripherals<=48 then
    local row=rows[id] or {id=id,label="Agent "..id}
    row.seenAt=os.clock() row.version=body.version:sub(1,32) row.error=nil
    row.release=type(body.release)=="string" and body.release:sub(1,64) or nil
    row.provisionToken=type(body.provisionToken)=="string" and body.provisionToken:sub(1,100) or nil
    row.label=type(body.label)=="string" and body.label:sub(1,64) or row.label
    row.peripherals=body.peripherals row.capabilities=body.capabilities rows[id]=row revision=revision+1
    send(id,"ack",{heartbeat=message.id})
  elseif message.kind=="result" then
    for _,job in ipairs(jobs) do if job.id==body.id and job.node==id and job.state~="completed" and job.state~="failed" then
      if type(body.result)~="table" then return end
      job.result=body.result job.state=body.result.ok==true and "completed" or "failed"
      store.save("/var/nexus/jobs.cfg",jobs) revision=revision+1 break
    end end
  end
end
function M.tick()
  if #actions>0 then local action=table.remove(actions,1) local ok,err=pcall(execute,action) if not ok then publish("NEXUS error: "..tostring(err)) end end
  if config.role~="master" then return end
  if os.clock()-lastScan>10 then wire.openModems() scan() end
  for _=1,4 do if #incoming==0 then break end receive(table.remove(incoming,1)) end
  if not M.autoAt or os.clock()-M.autoAt>=2 then
    M.autoAt=os.clock()
    local ok,err=pcall(automaticTick) if not ok then autoMessage="Automatic deployment: "..tostring(err):sub(1,180) end
  end
  for _,job in ipairs(jobs) do
    if (job.state=="queued" or job.state=="sent") and os.clock()-job.lastAttempt>=5 then
      if job.expiresAt and os.epoch("utc")>=job.expiresAt then job.state="failed" job.result={error="Mission deadline expired"}
      elseif not config.members[tostring(job.node)] then job.state="failed" job.result={error="Agent authorization removed"}
      elseif job.attempts>=3 then job.state="failed" job.result={error="Timeout; no confirmed result"}
      else job.attempts=job.attempts+1 job.lastAttempt=os.clock() job.state="sent" send(job.node,"mission",{id=job.id,type=job.type,count=job.count,expiresAt=job.expiresAt}) end
      store.save("/var/nexus/jobs.cfg",jobs) revision=revision+1 break
    end
  end
end
function M.snapshot()
  local result={role=config.role,group=config.group,computers={},drives=addon.copy(drives),jobs=addon.copy(jobs),
    message=notice,revision=revision,master=ownId(),online=0,managed=0,discovered=0,
    automation={enabled=type(config.automation)=="table" and config.automation.enabled==true,message=autoMessage}}
  for id,row in pairs(rows) do
    local value=addon.copy(row) local member=config.members[tostring(id)]
    value.authorized=member~=nil value.group=member and member.group or nil
    value.lastSeenSeconds=value.seenAt and math.max(0,os.clock()-value.seenAt) or nil
    value.activeMissions=0
    for _,job in ipairs(jobs) do if job.node==id and (job.state=="queued" or job.state=="sent") then value.activeMissions=value.activeMissions+1 end end
    value.state=value.seenAt and os.clock()-value.seenAt<=15 and "ONLINE" or (value.deployAt and os.clock()-value.deployAt<30 and "INSTALLING" or (member and "OFFLINE" or "DISCOVERED"))
    if value.deployRelease and value.release~=value.deployRelease then
      if value.deployAt and os.clock()-value.deployAt<30 then value.state="INSTALLING"
      else value.state="UPDATE FAILED" value.error="Expected bootstrap release not confirmed; check shared drive, disk startup setting and local startup protection" end
    end
    if value.state=="ONLINE" then result.online=result.online+1 end
    if member then result.managed=result.managed+1 end
    result.computers[#result.computers+1]=value
  end
  result.discovered=#result.computers table.sort(result.computers,function(a,b) return a.id<b.id end)
  return result
end
function M.start(ctx)
  M.stop() context=ctx
  M.release=nil M.autoAt=nil autoMessage="Automatic deployment disabled"
  rows,drives,seen={}, {},{} lastScan=-math.huge
  store.recover("/system/config/nexus.cfg") config=store.load("/system/config/nexus.cfg",{role="off",members={}})
  local malformed=type(config.members)~="table" or (config.role~="off" and config.role~="master")
    or (config.role=="master" and (not wire.validKey(config.key) or type(config.group)~="string" or #config.group>32))
  local count=0
  for id,member in pairs(type(config.members)=="table" and config.members or {}) do
    count=count+1
    if type(id)~="string" or not validId(tonumber(id)) or tonumber(id)==ownId() or type(member)~="table"
      or type(member.group)~="string" or #member.group>32 or count>64 then malformed=true end
  end
  if malformed then config={role="off",members={}} notice="Invalid MASTER config; restore backup locally" end
  if config.role=="master" then notice="MASTER ready; awaiting authenticated agents" end
  store.recover("/var/nexus/jobs.cfg") jobs=store.load("/var/nexus/jobs.cfg",{})
  if #jobs>128 then jobs={} end
  local validJobs={}
  for _,job in ipairs(jobs) do
    if type(job)=="table" and type(job.id)=="string" and #job.id<=80 and validId(job.node) and type(job.type)=="string"
      and type(job.attempts)=="number" and job.attempts>=0 and job.attempts<=3 and type(job.state)=="string" then
      if type(job.expiresAt)~="number" or job.expiresAt~=job.expiresAt or job.expiresAt==math.huge then job.expiresAt=os.epoch("utc")+120000 end
      if job.state=="sent" then job.state="queued" end
      job.lastAttempt=-1000000000 validJobs[#validJobs+1]=job
    end
  end
  jobs=validJobs
  if ctx.eventBus then listener=ctx.eventBus:on("rednet_message",enqueue) end
  runner=addon.periodic(ctx,"nexusd",0.25,M.tick)
end
function M.stop()
  if runner then runner:stop() runner=nil end
  if listener and context.eventBus then context.eventBus:off(listener) end
  listener=nil actions={} incoming={}
end
function M.health() return {ok=true,status=notice} end
return M
