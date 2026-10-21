-- Persistent console retry policy. State is saved with users.db before hashing.
local M={}
local delays={[5]=30,[6]=60,[7]=300,[8]=900,[9]=3600}
local cached,deadline
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function clock()
  if os.epoch then return os.epoch("utc")/1000,"utc" end
  return os.clock(),"uptime"
end
local function valid(t)
  if t==nil then return true end
  return type(t)=="table" and t.version==1 and finite(t.failures) and t.failures%1==0
    and t.failures>=0 and t.failures<=9 and finite(t.at) and finite(t.untilAt)
    and (t.clock=="utc" or t.clock=="uptime")
    and math.abs(t.untilAt-t.at-(delays[t.failures] or 0))<0.001
end
function M.status(t)
  if not valid(t) then return nil,"Authentication retry state unreadable" end
  if not t then cached=nil deadline=nil return {failures=0,retryAfter=0} end
  local now,mode=clock()
  local key=table.concat({t.version,t.failures,t.at,t.untilAt,t.clock},":")
  local delay=delays[t.failures] or 0
  local remaining=delay
  if mode=="utc" and t.clock=="utc" and now>=t.at then remaining=math.max(0,math.min(delay,t.untilAt-now)) end
  if cached~=key then cached=key deadline=os.clock()+remaining end
  -- A clock jump during this boot cannot shorten a wait already observed.
  remaining=math.max(remaining,deadline-os.clock(),0)
  -- Without UTC, only the monotonic countdown advances in this boot.
  if mode~="utc" or t.clock~="utc" or now<t.at then remaining=math.max(0,deadline-os.clock()) end
  return {failures=t.failures,retryAfter=math.ceil(remaining)}
end
function M.reserve(t)
  local status,err=M.status(t)
  if not status then return nil,err end
  if status.retryAfter>0 then return nil,"Too many attempts; retry in "..status.retryAfter.."s" end
  local now,mode=clock()
  local count=math.min(9,status.failures+1)
  return {version=1,failures=count,at=now,untilAt=now+(delays[count] or 0),clock=mode}
end
function M.defer(t)
  local now,mode=clock()
  return {version=1,failures=t.failures,at=now,untilAt=now+(delays[t.failures] or 0),clock=mode}
end
return M
