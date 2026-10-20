local wire=require("system.nexus.protocol")
local store=require("system.nexus.storage")
local observe=require("system.nexus.observe")
local radar=require("system.nexus.radar")
local M={}
local function safeCount(value) return type(value)=="number" and value%1==0 and value>=0 and value<=10000 end
function M.new(cfg,options)
  options=options or {}
  assert(cfg.role=="agent" and cfg.id==os.getComputerID() and wire.validKey(cfg.key),"Invalid agent association")
  local self={cfg=cfg,seen={},sequence=0,nextHeartbeat=os.clock()+(cfg.id%8)*0.05,boot=tostring(os.epoch("utc")),inventory={},lastScan=-math.huge,work={},pending={},radars={},radarIndex=0,nextRadar=0}
  store.recover("/nexus/receipts.cfg")
  self.receipts=store.load("/nexus/receipts.cfg",{})
  store.recover("/nexus/receipt-expiry.cfg")
  self.expiry=store.load("/nexus/receipt-expiry.cfg",{})
  function self:send(kind,body)
    self.sequence=self.sequence+1
    local packet=wire.sign(cfg.key,cfg.id,cfg.master,kind,cfg.id..":"..self.boot..":"..self.sequence,body)
    local ok,sent=pcall(rednet.send,cfg.master,packet,wire.name)
    return ok and sent==true
  end
  function self:tick()
    if os.clock()-self.lastScan>=10 then
      self.modems=wire.openModems() self.inventory=wire.inventory() self.lastScan=os.clock()
      self.radars={}
      for _,device in ipairs(self.inventory) do if device.kind=='radar' and #self.radars<8 then self.radars[#self.radars+1]=device.name end end
    end
    if self.modems>0 and #self.radars>0 and os.clock()>=self.nextRadar then
      self.radarDue=true self.nextRadar=os.clock()+0.5
      if options.wake then options.wake() end
    end
    if self.modems>0 and os.clock()>=self.nextHeartbeat then
      local _,free=pcall(fs.getFreeSpace,'/') local _,capacity=pcall(fs.getCapacity,'/')
      local diskFree=type(free)=='number' and free==free and free>=0 and free<1e15 and free or nil
      local diskCapacity=type(capacity)=='number' and capacity==capacity and capacity>=0 and capacity<1e15 and capacity or nil
      self:send("heartbeat",{version=wire.version,release=cfg.active,provisionToken=cfg.provisionToken,label=tostring(os.getComputerLabel() or "Agent "..cfg.id):sub(1,64),
        group=cfg.group,peripherals=self.inventory,capabilities={"ping","inventory","storage","sum","observe","radar.read"},queueDepth=#self.work+(self.working and 1 or 0),diskFree=diskFree,diskCapacity=diskCapacity,
        radarCount=#self.radars,radarError=self.radarError})
      self.nextHeartbeat=os.clock()+5
    end
  end
  function self:perform(task)
    if type(task.id)~="string" or #task.id>80 then return false end
    local now=os.epoch("utc")
    if task.expiresAt~=nil and (type(task.expiresAt)~="number" or task.expiresAt~=task.expiresAt or task.expiresAt<=now or task.expiresAt>now+300000) then return false end
    local pruned=false
    for id,deadline in pairs(self.expiry) do
      if type(deadline)=="number" and deadline<=now then self.receipts[id]=nil self.expiry[id]=nil pruned=true end
    end
    if pruned then store.save("/nexus/receipts.cfg",self.receipts) store.save("/nexus/receipt-expiry.cfg",self.expiry) end
    local result=self.receipts[task.id]
    if not result then
      if task.type=="ping" then result={ok=true,type="ping",id=cfg.id}
      elseif task.type=="inventory" then result={ok=true,peripherals=wire.inventory()}
      elseif task.type=="storage" then result={ok=true,free=fs.getFreeSpace("/"),capacity=fs.getCapacity("/")}
      elseif task.type=="sum" and safeCount(task.count) then result={ok=true,value=task.count*(task.count+1)/2}
      elseif task.type=='observe' then
        local ok,value=pcall(observe.read,task.endpoint)
        result=ok and value or {ok=false,error=tostring(value):sub(1,120)}
      else result={ok=false,error="Mission not in read-only allowlist"} end
      local count=0 for _ in pairs(self.receipts) do count=count+1 end
      if count>=128 then result={ok=false,error="Receipt journal full; archive/reprovision locally before more missions"}
      else
        -- Persist expiry first: a crash may leak a receipt, never erase a live one.
        if task.expiresAt then self.expiry[task.id]=task.expiresAt store.save("/nexus/receipt-expiry.cfg",self.expiry) end
        self.receipts[task.id]=result store.save("/nexus/receipts.cfg",self.receipts)
      end
    end
    self:send("result",{id=task.id,result=result})
    return true
  end
  function self:receive(sender,packet,protocol)
    if sender~=cfg.master or protocol~=wire.name then return false end
    local message=wire.verify(cfg.key,sender,cfg.id,packet,self.seen)
    if not message or message.kind~='mission' or type(message.body.id)~='string' or #message.body.id>80 then return false end
    local task=message.body
    if options.defer and task.type=='observe' and not self.receipts[task.id] then
      if self.pending[task.id] then return true end
      if #self.work>=8 then return false end
      self.pending[task.id]=true self.work[#self.work+1]=task
      if options.wake then options.wake() end
      return true
    end
    return self:perform(task)
  end
  function self:workStep()
    if self.radarDue then
      self.radarDue=false
      self.radarIndex=self.radarIndex%math.max(1,#self.radars)+1
      local name=self.radars[self.radarIndex]
      if name then
        self.working=true
        local ok,result=pcall(radar.read,name)
        if ok and result then
          result.group=cfg.group
          local ran,sent=pcall(self.send,self,'radar',result)
          self.radarError=(not ran or not sent) and 'Radar transmission failed' or nil
        else self.radarError=tostring(result):sub(1,120) end
        self.working=false
      end
      -- A continuous scan stream must not starve authorized read-only missions.
      if #self.work==0 then return true end
    end
    local task=table.remove(self.work,1) if not task then return false end
    self.working=true
    local ok,err=pcall(self.perform,self,task)
    self.working=false self.pending[task.id]=nil
    if not ok then self:send('result',{id=task.id,result={ok=false,error=tostring(err):sub(1,120)}}) end
    return true
  end
  return self
end
function M.run()
  store.recover("/nexus/config.cfg")
  local cfg=assert(store.load("/nexus/config.cfg"),"NEXUS association missing")
  local agent=M.new(cfg,{defer=true,wake=function() os.queueEvent('nexus_agent_work') end})
  print("NEXUS agent "..cfg.id.." | master "..cfg.master)
  local timer=os.startTimer(0.25)
  local admission={at=os.clock(),count=0}
  parallel.waitForAny(function() while true do
    local event,a,b,c=os.pullEvent()
    if event=="timer" and a==timer then agent:tick() timer=os.startTimer(0.25)
    elseif event=="rednet_message" then
      if os.clock()-admission.at>=1 then admission={at=os.clock(),count=0} end
      if admission.count<8 and a==cfg.master and c==wire.name and wire.shape(b) then
        admission.count=admission.count+1 agent:receive(a,b,c)
      end
    elseif event=="peripheral" or event=="peripheral_detach" then agent.lastScan=-math.huge end
  end end,function()
    while true do if not agent:workStep() then os.pullEvent('nexus_agent_work') end end
  end)
end
return M
