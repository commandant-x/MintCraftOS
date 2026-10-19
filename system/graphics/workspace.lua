local Scene=require("system.graphics.scene")
local Surface=require("system.graphics.surface")
local Legacy=require("system.graphics.legacy")
local fonts=require("system.graphics.fonts")
local widgets=require("system.graphics.widgets")
local sprites=require("system.graphics.sprites")
local primitives=require("system.graphics.primitives")
local View=require("system.graphics.view")
local PixelKeyboard=require("system.graphics.keyboard")
local M={}
local TITLE,BAR=20,28
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function box(x,y,w,h) return {x=x,y=y,w=w,h=h} end
local function copy(b) return box(b.x,b.y,b.w,b.h) end
local function signature(b) return table.concat({b.x,b.y,b.w,b.h},",") end
local function clockText()
  local m=math.floor(os.time()*60+1e-7)%1440
  return string.format("%02d:%02d",math.floor(m/60),m%60)
end
function M.new(ctx)
  local self={scene=Scene.new(),ctx=ctx,icons={},content={},page=1,taskPage=1,
    menu=false,query="",menuScroll=1,menuSelected=1,revision=0,hits={},context=nil,cacheBytes=0,cacheLimit=2097152}
  local function changed() self.revision=self.revision+1 end
  local function launch(id,args)
    self.menu=false self.context=nil self.typing=false self.query="" changed()
    local ok,err=ctx.apps.launch(id,args)
    if not ok and ctx.notifications then ctx.notifications:push("error","Launch failed",tostring(err),5) end
    return ok
  end
  local function context(items,x,y)
    local available=math.max(22,self.height-BAR-8)
    local capacity=math.max(1,math.floor(available/22))
    local pager=#items>capacity
    if pager then capacity=math.max(1,math.floor((available-18)/22)) end
    local cw=math.min(156,self.width-8) local ch=math.min(#items,capacity)*22+(pager and 18 or 0)
    local c=box(clamp(x,4,self.width-cw-4),clamp(y,4,self.height-BAR-ch-4),cw,ch)
    c.items,c.capacity,c.first,c.pager=items,capacity,1,pager
    self.context=c changed()
  end
  local function desktopContext(x,y)
    context({{label="New...",items={
      {label="File",id="files",args={path="/home/user/desktop",action="new_file"}},
      {label="Folder",id="files",args={path="/home/user/desktop",action="new_dir"}},
      {label="Lua file",id="files",args={path="/home/user/desktop",action="new_lua"}}}},
      {label="Files",id="files",args={path="/home/user/desktop"}},{label="Terminal",id="terminal"},
      {label="Settings",id="settings"},{label="More...",items={{label="Applications",id="settings",args={page="apps"}},
        {label="Devices",id="devices"},{label="Refresh",refresh=true}}}},x,y)
  end
  self.keyboardState={}
  self.keyboardState.onText=function(text) self.query=(self.query..text):sub(1,128) self.menuSelected,self.menuScroll=1,1 changed() end
  self.keyboardState.onBackspace=function() self.query=self.query:sub(1,-2) self.menuSelected,self.menuScroll=1,1 changed() end
  self.keyboardState.onEnter=function() local app=self:filtered()[self.menuSelected] if app then launch(app.id) end end
  self.keyboardState.onTab=self.keyboardState.onEnter
  function self:deactivate()
    for _,win in ipairs(ctx.wm.windows) do
      win.pixelManaged,win.pixelController,win.pixelNative=false,nil,false
      if win.app then win.app.graphicsActive=false end
      if win.maximized then win.maximized=false end
    end
    self.backend=nil self.drag=nil self.clientCapture=nil self.context=nil self.menu=false self.typing=false
    self.content={} self.cacheBytes=0
    self.scene:invalidate()
  end
  local function fit(win,b)
    b.w=clamp(math.floor(b.w),math.min(win.minPixelWidth or 102,self.width),self.width)
    b.h=clamp(math.floor(b.h),math.min(win.minPixelHeight or TITLE+29,self.height-BAR),self.height-BAR)
    b.x=clamp(math.floor(b.x),0,self.width-b.w) b.y=clamp(math.floor(b.y),0,self.height-BAR-b.h)
    local cols=math.max(1,math.floor((b.w-2)/6))
    local rows=math.max(1,math.floor((b.h-TITLE-2)/9))
    if win.w~=cols+2 or win.h~=rows+2 then win.w,win.h,win.dirty=cols+2,rows+2,true end
    win.pixelBounds=b
  end
  function self:toggle(win)
    if win.maximized and win.pixelPrevious then
      win.maximized=false fit(win,win.pixelPrevious) win.pixelPrevious=nil
    else
      win.pixelPrevious=copy(win.pixelBounds) win.maximized=true
      fit(win,box(0,0,self.width,self.height-BAR))
    end
    win.dirty=true changed()
  end
  function self:prepare(backend)
    local theme=require("system.gui.theme")
    local themeId=theme and theme.currentId or "mint"
    if self.backend~=backend or self.themeId~=themeId then
      if self.backend~=backend then self.drag,self.clientCapture=nil,nil end
      self.themeId=themeId
      self.backend=backend self.scene:invalidate()
      self.palette={desktop=15,panel=7,button=15,border=8,text=0,muted=8,accent=9,ink=15}
      if backend.mode==2 and backend.caps.palette then
        local rgb={0x101419,0x1b232d,0x2b3745,0x405166,0xf2f6fa,0xa8b7c8,themeId=="dark" and 0x64c7e6 or 0x65d8a0,0x101419}
        local names={"desktop","panel","button","border","text","muted","accent","ink"}
        for i,name in ipairs(names) do backend:palette(15+i,rgb[i]) self.palette[name]=15+i end
      end
    end
    self.width,self.height=backend.surface.width,backend.surface.height
    self.columns,self.rows=backend.caps.textWidth,backend.caps.textHeight
    -- Registry and disk assets are acquired here, never by layer draw callbacks.
    self.apps=ctx.apps.list()
    local appSignature={}
    for _,app in ipairs(self.apps) do
      appSignature[#appSignature+1]=app.id..":"..app.name
      self.icons[app.id]=self.icons[app.id] or {small=sprites.load(app.iconPath,14),large=sprites.load(app.iconPath,28)}
    end
    self.appSignature=table.concat(appSignature,"|")
    local live={}
    for _,win in ipairs(ctx.wm.windows) do
      if not win.closed then
        live[win.id]=true
        local b=win.pixelBounds or box((win.x-1)*6,(win.y-1)*9,(win.w-2)*6+2,(win.h-2)*9+TITLE+2)
        if win.maximized then
          if not win.pixelPrevious then win.pixelPrevious=copy(b) end
          b=box(0,0,self.width,self.height-BAR)
        end
        win.pixelManaged=true
        win.pixelNative=win.app and type(win.app.drawPixels)=="function" and type(win.app.handlePixels)=="function"
          and (not win.app.pixelPages or win.app.pixelPages[win.app.page]==true) or false
        if win.pixelNative and self.content[win.id] then
          self.cacheBytes=self.cacheBytes-self.content[win.id].bytes self.content[win.id]=nil
        end
        if win.app then win.app.graphicsActive=win.pixelNative end
        win.pixelController=function() self:toggle(win) end
        fit(win,b)
      end
    end
    for id,cached in pairs(self.content) do if not live[id] then
      self.cacheBytes=self.cacheBytes-(cached.bytes or 0) self.content[id]=nil
    end end
    if self.drag and (not live[self.drag.win.id] or self.drag.win.minimized) then self.drag=nil end
    if self.clientCapture and (not live[self.clientCapture.win.id] or self.clientCapture.win.minimized) then self.clientCapture=nil end
  end
  function self:filtered()
    local rows={} local q=self.query:lower()
    for _,app in ipairs(self.apps or {}) do
      if q=="" or app.name:lower():find(q,1,true) or app.id:lower():find(q,1,true) then rows[#rows+1]=app end
    end
    return rows
  end
  function self:layer(layers,id,b,revision,draw)
    layers[#layers+1]={id=id,x=b.x,y=b.y,w=b.w,h=b.h,revision=revision,draw=draw}
  end
  function self:draw(backend)
    local s,p=backend.surface,self.palette
    local w,h=self.width,self.height
    local layers={} self.hits={} self.taskHits={} self.windowHits={} self.notificationHits={}
    local compact=w<240
    local cellW,cellH=compact and 72 or 90,compact and 52 or 68
    local columns=math.max(1,math.floor(w/cellW))
    local rows=math.max(1,math.floor((h-BAR-24)/cellH))
    local capacity=columns*rows self.pages=math.max(1,math.ceil(#self.apps/capacity))
    self.page=clamp(self.page,1,self.pages)
    for i=(self.page-1)*capacity+1,math.min(#self.apps,self.page*capacity) do
      local offset=i-(self.page-1)*capacity-1
      self.hits[#self.hits+1]={rect=box(8+math.floor(offset/rows)*cellW,22+(offset%rows)*cellH,cellW-8,cellH-4),app=self.apps[i]}
    end
    self.pagePrevious=box(w-40,h-BAR-20,16,16) self.pageNext=box(w-20,h-BAR-20,16,16)
    self:layer(layers,"desktop",box(0,0,w,h),self.page..":"..self.appSignature,function(canvas)
      canvas:rect(0,0,w,h,p.desktop)
      widgets.label(canvas,10,7,"MintCraft OS",w-20,p.muted,p.desktop)
      for _,hit in ipairs(self.hits) do
        local r,app=hit.rect,hit.app local image=self.icons[app.id] and self.icons[app.id].large
        if image then sprites.draw(canvas,image,r.x+math.floor((r.w-image.width)/2),r.y) end
        local label=app.name local n=math.max(1,math.floor(r.w/6))
        if #label>n then
          local split=label:sub(1,n):match("^.*() ")
          widgets.label(canvas,r.x,r.y+30,label:sub(1,split and split-1 or n),r.w,p.text,p.desktop,"center")
          widgets.label(canvas,r.x,r.y+40,label:sub(split and split+1 or n+1),r.w,p.text,p.desktop,"center")
        else widgets.label(canvas,r.x,r.y+30,label,r.w,p.text,p.desktop,"center") end
      end
      if self.pages>1 then
        widgets.symbol(canvas,self.pagePrevious,"previous",p,false) widgets.symbol(canvas,self.pageNext,"next",p,false)
        widgets.label(canvas,w-100,h-BAR-15,self.page.." / "..self.pages,54,p.muted,p.desktop,"right")
      end
    end)
    local active=ctx.wm:active()
    for _,win in ipairs(ctx.wm.windows) do
      if not win.closed and not win.minimized and win.pixelBounds then
        local b=win.pixelBounds
        local client=box(b.x+1,b.y+TITLE,b.w-2,b.h-TITLE-1)
        local cw,ch=win.w-2,win.h-2
        local cache=self.content[win.id]
        if not win.pixelNative and win.surface and (not cache or cache.width~=cw or cache.height~=ch or cache.revision~=win.surfaceRevision) then
          self.cacheBytes=self.cacheBytes-(cache and cache.bytes or 0)
          cache={width=cw,height=ch,revision=win.surfaceRevision,bytes=0}
          local bytes=cw*ch*54
          if self.cacheBytes+bytes<=self.cacheLimit then
            cache.surface=Surface.new(cw*6,ch*9,15) cache.bytes=bytes
            for y=1,ch do local text,fg,bg=win.surface.getLine(y) Legacy.row(cache.surface,y,text,fg,bg,cw,ch) end
          end
          self.cacheBytes=self.cacheBytes+cache.bytes
          self.content[win.id]=cache
        end
        local controls={close=box(b.x+b.w-19,b.y+1,18,18),maximize=box(b.x+b.w-38,b.y+1,18,18),minimize=box(b.x+b.w-57,b.y+1,18,18)}
        self.windowHits[#self.windowHits+1]={win=win,rect=b,client=client,controls=controls}
        local revision=tostring(win.surfaceRevision)..":"..win.title..":"..tostring(win==active)..":"..tostring(win.maximized)..":"..tostring(self.drag and self.drag.win==win)
        self:layer(layers,"window:"..win.id,b,revision,function(canvas)
          canvas:rect(b.x,b.y,b.w,b.h,p.panel)
          primitives.rect(canvas,b.x,b.y,b.w,b.h,win==active and p.accent or p.border)
          widgets.label(canvas,b.x+7,b.y+6,self.drag and self.drag.win==win and "Move" or win.title,math.max(0,b.w-68),p.text,p.panel)
          for kind,r in pairs(controls) do widgets.symbol(canvas,r,kind,p,false) end
          if win.pixelNative then
            win:drawPixels(View.new(canvas,client.x,client.y,client.w,client.h),client.w,client.h,p)
          elseif cache then
            if cache.surface then
              for py=math.max(0,canvas.clip.y-client.y),math.min(client.h,cache.surface.height,canvas.clip.y+canvas.clip.h-client.y)-1 do
                canvas:span(client.x,client.y+py,cache.surface.rows[py+1]:sub(1,client.w))
              end
            else
              -- Bounded cache exhausted: rasterize only damaged source rows in place.
              local view={width=cw*6,height=ch*9,span=function(_,x,y,text)
                if y>=0 and y<client.h then canvas:span(client.x+x,client.y+y,text:sub(1,math.max(0,client.w-x))) end
              end}
              local first=math.max(1,math.floor((canvas.clip.y-client.y)/9)+1)
              local last=math.min(ch,math.ceil((canvas.clip.y+canvas.clip.h-client.y)/9))
              for row=first,last do local text,fg,bg=win.surface.getLine(row) Legacy.row(view,row,text,fg,bg,cw,ch) end
            end
            local cx,cy=win.surface.getCursorPos()
            if win==active and win.surface.getCursorBlink() and cx>=1 and cx<=cw and cy>=1 and cy<=ch then
              canvas:rect(client.x+(cx-1)*6,client.y+cy*9-1,5,1,p.text)
            end
          end
          -- Pixel resize grip; no glyph or approximate titlebar hitbox.
          primitives.line(canvas,b.x+b.w-7,b.y+b.h-2,b.x+b.w-2,b.y+b.h-7,p.muted)
        end)
      end
    end
    self.start=box(4,h-BAR+3,26,22)
    self.search=box(34,h-BAR+3,w>=420 and 112 or 26,22)
    local first=self.search.x+self.search.w+5 local last=w-44
    local available=last-first
    local windows={}
    for _,win in ipairs(ctx.wm.windows) do if not win.closed then windows[#windows+1]=win end end
    table.sort(windows,function(a,b) return a.id<b.id end)
    self.taskNext=nil
    if #windows>math.max(1,math.floor(available/112)) and #windows>1 then
      self.taskNext=box(last-15,h-BAR+3,15,22) available=available-17
    end
    local taskWidth=math.min(112,math.max(24,available))
    local taskCapacity=math.max(1,math.floor(available/taskWidth))
    self.taskPages=math.max(1,math.ceil(#windows/taskCapacity))
    self.taskPage=clamp(self.taskPage,1,self.taskPages)
    local taskRevision={clockText(),self.taskPage,tostring(self.menu),tostring(self.typing),#windows}
    for i=(self.taskPage-1)*taskCapacity+1,math.min(#windows,self.taskPage*taskCapacity) do
      local win=windows[i]
      if available>=24 then
        self.taskHits[#self.taskHits+1]={rect=box(first+(i-(self.taskPage-1)*taskCapacity-1)*taskWidth,h-BAR+3,taskWidth-3,22),win=win}
        taskRevision[#taskRevision+1]=win.id..":"..win.title..":"..tostring(win.minimized)..":"..tostring(win==active)
      end
    end
    self:layer(layers,"taskbar",box(0,h-BAR,w,BAR),table.concat(taskRevision,"|"),function(canvas)
      canvas:rect(0,h-BAR,w,BAR,p.panel) canvas:rect(0,h-BAR,w,1,p.border)
      widgets.symbol(canvas,self.start,"menu",p,self.menu)
      if self.search.w>30 then widgets.button(canvas,self.search,"Search",p,self.typing)
      else widgets.symbol(canvas,self.search,"search",p,self.typing) end
      for _,hit in ipairs(self.taskHits) do
        local selected=hit.win==active and not hit.win.minimized
        local image=self.icons[hit.win.appId] and self.icons[hit.win.appId].small
        widgets.button(canvas,hit.rect,hit.rect.w<64 and (image and "" or hit.win.title:sub(1,1)) or hit.win.title,p,selected)
        if hit.rect.w<64 and image then
          sprites.draw(canvas,image,hit.rect.x+math.floor((hit.rect.w-image.width)/2),hit.rect.y+math.floor((hit.rect.h-image.height)/2))
        end
        if hit.win.minimized then canvas:rect(hit.rect.x+4,hit.rect.y+hit.rect.h-3,hit.rect.w-8,1,p.muted) end
      end
      if self.taskNext then widgets.symbol(canvas,self.taskNext,"next",p,false) end
      widgets.label(canvas,w-38,h-BAR+10,clockText(),36,p.text,p.panel,"right")
    end)
    if self.menu then self:drawMenu(layers) end
    if self.context then
      local c=self.context
      self:layer(layers,"context",c,self.revision,function(canvas)
        canvas:rect(c.x,c.y,c.w,c.h,p.panel) primitives.rect(canvas,c.x,c.y,c.w,c.h,p.border)
        for i=c.first,math.min(#c.items,c.first+c.capacity-1) do
          widgets.label(canvas,c.x+8,c.y+6+(i-c.first)*22,c.items[i].label,c.w-16,p.text,p.panel)
        end
        if c.pager then widgets.symbol(canvas,box(c.x+c.w-20,c.y+c.h-17,18,16),"next",p,false) end
      end)
    end
    local notifications=ctx.notifications and ctx.notifications.queue or {}
    local toastCount=math.min(w<360 and 1 or 3,math.max(1,math.floor((h-BAR-80)/38)))
    for i=#notifications,math.max(1,#notifications-toastCount+1),-1 do
      local item=notifications[i] local y=h-BAR-42-(#notifications-i)*38
      if y>=8 then
        local r=box(math.max(4,w-248),y,math.min(240,w-8),34)
        local close=box(r.x+r.w-20,r.y+2,18,16)
        self.notificationHits[#self.notificationHits+1]={rect=r,close=close,id=item.id}
        self:layer(layers,"notification:"..item.id,r,item.id,function(canvas)
          canvas:rect(r.x,r.y,r.w,r.h,p.panel)
          canvas:rect(r.x,r.y,3,r.h,item.level=="error" and 14 or item.level=="warn" and 1 or p.accent)
          widgets.label(canvas,r.x+9,r.y+5,item.title,r.w-32,p.text,p.panel)
          widgets.label(canvas,r.x+9,r.y+18,item.message,r.w-16,p.muted,p.panel)
          widgets.symbol(canvas,close,"close",p,false)
        end)
      end
    end
    self.scene:draw(s,layers)
  end
  function self:drawMenu(layers)
    local p=self.palette local w,h=self.width,self.height
    local panel=box(4,math.max(4,h-BAR-284),math.min(302,w-8),math.min(280,h-BAR-8))
    self.menuPanel=panel self.menuInput=box(panel.x+8,panel.y+8,panel.w-16,24)
    self.menuRows={} self.keyboardHits={}
    self.touchKeyboard=self.touchKeyboard and panel.h>=130 or false
    local keyboardHeight=self.touchKeyboard and math.min(112,math.max(70,math.floor((panel.h-56)/7)*7)) or 0
    local itemHeight=self.touchKeyboard and 18 or 24
    local capacity=math.max(1,math.floor((panel.h-38-keyboardHeight)/itemHeight))
    local filtered=self:filtered()
    self.menuSelected=clamp(self.menuSelected,1,math.max(1,#filtered))
    self.menuScroll=clamp(self.menuScroll,1,math.max(1,#filtered-capacity+1))
    for i=self.menuScroll,math.min(#filtered,self.menuScroll+capacity-1) do
      self.menuRows[#self.menuRows+1]={rect=box(panel.x+8,panel.y+38+(i-self.menuScroll)*itemHeight,panel.w-35,itemHeight-1),app=filtered[i],index=i}
    end
    self.menuPrevious=box(panel.x+panel.w-22,panel.y+38,16,18)
    self.menuNext=box(panel.x+panel.w-22,panel.y+panel.h-keyboardHeight-22,16,18)
    if self.touchKeyboard then
      self.keyboardHits=PixelKeyboard.boxes(panel.x+6,panel.y+panel.h-keyboardHeight,panel.w-12,keyboardHeight,self.keyboardState)
    end
    self:layer(layers,"launcher",panel,self.revision..":"..self.menuScroll..":"..self.menuSelected,function(canvas)
      canvas:rect(panel.x,panel.y,panel.w,panel.h,p.panel) primitives.rect(canvas,panel.x,panel.y,panel.w,panel.h,p.border)
      widgets.input(canvas,self.menuInput,self.query,p,self.typing,"Search apps",24)
      self.keyboardButton=box(self.menuInput.x+self.menuInput.w-25,self.menuInput.y+2,22,20)
      widgets.symbol(canvas,self.keyboardButton,"keyboard",p,self.touchKeyboard)
      for _,hit in ipairs(self.menuRows) do
        local bg=hit.index==self.menuSelected and p.button or p.panel
        canvas:rect(hit.rect.x,hit.rect.y,hit.rect.w,hit.rect.h,bg)
        local image=self.icons[hit.app.id] and self.icons[hit.app.id].small
        if image then sprites.draw(canvas,image,hit.rect.x+3,hit.rect.y+math.floor((hit.rect.h-image.height)/2)) end
        widgets.label(canvas,hit.rect.x+25,hit.rect.y+math.floor((hit.rect.h-9)/2),hit.app.name,hit.rect.w-30,p.text,bg)
      end
      if #filtered==0 then widgets.label(canvas,panel.x+12,panel.y+44,"No applications",panel.w-24,p.muted,p.panel) end
      for _,hit in ipairs(self.keyboardHits) do widgets.button(canvas,hit.rect,hit.label or hit.text,p,hit.active,1) end
      if #filtered>capacity then
        widgets.symbol(canvas,self.menuPrevious,"previous",p,false) widgets.symbol(canvas,self.menuNext,"next",p,false)
      end
    end)
  end
  function self:handle(event)
    local name=event.name
    if name=="key" and keys.f1 and event.args[1]==keys.f1 then
      self.menu=not self.menu self.typing=self.menu self.query="" self.context=nil changed() return true
    end
    local pointer=name:match("^mouse_")~=nil
    local x,y=event.pixelX,event.pixelY
    if pointer and (not x or not y) then return true end
    local function deliver(hit)
      local win=hit.win
      if win.closed or win.minimized then return end
      if win.pixelNative then
        win:handlePixels({name=name,args={event.args[1],x-hit.client.x,y-hit.client.y},raw=event.raw,
          monitorTouch=event.monitorTouch,monitorSide=event.monitorSide,terminalSide=event.terminalSide})
      else
        local col,row=math.floor((x-hit.client.x)/6)+1,math.floor((y-hit.client.y)/9)+1
        if (name=="mouse_click" or name=="mouse_scroll") and (col<1 or col>win.w-2 or row<1 or row>win.h-2) then return end
        win:handle({name=name,args={event.args[1],win.x+col,win.y+row},
          raw=event.raw,monitorTouch=event.monitorTouch,monitorSide=event.monitorSide,terminalSide=event.terminalSide})
      end
    end
    if name=="mouse_up" then
      if self.clientCapture then deliver(self.clientCapture) end
      self.drag,self.clientCapture=nil,nil return true
    end
    if name=="mouse_click" and event.monitorTouch and self.drag and self.drag.touch then
      local d=self.drag local b=copy(d.bounds)
      if d.resize then b.w,b.h=b.w+x-d.x,b.h+y-d.y else b.x,b.y=b.x+x-d.x,b.y+y-d.y end
      fit(d.win,b) self.drag=nil changed() return true
    end
    if name=="mouse_drag" and self.drag then
      local d=self.drag local b=copy(d.bounds)
      if d.resize then b.w,b.h=b.w+x-d.x,b.h+y-d.y else b.x,b.y=b.x+x-d.x,b.y+y-d.y end
      fit(d.win,b) changed() return true
    end
    if name=="mouse_drag" and self.clientCapture then deliver(self.clientCapture) return true end
    if name=="mouse_click" then self.clientCapture=nil end
    if self.menu and (name=="char" or name=="paste" or name=="key") then
      if name=="char" or name=="paste" then self.query=(self.query..tostring(event.args[1])):sub(1,128) self.menuSelected,self.menuScroll=1,1
      else
        local key=event.args[1]
        if key==keys.escape then self.menu=false self.typing=false
        elseif key==keys.backspace then self.query=self.query:sub(1,-2) self.menuSelected,self.menuScroll=1,1
        elseif key==keys.enter then local app=self:filtered()[self.menuSelected] if app then launch(app.id) end
        elseif key==keys.up or key==keys.down then
          self.menuSelected=clamp(self.menuSelected+(key==keys.up and -1 or 1),1,math.max(1,#self:filtered()))
          self.menuScroll=self.menuSelected
        end
      end
      changed() return true
    end
    if name=="mouse_scroll" then
      if self.menu then self.menuScroll=self.menuScroll+event.args[1] changed() return true end
      if y>=self.height-BAR then self.taskPage=clamp(self.taskPage+event.args[1],1,self.taskPages) changed() return true end
    end
    if name~="mouse_click" and name~="mouse_scroll" then return pointer end
    if self.menu then
      if name=="mouse_click" then
        if widgets.hit(self.keyboardButton,x,y) then self.touchKeyboard=not self.touchKeyboard changed() return true end
        if widgets.hit(self.menuPrevious,x,y) then self.menuScroll=self.menuScroll-1 changed() return true end
        if widgets.hit(self.menuNext,x,y) then self.menuScroll=self.menuScroll+1 changed() return true end
        if self.touchKeyboard and PixelKeyboard.handle({name=name,args={event.args[1],x,y}},self.keyboardState) then changed() return true end
        for _,hit in ipairs(self.menuRows or {}) do if widgets.hit(hit.rect,x,y) then launch(hit.app.id) return true end end
        if not widgets.hit(self.menuPanel,x,y) then self.menu=false self.typing=false end
        changed()
      end
      return true
    end
    if self.context then
      local c=self.context changed()
      if name=="mouse_click" and widgets.hit(c,x,y) then
        if c.pager and y>=c.y+c.h-18 then c.first=c.first+c.capacity if c.first>#c.items then c.first=1 end return true end
        local item=c.items[c.first+math.floor((y-c.y)/22)]
        if item then
          if item.items then context(item.items,c.x,c.y)
          elseif item.refresh then sprites.invalidate() self.icons={} self.context=nil self.scene:invalidate()
          else launch(item.id,item.args) end
        end
      else self.context=nil end
      return true
    end
    if y>=self.height-BAR then
      if name=="mouse_click" then
        if widgets.hit(self.start,x,y) or widgets.hit(self.search,x,y) then
          self.menu=true self.typing=true self.query="" self.touchKeyboard=event.monitorTouch or false changed()
        elseif widgets.hit(self.taskNext,x,y) then self.taskPage=self.taskPage%self.taskPages+1 changed()
        else for _,hit in ipairs(self.taskHits) do if widgets.hit(hit.rect,x,y) then hit.win.minimized=false ctx.wm:focus(hit.win) changed() break end end end
      end
      return true
    end
    for _,hit in ipairs(self.notificationHits) do if widgets.hit(hit.rect,x,y) then
      if name=="mouse_click" and widgets.hit(hit.close,x,y) then
        local queue=ctx.notifications.queue
        for i=#queue,1,-1 do if queue[i].id==hit.id then table.remove(queue,i) break end end
        if ctx.notifications.schedule then ctx.notifications:schedule() end
        changed()
      end
      return true
    end end
    for i=#self.windowHits,1,-1 do
      local hit=self.windowHits[i] local win=hit.win
      if not win.closed and not win.minimized and widgets.hit(hit.rect,x,y) then
        if name=="mouse_click" then
          ctx.wm:focus(win)
          if event.args[1]==1 then
            if widgets.hit(hit.controls.close,x,y) then win:requestClose() changed() return true end
            if widgets.hit(hit.controls.minimize,x,y) then win.minimized=true changed() return true end
            if widgets.hit(hit.controls.maximize,x,y) then self:toggle(win) return true end
            if y<hit.rect.y+TITLE then
              self.drag={win=win,x=x,y=y,bounds=copy(hit.rect),touch=event.monitorTouch} changed() return true
            end
            if x>=hit.rect.x+hit.rect.w-9 and y>=hit.rect.y+hit.rect.h-9 then
              self.drag={win=win,x=x,y=y,bounds=copy(hit.rect),resize=true,touch=event.monitorTouch} changed() return true
            end
          end
        end
        if widgets.hit(hit.client,x,y) then
          if name=="mouse_click" and not event.monitorTouch then self.clientCapture={win=win,client=copy(hit.client)} end
          deliver(hit)
        end
        return true
      end
    end
    if name=="mouse_scroll" then self.page=clamp(self.page+event.args[1],1,self.pages) changed() return true end
    if self.pages>1 then
      if widgets.hit(self.pagePrevious,x,y) then self.page=math.max(1,self.page-1) changed() return true end
      if widgets.hit(self.pageNext,x,y) then self.page=math.min(self.pages,self.page+1) changed() return true end
    end
    if event.args[1]==2 then
      desktopContext(x,y) return true
    end
    if event.args[1]==1 then for _,hit in ipairs(self.hits) do if widgets.hit(hit.rect,x,y) then launch(hit.app.id) return true end end end
    if event.monitorTouch then
      local now=os.clock() local last=self.lastTap self.lastTap={x=x,y=y,time=now}
      if last and now-last.time<0.5 and math.abs(last.x-x)<6 and math.abs(last.y-y)<6 then desktopContext(x,y) end
    end
    return true
  end
  return self
end
return M
