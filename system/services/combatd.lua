local addon = require("system.libraries.addon")
local geometry = require("system.navigation.geometry")
local config = require("system.libraries.config")
local safeWrite = require("system.libraries.safe_write")
local permissions = require("system.security.permissions")
local sable = require("system.services.sabled")
local log = require("system.libraries.log")
local radarNet = require("system.services.radarnetd")
local adapters = require("system.navigation.combat_adapters")
local M = {}
local ctx, runner, inventory, settings = nil, nil, {}, {}
local tracks, revision, pending, tokens, serial = {}, 0, {}, {}, 0
local active, firing, uncertain = nil, nil, {}
local probeResult
local lastFault
local slowReads={}
local lastCycleCompletedAt
local slowMethods={getRange=true,getDishCount=true,getRotationSpeed=true}
local cached = { ok = false, status = "waiting for combat", devices = {}, radars = {}, targets = {}, cannons = {}, errors = {}, revision = 0, timestamp = 0 }
local READS = { radar = {"getTracks", "getPosition", "getRange", "getRotation", "getRotationSpeed", "getDishCount", "getScanGeometry"},
  cannon = {"getInfo", "isComputerControl"}, controller = {"getAngle"} }

local function loadSettings()
  settings = config.load("/system/config/combat.cfg", {})
  if type(settings)~="table" then settings={} end
  settings.refreshSeconds=0.05
  settings.radar = settings.radar or {}
  settings.radar.maxTargets = math.max(1, math.min(128, tonumber(settings.radar.maxTargets) or 128))
  settings.radar.staleSeconds = 5
  settings.aliases, settings.profiles, settings.radars = settings.aliases or {}, settings.profiles or {}, settings.radars or {}
  settings.requireFireConfirmation, settings.semiAuto = true, true
end

local function allowed(actor, permission)
  local process = ctx and actor and ctx.scheduler.processes[actor.pid]
  if not process or process.state ~= "ready" then return false, "owner not running" end
  return permissions.require({pid = process.pid, appId = process.meta.appId, permissions = process.permissions}, permission)
end

local function role(row)
  if addon.hasType(row, "cannon_mount") and row.set.getInfo and row.set.setTargetAngles then return "cannon" end
  if row.set.getTracks then return "radar" end
  for _, value in ipairs(row.types) do
    if value == "create_radar:yaw_controller" or value == "create_radar:pitch_controller" or value == "create_radar:fire_controller" then return "controller" end
  end
  return "unknown"
end

local function knownRadar(row)
  return addon.hasType(row, "create_radar:radar")
    or addon.hasType(row, "create_radar:radar_bearing")
    or addon.hasType(row, "create_radar:plane_radar")
end

local function find(rows, id)
  if id==nil then return nil end
  for _, row in ipairs(rows or {}) do if row.id == id or row.name == id then return row end end
end

local function origin(position, calibration)
  local onShip = sable.status().inSublevel
  local frame = calibration.frame or "unknown"
  if calibration.origin and calibration.positionMode==nil then
    if onShip then return nil,"fixed world origin invalid on moving sublevel" end
    return addon.vec(calibration.origin), "calibrated world"
  end
  if calibration.positionMode == "manual" then
    position = {x=calibration.positionX,y=calibration.positionY,z=calibration.positionZ}
    if not addon.vec(position) then return nil,"configured radar coordinates incomplete" end
    if frame == "world" and onShip then return nil,"fixed world coordinates invalid on moving sublevel" end
  end
  if frame == "world" then return addon.vec(position), "world" end
  if frame == "body" then
    local snapshot=sable.snapshot()
    if not onShip or os.clock()-(snapshot.timestamp or 0)>0.5 then return nil,"stale/missing sublevel pose" end
    local position,why=geometry.transform(position,snapshot.sublevel and snapshot.sublevel.logicalPose)
    return position,position and "world" or why
  end
  return nil, "unknown"
end

