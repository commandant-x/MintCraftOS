-- Run only in disposable CraftOS-PC storage, with /source mounted read-only.
local ok,err=pcall(function()
  shell.setDir("/") assert(shell.run("/source/install.lua")) pocket=nil http=nil
  local apps=require("system.libraries.apps")
  parallel.waitForAny(function() require("system.boot.bootloader").start() end,function()
    for _=1,50 do if apps.ctx and apps.get("combat") then break end sleep(0.1) end
    sleep(0.4)
    local combat=require("system.services.combatd")
    local cached={revision=123,timestamp=os.clock(),ok=true,devices={},cannons={},controllers={},errors={},
      radars={{id="test",name="North radar (fixture)",position={x=0,y=80,z=0},range=500,heading=25,fov=60,verticalFov=20,running=true,positionSource="test fixture",fovSource="test fixture",rawTrackCount=2}},
      targets={{id="player",label="Alex (fixture)",labelSource="api",kind="player",position={x=100,y=90,z=180},timestamp=os.clock(),freshnessKnown=true},
        {id="vessel",label="Vessel (fixture)",labelSource="api",kind="vessel",position={x=-150,y=120,z=-120},timestamp=os.clock(),freshnessKnown=true}}}
    local reads,statusReads=0,0
    combat.snapshot=function() reads=reads+1 return cached end
    combat.status=function() statusReads=statusReads+1 return {revision=cached.revision} end
    local parent=term.current()
    local function draw(app,w,h)
      local view=window.create(parent,1,1,w,h,true) local before=term.redirect(view)
      term.setBackgroundColor(colors.lightGray) term.clear()
      local call=peripheral.call
      peripheral.call=function() error("peripheral acquisition during draw") end
      local rendered,problem=pcall(app.draw,app,w,h)
      peripheral.call=call term.redirect(before)
      assert(rendered,problem)
    end
    local function click(app,box) assert(app:handle({name="mouse_click",args={1,box.x,box.y}})) end
    for _,id in ipairs({"combat","navigation"}) do
      local launched,pid=apps.launch(id) assert(launched,tostring(pid)) sleep(0.25)
      local proc=apps.ctx.scheduler.processes[pid] local app=proc.window.app
      for _,size in ipairs({{20,10},{26,17},{44,20},{80,30},{120,36}}) do
        draw(app,size[1],size[2]) click(app,app.pages.trigger) draw(app,size[1],size[2])
        assert(app.pages.open)
        local box=app.pages.menuBoxes[math.min(2,#app.pages.menuBoxes)]
        click(app,box) assert(app.page==box.id and not app.pages.open)
        draw(app,size[1],size[2]) click(app,app.commands.trigger) draw(app,size[1],size[2])
        assert(app.commands.open and #app.commands.menuBoxes>0)
        click(app,app.commands.close)
        assert(not app.commands.open and proc.state=="ready")
      end
      if id=="combat" then
        app.page="radar" draw(app,80,30) click(app,app.categories.trigger) draw(app,80,30)
        local box=app.categories.menuBoxes[2] click(app,box)
        assert(app.filters[box.id] and app.categories.open)
        draw(app,80,30) click(app,box) assert(not app.filters[box.id])
        click(app,app.categories.close)
        local before,checks=reads,statusReads sleep(0.6)
        assert(reads==before,"20 Hz redraw recopied unchanged snapshots")
        assert(statusReads-checks>=8,"radar render timer stayed at 5 Hz")
        proc.window.minimized=true checks=statusReads sleep(0.3)
        assert(statusReads==checks,"minimized radar kept refreshing") proc.window.minimized=false
        app.page="three" draw(app,120,36) click(app,app.commands.trigger) draw(app,120,36)
      else app.page="calibration" draw(app,120,36) click(app,app.commands.trigger) draw(app,120,36) end
      if term.screenshot then term.screenshot() sleep(1.1) end
      apps.ctx.scheduler:kill(pid)
    end
  end)
end)
local h=assert(fs.open("/action-menus-result.txt","w"))
h.write(ok and "PASS: Navigation/Combat menus, pocket/monitor sizes, filters, modal routing and cached 20 Hz render" or "FAIL: "..tostring(err)) h.close() os.shutdown()
