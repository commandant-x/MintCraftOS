-- Native rendering in a visible, disposable CraftOS-PC instance.
local ok,err=pcall(function()
  shell.setDir('/') assert(shell.run('/source/install.lua'))
  local snapshot={role='master',master=38,group='factory',online=7,managed=7,discovered=7,
    revision=1,message='HIVE ready',jobs={},drives={},computers={}}
  for id=28,34 do snapshot.computers[#snapshot.computers+1]={id=id,label='Factory '..id,
    group='factory',state='ONLINE',authorized=true,version='0.2.0',name='computer_'..id,
    activeMissions=id%3,lastSeenSeconds=id%5,capabilities={'ping','inventory','storage','sum'},
    peripherals={{name='back',type='modem'},{name='left',type='inventory'}}} end
  package.loaded['system.services.nexusd']={version='0.2.0',snapshot=function() return snapshot end,request=function() return true end}
  local app local win={closed=false}
  local ctx={pid=4,args={},windowManager={create=function(_,options) app=options.app return win end},
    startTimer=function() return 1 end,onCleanup=function() end,pullEvent=function() return coroutine.yield() end}
  local co=coroutine.create(function() require('apps.nexus.main').run(ctx) end)
  assert(coroutine.resume(co))
  app.page='map' app.selected=30
  local renderer=require('system.gui.renderer')
  for _,size in ipairs({{100,34},{26,20},{18,9}}) do
    local target=window.create(term.current(),1,1,size[1],size[2],true)
    local old=term.redirect(target)
    renderer.fill(1,1,size[1],size[2],colors.white)
    app:draw(size[1],size[2])
    local frame={}
    for y=1,size[2] do local text,fg,bg=target.getLine(y) frame[y]={text=text,fg=fg,bg=bg} end
    local h=assert(fs.open('/network-frame-'..size[1]..'.json','w')) h.write(textutils.serializeJSON(frame)) h.close()
    term.redirect(old)
    if term.screenshot then term.screenshot() end
  end
end)
local h=assert(fs.open('/network-result.txt','w')) h.write(ok and 'PASS: native 2D network desktop/pocket/minimum layouts' or 'FAIL: '..tostring(err)) h.close()
os.shutdown()
