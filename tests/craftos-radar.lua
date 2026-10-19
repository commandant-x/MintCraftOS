-- Isolated GUI test with main-thread-style yielding bearing reads and fresh config.
local ok,err=pcall(function()
  shell.setDir('/') assert(shell.run('/source/install.lua'))
  -- This suite exercises the text compatibility views. Native graphics and
  -- the CC Graphics ROM window API are covered by craftos-ccgraphics.lua.
  local config=require('system.libraries.config')
  local display=config.load('/system/config/system.cfg',{})
  display.safeMode=true assert(config.save('/system/config/system.cfg',display))
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
    assert(not combat.configure({pid=pid},'radars','right',{frame='unknown',headingFrame='world',headingSign=1,headingOffset=0}))
    assert(combat.configure({pid=pid},'radars','right',{frame='body',headingFrame='world',headingSign=1,headingOffset=0}))
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
    device.getTracks=function() count=count+1 return native({{id='target',position={x=20,y=75,z=40},scannedTime=count}}) end
    device.getPosition=nil
    combat.rescan() sleep(0.5)
    assert(combat.snapshot().radars[1].readErrors.getPosition)
    assert(combat.configure({pid=pid},'radars','right',{frame='world',positionMode='manual',positionX=10,positionY=70,positionZ=20,headingFrame='world',headingSign=1,headingOffset=0}))
    sleep(0.5)
    local manual=combat.snapshot().radars[1]
    assert(manual.position.x==10 and manual.position.y==70 and not manual.readErrors.getPosition)
    assert(process.window.app.snapshot.radars[1].position, 'map not restored with configured origin')
    local setup=require('system.navigation.radar_setup')
    app=process.window.app
    app.setup=setup.new(combat.snapshot(),'right',combat.configuration(),false,
      function(id,value) return combat.configure({pid=pid},'radars',id,value) end,combat.validateRadar)
    local wizard=app.setup
    for step=1,4 do
      wizard.step=step
      for _,size in ipairs({{24,12},{49,15},{80,26},{118,36}}) do
        local target=window.create(parent,1,1,size[1],size[2],false)
        local old=term.redirect(target)
        local before=count
        app:draw(size[1],size[2])
        assert(before==count,'setup draw acquired radar')
        term.redirect(old)
      end
    end
    wizard.step=2
    wizard.entries.right.text='9 69 19' wizard.entries.right.kind='Bloc'
    for _=1,3 do
      local target=window.create(parent,1,1,80,26,false)
      local old=term.redirect(target)
      app:draw(80,26)
      local button
      for _,box in ipairs(wizard.bar) do if box.id=='next' then button=box end end
      assert(button)
      app:handle({name='mouse_click',args={1,button.x,button.y}})
      term.redirect(old)
    end
    assert(not app.setup and combat.configuration().radars.right.positionX==9.5,'wizard confirmation not persisted')
    app.setup=setup.new(combat.snapshot(),'right',combat.configuration(),false,
      function() error('cancel must not save') end,combat.validateRadar)
    app.setup:fields() app.setup.entries.right.text='1 2 3'
    app.setup.closed=true
    app:handle({name='key',args={keys.escape}})
    assert(combat.configuration().radars.right.positionX==9.5)
    local wizard5=setup.new({radars={{id='plane',kind='fixed',capabilities={position=true},rawPosition={x=1,y=2,z=3}}}},'plane',{radars={}},true,function() end,combat.validateRadar)
    wizard5:fields() wizard5.drafts.plane.apiProfile='5.0-EA'
    local target=window.create(parent,1,1,80,26,false)
    local old=term.redirect(target)
    wizard5:draw(80,26)
    for _,box in ipairs(wizard5.bar) do if box.id=='next' then wizard5:handle({name='mouse_click',args={1,box.x,box.y}}) break end end
    term.redirect(old)
    assert(wizard5.candidate().frame=='world','EA plane world position would be double transformed')
    app.setup=setup.new(combat.snapshot(),'right',combat.configuration(),false,
      function(id,value) return combat.configure({pid=pid},'radars',id,value) end,combat.validateRadar)
    app.setup=nil
    device.getScanGeometry=function() return native({version=1,position={x=10,y=70,z=20},positionFrame='world',headingFrame='world',
      heading=(os.clock()*30)%360,rotation=(os.clock()*30)%360,fov=90,halfHeight=60,range=1000,dishCount=4,running=true}) end
    combat.rescan() sleep(0.5)
    assert(combat.autoConfigureRadars({pid=pid})) sleep(0.3)
    assert(app.snapshot.radars[1].autoGeometry and app.snapshot.radars[1].fovSource=='scanner API' and app.snapshot.radars[1].position.x==10,'automatic API did not replace manual setup')
    device.getTracks=function()
      count=count+1
      return native({{id='target',name='Pilot',category='player',entityType='minecraft:player',position={x=100,y=75,z=40},scannedTime=count},
        {id='vessel',category='sable',position={x=400,y=100,z=100},scannedTime=count},
        {id='mob',category='mob',position={x=-300,y=75,z=-200},scannedTime=count}})
    end
    sleep(0.5)
    local radarNet=require('system.services.radarnetd')
    local netConfig=radarNet.configuration() netConfig.enabled=true netConfig.allowInsecure=true netConfig.group='test-world' netConfig.trusted['2']=true
    netConfig.x=0 netConfig.y=70 netConfig.z=0 netConfig.radius=400
    assert(radarNet.configure({pid=pid},netConfig))
    local remotePacket={version=1,group='test-world',session='outpost',sequence=1,label='North station',frame='world',
      radars={{id='remote-radar',position={x=1000,y=70,z=-500},range=600,age=0,heading=45,fov=60,halfHeight=60,running=true,fovSource='scanner API'}},
      targets={{id='remote-player',renderName='Remote pilot',category='player',position={x=1100,y=90,z=-450},age=0,radarId='remote-radar'}}}
    os.queueEvent('rednet_message',2,remotePacket,radarNet.protocol)
    sleep(0.3)
    assert(#app.snapshot.radars==2 and #app.snapshot.targets==4,'remote station did not aggregate')
    local function draw(width,height)
      local surface=window.create(parent,1,1,width,height,false)
      local old=term.redirect(surface) local before=count
      app:draw(width,height) assert(count==before,'draw performed acquisition')
      term.redirect(old)
      return surface
    end
    for _,page in ipairs({'radar','three','targets','network'}) do
      app.page=page app.canvas=nil
      for _,size in ipairs({{24,12},{49,15},{80,26},{118,36}}) do draw(size[1],size[2]) end
    end
    app.page='radar' app.view.network=true app.canvas=nil draw(118,36)
    local function category(id)
      local trigger=app.categories.trigger
      app:handle({name='mouse_click',args={1,trigger.x,trigger.y}}) draw(118,36)
      local selected
      for _,box in ipairs(app.categories.menuBoxes) do if box.id==id then selected=box end end
      assert(selected,'filter inaccessible')
      app:handle({name='mouse_click',args={1,selected.x,selected.y}})
      app:handle({name='key',args={keys.escape}}) draw(118,36)
    end
    category('players')
    assert(app.filters.players and #app.graphHits==2,'player filter did not affect 2D')
    local marker=app.graphHits[1]
    app:handle({name='mouse_click',args={1,marker.x,marker.y+4}})
    assert(app.targetId==marker.id,'marker hitbox offset')
    draw(118,36)
    app:handle({name='mouse_click',args={1,marker.x,marker.y+4}})
    assert(app.targetId==nil,'second tap did not deselect')
    app.page='three' app.canvas=nil draw(118,36) assert(#app.graphHits==2,'3D filters differ')
    category('players')
    assert(next(app.filters)==nil and #app.graphHits==4,'second category tap did not reset')
    app.page='targets' draw(118,36)
    local remoteRow
    for _,box in ipairs(app.rowHits) do if box.id=='remote-player' then remoteRow=box end end
    app:handle({name='mouse_click',args={1,remoteRow.x,remoteRow.y}})
    assert(app.targetId=='remote-player')
    app:handle({name='mouse_click',args={1,remoteRow.x,remoteRow.y}}) assert(app.targetId==nil)
    app.page='network' draw(118,36)
    local function clickAction(id)
      for _,box in ipairs(app.bar) do if box.id==id then app:handle({name='mouse_click',args={1,box.x,box.y}}) return end end
      local trigger=app.commands.trigger
      app:handle({name='mouse_click',args={1,trigger.x,trigger.y}}) draw(118,36)
      for _,box in ipairs(app.commands.menuBoxes) do if box.id==id then app:handle({name='mouse_click',args={1,box.x,box.y}}) return end end
      error('missing action '..id)
    end
    clickAction('networkConfig') assert(app.page=='config')
    app.networkConfig.radius=0 draw(118,36) clickAction('networkSave')
    assert(app.page=='config','invalid zone dismissed configuration')
    app.networkConfig.radius=400 app.networkConfig.alerts=true draw(118,36) clickAction('networkSave')
    assert(app.page=='network' and app.configKind=='radar','saved network form trapped advanced config')
    sleep(0.3) assert(app.snapshot.zone.alerts)
    process.window:toggleMaximize()
    for _,page in ipairs({'radar','three','targets','network'}) do
      remotePacket.sequence=remotePacket.sequence+1
      os.queueEvent('rednet_message',2,remotePacket,radarNet.protocol)
      app.page=page app.canvas=nil
      os.queueEvent('radar_setup_preview') sleep(0.25)
      assert(process.state=='ready',tostring(process.error))
      if term.screenshot then term.screenshot() sleep(1.05) end
    end
    netConfig=radarNet.configuration() netConfig.enabled=false
    assert(radarNet.configure({pid=pid},netConfig))
    local many,names={},{}
    for i=1,40 do
      local n=i local id='radar_'..i names[#names+1]=id
      many[id]={getTracks=function() return native({}) end,getScanGeometry=function()
        return native({version=1,positionFrame='world',headingFrame='world',position={x=n*100,y=70,z=0},range=1000,
          heading=(os.clock()*30+n*5)%360,rotation=0,fov=90,halfHeight=20,running=true,dishCount=2})
      end}
    end
    peripheral.getNames=function() return names end
    peripheral.getMethods=function(name) local out={} for method in pairs(many[name]) do out[#out+1]=method end return out end
    peripheral.wrap=function(name) return many[name] end
    combat.rescan() sleep(1)
    assert(#combat.snapshot().radars==40,'forty yielding sensors not acquired')
    assert(os.clock()-combat.snapshot().timestamp<0.5,'forty-sensor worker starved')
    assert(combat.autoConfigureRadars({pid=pid})) sleep(0.4)
    app.page='three' app.view.network=true app.canvas=nil draw(118,36)
    assert(process.state=='ready' and #app.snapshot.radars==40,'forty-sensor view crashed')
  end)
end)
local h=assert(fs.open('/radar-result.txt','w'))
h.write(ok and 'PASS: bearing, scanner API, four-size views, remote station aggregation, forty yielding radars, cached redraw' or 'FAIL: '..tostring(err))
h.close() os.shutdown()
