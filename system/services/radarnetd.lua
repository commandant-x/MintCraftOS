local addon=require("system.libraries.addon")
local config=require("system.libraries.config")
local safeWrite=require("system.libraries.safe_write")
local permissions=require("system.security.permissions")
local M={protocol="mintcraft.radar.v1",securityWarning="INSECURE Rednet: unauthenticated and unencrypted; station IDs can be spoofed"}
local ctx,runner,ingressRunner,listener,modem,problem
local nodes,settings,sequence={}, {},0
local session=tostring(os.epoch and os.epoch("utc") or os.clock())
local announced,lastAlert={},-math.huge
local ENVELOPE="mintcraft.radar.hmac-sha256.v1"
local MAX_PAYLOAD=65536
local VERIFY_EVENT="mintcraft_radar_verify"
local verifySequence=0
local ingress,admission,metrics
local function resetIngress()
  ingress={trusted={},discovery={}}
  admission={since=os.clock(),trusted=0,discovery=0,senders={},count=0}
  metrics={queued=0,coalesced=0,accepted=0,rejected=0,dropped=0,rateDrops=0,queueDrops=0,shapeDrops=0,processed=0,highWater=0}
end
resetIngress()
local function authentication()
  if (settings.sharedKey or "")=="" then
    if settings.allowInsecure then return "insecure" end
    return nil,"Radar blocked: configure sharedKey or explicitly allowInsecure (unauthenticated, unencrypted)"
  end
  local ok,crypto=pcall(require,"system.libraries.password_crypto")
  if not ok or type(crypto)~="table" or type(crypto.mac)~="function" then
    return nil,"Radar blocked: vetted HMAC-SHA256 provider unavailable"
  end
  if not os.epoch then return nil,"Radar blocked: UTC clock required for authenticated freshness" end
  return "keyed",crypto
end
local function macInput(sender,payload)
  return ENVELOPE.."\n"..M.protocol.."\n"..tostring(sender).."\n"..payload
end
local function mac(crypto,sender,payload)
  local ok,value=pcall(crypto.mac,settings.sharedKey,macInput(sender,payload))
  if not ok or type(value)~="string" or #value~=64 or not value:match("^%x+$") then return nil end
  return value
end
local function signaturesEqual(left,right)
  -- Both signatures are exactly 64 bytes; inspect every byte without early exit.
  local difference=0
  for i=1,64 do local delta=left:byte(i)-right:byte(i) difference=difference+delta*delta end
  return difference==0
end
local function short(value,limit)
  return type(value)=="string" and #value<=limit and not value:find("[%c]") and value or nil
