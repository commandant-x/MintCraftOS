package.path = "./?.lua;" .. package.path
local files, reads, closed = {}, 0, 0
local fail
local function check(stage) if fail == stage then error("disk full: " .. stage) end end
fs = {
  exists=function(path) check("exists") return path == "/var/logs" or files[path] ~= nil end,
  makeDir=function() check("mkdir") end,
  getSize=function(path) check("size") return #files[path] end,
  delete=function(path) check("delete") assert(path:match("system%.log%.[12]$")) files[path]=nil end,
  move=function(a,b) check("move") files[b],files[a]=files[a],nil end,
  open=function(path,mode)
    check("open")
    if fail == "nilopen" then return nil,"full" end
    if mode == "a" then return {
      writeLine=function(line) check("write") files[path]=(files[path] or "")..line.."\n" end,
      close=function() closed=closed+1 check("close") end,
    } end
    local offset=1
    return {
      readLine=function()
        check("read") reads=reads+1
        local data=files[path] or ""
        if offset>#data then return nil end
        local last=data:find("\n",offset,true) or #data+1
        local line=data:sub(offset,last-1) offset=last+1 return line
      end,
      close=function() closed=closed+1 check("close") end,
    }
  end,
}
textutils={unserialize=function(line)
  local fn=load("return "..line,"log","t",{})
  if fn then local ok,row=pcall(fn) if ok then return row end end
end}
local log=require("system.libraries.log")
local path="/var/logs/system.log"
local message='one\ntwo\r\t"\\'..string.char(0).."9"
assert(log.info("test",message))
assert(select(2,files[path]:gsub("\n",""))==1,"record spans physical lines")
assert(log.parse(log.tail(1)[1]).message==message,"escaping lost data")
local count=reads
for _=1,100 do assert(#log.tail(120)==1) end
assert(reads==count,"unchanged draws reread file")
local copy=log.tail(1) copy[1]="bad" assert(log.tail(1)[1]~="bad")
files[path]='{\n time="old",\n level="error",\n source="legacy",\n message="hello",\n}\nraw legacy\n'
log.invalidate()
local rows=log.tail(120)
assert(#rows==2 and log.parse(rows[1]).message=="hello" and rows[2]=="raw legacy")
assert(#log.tail(0)==0)
local bomb=setmetatable({},{__tostring=function() error("bad tostring") end})
assert(log.info(bomb,bomb))
assert(log.parse(log.tail(1)[1]).message=="<unprintable>")
local before=closed
fail="write" assert(not log.error("test","full")) assert(closed==before+1,"failed write leaked handle")
for _,stage in ipairs({"exists","open","nilopen","close","size"}) do
  fail=stage assert(pcall(log.warn,"test","failure")) assert(not log.warn("test","failure"))
end
fail=nil
files["/var/logs/last_crash.log"]="recovery"
files["/var/logs/peripheral_probe.log"]="probe"
files[path]=string.rep("x",100000)
files[path..".1"]=string.rep("x",100000)
files[path..".2"]=string.rep("x",100000)
assert(log.info("test","migrate quota"))
for _,suffix in ipairs({"",".1",".2"}) do assert(#(files[path..suffix] or "")<=65536) end
for _=1,35 do assert(log.debug("test",string.rep("x",8192))) end
for _,suffix in ipairs({"",".1",".2"}) do assert(#(files[path..suffix] or "")<=65536) end
assert(files["/var/logs/last_crash.log"]=="recovery" and files["/var/logs/peripheral_probe.log"]=="probe")
files[path]=string.rep("x",65536)
for _,stage in ipairs({"delete","move"}) do fail=stage assert(not log.info("test","rotate")) end
fail="read" log.invalidate() assert(pcall(log.tail,20)) fail=nil
local exists=fs.exists
fs.exists=function() return false end
fail="mkdir" assert(not log.info("test","mkdir failed")) fail=nil fs.exists=exists
local date=os.date
os.date=function() error("clock unavailable") end
assert(not log.info("test","date failed")) os.date=date
print("logging: compact/legacy, revision cache, disk errors, handle cleanup and quota passed")
