local addon=require("system.libraries.addon")
local wire=require("system.nexus.protocol")
local store=require("system.nexus.storage")
local bootstrap=require("system.nexus.bootstrap")
local automation=require("system.nexus.automation")
local tasks=require("system.nexus.tasks")
local fleet=require("system.nexus.fleet")
local observe=require("system.nexus.observe")
local monitor=require("system.nexus.monitor")
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
local bundle,nodeKeys,assets=nil,{},{}
local rules=addon.copy(monitor.defaults)
local alerts={active={},history={}}
local alertsDirty=false
local function alertEvent(entry,phase,utc)
  alerts.history[#alerts.history+1]={key=entry.key,kind=entry.kind,source=entry.source,message=entry.message,phase=phase,at=utc}
  while #alerts.history>64 do table.remove(alerts.history,1) end
  if phase=='opened' then
    pcall(log[entry.kind=='error' and 'error' or 'warn'],'nexus',entry.source..': '..entry.message)
  else pcall(log.info,'nexus',entry.source..': '..phase) end
end
local function updateAlerts()
  if alertsDirty then store.save('/var/nexus/alerts.cfg',alerts) alertsDirty=false end
  if not config.automation or not config.automation.enabled then return end
  if os.clock()-(M.startedAt or 0)<5 then return end
  local utc=os.epoch('utc')/1000
  local desired=monitor.evaluate(assets,rows,config.members,rules,alerts.active,os.clock(),utc)
  local keys={} for key in pairs(desired) do keys[#keys+1]=key end table.sort(keys)
  local active,opened={},{} local changed=alerts.truncated~=(#keys>192)
  for index,key in ipairs(keys) do if index<=192 then
    local value=desired[key] local old=alerts.active[key]
    local entry={key=key,kind=value.kind,source=value.source,message=value.message,firstAt=old and old.firstAt or utc,
      acknowledged=old and old.acknowledged or false}
    active[key]=entry
    if not old then alertEvent(entry,'opened',utc) opened[#opened+1]=entry changed=true
    elseif old.message~=entry.message or old.source~=entry.source then changed=true end
  end end
  for key,old in pairs(alerts.active) do if not desired[key] then
    local assetKey=key:match('^asset:(.*):[^:]+$') local id=key:match('^agent:(%d+):')
    local phase=not rules.enabled and 'disabled' or ((assetKey and not assets[assetKey] or id and not config.members[id]) and 'removed' or 'resolved')
    alertEvent(old,phase,utc) changed=true
  end end
  alerts.active=active alerts.truncated=#keys>192
  if context.notifications and #opened>0 then
    if #opened>3 then
      local kind='warn' for _,entry in ipairs(opened) do if entry.kind=='error' then kind='error' break end end
      pcall(context.notifications.push,context.notifications,kind,'NEXUS alerts',#opened..' new conditions; see Alerts',5)
    else for _,entry in ipairs(opened) do pcall(context.notifications.push,context.notifications,entry.kind,'NEXUS '..entry.source,entry.message,5) end end
  end
  if changed then alertsDirty=true revision=revision+1 end
  if alertsDirty then store.save('/var/nexus/alerts.cfg',alerts) alertsDirty=false end
end
local function nodeKey(id)
  if not nodeKeys[id] then nodeKeys[id]=wire.nodeKey(config.key,id) end
  return nodeKeys[id]
end
local function getBundle()
  if not bundle then
    local value={paths=addon.copy(bootstrap.files),data={},hashes={}}
    value.paths[#value.paths+1]='system/nexus/bootstrap.lua'
    local fingerprint={}
    for _,path in ipairs(value.paths) do
      value.data[path]=assert(store.read('/'..path),'Missing agent module: '..path)
      value.hashes[path]=wire.hash(value.data[path])
      fingerprint[#fingerprint+1]=path..':'..value.hashes[path]
    end
    value.release=wire.hash(table.concat(fingerprint,'\n')):sub(1,40)
    bundle=value
  end
  return bundle
end
local function ownId() return os.getComputerID() end
local function validId(id) return type(id)=="number" and id>=0 and id<2147483647 and id%1==0 end
local function actorAllowed(actor)
  local process=context.scheduler and actor and context.scheduler.processes[actor.pid]
  if not process or process.state~="ready" or not process.meta or process.meta.appId~="nexus" then return false,"NEXUS window not running" end
  return permissions.require({pid=actor.pid,appId="nexus",permissions=process.permissions},"system.security.admin")
end
local function saveConfig(value)
  store.save("/system/config/nexus.cfg",value)
  if config.key~=value.key then nodeKeys={} end
  config=value
end
local function publish(message)
  notice=tostring(message):sub(1,300) revision=revision+1
  pcall(log.info,"nexus",notice)
end
local function nextId()
  serial=serial+1 return ownId()..":"..boot..":"..serial
end
local function send(id,kind,body)
  if not config.members[tostring(id)] then return false end
  local packet=wire.sign(nodeKey(id),ownId(),id,kind,nextId(),body)
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
local function prepare(driveName,ids,resetToken,resets,forces)
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
    manifest.nodes[tostring(id)]={group=member.group,key=nodeKey(id),resetToken=resetToken,forceToken=forces and forces[tostring(id)]}
  end
  local payload=getBundle()
  for _,path in ipairs(payload.paths) do
    local destination=fs.combine(mount,'nexus/payload/'..path)
    manifest.hashes[path]=payload.hashes[path]
    if store.read(destination)~=payload.data[path] then store.write(destination,payload.data[path]) end
  end
  manifest.release=payload.release
  for id,node in pairs(manifest.nodes) do
    local recovery=resets and resets[id]
    if recovery and recovery.release==manifest.release then node.resetToken=recovery.token end
  end
  local manifestPath=fs.combine(mount,'nexus/manifest.cfg')
  if store.read(manifestPath)~=textutils.serialize(manifest) then store.save(manifestPath,manifest) end
  local reassociate=[=[
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
]=]
  local helper=fs.combine(mount,'nexus/reassociate.lua')
  if store.read(helper)~=reassociate then store.write(helper,reassociate) end
  if previous~=diskStartup then store.write(startupPath,diskStartup) end
  return manifest
end
function M.request(actor,action,args)
  local ok,err=actorAllowed(actor) if not ok then return false,err end
  if #actions>=8 then return false,"NEXUS action queue full" end
  if action~="scan" and action~="prepare" and action~="deploy" and action~="seal" and action~="mission" and action~="groupMission" and action~="assign" and action~="reboot" and action~="shutdown" and action~="auto" and action~="resetAuto" and action~="setupAuto" and action~="pause" and action~='monitorConfig' and action~='ackAlerts' then return false,"Unknown NEXUS action" end
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
  if args.type=='observe' then
    assert(type(args.endpoint)=='string' and #args.endpoint<=64 and type(args.asset)=='string' and #args.asset<=100,'Observation endpoint required')
  end
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
    createdAt=os.epoch("utc"),expiresAt=os.epoch("utc")+(args.type=='observe' and 45000 or 120000),lastAttempt=-1000000000,attempts=0,
    endpoint=args.endpoint,asset=args.asset}
  jobs[#jobs+1]=job store.save("/var/nexus/jobs.cfg",jobs)
  return job
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
  elseif action.action=='monitorConfig' then
    local value,err=monitor.rules(args.rules) assert(value,err)
    store.save('/system/config/nexus-monitor.cfg',value) rules=value M.monitorAt=nil
    publish('Monitoring thresholds saved; no machine commands enabled')
  elseif action.action=='ackAlerts' then
    for _,entry in pairs(alerts.active) do entry.acknowledged=true end
    alertsDirty=true store.save('/var/nexus/alerts.cfg',alerts) alertsDirty=false revision=revision+1
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
  if policy.allowReset and not policy.forces then
    local nextValue=addon.copy(config) nextValue.automation.forces={}
    for _,id in ipairs(policy.ids) do
      nextValue.automation.forces[tostring(id)]=wire.hash(config.key..':local-recovery:'..id..':'..nextId()):sub(1,40)
    end
    saveConfig(nextValue) policy=config.automation
  end
  M.release=getBundle().release
  local view={}
  for id,row in pairs(rows) do view[id]=addon.copy(row) view[id].age=row.seenAt and os.clock()-row.seenAt or math.huge end
  if policy.allowReset then
    local mount
    for _,drive in ipairs(drives) do if drive.name==policy.drive then mount=drive.mount end end
    if mount then for _,id in ipairs(policy.ids) do
      local attempt=(policy.attempts or {})[tostring(id)]
      if view[id] then view[id].updateFailure=attempt and attempt.release==M.release and attempt.failure==true or false end
      local packet
      if attempt and attempt.release==M.release and not attempt.failure and (attempt.phase or 'update')=='update'
        and view[id] and view[id].release~=M.release then
        packet=store.load(fs.combine(mount,'nexus/failures/'..id..'.cfg'))
      end
      if packet and view[id] then
        -- Bind the report to the current release and a recently attempted boot.
        local message=wire.verify(nodeKey(id),id,ownId(),packet)
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
    local manifest=prepare(policy.drive,policy.ids,policy.resetToken,policy.resets,policy.forces)
    local nextValue=addon.copy(config)
    nextValue.automation.attempts=nextValue.automation.attempts or {}
    local batch={} local at=os.epoch('utc')
    for _=1,#policy.ids do
      if not step or step.kind~='deploy' then break end
      batch[#batch+1]=step
      nextValue.automation.attempts[tostring(step.id)]={release=manifest.release,count=step.count,at=at,phase=step.phase}
      step=automation.plan(nextValue.automation,view,config.members,M.release,at)
    end
    -- Journal the whole wave before the first power call. No intentional delay
    -- is inserted between computers; retry cooldowns remain per target.
    saveConfig(nextValue)
    local failures,starts=0,{}
    for _,entry in ipairs(batch) do
      local id=entry.id
      starts[#starts+1]=function()
        local row=rows[id]
        local ok,err=pcall(power,id,row.powered and 'reboot' or 'turnOn')
        row.deployAt=os.clock() row.deployRelease=manifest.release
        if not ok then failures=failures+1 row.error=tostring(err):sub(1,160) end
      end
    end
    if parallel and parallel.waitForAll then parallel.waitForAll(table.unpack(starts))
    else for _,start in ipairs(starts) do start() end end
    autoMessage='Deployment wave: '..#batch..' agents, no start delay; power errors '..failures
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
  if admission.count>=32 or #incoming>=64 then return end
  admission.count=admission.count+1 incoming[#incoming+1]={sender=sender,packet={payload=packet.payload,mac=packet.mac}}
end
local function receive(item)
  local id=item.sender
  if not config.members[tostring(id)] then return end
  seen[id]=seen[id] or {}
  local message=wire.verify(nodeKey(id),id,ownId(),item.packet,seen[id])
  if not message then return end
  local body=message.body
  if message.kind=="heartbeat" and type(body.version)=="string" and type(body.peripherals)=="table" and #body.peripherals<=48 then
    local row=rows[id] or {id=id,label="Agent "..id}
    row.seenAt=os.clock() row.version=body.version:sub(1,32) row.error=nil
    row.release=type(body.release)=="string" and body.release:sub(1,64) or nil
    row.provisionToken=type(body.provisionToken)=="string" and body.provisionToken:sub(1,100) or nil
    row.label=type(body.label)=="string" and body.label:sub(1,64) or row.label
    row.peripherals=body.peripherals row.capabilities=body.capabilities
    row.queueDepth=type(body.queueDepth)=='number' and math.max(0,math.min(9,body.queueDepth)) or 0
    row.diskFree=type(body.diskFree)=='number' and body.diskFree==body.diskFree and body.diskFree>=0 and body.diskFree<1e15 and body.diskFree or nil
    row.diskCapacity=type(body.diskCapacity)=='number' and body.diskCapacity==body.diskCapacity and body.diskCapacity>0 and body.diskCapacity<1e15 and body.diskCapacity or nil
    rows[id]=row revision=revision+1
    send(id,"ack",{heartbeat=message.id})
  elseif message.kind=="result" then
    for _,job in ipairs(jobs) do if job.id==body.id and job.node==id and job.state~="completed" and job.state~="failed" then
      if type(body.result)~="table" then return end
      job.result=job.type=='observe' and observe.normalize(body.result) or body.result
      job.state=job.result.ok==true and "completed" or "failed"
      if job.asset and assets[job.asset] then
        local asset=assets[job.asset]
        asset.result=job.result asset.receivedAt=os.epoch('utc')/1000 asset.owner=id asset.sampleOwner=id asset.lastError=nil
        store.save('/var/nexus/assets.cfg',assets)
      end
      store.save("/var/nexus/jobs.cfg",jobs) revision=revision+1 break
    end end
  end
end
local function coordinate()
  local policy=config.automation
  if not policy or not policy.enabled then return end
  local changed=false
  for _,job in ipairs(jobs) do
    if (job.state=='queued' or job.state=='sent') and monitor.orphaned(job,rows,os.clock()) then
      job.state='failed' job.result={ok=false,error='Observation owner unavailable; lease released'} changed=true
      local asset=job.asset and assets[job.asset]
      if asset then asset.attemptAt=0 asset.lastError=job.result.error end
    end
  end
  local pending={} for _,job in ipairs(jobs) do if job.asset and (job.state=='queued' or job.state=='sent') then pending[job.asset]=true end end
  for key,asset in pairs(assets) do
    if not pending[key] and os.epoch('utc')/1000-math.max(asset.receivedAt or 0,asset.attemptAt or 0)>300
      and monitor.orphaned({type='observe',node=asset.owner,endpoint=asset.endpoint},rows,os.clock()) then assets[key]=nil changed=true end
  end
  if changed then store.save('/var/nexus/jobs.cfg',jobs) store.save('/var/nexus/assets.cfg',assets) revision=revision+1 end
  local active=0 for _,job in ipairs(jobs) do if job.state=='queued' or job.state=='sent' then active=active+1 end end
  if active>=96 then return end
  local nextTask=fleet.plan(rows,config.members,jobs,policy,assets,os.clock(),os.epoch('utc')/1000)
  if not nextTask then return end
  local job=mission({id=nextTask.node,type='observe',endpoint=nextTask.endpoint,asset=nextTask.asset})
  local old=assets[nextTask.asset] or {}
  if old.result and not old.sampleOwner then old.sampleOwner=old.owner end
  old.key=nextTask.asset old.endpoint=nextTask.endpoint old.kind=nextTask.kind old.owner=nextTask.node
  old.attemptAt=os.epoch('utc')/1000 old.jobId=job.id
  assets[nextTask.asset]=old
  store.save('/var/nexus/assets.cfg',assets) revision=revision+1
end
function M.tick()
  if #actions>0 then local action=table.remove(actions,1) local ok,err=pcall(execute,action) if not ok then publish("NEXUS error: "..tostring(err)) end end
  if config.role~="master" then return end
  if os.clock()-lastScan>10 then wire.openModems() scan() end
  for _=1,6 do if #incoming==0 then break end receive(table.remove(incoming,1)) end
  if not M.autoAt or os.clock()-M.autoAt>=0.25 then
    M.autoAt=os.clock()
    local ok,err=pcall(automaticTick) if not ok then autoMessage="Automatic deployment: "..tostring(err):sub(1,180) end
  end
  if not M.coordinationAt or os.clock()-M.coordinationAt>=0.5 then
    M.coordinationAt=os.clock()
    local ok,err=pcall(coordinate) if not ok then publish('Coordination: '..tostring(err):sub(1,160)) end
  end
  if not M.monitorAt or os.clock()-M.monitorAt>=1 then
    M.monitorAt=os.clock()
    local ok,err=pcall(updateAlerts) if not ok then publish('Monitoring: '..tostring(err):sub(1,160)) end
  end
  for _,job in ipairs(jobs) do
    if (job.state=="queued" or job.state=="sent") and os.clock()-job.lastAttempt>=5 then
      if job.expiresAt and os.epoch("utc")>=job.expiresAt then job.state="failed" job.result={error="Mission deadline expired"}
      elseif not config.members[tostring(job.node)] then job.state="failed" job.result={error="Agent authorization removed"}
      elseif job.attempts>=3 then job.state="failed" job.result={error="Timeout; no confirmed result"}
      else job.attempts=job.attempts+1 job.lastAttempt=os.clock() job.state="sent" send(job.node,"mission",{id=job.id,type=job.type,count=job.count,expiresAt=job.expiresAt,endpoint=job.endpoint}) end
      if job.state=='failed' and job.type=='observe' and job.asset and assets[job.asset] then
        local asset=assets[job.asset]
        asset.lastError=job.result.error or 'Observation failed'
        store.save('/var/nexus/assets.cfg',assets)
      end
      store.save("/var/nexus/jobs.cfg",jobs) revision=revision+1 break
    end
  end
end
function M.snapshot()
  local result={role=config.role,group=config.group,computers={},drives=addon.copy(drives),jobs=addon.copy(jobs),
    message=notice,revision=revision,master=ownId(),online=0,managed=0,discovered=0,
    automation={enabled=type(config.automation)=="table" and config.automation.enabled==true,message=autoMessage},assets={},
    resources={live=0,stale=0,items=0,energy=0,capacity=0,fluid=0,partial=false},
    monitoring={rules=addon.copy(rules),running=rules.enabled and type(config.automation)=='table' and config.automation.enabled==true,
      active={},history=addon.copy(alerts.history),truncated=alerts.truncated==true}}
  for _,entry in pairs(alerts.active) do result.monitoring.active[#result.monitoring.active+1]=addon.copy(entry) end
  table.sort(result.monitoring.active,function(a,b) return a.key<b.key end)
  for _,asset in pairs(assets) do
    if config.members[tostring(asset.owner)] then
      local value=addon.copy(asset)
      local stamp=value.receivedAt
      if stamp and value.result and type(value.result.measuredAt)=='number' then stamp=math.min(stamp,value.result.measuredAt/1000) end
      value.age=stamp and math.max(0,os.epoch('utc')/1000-stamp) or nil
      value.stale=not monitor.fresh(value,rows,os.clock(),os.epoch('utc')/1000,rules)
      result.assets[#result.assets+1]=value
      local data=value.result
      if not value.stale and data and data.ok then
        result.resources.live=result.resources.live+1
        for key,field in pairs({items='items',energy='energy',capacity='capacity',fluid='amount'}) do result.resources[key]=result.resources[key]+(data[field] or 0) end
        result.resources.partial=result.resources.partial or data.partial
      else result.resources.stale=result.resources.stale+1 end
    end
  end
  table.sort(result.assets,function(a,b) return a.key<b.key end)
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
  M.release=nil M.autoAt=nil M.coordinationAt=nil M.monitorAt=nil bundle=nil nodeKeys={} autoMessage="Automatic deployment disabled"
  M.startedAt=os.clock() alertsDirty=false
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
  store.recover('/var/nexus/assets.cfg') local savedAssets=store.load('/var/nexus/assets.cfg',{}) assets={}
  local assetCount=0
  for key,asset in pairs(savedAssets) do
    if assetCount<128 and type(key)=='string' and #key<=100 and type(asset)=='table' and validId(asset.owner)
      and type(asset.endpoint)=='string' and #asset.endpoint<=64 then
      assets[key]={key=key,owner=asset.owner,sampleOwner=validId(asset.sampleOwner) and asset.sampleOwner or asset.owner,endpoint=asset.endpoint,kind=type(asset.kind)=='string' and asset.kind:sub(1,32) or 'unknown',
        attemptAt=type(asset.attemptAt)=='number' and asset.attemptAt==asset.attemptAt and asset.attemptAt>=0 and asset.attemptAt<=os.epoch('utc')/1000+5 and asset.attemptAt or 0,
        receivedAt=validId(asset.sampleOwner) and type(asset.receivedAt)=='number' and asset.receivedAt==asset.receivedAt and asset.receivedAt>=0 and asset.receivedAt<=os.epoch('utc')/1000+5 and asset.receivedAt or nil,
        lastError=type(asset.lastError)=='string' and asset.lastError:sub(1,120) or nil,result=asset.result and observe.normalize(asset.result) or nil}
      assetCount=assetCount+1
    end
  end
  store.recover('/system/config/nexus-monitor.cfg')
  rules=monitor.rules(store.load('/system/config/nexus-monitor.cfg',monitor.defaults)) or addon.copy(monitor.defaults)
  store.recover('/var/nexus/alerts.cfg') local saved=store.load('/var/nexus/alerts.cfg',{})
  alerts={active={},history={},truncated=saved.truncated==true}
  local function entry(value,key)
    if type(value)~='table' or type(key)~='string' or #key>160 or (value.kind~='warn' and value.kind~='error')
      or type(value.source)~='string' or type(value.message)~='string' then return nil end
    return {key=key,kind=value.kind,source=value.source:sub(1,64),message=value.message:sub(1,180),
      firstAt=type(value.firstAt)=='number' and value.firstAt or os.epoch('utc')/1000,acknowledged=value.acknowledged==true,
      phase=type(value.phase)=='string' and value.phase:sub(1,16) or nil,at=type(value.at)=='number' and value.at or nil}
  end
  local count=0
  for key,value in pairs(type(saved.active)=='table' and saved.active or {}) do
    local value=entry(value,key)
    if value and count<192 then alerts.active[key]=value count=count+1 end
  end
  local history=type(saved.history)=='table' and saved.history or {}
  for index=math.max(1,#history-63),#history do local value=entry(history[index],type(history[index])=='table' and history[index].key)
    if value then alerts.history[#alerts.history+1]=value end
  end
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
