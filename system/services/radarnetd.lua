local addon=require("system.libraries.addon")
local config=require("system.libraries.config")
local safeWrite=require("system.libraries.safe_write")
local permissions=require("system.security.permissions")
local M={protocol="mintcraft.radar.v1"}
local ctx,runner,listener,modem,problem
local nodes,settings,sequence={}, {},0
local session=tostring(os.epoch and os.epoch("utc") or os.clock())
local announced,lastAlert={},-math.huge
local function short(value,limit)
  return type(value)=="string" and #value<=limit and not value:find("[%c]") and value or nil
end
local function validId(id) return addon.finite(id) and id>=0 and id%1==0 end
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
    if not validId(tonumber(id)) or type(enabled)~="boolean" then return false,"invalid station ID" end count=count+1
  end
  if count>16 then return false,"maximum 16 stations" end
  if not addon.finite(value.radius) or value.radius<=0 or value.radius>100000 then return false,"Zone radius must be 1..100000m" end
  if not addon.vec({x=value.x,y=value.y,z=value.z}) then return false,"Zone requires world X/Y/Z" end
  for _,key in ipairs({"enabled","publish","alerts"}) do if type(value[key])~="boolean" then return false,"invalid "..key end end
  local changed=value.group~=settings.group or value.enabled~=settings.enabled
  local saved,why=save(value)
  if saved then if changed then nodes={} end if runner then runner:rescan() end end
  return saved,why
end
local function open()
  modem=nil
  if not settings.enabled then problem="Disabled" return end
  for _,row in ipairs(addon.inventory()) do if addon.hasType(row,"modem") then
    local ok=pcall(function() if not rednet.isOpen(row.name) then rednet.open(row.name) end end)
    if ok then modem=row.name problem=nil return end
  end end
  problem="No modem; connect a wired/wireless modem"
end
-- Accept only bounded primitive measurement fields. Packets cannot request commands.
function M.receive(sender,packet,protocol)
  if protocol~=M.protocol or not settings.enabled or not validId(sender) or sender==os.getComputerID() then return false end
  if type(packet)~="table" or packet.version~=1 or packet.group~=settings.group or packet.frame~="world" or
    not short(packet.session,80) or not addon.finite(packet.sequence) or packet.sequence<0 or packet.sequence%1~=0 or
    not short(packet.label,80) or type(packet.radars)~="table" or #packet.radars>64 or
    type(packet.targets)~="table" or #packet.targets>128 then return false end
  local old=nodes[sender]
  if old and old.session==packet.session and packet.sequence<=old.sequence then return false end
  if old and os.clock()-old.received<0.15 then return false end
  if not old then local count=0 for _ in pairs(nodes) do count=count+1 end if count>=16 then return false end end
  local node={id=sender,label=packet.label,session=packet.session,sequence=packet.sequence,received=os.clock(),radars={},targets={}}
  for _,radar in ipairs(packet.radars) do
    if type(radar)~="table" then return false end
    local pos=addon.vec(radar.position)
    if not short(radar.id,128) or not pos or not addon.finite(radar.range) or radar.range<=0 or radar.range>100000 or
      not addon.finite(radar.age) or radar.age<0 or radar.age>5 then return false end
    local id="net:"..sender..":"..radar.id
    node.radars[#node.radars+1]={id=id,name=packet.label.." / "..radar.id,position=pos,range=radar.range,frame="world",remote=true,
      stationId=sender,timestamp=os.clock()-radar.age,heading=addon.finite(radar.heading) and radar.heading or nil,
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
    local timestamp=os.clock()-target.age
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
  local result={nodes={},radars={},targets={},enabled=settings.enabled,modem=modem,error=problem}
  local now=os.clock()
  for id,node in pairs(nodes) do
    local online=now-node.received<=5
    result.nodes[#result.nodes+1]={id=id,label=node.label,online=online,age=now-node.received,included=settings.trusted[tostring(id)]==true,radars=#node.radars,targets=#node.targets}
    if online and settings.trusted[tostring(id)] then
      for _,key in ipairs({"radars","targets"}) do for _,row in ipairs(node[key]) do
        if now-row.timestamp<=5 and #result[key]<(key=="radars" and 256 or 128) then result[key][#result[key]+1]=addon.copy(row) end
      end end
    end
  end
  table.sort(result.nodes,function(a,b) return a.id<b.id end)
  return result
end
function M.status() local snap=M.snapshot() return {enabled=snap.enabled,modem=snap.modem,error=snap.error,stations=#snap.nodes} end
function M.rescan() if runner then runner:rescan() end end
function M.publish(snapshot)
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
    local ok,err=pcall(rednet.broadcast,M.publish(require("system.services.combatd").snapshot()),M.protocol)
    if not ok then problem=tostring(err) end
  end
end
function M.start(context)
  M.stop() ctx=context nodes={} announced={}
  settings=config.load("/system/config/radarnet.cfg",{})
  if type(settings)~="table" then settings={} end
  settings.enabled=settings.enabled==true settings.publish=settings.publish==true settings.alerts=settings.alerts==true
  settings.group=short(settings.group,40) or "overworld-local"
  settings.trusted=type(settings.trusted)=="table" and settings.trusted or {}
  for _,key in ipairs({"x","y","z"}) do if not addon.finite(settings[key]) then settings[key]=0 end end
  if not addon.finite(settings.radius) or settings.radius<=0 then settings.radius=100 end
  listener=ctx.eventBus:on("rednet_message",M.receive)
  runner=addon.periodic(ctx,"radarnetd",0.2,M.tick)
end
function M.stop()
  if runner then runner:stop() runner=nil end
  if ctx and listener then ctx.eventBus:off(listener) end
  ctx=nil listener=nil modem=nil nodes={}
  -- Shared Rednet modems belong to Messenger too: never close them here.
end
return M
