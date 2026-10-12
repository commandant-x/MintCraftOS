local ok,err=pcall(function()
  shell.setDir('/') assert(shell.run('/source/install.lua')) http=nil pocket={}
  local apps=require('system.libraries.apps')
  parallel.waitForAny(function() require('system.boot.bootloader').start() end,function()
    for _=1,50 do if apps.ctx and apps.get('settings') then break end sleep(0.1) end
    assert(apps.ctx) sleep(3.3)
    local profile=require('system.libraries.profile')
    local desktop=require('system.gui.desktop')
    assert(profile.mode()=='pocket' and #apps.list()==6)
    assert(apps.get('combat') and not apps.launch('combat'),'disabled app bypassed profile')
    assert(apps.ctx.services.services.combatd.state=='stopped','heavy combat worker booted on pocket')
    os.queueEvent('pocket_preview') sleep(0.1)
    local w,h=term.getSize()
    assert(w==26 and h==20,'pocket viewport not used')
    assert(#desktop.icons==6)
    for _,icon in ipairs(desktop.icons) do assert(icon.x+icon.w-1<=w and icon.y+icon.h-1<h-1) end
    if term.screenshot then term.screenshot() sleep(1.05) end
    local box=desktop.pageHits.apps
    os.queueEvent('mouse_click',1,box.x,box.y) sleep(0.3)
    local process
    for _,p in pairs(apps.ctx.scheduler.processes) do if p.meta and p.meta.appId=='settings' then process=p end end
    assert(process and process.window and process.window.app.page=='apps')
    process.window:toggleMaximize() os.queueEvent('pocket_preview') sleep(0.2)
    local surface=window.create(term.current(),1,1,24,17,false)
    local old=term.redirect(surface) process.window.app:draw(24,17) term.redirect(old)
    local header=''
    for row=1,3 do header=header..surface.getLine(row) end
    assert(header:find('Apps',1,true) and header:find('Profile:',1,true),'selector header missing')
    local browser
    for _,row in ipairs(process.window.app.appRows) do if row.id=='browser' then browser=row end end
    assert(browser)
    process.window.app:handle({name='mouse_click',args={1,browser.x,browser.y}})
    assert(profile.appEnabled('browser') and #apps.list()==7,'checkbox did not enable app')
    process.window.app:handle({name='mouse_click',args={1,browser.x,browser.y}})
    assert(not profile.appEnabled('browser') and #apps.list()==6,'checkbox did not disable app')
    if term.screenshot then term.screenshot() sleep(1.05) end
    local app=process.window.app
    local value=profile.configuration() value.apps.combat=true
    assert(profile.configure(value)) assert(#apps.list()==7)
    local launched,pid=apps.launch('combat') assert(launched,tostring(pid)) sleep(0.3)
    assert(apps.ctx.scheduler.processes[pid].state=='ready')
    assert(apps.ctx.services.services.combatd.state=='running','selected service not started on demand')
    apps.ctx.scheduler:kill(pid)
    value.mode='desktop' value.apps={} assert(profile.configure(value))
    assert(#apps.list()>6) desktop.page=1 desktop.draw()
    assert(desktop.pageCount>1,'full app set overflowing instead of paging')
    desktop.page=desktop.pageCount desktop.draw()
    for _,icon in ipairs(desktop.icons) do assert(icon.x+icon.w-1<=w and icon.y+icon.h-1<h-1) end
    os.queueEvent('pocket_preview') sleep(0.2)
    assert(process.state=='ready')
    if term.screenshot then term.screenshot() sleep(1.05) end
  end)
end)
local output=assert(fs.open('/pocket-result.txt','w')) output.write(ok and 'PASS: pocket defaults, bounded icons, selector, disabled launch and on-demand addon services' or 'FAIL: '..tostring(err)) output.close()
os.shutdown()
