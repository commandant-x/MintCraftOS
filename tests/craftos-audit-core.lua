-- Isolated normal-window CraftOS-PC only; /source is read-only.
local ok,err=pcall(function()
  shell.setDir("/") assert(shell.run("/source/install.lua")) http=nil pocket=nil
  local apps=require("system.libraries.apps")
  parallel.waitForAny(function() require("system.boot.bootloader").start() end,function()
    for _=1,50 do if apps.ctx and apps.get("settings") then break end sleep(0.1) end
    sleep(0.2)
    local launched,pid=apps.launch("settings") assert(launched,tostring(pid)) sleep(0.1)
    local process=apps.ctx.scheduler.processes[pid] local app=process.window.app
    local started=os.epoch("utc")
    app:beginInput("adminLogin") app.input="" app.keyboard.onEnter()
    assert(os.epoch("utc")-started<1500,"KDF blocked the input callback")
    assert(app.authBusy,"authentication did not remain asynchronous")
    local owner=scheduler or apps.ctx.scheduler
    local beats=0
    local heartbeat=owner:spawn("auth heartbeat",function() for i=1,4 do sleep(0.1) beats=beats+1 end end,{eventMode="raw"})
    owner:start(heartbeat) sleep(0.7)
    assert(beats==4,"authentication swallowed scheduler events")
    app:action("cancelAuth")
    for _=1,30 do if not app.authBusy then break end sleep(0.1) end
    assert(not app.authBusy,"authentication cancel did not release the worker")
    assert(type(require("system.security.users").current().passwordHash)=="string","cancel committed password migration")
    local win=process.window
    local draws=0
    local original=win.app.draw
    win.app.draw=function(...) draws=draws+1 return original(...) end
    win.dirty=true os.queueEvent("audit_render") sleep(0.1)
    local before=draws
    for _=1,10 do os.queueEvent("audit_clean_frame") end
    sleep(0.1) assert(draws==before,"clean Settings reran its draw on unrelated frames")
    owner:kill(pid)
    launched,pid=apps.launch("editor",{path="/home/user/documents/close-audit.txt"}) assert(launched,tostring(pid)) sleep(0.1)
    process=owner.processes[pid] app=process.window.app
    app:handle({name="char",args={"unsaved"}})
    assert(not process.window:requestClose() and not process.window.closed,"Editor lost unsaved work")
    owner:kill(pid)
    local crypto=require("system.libraries.password_crypto")
    local begin=os.epoch("utc") crypto.pbkdf2("benchmark","salt",1024)
    local duration=os.epoch("utc")-begin
    local h=assert(fs.open("/kdf-benchmark.txt","w")) h.write(tostring(duration).."ms / 1024 PBKDF2 iterations (no sleeps)") h.close()
  end)
end)
local h=assert(fs.open("/audit-core-result.txt","w")) h.write(ok and "PASS: async/cancellable real KDF, kernel heartbeat, clean frame cache, unsaved close veto" or "FAIL: "..tostring(err)) h.close() os.shutdown()
