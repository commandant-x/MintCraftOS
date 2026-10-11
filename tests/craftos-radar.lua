-- Isolated GUI test with main-thread-style yielding bearing reads and fresh config.
local ok,err=pcall(function()
  shell.setDir('/') assert(shell.run('/source/install.lua'))
  http=nil
  local count,task=0,0
  local function native(value)
    task=task+1 local id=task
    os.queueEvent('task_complete',id,true,value)
    while true do local _,got,success,result=os.pullEvent('task_complete') if got==id then assert(success) return result end end
  end
  local device={getPosition=function() return native({x=10,y=70,z=20}) end,
    getRange=function() return native(1000) end,getRotation=function() return native(45) end,
    getDishCount=function() return native(4) end,getRotationSpeed=function() return native(2) end,
    getTracks=function() count=count+1 return native({{id='target',position={x=20,y=75,z=40},scannedTime=count}}) end}
  peripheral.getNames=function() return {'right'} end
  peripheral.getType=function() return 'create_radar:radar_bearing' end
  peripheral.getMethods=function() local rows={} for method in pairs(device) do rows[#rows+1]=method end return rows end
  peripheral.wrap=function() return device end
  local apps=require('system.libraries.apps')
  local combat=require('system.services.combatd')
  parallel.waitForAny(function() require('system.boot.bootloader').start() end,function()
    for _=1,50 do if apps.ctx and apps.get('combat') then break end sleep(0.1) end
    assert(apps.ctx) sleep(0.5)
    local bearing=combat.snapshot().radars[1]
    assert(bearing and bearing.position and bearing.rawTrackCount==1, 'fresh bearing not acquired/renderable')
    local launched,pid=apps.launch('combat') assert(launched,tostring(pid)) sleep(0.4)
    local process=apps.ctx.scheduler.processes[pid]
    assert(process.state=='ready' and process.window.app.snapshot.radars[1].position)
    assert(combat.configure({pid=pid},'radars','right',{frame='unknown',headingFrame='world',headingSign=1,headingOffset=0}))
    sleep(0.5)
    local app=process.window.app
    assert(not app.snapshot.radars[1].position and app.snapshot.radars[1].rawPosition)
    local parent=term.current()
    for _,size in ipairs({{24,12},{49,15},{80,26}}) do
      local target=window.create(parent,1,1,size[1],size[2],false)
      local old=term.redirect(target)
      local before=count
      app:draw(size[1],size[2])
      local text=''
      for y=1,size[2] do local line=target.getLine(y) text=text..line end
      assert(text:find('Contacts returned:',1,true),'raw bearing readings not visible')
      assert(count==before,'draw read radar')
      term.redirect(old)
    end
    device.getTracks=function() error('injected read error') end
    sleep(0.5)
    assert(combat.snapshot().radars[1].readErrors.getTracks, 'read error hidden')
    assert(process.state=='ready',tostring(process.error))
  end)
end)
local h=assert(fs.open('/radar-result.txt','w'))
h.write(ok and 'PASS: fresh bearing reads, native yields, unknown-frame diagnostics at three sizes, read error isolation' or 'FAIL: '..tostring(err))
h.close() os.shutdown()
