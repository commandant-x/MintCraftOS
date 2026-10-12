local ok,err=pcall(function()
  shell.setDir('/') assert(shell.run('/source/install.lua')) pocket=nil
  local sha=string.rep('a',40) local closed=0 local failedRead=false local received=0
  local installer='-- MintCraft installer protocol: 2\nlocal f={ ["VERSION"]="9.9.9\\n",["system/update-test.lua"]="return true",["system/config/keep-test.cfg"]="new default" }; require("system.libraries.installer").install(f,mintcraftInstallOptions)'
  local function response(body,broken)
    return {readAll=function() if broken then error('injected closed response') end return body end,getResponseCode=function() return 200 end,getResponseHeaders=function() return {} end,close=function() closed=closed+1 end}
  end
  http={request=function(url) os.queueEvent('http_success',url,response('9.9.9')) return true end,
    get=function(url)
      received=received+1
      local body=url:find('api.github.com',1,true) and textutils.serializeJSON({sha=sha}) or url:find('install.lua',1,true) and installer or url:find('/VERSION',1,true) and '9.9.9' or '<html><title>Example</title><p>Hello world</p></html>'
      local handle=response(body,failedRead and not url:find('githubusercontent',1,true))
      local timer=os.startTimer(0.3)
      while true do local _,id=os.pullEvent('timer') if id==timer then break end end
      os.queueEvent('http_success',url,handle)
      while true do local _,address,result=os.pullEvent('http_success') if address==url then return result end end
    end}
  local apps=require('system.libraries.apps')
  parallel.waitForAny(function() require('system.boot.bootloader').start() end,function()
    for _=1,50 do if apps.ctx and apps.get('browser') then break end sleep(0.1) end
    sleep(0.4)
    local originalHandle=assert(fs.open('/VERSION','r')) local original=originalHandle.readAll() originalHandle.close()
    local launched,pid=apps.launch('browser') assert(launched,tostring(pid)) sleep(0.2)
    local proc=apps.ctx.scheduler.processes[pid] local app=proc.window.app
    local parent=term.current()
    local function draw(object,w,h)
      local view=window.create(parent,1,1,w,h,false) local before=term.redirect(view)
      object:draw(w,h) term.redirect(before)
    end
    draw(app,80,24)
    failedRead=true
    local before=received
    local link=app.bookmarks[1] app:handle({name='mouse_click',args={1,link.x,link.y}})
    assert(before==received,'click synchronously fetched HTTP')
    sleep(0.7)
    assert(proc.state=='ready' and app.tabs[1].page.errorCode=='BRW-002','HTTP read failure crashed browser')
    failedRead=false draw(app,80,24)
    link=app.bookmarks[1] app:handle({name='mouse_click',args={1,link.x,link.y}}) sleep(0.7)
    assert(proc.state=='ready' and app.tabs[1].title=='Example','quick link did not recover')
    for _,size in ipairs({{20,10},{24,17},{80,24}}) do draw(app,size[1],size[2]) end
    apps.ctx.scheduler:kill(pid)
    launched,pid=apps.launch('update') assert(launched,tostring(pid)) sleep(0.2)
    proc=apps.ctx.scheduler.processes[pid] app=proc.window.app
    draw(app,24,10) app:refresh()
    assert(app.busy) sleep(0.7)
    assert(proc.state=='ready' and not app.busy and app.status.remoteVersion=='9.9.9','Update check failed')
    local freeSpace=fs.getFreeSpace fs.getFreeSpace=function() return 0 end
    app:apply() sleep(1.6)
    assert(proc.state=='ready' and app.message:find('UPD-DISK',1,true),'disk failure did not stay in Update UI')
    fs.getFreeSpace=freeSpace
    app:apply() sleep(1.6)
    assert(proc.state=='ready' and not app.busy and app.message:find('reboot',1,true),'Update Apply failed: '..app.message)
    assert(fs.exists('/system/update-test.lua'))
    assert(not fs.exists('/var/tmp/mintcraft_update.lua'),'installer needlessly stored on disk')
    app:rollback() sleep(0.4)
    assert(proc.state=='ready' and not app.busy and app.message:find('reboot',1,true),'Rollback failed: '..app.message)
    local h=assert(fs.open('/VERSION','r')) local restored=h.readAll() h.close()
    assert(restored==original and not fs.exists('/system/update-test.lua'),'granular rollback incomplete')
    assert(fs.exists('/system/config/keep-test.cfg'),'rollback erased new user configuration')
    for _,size in ipairs({{20,10},{24,17},{44,10}}) do draw(app,size[1],size[2]) end
    assert(closed>=6)
  end)
end)
local h=assert(fs.open('/network-apps-result.txt','w')) h.write(ok and 'PASS: browser HTTP failure/recovery, native workers, Update check/apply/granular rollback, small views' or 'FAIL: '..tostring(err)) h.close() os.shutdown()