function M.acquire(rescan)
  if rescan then inventory = addon.inventory(true) slowReads={} end
  local now = os.clock()
  local cycleStart,completed,lastPartialAt=now,0,now
  local previousSnapshot,done,present=cached,{},{}
  for _,item in ipairs(inventory) do present[item.name]=true end
  for id in pairs(slowReads) do if not present[id] then slowReads[id]=nil end end
  for _,target in pairs(tracks) do
    for source,report in pairs(target.observations or {}) do if not present[source] then
      target.retiredFriendly=target.retiredFriendly or report.friendly==true
      target.retiredSynthetic=target.retiredSynthetic or report.synthetic==true
      target.observations[source]=nil
      if target.sources then target.sources[source]=nil end
    end end
  end
  local trackCount=0
  for id,target in pairs(tracks) do if now-target.timestamp>10 then tracks[id]=nil else trackCount=trackCount+1 end end
  local snap = {ok = true, devices = {}, radars = {}, targets = {}, cannons = {}, controllers = {}, unknownCombatDevices = {}, errors = {}, timestamp = now, frame = "world"}
  local function acquisition()
    local elapsed=os.clock()-cycleStart
    return {startedAt=cycleStart,completed=completed,pending=#inventory-completed,
      elapsed=elapsed,overrun=elapsed>0.05,targetHz=20,
      cycleCapacityHz=elapsed>0 and 1/elapsed or nil,budget=addon.metrics()}
  end
  local function publishPartial()
    if os.clock()-lastPartialAt<0.05 or completed==#inventory then return end
    lastPartialAt=os.clock()
    local partial=addon.copy(snap)
    for _,key in ipairs({"radars","cannons","controllers","devices","unknownCombatDevices"}) do
      local included={} for _,row in ipairs(partial[key]) do included[row.id or row.name]=true end
      for _,row in ipairs(previousSnapshot[key] or {}) do
        local id=row.id or row.name
        if not included[id] and (row.remote or present[id] and not done[id]) then
          local pendingRow=addon.copy(row)
          pendingRow.pending=true pendingRow.stale=true
          for _,measure in pairs(pendingRow.measurements or {}) do measure.valid=false end
          partial[key][#partial[key]+1]=pendingRow
        end
      end
    end
    partial.timestamp=os.clock() partial.acquisition=acquisition()
    partial.targets={}
    for _,target in pairs(tracks) do
      local row=addon.copy(target)
      row.pending=present[row.radarId] and not done[row.radarId] or nil
      row.stale=row.pending or not row.freshnessKnown or os.clock()-row.timestamp>5
      if os.clock()-row.timestamp<=10 then partial.targets[#partial.targets+1]=row end
    end
    local targetIds={} for _,row in ipairs(partial.targets) do targetIds[row.id]=true end
    for _,row in ipairs(previousSnapshot.targets or {}) do
      if not targetIds[row.id] and row.remote and os.clock()-row.timestamp<=10 then
        local retained=addon.copy(row) retained.pending=true retained.stale=true
        partial.targets[#partial.targets+1]=retained
      end
    end
    partial.network=cached.network partial.zone=cached.zone
    partial.counts={radars=#partial.radars,targets=#partial.targets,cannons=#partial.cannons,unknown=#partial.unknownCombatDevices}
    partial.available=#partial.radars+#partial.cannons+#partial.controllers>0
    partial.ok=false partial.status="combat acquisition overrun; partial results, "..partial.acquisition.pending.." devices pending"
    revision=revision+1 partial.revision=revision cached=partial
  end
  local branches={}
  for _, item in ipairs(inventory) do
    branches[#branches+1]=function()
    local now=os.clock()
    item.role = role(item)
    if item.role ~= "unknown" then
      local public = {id = item.name, name = item.name, types = item.types, methods = item.methods, role = item.role}
      snap.devices[#snap.devices + 1] = public
      local methods = READS[item.role]
      local radarConfig = item.role=="radar" and settings.radars[item.name]
      local adapter
      if item.role=="radar" then
        adapter=adapters.radar(item,(radarConfig or {}).apiProfile,
          radarConfig and (radarConfig.positionMode=="manual" or radarConfig.origin))
        methods=adapter.methods
      end
      local proxy,readMethods,observed,received={},{},{},{}
      local cache=slowReads[item.name] or {} slowReads[item.name]=cache
      for _,method in ipairs(methods) do
        local saved=cache[method]
        if not (item.role=="radar" and slowMethods[method] and saved and now-saved.observedAt<1) then
          readMethods[#readMethods+1]=method
          if type(item.device[method])=="function" then
            proxy[method]=function()
              observed[method]=os.clock()
              local ok,value=pcall(item.device[method])
              received[method]=os.clock()
              if not ok then error(value,0) end
              return value
            end
          end
        end
      end
      local values, errors = addon.read(proxy, readMethods)
      for _,method in ipairs(methods) do if item.role=="radar" and slowMethods[method] then
        if observed[method] then
          cache[method]={value=values[method],error=errors[method],observedAt=observed[method],receivedAt=received[method]}
        elseif cache[method] then
          local saved=cache[method]
          values[method],errors[method]=saved.value,saved.error
          observed[method],received[method]=saved.observedAt,saved.receivedAt
        end
      end end
      now=observed.getTracks or observed.getInfo or os.clock()
      local scan=type(values.getScanGeometry)=="table" and values.getScanGeometry.version==1 and values.getScanGeometry or nil
      if scan then
        values.getPosition,values.getRange,values.getRotation=scan.position,scan.range,scan.rotation
        values.getRotationSpeed,values.getDishCount=scan.rotationSpeed,scan.dishCount
      end
      for method, err in pairs(errors) do snap.errors[#snap.errors + 1] = item.name .. ": " .. method .. ": " .. err end
      if item.role == "radar" then
        local cal = settings.radars[item.name] or {}
        local effectiveCal = cal
        if scan and scan.positionFrame=="world" and cal.positionMode~="manual" and not cal.origin then
          effectiveCal=addon.copy(cal) effectiveCal.frame="world"
        end
        -- The documented API returns block coordinates. They are world coordinates
        -- on fixed terrain, not necessarily on a moving sublevel/shipyard.
        if not scan and cal.frame == nil and knownRadar(item) and not sable.status().inSublevel then
          effectiveCal = addon.copy(cal)
          effectiveCal.frame = "world"
        end
        if adapter.profile=="5.0-EA" and addon.hasType(item,"create_radar:plane_radar") and cal.positionMode~="manual" and not cal.origin then
          effectiveCal=addon.copy(cal) effectiveCal.frame="world"
        end
        local pos, frame = origin(values.getPosition, effectiveCal)
        local radar = {id = item.name, name = item.name, position = pos, frame = frame, rawPosition = addon.vec(values.getPosition),
          range = addon.finite(values.getRange) and values.getRange or nil, heading = nil,
          rawRotation = addon.finite(values.getRotation) and values.getRotation or nil,
          fov = addon.finite(cal.fov) and cal.fov or nil, fovSource = cal.fov and "calibrated" or "unknown",
          verticalFov=addon.finite(cal.verticalFov) and cal.verticalFov or nil,
          rotationSpeed = values.getRotationSpeed, dishCount = values.getDishCount,
          rawTrackCount = type(values.getTracks)=="table" and #values.getTracks or nil,
          readErrors = addon.copy(errors), timestamp = now,observedAt=now,receivedAt=received.getTracks or os.clock(),
          fieldTimes={observedAt=addon.copy(observed),receivedAt=addon.copy(received)},
          capabilities={tracks=item.set.getTracks==true,position=item.set.getPosition==true,
            range=item.set.getRange==true,rotation=item.set.getRotation==true,dishes=item.set.getDishCount==true},
          trackApi="getTracks", classificationSource="not exposed"}
        radar.autoGeometry=scan~=nil
        radar.scanPositionFrame=scan and scan.positionFrame
        radar.scanHeadingFrame=scan and scan.headingFrame
        radar.running=scan and scan.running
        radar.halfHeight=scan and addon.finite(scan.halfHeight) and scan.halfHeight>=0 and scan.halfHeight or nil
        if scan and addon.finite(scan.fov) and scan.fov>0 and scan.fov<=360 then
          radar.fov,radar.fovSource=scan.fov,"scanner API"
        end
        radar.kind=addon.hasType(item,"create_radar:plane_radar") and "fixed" or item.set.getRotation and "rotating" or "unknown"
        radar.apiProfile=adapter.profile
        radar.profileEvidence,radar.adapterOrigin,radar.profileLimitation=adapter.evidence,adapter.origin,adapter.limitation
        if adapter.profile=="bridge" and not scan then
          radar.readErrors.getScanGeometry="bridge geometry v1 unavailable"
          snap.errors[#snap.errors+1]=item.name..": bridge geometry v1 unavailable"
        end
        radar.positionSource = (cal.origin and cal.positionMode==nil) and "configured world origin" or
          cal.positionMode=="manual" and "configured "..tostring(cal.frame) or "API"
        radar.positionIssue = not pos and frame or nil
        for _, method in ipairs({"getTracks", "getPosition", "getRange"}) do
          if not item.set[method] and not (method=="getPosition" and pos) and not (scan and values[method]~=nil) then
            radar.readErrors[method] = "method unavailable"
            snap.errors[#snap.errors + 1] = item.name .. ": " .. method .. " unavailable"
          end
        end
        radar.readStatus = next(radar.readErrors) and "read failed/incomplete" or
          not radar.position and "position frame required" or
          (not radar.range or radar.range<=0) and "range unavailable" or
          radar.rawTrackCount==0 and "reading OK; no contacts returned" or "reading OK"
        if scan and scan.headingFrame=="world" and addon.finite(scan.heading) then
          radar.heading=scan.heading%360 radar.headingSource="scanner API"
        elseif cal.headingValidated and radar.rawRotation then
          radar.heading = (radar.rawRotation * (cal.headingSign or 1) + (cal.headingOffset or 0)) % 360
          if cal.headingFrame == "body" then
            local nav = require("system.services.avionicsd").snapshot().measurements or {}
            radar.heading = nav.heading and nav.heading.valid and now-nav.heading.timestamp<=0.5 and radar.heading + nav.heading.value or nil
          end
        elseif addon.finite(cal.heading) then radar.heading = cal.heading end
        radar.measurements={position=addon.measure(pos,"m",frame,item.name,now),heading=addon.measure(radar.heading,"deg","world",item.name,now),range=addon.measure(radar.range,"m",frame,item.name,now),fov=addon.measure(radar.fov,"deg","radar calibrated",item.name,now)}
        radar.measurements.position.timestamp=observed.getScanGeometry or observed.getPosition or now
        radar.measurements.heading.timestamp=observed.getScanGeometry or observed.getRotation or now
        radar.measurements.range.timestamp=observed.getRange or observed.getScanGeometry or now
        snap.radars[#snap.radars + 1] = radar
        local badRecords=0
        for index, raw in ipairs(type(values.getTracks) == "table" and values.getTracks or {}) do
          if index>512 then
            snap.errors[#snap.errors+1]=item.name..": track processing capped at 512 entries"
            break
          end
          if type(raw)=="table" then
          local id, position = raw.id and tostring(raw.id), addon.vec(raw.position)
          if id and position and (tracks[id] or trackCount<settings.radar.maxTargets) then
            local old = tracks[id]
            if not old then trackCount=trackCount+1 end
            local target = old or {id = id, history = {}, timestamp=now, position=position}
            target.observations=target.observations or {}
            local previous=target.observations[item.name]
            local numeric=addon.finite(raw.scannedTime)
            local progressed=previous and numeric and addon.finite(previous.scannedTime) and raw.scannedTime>previous.scannedTime
            local verified=progressed and now-previous.observedAt>=0 and now-previous.observedAt<=5 or false
            local same=previous and numeric and raw.scannedTime==previous.scannedTime
            local observation={scannedTime=raw.scannedTime,receivedAt=received.getTracks or now,
              observedAt=progressed and now or same and previous.observedAt or now,
              verified=verified or same and previous.verified or false,
              friendly=raw.friendly,synthetic=raw.synthetic}
            -- Only verified new boolean evidence can remove a safety flag.
            if previous then
              if numeric and addon.finite(previous.scannedTime) and raw.scannedTime<previous.scannedTime then
                observation.scannedTime=previous.scannedTime
              end
              if not verified or type(raw.friendly)~="boolean" then
                observation.friendly=previous.friendly==true or raw.friendly==true or raw.friendly
              end
              if not verified or type(raw.synthetic)~="boolean" then
                observation.synthetic=previous.synthetic==true or raw.synthetic==true or raw.synthetic
              end
            end
            local sourceCount=0 for _ in pairs(target.observations) do sourceCount=sourceCount+1 end
            if previous or sourceCount<128 then target.observations[item.name]=observation
            else target.classificationUncertain=true end
            local changed = not old or (verified and (not addon.finite(target.scannedTime) or raw.scannedTime>target.scannedTime))
            if changed then
              target.timestamp, target.position, target.scannedTime = observation.observedAt, position, raw.scannedTime
              if not same then target.history[#target.history + 1] = {position = position, timestamp = now} end
              if #target.history > 20 then table.remove(target.history, 1) end
              target.category, target.entityType, target.radarId = raw.category, raw.entityType, item.name
              target.velocity, target.frame = addon.vec(raw.velocity), "world"
              target.velocityUnit = raw.category=="entity" and "blocks/tick" or "API units (unverified)"
              target.renderName = type(raw.name) == "string" and raw.name or type(raw.displayName) == "string" and raw.displayName or nil
              target.freshnessKnown=observation.verified
            end
            if target.radarId==item.name and not observation.verified then target.freshnessKnown=false end
            target.label = settings.aliases[id] or target.renderName or ("ID " .. id:sub(1, 8))
            target.labelSource = settings.aliases[id] and "alias" or target.renderName and "api" or "id"
            target.sources=target.sources or {}
            if target.observations[item.name] then target.sources[item.name]=now end
            target.friendly,target.synthetic=target.retiredFriendly or nil,target.retiredSynthetic or nil
            for _,report in pairs(target.observations) do
              if report.friendly==true then target.friendly=true elseif target.friendly==nil and report.friendly==false then target.friendly=false end
              if report.synthetic==true then target.synthetic=true elseif target.synthetic==nil and report.synthetic==false then target.synthetic=false end
            end
            target.classificationSource="per-radar scan evidence; true wins conflicts"
            if type(raw.friendly)=="boolean" or type(raw.synthetic)=="boolean" then radar.classificationSource="API friendly/synthetic" end
            tracks[id] = target
          end
          else badRecords=badRecords+1 end
        end
        if badRecords>0 then snap.errors[#snap.errors+1]=item.name..": malformed track records: "..badRecords end
      elseif item.role == "cannon" then
        local info = type(values.getInfo) == "table" and values.getInfo or {}
        local cal = settings.profiles[item.name] or {}
        local pos, frame = origin({x=info.x,y=info.y,z=info.z}, cal)
        snap.cannons[#snap.cannons + 1] = {id=item.name,name=item.name,position=pos,frame=frame,
          yaw=info.yaw,pitch=info.pitch,assembled=info.assembled,computerControl=info.computerControl,
          targetYaw=info.targetYaw,targetPitch=info.targetPitch,info=info,calibrated=cal.validated==true,timestamp=now,observedAt=now,receivedAt=received.getInfo or os.clock(),
          measurements={position=addon.measure(pos,"m",frame,item.name,now),yaw=addon.measure(info.yaw,"deg","mount",item.name,now),pitch=addon.measure(info.pitch,"deg","mount",item.name,now)}}
      else snap.controllers[#snap.controllers + 1] = {id=item.name,name=item.name,values=values} end
    else
      local text = table.concat(item.types, " ")
      snap.devices[#snap.devices+1]={id=item.name,name=item.name,types=addon.copy(item.types),methods=addon.copy(item.methods),role="unknown (list only)"}
      if text:find("radar",1,true) or text:find("cannon",1,true) then snap.unknownCombatDevices[#snap.unknownCombatDevices+1] = {name=item.name,types=item.types,methods=item.methods} end
    end
    done[item.name]=true completed=completed+1 publishPartial()
    end
  end
  if #branches>0 then addon.parallel(branches) end
  now=os.clock() snap.timestamp=now snap.acquisition=acquisition()
  snap.acquisition.effectiveHz=lastCycleCompletedAt and now>lastCycleCompletedAt and 1/(now-lastCycleCompletedAt) or nil
  lastCycleCompletedAt=now
  for _,key in ipairs({"devices","radars","cannons","controllers"}) do table.sort(snap[key],function(a,b) return a.name<b.name end) end
  for token,entry in pairs(tokens) do if now>entry.expires then tokens[token]=nil end end
  for id, target in pairs(tracks) do
    for source,time in pairs(target.sources or {}) do if now-time>5 then target.sources[source]=nil end end
    target.stale = not target.freshnessKnown or now - target.timestamp > 5
    target.measurements={position=addon.measure(target.position,"m","world",target.radarId,target.timestamp),velocity=addon.measure(target.velocity,target.velocityUnit,"world",target.radarId,target.timestamp)}
    for _,measurement in pairs(target.measurements) do if target.stale then measurement.valid=false end end
    if now - target.timestamp > 10 then tracks[id] = nil else snap.targets[#snap.targets + 1] = addon.copy(target) end
  end
  local mesh=radarNet.snapshot()
  local agents=require("system.nexus.radar_hub").snapshot(now)
  for _,radar in ipairs(agents.radars) do mesh.radars[#mesh.radars+1]=radar end
  for _,target in ipairs(agents.targets) do mesh.targets[#mesh.targets+1]=target end
  snap.network=mesh
  snap.zone=radarNet.configuration()
  local byId={} for _,target in ipairs(snap.targets) do byId[target.id]=target end
  for _,radar in ipairs(mesh.radars) do snap.radars[#snap.radars+1]=radar end
  for _,target in ipairs(mesh.targets) do
    local existing=byId[target.id]
    if not existing and #snap.targets<settings.radar.maxTargets then
      target.label=settings.aliases[target.id] or target.renderName or ("ID "..target.id:sub(1,8))
      target.labelSource=settings.aliases[target.id] and "alias" or target.renderName and "api" or "id"
      target.stale=target.stale or now-target.timestamp>5
      snap.targets[#snap.targets+1]=target byId[target.id]=target
    elseif existing then
      existing.sources=existing.sources or {[existing.radarId]=existing.timestamp}
      existing.sources[target.radarId]=target.timestamp
      -- Remote data never upgrades a local contact into a commandable target.
      if (existing.remote or existing.stale) and target.timestamp>existing.timestamp then
        local sources=existing.sources
        for key in pairs(existing) do existing[key]=nil end
        for key,value in pairs(target) do existing[key]=addon.copy(value) end
        existing.sources=sources existing.remote=true existing.stale=target.stale or now-target.timestamp>5
        existing.label=settings.aliases[existing.id] or existing.renderName or ("ID "..existing.id:sub(1,8))
        existing.labelSource=settings.aliases[existing.id] and "alias" or existing.renderName and "api" or "id"
      end
    end
  end
  local prefixes={}
  for _,target in ipairs(snap.targets) do if target.labelSource=="id" then local prefix=target.id:sub(1,8) prefixes[prefix]=(prefixes[prefix] or 0)+1 end end
  for _,target in ipairs(snap.targets) do if target.labelSource=="id" and prefixes[target.id:sub(1,8)]>1 then target.label="ID "..target.id:sub(1,8)..".."..target.id:sub(-6) end end
  table.sort(snap.targets, function(a,b) if a.timestamp ~= b.timestamp then return a.timestamp > b.timestamp end return a.id < b.id end)
  while #snap.targets > settings.radar.maxTargets do
    local removed = table.remove(snap.targets)
    tracks[removed.id] = nil
  end
  revision = revision + 1
  snap.revision = revision
  snap.counts = {radars=#snap.radars, targets=#snap.targets, cannons=#snap.cannons, unknown=#snap.unknownCombatDevices}
  snap.available = #snap.radars+#snap.cannons+#snap.controllers>0
  snap.ok=#snap.errors==0
  snap.status = not snap.ok and "combat telemetry degraded" or snap.available and "combat peripherals ready" or "no supported combat peripheral"
  if snap.ok and snap.acquisition.overrun then snap.status="combat acquisition overrun; inspect measured cadence/budget" end
  lastFault=snap.errors[1]
  snap.lastFault=lastFault
  cached = snap
  radarNet.checkPerimeter(snap)
end

function M.snapshot() local result=addon.copy(cached) result.probe=addon.copy(probeResult) return result end
function M.status() return {ok=cached.ok,available=cached.available,status=cached.status,lastFault=lastFault,revision=cached.revision,timestamp=cached.timestamp,counts=addon.copy(cached.counts or {}),errors=addon.copy(cached.errors),uncertain=addon.copy(uncertain),acquisition=addon.copy(cached.acquisition)} end
function M.health()
  local health=M.status()
  health.pid,health.lastSuccess=runner and runner.pid,runner and runner.lastSuccess
  health.commandPid=M.commandPid
  local commandWorker=ctx and ctx.scheduler.processes[M.commandPid]
  if commandWorker and commandWorker.state~="ready" then
    health.ok,health.lastFault,health.status=false,commandWorker.error or "combat command worker stopped","combat command worker stopped"
  end
  if next(uncertain) then health.ok=false health.lastFault=health.lastFault or "combat output uncertain; manual verification required" end
  return health
end
function M.rescan() if runner then runner:rescan() end end
function M.configuration() return addon.copy(settings) end
function M.autoConfigureRadars(actor)
  local ok,err=allowed(actor,"combat.configure") if not ok then return false,err end
  local updated=addon.copy(settings) local count=0 local missing=0
  for _,radar in ipairs(cached.radars) do if not radar.remote then
    if radar.autoGeometry and radar.rawPosition and radar.scanPositionFrame=="world" then
      local cal=updated.radars[radar.id] or {}
      cal.positionMode="api" cal.frame="world" cal.apiProfile="bridge"
      -- Retain the old manual origin/coordinates for recovery without using them.
      if cal.origin then cal.manualOriginBackup=cal.origin cal.origin=nil end
      updated.radars[radar.id]=cal count=count+1
    else missing=missing+1 end
  end end
  if count==0 then return false,"No valid optional bridge geometry; stock 4.x/EA require manual Setup (position/orientation)" end
  local saved,why=safeWrite.write("/system/config/combat.cfg",textutils.serialize(updated))
  if not saved then return false,why end
  settings=updated M.rescan()
  return true,tostring(count).." radars on automatic API; "..missing.." without bridge"
end
function M.validateRadar(value)
  if type(value)~="table" then return false,"invalid radar configuration" end
  if value.frame~="world" and value.frame~="body" then return false,"Position frame required: world/body" end
  if value.headingFrame~="world" and value.headingFrame~="body" then return false,"heading frame required" end
  if value.headingSign~=1 and value.headingSign~=-1 then return false,"headingSign must be +1 or -1" end
  if not addon.finite(value.headingOffset) then return false,"heading offset invalid" end
  if value.positionMode~=nil and value.positionMode~="api" and value.positionMode~="manual" then return false,"invalid radar position source" end
  if value.apiProfile~=nil and value.apiProfile~="auto" and value.apiProfile~="4.x" and value.apiProfile~="5.0-EA" and value.apiProfile~="bridge" then return false,"unknown radar API profile" end
  if value.positionMode=="manual" then
    if not addon.vec({x=value.positionX,y=value.positionY,z=value.positionZ}) then return false,"manual position requires finite X/Y/Z" end
    if value.frame=="world" and sable.status().inSublevel then return false,"moving sublevel requires local body coordinates" end
  end
  for _,entry in ipairs({{"fov",360},{"verticalFov",180}}) do
    local v=value[entry[1]]
    if v~=nil and (not addon.finite(v) or v<=0 or v>entry[2]) then return false,entry[1].." outside bounds" end
  end
  if value.heading~=nil and not addon.finite(value.heading) then return false,"fixed heading invalid" end
  return true
end
function M.configure(actor, section, id, value)
  local ok, err = allowed(actor, "combat.configure")
  if not ok then return false, err end
  if section ~= "aliases" and section ~= "profiles" and section ~= "radars" then return false, "invalid section" end
  if type(id)~="string" or id=="" then return false,"invalid ID" end
  if section=="aliases" then
    if type(value)~="string" or #value>80 then return false,"alias must be at most 80 characters" end
  elseif type(value)~="table" then return false,"invalid calibration" end
  if section=="profiles" or section=="radars" then
    if value.frame~="world" and value.frame~="body" and value.frame~="unknown" then return false,"unknown coordinate convention" end
    if value.headingFrame~="world" and value.headingFrame~="body" then return false,"heading frame required" end
    local signKeys=section=="profiles" and {"yawSign","pitchSign"} or {"headingSign"}
    for _,key in ipairs(signKeys) do if value[key]~=1 and value[key]~=-1 then return false,key.." must be +1 or -1" end end
    if section=="radars" then
      local valid,why=M.validateRadar(value) if not valid then return false,why end
      if value.positionMode~=nil and value.positionMode~="api" and value.positionMode~="manual" then return false,"invalid radar position source" end
      if value.positionMode=="manual" then
        if not addon.vec({x=value.positionX,y=value.positionY,z=value.positionZ}) then return false,"manual position requires finite X/Y/Z" end
        if value.frame=="unknown" then return false,"manual position requires world/body frame" end
        if value.frame=="world" and sable.status().inSublevel then return false,"moving sublevel requires local body coordinates" end
      end
      if value.fov~=nil and (not addon.finite(value.fov) or value.fov<=0 or value.fov>360) then return false,"FOV must be 1..360 deg" end
      if value.verticalFov~=nil and (not addon.finite(value.verticalFov) or value.verticalFov<=0 or value.verticalFov>180) then return false,"vertical FOV must be 1..180 deg" end
      if not addon.finite(value.headingOffset) then return false,"heading offset invalid" end
    elseif value.validated then
      for _,key in ipairs({"gravity","muzzleVelocity","minYaw","maxYaw","minPitch","maxPitch","yawOffset","pitchOffset"}) do
        if not addon.finite(value[key]) then return false,key.." missing" end
      end
      if value.gravity<=0 or value.muzzleVelocity<=0 or value.minPitch>value.maxPitch or value.minYaw>value.maxYaw then return false,"invalid ballistic/mechanical profile" end
    end
  end
  local previous=settings[section][id]
  settings[section][id] = addon.copy(value)
  local saved, reason = safeWrite.write("/system/config/combat.cfg", textutils.serialize(settings))
  if saved then M.rescan() end
  if not saved then settings[section][id]=previous end
  return saved, reason
end

function M.solution(cannonId, targetId)
  if cached.acquisition and cached.acquisition.pending>0 then return nil,"combat acquisition incomplete; command blocked" end
  local cannon, target = find(cached.cannons, cannonId), find(cached.targets, type(targetId)=="table" and targetId.id or targetId)
  if not cannon or not target then return nil, "select cannon and target" end
  if target.remote then return nil,"remote Rednet contact: display/alerts only" end
  if target.classificationUncertain then return nil,"classification source limit exceeded; command blocked" end
  if target.friendly==true then return nil,"API marks target friendly; command blocked" end
  if target.synthetic==true then return nil,"API marks synthetic contact; command blocked" end
  if not target.freshnessKnown or target.stale or os.clock()-target.timestamp > 5 then return nil, "target stale/unverified scan progression" end
  if os.clock()-(cannon.timestamp or 0)>0.5 then return nil,"cannon telemetry stale" end
  local profile = settings.profiles[cannon.id] or {}
  if not profile.validated then return nil, "cannon profile not calibrated" end
  local rel, err = geometry.relative(target.position, cannon.position)
  if not rel then return nil, err end
  local g, v = profile.gravity, profile.muzzleVelocity
  if not addon.finite(g) or not addon.finite(v) or g <= 0 or v <= 0 or rel.distance <= 0 then return nil, "invalid ballistic data" end
  local v2 = v*v
  local disc = v2*v2 - g*(g*rel.distance*rel.distance + 2*rel.y*v2)
  if disc < 0 then return nil, "target out of ballistic range" end
  local pitch = math.deg(math.atan((v2-math.sqrt(disc))/(g*rel.distance)))
  local bearing=rel.bearing
  if profile.headingFrame=="body" or profile.frame=="body" then
    local nav=require("system.services.avionicsd").snapshot()
    for _,axis in ipairs({"pitch","roll"}) do
      local measure=(nav.measurements or {})[axis]
      local stamp=measure and (measure.observedAt or measure.timestamp)
      if not measure or not measure.valid or not addon.finite(measure.value) or not addon.finite(stamp) or
        os.clock()-stamp<0 or os.clock()-stamp>0.5 or (measure.validUntil and os.clock()>measure.validUntil) then
        return nil,"body attitude unavailable/stale; yaw-only solution blocked"
      end
      if math.abs(measure.value)>0.01 then return nil,"inclined body mount unsupported; yaw-only solution blocked" end
    end
    local heading=(nav.measurements or {}).heading
    local stamp=heading and (heading.observedAt or heading.timestamp)
    if not heading or not heading.valid or not addon.finite(heading.value) or not addon.finite(stamp) or os.clock()-stamp<0 or os.clock()-stamp>0.5 or (heading.validUntil and os.clock()>heading.validUntil) then return nil,"ship heading unavailable" end
    if profile.headingFrame=="body" then bearing=geometry.wrap(bearing-heading.value) end
  end
  local yaw = bearing*(profile.yawSign or 1)+(profile.yawOffset or 0)
  pitch = pitch*(profile.pitchSign or 1)+(profile.pitchOffset or 0)
  if not (addon.finite(profile.minPitch) and addon.finite(profile.maxPitch) and addon.finite(profile.minYaw) and addon.finite(profile.maxYaw)) then return nil, "mechanical limits missing" end
  if yaw<profile.minYaw or yaw>profile.maxYaw then yaw=yaw+360*math.floor(((profile.minYaw+profile.maxYaw)/2-yaw)/360+0.5) end
  if pitch < profile.minPitch or pitch > profile.maxPitch or yaw < profile.minYaw or yaw > profile.maxYaw then return nil, "outside calibrated mount limits" end
  return {yaw=yaw,pitch=pitch,distance=rel.distance,deltaY=rel.y,cannonId=cannon.id,targetId=target.id,
    targetTimestamp=target.timestamp,revision=cached.revision,estimated=true,model="vacuum, no drag"}
end

local function enqueue(actor, kind, cannonId, targetId, token)
  local ok, err = allowed(actor, kind == "fire" and "combat.fire" or "combat.aim")
  if not ok then return false, err end
  if #pending >= 8 then return false, "command queue full" end
  if uncertain[cannonId] then return false,"previous command uncertain; Rescan/verify mount before acknowledgement" end
  if active and active.cannonId==cannonId then return false,"cannon command active" end
  for _, command in ipairs(pending) do if command.cannonId == cannonId then return false, "cannon command pending" end end
  local solution, reason = M.solution(cannonId,targetId)
  if not solution then return false, reason end
  if kind == "fire" then
    if type(token)~="string" then return false,"fire confirmation missing" end
    local entry = tokens[token]
    tokens[token] = nil
    if not entry or entry.pid ~= actor.pid or entry.cannonId ~= cannonId or entry.targetId ~= targetId or os.clock()>entry.expires then return false, "fire confirmation invalid/expired" end
  end
  serial = serial + 1
  pending[#pending + 1] = {id=serial,pid=actor.pid,kind=kind,cannonId=cannonId,targetId=targetId,solution=solution}
  os.queueEvent("mintcraft_combat_command")
  return true, serial
end

function M.prepareFire(actor, cannonId, targetId)
  local ok, err = allowed(actor,"combat.fire")
  if not ok then return nil, err end
  local solution, reason = M.solution(cannonId,targetId)
  if not solution then return nil, reason end
  serial = serial + 1
  local token = tostring(serial) .. ":" .. tostring(actor.pid)
  tokens[token] = {pid=actor.pid,cannonId=cannonId,targetId=targetId,expires=os.clock()+5}
  return token
end
function M.requestAim(actor, cannonId, targetId) return enqueue(actor,"aim",cannonId,targetId) end
function M.requestFire(actor, cannonId, targetId, token) return enqueue(actor,"fire",cannonId,targetId,token) end

function M.probe(actor,name)
  local ok, err = allowed(actor,"peripheral.probe")
  if not ok then return nil, err end
  local row = find(inventory,name)
  if not row then return nil,"unknown device" end
  for _,value in ipairs(row.types) do
    if value=="altitude_sensor" or value=="gimbal_sensor" or value=="navigation_table" or value=="analog_transmission" or value=="throttle_lever" or value=="propeller_bearing" or value=="propeller" then return require("system.services.avionicsd").probe(name) end
  end
  local data, errors = addon.read(row.device, READS[role(row)] or {})
  return {name=name,types=addon.copy(row.types),methods=addon.copy(row.methods),values=data,errors=errors}
end

function M.requestProbe(actor,name)
  local ok, err = allowed(actor,"peripheral.probe")
  if not ok then return false,err end
  if #pending>=8 then return false,"command queue full" end
  serial=serial+1
  pending[#pending+1] = {id=serial,kind="probe",pid=actor.pid,name=name}
  os.queueEvent("mintcraft_combat_command")
  return true,serial
end

function M.acknowledge(actor,id,confirmed)
  local ok,err=allowed(actor,"combat.configure")
  if not ok then return false,err end
  if confirmed~=true or (active and active.cannonId==id) then return false,"manual verification required; output busy" end
  if firing and firing.name==id then firing=nil end
  uncertain[id]=nil
  return true
end
function M.release(pid)
  for i=#pending,1,-1 do if pending[i].pid==pid then table.remove(pending,i) end end
  for token,entry in pairs(tokens) do if entry.pid==pid then tokens[token]=nil end end
end

local function processCommand(command)
  if command.kind == "probe" then
    local data, err = M.probe({pid=command.pid},command.name)
    if data then
      probeResult=addon.copy(data)
      local saved,why=safeWrite.write("/var/logs/peripheral_probe.log",textutils.serialize(data))
      return saved,saved and "Probe exported /var/logs/peripheral_probe.log" or why
    end
    return false, err
  end
  local ok, err = allowed({pid=command.pid},command.kind=="fire" and "combat.fire" or "combat.aim")
  if not ok then return false,err end
  local solution, reason = M.solution(command.cannonId,command.targetId)
  if not solution then return false,reason end
  local row = find(inventory,command.cannonId)
  if not row then return false,"cannon detached" end
  local info, readErr = addon.call(row.device,"getInfo")
  if readErr or type(info) ~= "table" or info.assembled ~= true then return false,"cannon not assembled/readable" end
  if command.kind == "aim" then
    command.outputAttempted=true
    local control, controlErr = addon.call(row.device,"setComputerControl",true)
    if controlErr or control==false then return false,controlErr or "control refused" end
    local result, aimErr = addon.call(row.device,"setTargetAngles",solution.yaw,solution.pitch)
    return aimErr==nil and result~=false,aimErr or (result==false and "aim refused" or "Aim sent")
  end
  if not addon.finite(info.yaw) or not addon.finite(info.pitch) or math.abs(geometry.wrap(info.yaw-solution.yaw))>2 or math.abs(info.pitch-solution.pitch)>2 then return false,"cannon not aligned with selected target" end
  firing=row
  command.outputAttempted=true
  local value, fireErr = addon.call(row.device,"fire",true)
  if fireErr or not adapters.fireResult(value,true) then return false,fireErr or "fire refused" end
  local timer = os.startTimer(0.1)
  while true do local _, id=os.pullEvent("timer") if id==timer then break end end
  local released, stopErr = addon.call(row.device,"fire",false)
  if not adapters.fireResult(released,false) then stopErr=stopErr or "fire release state mismatch" end
  if not stopErr then firing=nil end
  log.warn("combat", "confirmed fire " .. command.cannonId .. " target=" .. command.targetId)
  return stopErr==nil,stopErr or "Fire pulse completed"
end

function M.start(context)
  local stopped,why=M.stop()
  if stopped==false then error(why) end
  ctx = context
  lastFault=nil
  tracks={} cached.targets={} slowReads={} lastCycleCompletedAt=nil
  loadSettings()
  runner = addon.periodic(ctx,"combatd",0.05,M.acquire)
  runner.onError = function(err)
    revision=revision+1
    cached.errors = {err} cached.ok=false cached.revision=revision
    cached.status="combat acquisition failed" cached.lastFault=err
    if lastFault~=err then
      lastFault=err pcall(log.error,"combat",err)
      if ctx.notifications then pcall(ctx.notifications.push,ctx.notifications,"warn","Combat read failed",err,5) end
    end
  end
  if runner.error then runner.onError(runner.error) end
  M.commandPid = ctx.scheduler:spawn("combat commands",function()
    while true do
      while #pending>0 do
        local command = table.remove(pending,1)
        active=command
        local ok, success, message = addon.bounded(function() return processCommand(command) end,0.5)
        if not ok then
          message = success
        end
        if (not ok or success~=true) and command.cannonId and command.outputAttempted then uncertain[command.cannonId]=tostring(message) end
        if firing then
          local row=firing
          local cleared,clearErr=addon.bounded(function()
            local value,err=addon.call(row.device,"fire",false)
            if err or not adapters.fireResult(value,false) then error(err or "fire release state mismatch") end
          end,0.5)
          if cleared then firing=nil else uncertain[row.name]=tostring(clearErr) end
        end
        active=nil
        os.queueEvent("mintcraft_combat_result",command.pid,command.id,ok and success==true,tostring(message))
        if not ok or success==false then
          pcall(log.error,"combat",tostring(message))
          if ctx.notifications then pcall(ctx.notifications.push,ctx.notifications,"warn","Combat command failed",tostring(message),4) end
        end
      end
      os.pullEvent("mintcraft_combat_command")
    end
  end,{eventMode="raw",appId="combatd",protected=true})
  ctx.scheduler:start(M.commandPid)
end

function M.stop()
  if active or firing then return false,"combat output active/uncertain; wait for release" end
  if runner then runner:stop() runner=nil end
  if ctx and M.commandPid then ctx.scheduler:kill(M.commandPid,true) end
  pending,tokens={},{}
  ctx=nil
  return true
end

return M
