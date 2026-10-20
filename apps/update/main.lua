local renderer=require("system.gui.renderer")
local updated=require("system.services.updated")
local ui=require("system.gui.components")
local theme=require("system.gui.theme")
local pixel=require("apps.update.pixel")
local M={}
function M.run(ctx)
  local actor={pid=ctx.pid}
  local app={status=updated.status,control={busy=false},message="Ready",detailScroll=1}
  local win,timer
  local function call(fn,...)
    local ran,ok,result=pcall(fn,...)
    if not ran then return false,tostring(ok) end
    return ok,result
  end
  function app:poll()
    self.control=updated.controlStatus() self.busy=self.control.busy self.status=updated.status
    if not self.busy then
      local ok,metadata=pcall(function() return {cfg=updated.loadConfig(),backup=updated.rollbackInfo(),localVersion=updated.localVersion()} end)
      if ok then self.metadata=metadata else self.message="Metadata read failed: "..tostring(metadata) end
    end
    if win then win.dirty=true end
  end
  function app:request(action,token)
    if self.busy then self.message="UPD-BUSY: operation already running" return end
    local ok,result=call(updated.requestAction,actor,action,token)
    self.message=ok and ("Queued #"..result..": "..action) or tostring(result)
    if ok then self.operation=result self.detailScroll=1 end
    self:poll()
  end
  function app:prepare(action)
    if self.busy then return end
    local ok,result=call(updated.prepareAction,actor,action)
    if ok then self.confirm=result else self.message=tostring(result) end
  end
  function app:confirmAction()
    local pending=self.confirm self.confirm=nil
    if pending then self:request(pending.action,pending.token) end
  end
  function app:refresh() self:request("check") end
  function app:apply() self:prepare("apply") end
  function app:rollback() self:prepare("rollback") end
  function app:activate(id)
    if id=="confirm" then self:confirmAction()
    elseif id=="cancel" then self.confirm=nil
    elseif id=="check" then self:refresh()
    elseif id=="apply" then self:apply()
    elseif id=="rollback" then self:rollback() end
  end
  function app:draw(w,h)
    self.lastH=h self.buttons={}
    renderer.fill(1,1,w,h,theme.get("windowBg"))
    if w<20 or h<8 then self.confirm=nil renderer.writeAt(1,1,"Enlarge Update",theme.get("windowFg")) return end
    local status,metadata=self.status,self.metadata or {}
    local lines={"Installed: "..tostring(metadata.localVersion or status.localVersion),"Release: "..tostring(status.remoteVersion),
      "State: "..tostring(self.control.phase or "idle"),"Rollback: "..tostring(metadata.backup and metadata.backup.fromVersion or "none"),
      tostring(self.control.message or self.message),tostring(self.message)}
    if self.confirm then
      local c=self.confirm
      lines={"Confirm "..c.action.."?",tostring(c.localVersion).." -> "..tostring(c.version),c.source and c.source.sha or ("Checkpoint "..tostring(c.backupId)),"Transaction continues after first write."}
    end
    for i=1,math.min(#lines,h-2) do renderer.writeAt(1,i,renderer.crop(lines[i]:gsub("[%c]"," "),w),theme.get("windowFg"),theme.get("windowBg")) end
    self.buttons=ui.toolbar(1,h-1,w,self.confirm and {{id="confirm",label="Confirm"},{id="cancel",label="Cancel"}} or {{id="check",label="Check"},{id="apply",label="Apply"},{id="rollback",label="Rollback"}})
  end
  function app:handle(event)
    if self.graphicsActive and not event.name:match("^mouse_") then return self:handlePixels(event) end
    if event.name=="key" and event.args[1]==keys.escape then self.confirm=nil return true end
    if event.name~="mouse_click" then return false end
    local action=ui.toolbarHit(self.buttons,event.args[2],event.args[3])
    if action then self:activate(action) return true end
    return false
  end
  pixel.attach(app)
  app:poll()
  local w,h=term.getSize()
  win=ctx.windowManager:create({title="Update",w=math.min(88,w-4),h=math.min(30,h-3),x=7,y=4,app=app})
  ctx.onCleanup(function() if timer then os.cancelTimer(timer) end end)
  timer=ctx.startTimer(0.2)
  while not win.closed do
    local event=ctx.pullEvent()
    if event and event.name=="timer" and event.args[1]==timer then
      if not win.minimized then app:poll() end timer=ctx.startTimer(0.2)
    elseif event and event.name=="mintcraft_update_result" and event.args[1]==ctx.pid and event.args[2]==app.operation then
      app.operation=nil app.message=tostring(event.args[4]) app:poll()
    end
  end
end
return M
