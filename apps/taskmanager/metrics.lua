local addon=require("system.libraries.addon")
local M={}
local function finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end
M.finite=finite
function M.size(bytes)
  if not finite(bytes) or bytes<0 then return "unavailable" end
  if bytes>=1048576 then return string.format("%.1f MiB",bytes/1048576) end
  if bytes>=1024 then return string.format("%.1f KiB",bytes/1024) end
  return string.format("%.0f B",bytes)
end
function M.rate(current,previous,elapsed)
  if not finite(current) or not finite(previous) or current<0 or previous<0 or not finite(elapsed) or elapsed<0.25 or elapsed>5 or current<previous then return end
  return (current-previous)/elapsed
end
function M.sourceChanged(current,previous)
  if not previous then return false end
  if not finite(previous.timestamp) or current.timestamp<previous.timestamp then return true end
  local render,prior=current.render or {},previous.render or {}
  if render.generation~=prior.generation or render.backend~=prior.backend then return true end
  for _,pair in ipairs({{(current.acquisition or {}).reads,(previous.acquisition or {}).reads},{render.frames,prior.frames},{render.bytes,prior.bytes}}) do
    if finite(pair[1])~=finite(pair[2]) or finite(pair[1]) and pair[1]<pair[2] then return true end
  end
  return false
end
function M.sample(ctx,previous,now,observed)
  local errors={}
  local function query(label,fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if not ok then errors[#errors+1]=label..": "..tostring(value) return end
    return value
  end
  local s={timestamp=now,rows={},ready=0,errors=errors}
  local permitted=true
  if ctx.security and type(ctx.security.require)=="function" then
    local called,ok,reason=pcall(ctx.security.require,"process.list") permitted=called and ok
    if not permitted then errors[#errors+1]=tostring(called and reason or ok) end
  end
  if permitted then s.rows=query("Processes",ctx.listProcesses) or {} end
  if type(s.rows)~="table" then errors[#errors+1]="Invalid process snapshot" s.rows={} end
  for _,row in ipairs(s.rows) do if row.state=="ready" then s.ready=s.ready+1 end end
  s.heapKB=query("Lua heap",collectgarbage,"count")
  if not finite(s.heapKB) or s.heapKB<0 then s.heapKB=nil end
  local free=query("Disk free",fs and fs.getFreeSpace,"/")
  local capacity=query("Disk capacity",fs and fs.getCapacity,"/")
  s.unlimited=free=="unlimited" or capacity=="unlimited"
  s.free=finite(free) and free>=0 and free or nil
  s.capacity=finite(capacity) and capacity>0 and capacity or nil
  if s.free and s.capacity and s.free<=s.capacity then s.used=s.capacity-s.free end
  if s.free and s.capacity and s.free>s.capacity then errors[#errors+1]="Inconsistent disk counters" end
  s.disk=s.unlimited and "Disk: unlimited" or s.used and ("Disk: "..M.size(s.used).." / "..M.size(s.capacity)) or ("Disk free: "..M.size(s.free))
  s.memory=s.heapKB and ("Lua heap: "..M.size(s.heapKB*1024)) or "Lua heap: unavailable"
  s.acquisition=query("Peripheral counters",addon.metrics) or {}
  s.render=query("Render counters",ctx.system and ctx.system.renderStats) or {}
  if type(s.acquisition)~="table" then errors[#errors+1]="Invalid acquisition counters" s.acquisition={} end
  if type(s.render)~="table" then errors[#errors+1]="Invalid render counters" s.render={} end
  if previous and finite(previous.timestamp) then
    local dt=now-previous.timestamp
    s.readRate=M.rate(s.acquisition.reads,(previous.acquisition or {}).reads,dt)
    s.renderRate=M.rate(s.render.frames,(previous.render or {}).frames,dt)
    if (s.render.backend=="PIXEL16" or s.render.backend=="PIXEL256") and s.render.generation and s.render.generation==(previous.render or {}).generation and s.render.backend==previous.render.backend then
      s.pixelRate=M.rate(s.render.bytes,previous.render.bytes,dt)
    end
  end
  s.gap=M.sourceChanged(s,observed or previous)
  if s.gap then s.readRate=nil s.renderRate=nil s.pixelRate=nil end
  return s
end
function M.record(history,s)
  local last=history[#history]
  if last and s.timestamp<last.timestamp then for i=#history,1,-1 do history[i]=nil end last=nil end
  if last and s.timestamp==last.timestamp and s.gap then last.readRate=nil last.pixelRate=nil last.renderRate=nil end
  if not last or s.timestamp-last.timestamp>=0.5 or s.gap and s.timestamp>last.timestamp then
    history[#history+1]={timestamp=s.timestamp,heapKB=s.heapKB,readRate=s.readRate,pixelRate=s.pixelRate,renderRate=s.renderRate}
    if #history>60 then table.remove(history,1) end
    return true
  end
end
return M