end
local function validId(id) return addon.finite(id) and id>=0 and id%1==0 end
local function pruneDiscovery()
  local discovered={}
  for id,node in pairs(nodes) do
    if not settings.trusted[tostring(id)] then discovered[#discovered+1]=node end
  end
  table.sort(discovered,function(a,b) return a.received>b.received or (a.received==b.received and a.id<b.id) end)
  for i=17,#discovered do nodes[discovered[i].id]=nil end
end
local function save(value)
  local ok,err=safeWrite.write("/system/config/radarnet.cfg",textutils.serialize(value))
  if ok then settings=addon.copy(value) end return ok,err
end
function M.configuration() return addon.copy(settings) end
function M.configure(actor,value)
  local process=ctx and actor and ctx.scheduler.processes[actor.pid]
  if not process or process.state~="ready" then return false,"owner not running" end
  local ok,err=permissions.require({pid=actor.pid,appId=process.meta.appId,permissions=process.permissions},"combat.configure")
  if not ok then return false,err end
  if type(value)~="table" or not short(value.group,40) or value.group=="" then return false,"Network group required (same world/dimension)" end
  if type(value.trusted)~="table" then return false,"invalid station list" end
  local count=0 for id,enabled in pairs(value.trusted) do
    if type(id)~="string" or not validId(tonumber(id)) or tostring(tonumber(id))~=id or type(enabled)~="boolean" then return false,"invalid station ID" end count=count+1
  end
  if count>16 then return false,"maximum 16 stations" end
  if value.sharedKey~=nil and (type(value.sharedKey)~="string" or (#value.sharedKey>0 and #value.sharedKey<16) or #value.sharedKey>256) then
    return false,"Shared key must be empty or 16..256 bytes"
  end
  if value.allowInsecure~=nil and type(value.allowInsecure)~="boolean" then return false,"invalid allowInsecure" end
  if value.enabled and (value.sharedKey or "")=="" and value.allowInsecure~=true then
    return false,"Configure a shared key, or explicitly allow insecure Rednet"
  end
  if not addon.finite(value.radius) or value.radius<=0 or value.radius>100000 then return false,"Zone radius must be 1..100000m" end
  if not addon.vec({x=value.x,y=value.y,z=value.z}) then return false,"Zone requires world X/Y/Z" end
  for _,key in ipairs({"enabled","publish","alerts"}) do if type(value[key])~="boolean" then return false,"invalid "..key end end
  local changed=value.group~=settings.group or value.enabled~=settings.enabled or
    (value.sharedKey or "")~=(settings.sharedKey or "") or value.allowInsecure~=settings.allowInsecure
  local nextSettings=addon.copy(value)
  nextSettings.sharedKey=value.sharedKey or "" nextSettings.allowInsecure=value.allowInsecure==true
  local saved,why=save(nextSettings)
  if saved then resetIngress() if changed then nodes={} else pruneDiscovery() end if runner then runner:rescan() end end
  return saved,why
end
local function open()
  modem=nil
  if not settings.enabled then problem="Disabled" return end
  local mode,why=authentication()
  if not mode then problem=why return end
  for _,row in ipairs(addon.inventory()) do if addon.hasType(row,"modem") then
    local ok=pcall(function() if not rednet.isOpen(row.name) then rednet.open(row.name) end end)
    if ok then modem=row.name problem=nil return end
  end end
  problem="No modem; connect a wired/wireless modem"
end
-- This event-bus callback does no crypto, decoding, copying or history traversal.
-- Sender IDs only select reserved capacity; they are not authentication evidence.
local function enqueue(sender,packet,protocol)
  if not ctx or protocol~=M.protocol or not settings.enabled or not validId(sender) or sender==os.getComputerID() then return false end
  local now=os.clock()
  if now-admission.since>=1 then
    admission={since=now,trusted=0,discovery=0,senders={},count=0}
  end
  local lane=settings.trusted[tostring(sender)] and "trusted" or "discovery"
  local limit=lane=="trusted" and 128 or 16
  local attempts=admission.senders[sender]
  if admission[lane]>=limit or (attempts and attempts>=8) or (not attempts and admission.count>=64) then
    metrics.dropped=metrics.dropped+1 metrics.rateDrops=metrics.rateDrops+1 return false
  end
  admission[lane]=admission[lane]+1
  if not attempts then admission.count=admission.count+1 end
  admission.senders[sender]=(attempts or 0)+1
  -- Invalid traffic consumes admission too, before even cheap shape checks.
  if type(packet)~="table" or ((settings.sharedKey or "")~="" and
    (packet.format~=ENVELOPE or packet.sender~=sender or type(packet.payload)~="string" or
    #packet.payload>MAX_PAYLOAD or type(packet.mac)~="string" or #packet.mac~=64)) then
    metrics.dropped=metrics.dropped+1 metrics.shapeDrops=metrics.shapeDrops+1 return false
  end
  local queue=ingress[lane]
  -- Latest arrival replaces pending raw input without changing FIFO position.
  -- Neither claimed sequence numbers nor paired IDs are trusted before HMAC.
  for _,row in ipairs(queue) do
    if row.sender==sender then
      row.packet=packet row.received=now
      metrics.coalesced=metrics.coalesced+1 return true
    end
  end
  if #queue>=16 then
    metrics.dropped=metrics.dropped+1 metrics.queueDrops=metrics.queueDrops+1 return false
  end
  queue[#queue+1]={sender=sender,packet=packet,protocol=protocol,received=now}
  metrics.queued=metrics.queued+1
  metrics.highWater=math.max(metrics.highWater,#ingress.trusted+#ingress.discovery)
  return true
end
local function drainIngress()
  local active=ingress
  -- Four paired slots sustain 16 stations at 5 Hz; discovery retains one slot.
  for _,lane in ipairs({"trusted","trusted","trusted","trusted","discovery"}) do
    local queue=ingress[lane]
    if #queue==0 then queue=ingress[lane=="trusted" and "discovery" or "trusted"] end
    local row=table.remove(queue,1)
    if row then
      metrics.processed=metrics.processed+1
      local accepted=M.receive(row.sender,row.packet,row.protocol,row.received)
      local key=accepted and "accepted" or "rejected"
      metrics[key]=metrics[key]+1
      -- A queued wake gives other raw workers a dispatch between HMACs without
      -- imposing a server-tick timer wait. Never reuse a token across restarts.
      if #ingress.trusted+#ingress.discovery>0 then
        verifySequence=verifySequence+1
        local token=verifySequence
        os.queueEvent(VERIFY_EVENT,token)
        repeat
          local event,id=os.pullEvent(VERIFY_EVENT)
          if event==VERIFY_EVENT and id==token then break end
        until false
        if ingress~=active or not ctx then return end
      end
    end
  end
end
-- Accept only bounded primitive measurement fields. Packets cannot request commands.
function M.receive(sender,packet,protocol,receivedAt)
  if protocol~=M.protocol or not settings.enabled or not validId(sender) or sender==os.getComputerID() then return false end
  local mode,crypto=authentication()
  if not mode then return false end
  local transportAge=receivedAt and math.max(0,os.clock()-receivedAt) or 0
  if mode=="keyed" then
    if type(packet)~="table" or packet.format~=ENVELOPE or packet.sender~=sender or
      type(packet.payload)~="string" or #packet.payload>MAX_PAYLOAD or
      type(packet.mac)~="string" or #packet.mac~=64 then return false end
    local expected=mac(crypto,sender,packet.payload)
    if not expected then return false end
    if not signaturesEqual(expected,packet.mac) then return false end
    local decoded,value=pcall(textutils.unserialize,packet.payload)
    if not decoded or type(value)~="table" then return false end
    packet=value
    local utc=os.epoch("utc")/1000
    if not addon.finite(packet.sentAt) or packet.sentAt>utc+2 or packet.sentAt<utc-10 then return false end
    transportAge=math.max(0,utc-packet.sentAt)
  elseif type(packet)=="table" and packet.format then
    -- A keyed envelope is never silently downgraded to plaintext.
    return false
  end
  if type(packet)~="table" or packet.version~=1 or packet.group~=settings.group or packet.frame~="world" or
    not short(packet.session,80) or not addon.finite(packet.sequence) or packet.sequence<0 or packet.sequence%1~=0 or
    not short(packet.label,80) or type(packet.radars)~="table" or #packet.radars>64 or
    type(packet.targets)~="table" or #packet.targets>128 then return false end
  local old=nodes[sender]
  local signedSessions={}
  if mode=="keyed" then
    local count=0 local utc=os.epoch("utc")/1000
    for id,record in pairs(old and old.signedSessions or {}) do
      if utc-record.sentAt<=10 then signedSessions[id]=record count=count+1 end
    end
    local record=signedSessions[packet.session]
    if record and packet.sequence<=record.sequence then return false end
    if not record and count>=32 then return false end
    signedSessions[packet.session]={sequence=packet.sequence,sentAt=packet.sentAt}
  end
  if old and old.session==packet.session and packet.sequence<=old.sequence then return false end
  local admittedAt=receivedAt or os.clock()
  -- Worker scheduling jitter must not rate-limit healthy 5 Hz arrivals.
  if old and admittedAt-(old.admittedAt or old.received)<0.15 then return false end
  if not old and not settings.trusted[tostring(sender)] then
    -- Discovery has its own quota: strangers cannot consume paired station slots.
    local count=0
    for id in pairs(nodes) do if not settings.trusted[tostring(id)] then count=count+1 end end
    if count>=16 then return false end
  end
  local node={id=sender,label=packet.label,session=packet.session,sequence=packet.sequence,received=os.clock(),admittedAt=admittedAt,radars={},targets={},signedSessions=signedSessions}
  for _,radar in ipairs(packet.radars) do
    if type(radar)~="table" then return false end
    local pos=addon.vec(radar.position)
    if not short(radar.id,128) or not pos or not addon.finite(radar.range) or radar.range<=0 or radar.range>100000 or
      not addon.finite(radar.age) or radar.age<0 or radar.age>5 then return false end
    local id="net:"..sender..":"..radar.id
    node.radars[#node.radars+1]={id=id,name=packet.label.." / "..radar.id,position=pos,range=radar.range,frame="world",remote=true,
      stationId=sender,timestamp=os.clock()-radar.age-transportAge,heading=addon.finite(radar.heading) and radar.heading or nil,
      fov=addon.finite(radar.fov) and radar.fov>0 and radar.fov<=360 and radar.fov or nil,
      halfHeight=addon.finite(radar.halfHeight) and radar.halfHeight>=0 and radar.halfHeight<=100000 and radar.halfHeight or nil,
      verticalFov=addon.finite(radar.verticalFov) and radar.verticalFov>0 and radar.verticalFov<=180 and radar.verticalFov or nil,
      running=type(radar.running)=="boolean" and radar.running or nil,
      fovSource=short(radar.fovSource,40) or "remote calibration",positionSource="remote world"}
    if radar.running==false then node.radars[#node.radars].running=false end
  end
  for _,target in ipairs(packet.targets) do
    if type(target)~="table" then return false end
    if not short(target.id,128) or not addon.vec(target.position) or not addon.finite(target.age) or target.age<0 or target.age>5 then return false end
    local source=short(target.radarId,128)
    if not source then return false end
    local present=false for _,radar in ipairs(node.radars) do if radar.id=="net:"..sender..":"..source then present=true break end end
    if not present then return false end
    local history={}
    if old then for _,previous in ipairs(old.targets) do if previous.id==target.id then history=addon.copy(previous.history) break end end end
    local timestamp=os.clock()-target.age-transportAge
    if #history==0 or timestamp>history[#history].timestamp+0.05 then
      history[#history+1]={position=addon.vec(target.position),timestamp=timestamp}
      if #history>20 then table.remove(history,1) end
    end
    node.targets[#node.targets+1]={id=target.id,position=addon.vec(target.position),velocity=addon.vec(target.velocity),
      category=short(target.category,40),entityType=short(target.entityType,128),renderName=short(target.renderName,80),
      friendly=target.friendly==true,synthetic=target.synthetic==true,remote=true,stationId=sender,
      timestamp=timestamp,freshnessKnown=true,frame="world",radarId="net:"..sender..":"..source,history=history}
  end
  nodes[sender]=node return true
end
function M.snapshot()
  local mode,why=authentication()
  local warning=mode=="keyed" and "Shared-key authenticated Rednet; NOT encrypted; key holders can impersonate stations" or M.securityWarning
  local result={nodes={},radars={},targets={},enabled=settings.enabled,modem=modem,
    warning=warning,authenticated=mode=="keyed",encrypted=false,error=problem or (settings.enabled and (mode and warning or why) or nil)}
  local now=os.clock()
  for id,node in pairs(nodes) do
    local online=now-node.received<=5
    result.nodes[#result.nodes+1]={id=id,label=node.label,online=online,age=now-node.received,included=settings.trusted[tostring(id)]==true,radars=#node.radars,targets=#node.targets}
    if mode and online and settings.trusted[tostring(id)] then
      for _,key in ipairs({"radars","targets"}) do for _,row in ipairs(node[key]) do
        if now-row.timestamp<=5 and #result[key]<(key=="radars" and 256 or 128) then result[key][#result[key]+1]=addon.copy(row) end
      end end
    end
  end
  table.sort(result.nodes,function(a,b) return a.id<b.id end)
  return result
end
function M.status()
  local mode,why=authentication()
  local warning=mode=="keyed" and "Shared-key authenticated Rednet; NOT encrypted; key holders can impersonate stations" or M.securityWarning
  local count=0 for _ in pairs(nodes) do count=count+1 end
  local stats={} for key,value in pairs(metrics) do stats[key]=value end
  stats.pending=#ingress.trusted+#ingress.discovery
  stats.trustedPending=#ingress.trusted stats.discoveryPending=#ingress.discovery
  return {enabled=settings.enabled,modem=modem,error=problem or (settings.enabled and (mode and warning or why) or nil),
    warning=warning,authenticated=mode=="keyed",encrypted=false,stations=count,ingress=stats}
end
function M.rescan() if runner then runner:rescan() end end
function M.publish(snapshot)
  local mode,crypto=authentication()
  if not mode then return nil,crypto end
  local now=os.clock()
  sequence=sequence+1
  local packet={version=1,group=settings.group,frame="world",session=session,sequence=sequence,label=(os.getComputerLabel() or "Station "..os.getComputerID()):sub(1,80),radars={},targets={}}
  local sources={}
  if settings.publish then
    for _,radar in ipairs(snapshot.radars or {}) do
      if not radar.remote and radar.position and addon.finite(radar.range) and radar.range>0 and now-radar.timestamp<=0.5 and #packet.radars<64 then
        sources[radar.id]=true
        packet.radars[#packet.radars+1]={id=radar.id,position=radar.position,range=radar.range,heading=radar.heading,fov=radar.fov,
          halfHeight=radar.halfHeight,verticalFov=radar.verticalFov,running=radar.running,fovSource=radar.fovSource,age=math.max(0,now-radar.timestamp)}
      end
    end
    for _,target in ipairs(snapshot.targets or {}) do
      if not target.remote and sources[target.radarId] and not target.stale and #packet.targets<128 then
        packet.targets[#packet.targets+1]={id=target.id,position=target.position,velocity=target.velocity,radarId=target.radarId,
          category=target.category,entityType=target.entityType,renderName=target.renderName,friendly=target.friendly,synthetic=target.synthetic,age=math.max(0,now-target.timestamp)}
      end
    end
  end
  if mode=="keyed" then
    packet.sentAt=os.epoch("utc")/1000
    local ok,payload=pcall(textutils.serialize,packet,{compact=true})
    if not ok or type(payload)~="string" or #payload>MAX_PAYLOAD then return nil,"Radar payload exceeds authenticated wire limit" end
    local sender=os.getComputerID()
    local signature=mac(crypto,sender,payload)
    if not signature then return nil,"Radar HMAC failed" end
    return {format=ENVELOPE,sender=sender,payload=payload,mac=signature}
  end
  return packet
end
function M.checkPerimeter(snapshot)
  if not settings.enabled or not settings.alerts then announced={} return end
  local now=os.clock() local inside={}
  for _,target in ipairs(snapshot.targets or {}) do
    local p=target.position
    if p and not target.stale and not target.synthetic and not target.friendly and (p.x-settings.x)^2+(p.z-settings.z)^2<=settings.radius^2 then
      inside[target.id]=true
      if not announced[target.id] and now-lastAlert>=2 then
        lastAlert=now announced[target.id]=true
        if ctx and ctx.notifications then ctx.notifications:push("warn","Radar perimeter",target.label or target.id,5) end
        require("system.libraries.log").warn("radarnet","Contact in zone: "..target.id)
      end
    end
  end
  for id in pairs(announced) do if not inside[id] then announced[id]=nil end end
end
function M.tick(rescan)
  if rescan then open() end
  local now=os.clock() for id,node in pairs(nodes) do if now-node.received>60 then nodes[id]=nil end end
  if settings.enabled and modem then
    local packet,why=M.publish(require("system.services.combatd").snapshot())
    if not packet then problem=why return end
    local ok,err=pcall(rednet.broadcast,packet,M.protocol)
    if not ok then problem=tostring(err) end
  end
end
function M.start(context)
  M.stop() ctx=context nodes={} announced={}
  settings=config.load("/system/config/radarnet.cfg",{})
  if type(settings)~="table" then settings={} end
  settings.enabled=settings.enabled==true settings.publish=settings.publish==true settings.alerts=settings.alerts==true
  settings.group=short(settings.group,40) or "overworld-local"
  settings.allowInsecure=settings.allowInsecure==true
  settings.sharedKey=type(settings.sharedKey)=="string" and settings.sharedKey or ""
  if #settings.sharedKey>256 or (#settings.sharedKey>0 and #settings.sharedKey<16) then
    settings.sharedKey="" settings.allowInsecure=false
  end
  local trusted={}
  if type(settings.trusted)=="table" then
    local ids={}
    for id,enabled in pairs(settings.trusted) do
      if type(id)=="string" and validId(tonumber(id)) and tostring(tonumber(id))==id and enabled==true then ids[#ids+1]=id end
    end
    table.sort(ids)
    for i=1,math.min(16,#ids) do trusted[ids[i]]=true end
  end
  settings.trusted=trusted
  for _,key in ipairs({"x","y","z"}) do if not addon.finite(settings[key]) then settings[key]=0 end end
  if not addon.finite(settings.radius) or settings.radius<=0 then settings.radius=100 end
  resetIngress()
  listener=ctx.eventBus:on("rednet_message",enqueue)
  if settings.enabled then require("system.libraries.log").warn("radarnet",M.status().error or M.securityWarning) end
  ingressRunner=addon.periodic(ctx,"radarnet-ingress",0.05,drainIngress)
  runner=addon.periodic(ctx,"radarnetd",0.2,M.tick)
end
function M.stop()
  if ingressRunner then ingressRunner:stop() ingressRunner=nil end
  if runner then runner:stop() runner=nil end
  if ctx and listener then ctx.eventBus:off(listener) end
  ctx=nil listener=nil modem=nil problem=nil nodes={}
  resetIngress()
  -- Shared Rednet modems belong to Messenger too: never close them here.
end
return M
