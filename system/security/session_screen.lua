local security=require("system.services.securityd")
local users=require("system.security.users")
local widgets=require("system.graphics.widgets")
local M={}
local inputs={char=true,paste=true,key=true,key_up=true,mouse_click=true,mouse_up=true,
  mouse_drag=true,mouse_scroll=true,monitor_touch=true,file_transfer=true,terminate=true}
function M.new(ctx)
  local self={password="",confirmation=nil,message="",busy=false,active=nil}
  local function invalidate()
    if ctx.invalidateDisplay then ctx.invalidateDisplay() end
  end
  function self:retrySeconds()
    return math.max(0,math.ceil((self.retryUntil or 0)-os.clock()))
  end
  function self:refreshRetry()
    local ok,status,err=pcall(users.authenticationStatus)
    if not ok or type(status)~="table" or type(status.retryAfter)~="number" then
      self.retryError=ok and tostring(err or "Retry protection unavailable") or "Retry protection unavailable"
      status=nil
    else self.retryError=nil end
    self.retryUntil=os.clock()+(status and status.retryAfter or 0)
    self.lastRetry=self:retrySeconds()
  end
  function self:tick()
    local seconds=self:retrySeconds()
    if self.active and self.lastRetry~=seconds then self.lastRetry=seconds invalidate() return true end
    return false
  end
  function self:messageText()
    if self.retryError then return self.retryError end
    local seconds=self:retrySeconds()
    if seconds>0 and not self.busy then return "Too many attempts; retry in "..seconds.."s" end
    return self.message
  end
  function self:blocked()
    local revision=security.sessionRevision and security.sessionRevision()
    if revision==nil or self.cachedRevision~=revision or self.cachedBlock==nil then
      self.enrollment=users.needsEnrollment()
      self.cachedBlock=self.enrollment or security.isLocked()
      self.cachedRevision=revision
    end
    return self.cachedBlock
  end
  function self:sync()
    local revision=security.sessionRevision and security.sessionRevision()
    if security.sessionIdentity and (self.identityRevision~=revision or not self.identityKnown) then
      local identity=security.sessionIdentity()
      if self.identityKnown and identity~=self.identity then
        -- Sign-out/account changes must not expose another user's cached windows.
        for pid,process in pairs(ctx.scheduler.processes or {}) do
          if #(process.windows or {})>0 then
            for _,win in ipairs(process.windows) do win.closed=true end
            if not (process.meta and process.meta.protected) then ctx.scheduler:kill(pid) end
          end
        end
        if ctx.pixelWorkspace then ctx.pixelWorkspace:deactivate() end
      end
      self.identity,self.identityRevision,self.identityKnown=identity,revision,true
    end
    local blocked=self:blocked()
    if self.active~=blocked then
      self.active=blocked self.password="" self.confirmation=nil self.message=""
      if blocked then self:refreshRetry() end
      if ctx.pixelWorkspace then ctx.pixelWorkspace:deactivate() end
      invalidate()
    end
    return blocked
  end
  function self:submit()
    if self.busy or self.retryError or self:retrySeconds()>0 then return end
    local enrollment=self.enrollment
    if enrollment then
      if #self.password<8 then self.message="Use at least 8 characters" return end
      if not self.confirmation then
        self.confirmation=self.password self.password="" self.message="Confirm new password" return
      end
      if self.password~=self.confirmation then
        self.password="" self.confirmation=nil self.message="Passwords differ; try again" return
      end
    end
    local password=self.password self.password="" self.confirmation=nil
    self.busy=true self.message="Verifying..."
    local pid=ctx.scheduler:spawn("Session authentication",function()
      self.authStage="Authentication"
      local options={stage=function(label) self.authStage=label self.message=label invalidate() end,
      progress=function(done,total)
        self.message=self.authStage.." "..math.floor(done/total*100).."%" invalidate()
      end}
      local success,ok,err=pcall(function()
        if enrollment then return security.enroll(password,options) end
        -- Guest has no password and must not bypass the protected console.
        local identity,problem="admin",nil
        if users.loginIdentity then identity,problem=users.loginIdentity() end
        if not identity then return false,problem end
        return security.login(identity,password,options)
      end)
      password=nil self.busy=false self:refreshRetry()
      self.message=success and (ok and "" or tostring(err)) or "Authentication unavailable"
      self:sync() invalidate()
      os.queueEvent("mintcraft_session_result")
    end,{eventMode="raw",protected=true,permissions={"system.auth"}})
    local ok=ctx.scheduler:start(pid)
    if not ok then password=nil self.busy=false self.message="Authentication unavailable" end
  end
  function self:handle(event)
    self:sync()
    if not self.active and event.name=="key" and keys.f12 and event.args[1]==keys.f12 then
      security.lock() self:sync() return true
    end
    if not self.active or not inputs[event.name] then return false end
    if not self.busy and not self.retryError and self:retrySeconds()==0 then
      if event.name=="char" or event.name=="paste" then
        self.password=(self.password..tostring(event.args[1])):sub(1,1024)
      elseif event.name=="key" then
        if event.args[1]==keys.backspace then self.password=self.password:sub(1,-2)
        elseif event.args[1]==keys.enter then self:submit() end
      elseif event.name=="mouse_click" then
        -- Clicking only submits inside the explicit button.
        local _,x,y=table.unpack(event.args)
        x,y=event.pixelX or x,event.pixelY or y
        if self.pixelButton and widgets.hit(self.pixelButton,x,y) then self:submit() end
      end
    end
    invalidate() return true
  end
  function self:title()
    return self.enrollment and "Protect this computer" or "Session locked"
  end
  function self:drawText()
    term.setBackgroundColor(colors.black) term.setTextColor(colors.white) term.clear()
    local w,h=term.getSize()
    local function line(y,text) term.setCursorPos(2,math.min(h,y)) term.write(text:sub(1,math.max(0,w-2))) end
    line(2,self:title()) line(4,"Password: "..string.rep("*",math.min(#self.password,math.max(0,w-13))))
    line(6,self:messageText()) line(8,"Enter to continue | F12 to lock")
    term.setCursorBlink(false)
  end
  function self:drawPixels(backend)
    local s=backend.surface local w,h=s.width,s.height
    local p={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15}
    s:rect(0,0,w,h,15)
    local bw=math.min(360,w-16) local x=math.floor((w-bw)/2) local y=math.max(4,math.floor((h-125)/2))
    widgets.label(s,x,y,self:title(),bw,0,15)
    widgets.input(s,{x=x,y=y+24,w=bw,h=24},string.rep("*",#self.password),p,true,"Password")
    widgets.label(s,x,y+58,self:messageText(),bw,0,15)
    self.pixelButton={x=x,y=y+78,w=bw,h=24}
    widgets.button(s,self.pixelButton,(self.busy or self:retrySeconds()>0 or self.retryError) and "Please wait" or "Continue",p,true)
    widgets.label(s,x,y+110,"Enter to continue | F12 to lock",bw,8,15)
  end
  return self
end
return M
