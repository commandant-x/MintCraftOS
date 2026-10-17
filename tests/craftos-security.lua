-- Run with a read-only /source mount; writes only to the isolated emulator data dir.
package.path="/source/?.lua;"..package.path
local output={}
local function report(text) output[#output+1]=text print(text) end
local ok,err=pcall(function()
  local crypto=require("system.libraries.password_crypto")
  package.loaded["system.libraries.log"]={info=function() end,warn=function() end,error=function() end}
  local scheduler=require("system.kernel.scheduler").new()
  local done,record=false,nil
  local start=os.epoch("utc")
  local pulse,last,maxGap,count=os.startTimer(0.05),start,0,0
  local worker=scheduler:spawn("production password KDF",function()
    record=crypto.create("native latency password",{progress=function(i,total)
      assert(total==600000)
      if i%100000==0 then report("progress="..i.." elapsedMs="..(os.epoch("utc")-start)) end
    end})
    done=true
  end,{eventMode="raw",protected=true})
  scheduler:start(worker)
  while not done do
    local raw=table.pack(os.pullEventRaw())
    if raw[1]=="timer" and raw[2]==pulse then
      local now=os.epoch("utc") maxGap=math.max(maxGap,now-last) last=now count=count+1 pulse=os.startTimer(0.05)
    end
    scheduler:dispatch({name=raw[1],args={table.unpack(raw,2,raw.n)},raw=raw})
    local state=scheduler.processes[worker].state
    assert(state~="crashed",tostring(scheduler.processes[worker].error))
  end
  local elapsed=os.epoch("utc")-start
  report("production600kMs="..elapsed.." timerPulses="..count.." maxGapMs="..maxGap)
  assert(record and record.iterations==600000 and count>0,"production KDF did not yield")
  assert(maxGap<250,"KDF starved 50ms pulse for >=250ms")
  local cancelled=false
  local success=pcall(crypto.create,"cancelled password",{cancelled=function() return true end})
  assert(not success,"KDF ignored cancellation")
  report("PASS: native production KDF, responsive event pump, cancellation and fixed production cost")
end)
if not ok then report("FAIL: "..tostring(err)) end
local handle=assert(fs.open("/security-latency-result.txt","w")) handle.write(table.concat(output,"\n")) handle.close()
os.shutdown()
