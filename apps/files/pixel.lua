local ui=require("system.graphics.widgets")
local primitives=require("system.graphics.primitives")
local keyboard=require("system.graphics.keyboard")
local fonts=require("system.graphics.fonts")
local M={}
local function rect(x,y,w,h) return {x=x,y=y,w=w,h=h} end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function icon(s,x,y,folder,p)
  if folder then s:rect(x,y+3,13,8,4) s:rect(x+1,y,6,3,4)
  else primitives.rect(s,x+2,y,8,11,p.muted) s:rect(x+4,y+3,4,1,p.muted) s:rect(x+4,y+6,4,1,p.muted) end
end
function M.attach(app,api,actions)
  local function filtered()
    local q=(app.nativeQuery or ""):lower()
    if app.filterRevision~=app.fileRevision or app.filterQuery~=q then
      app.filtered={}
      for _,name in ipairs(app.files) do if q=="" or name:lower():find(q,1,true) then app.filtered[#app.filtered+1]=name end end
      app.filterRevision,app.filterQuery=app.fileRevision,q
    end
    return app.filtered
  end
  local function action(id)
    app.nativeMenu=false app.nativeSearchFocused=false app.showSearchKeyboard=false
    if id=="confirm" then api.confirm()
    elseif id=="cancel" then api.cancel()
    elseif id=="open" then if app.selected then api.open(app.selected) end
    else api.action(id) end
  end
  local function input(text)
    if app.mode then app.keyboard.onText(text)
    else app.nativeQuery=((app.nativeQuery or "")..text):sub(1,128) app.scroll=1 app.selected=nil end
  end
  local searchKeyboard={}
  searchKeyboard.onText=input
  searchKeyboard.onBackspace=function() app.nativeQuery=(app.nativeQuery or ""):sub(1,-2) app.scroll=1 end
  searchKeyboard.onEnter=function() app.nativeSearchFocused=false app.showSearchKeyboard=false end
  searchKeyboard.onTab=searchKeyboard.onEnter
  function app:drawPixels(s,w,h,p)
    s:rect(0,0,w,h,p.panel)
    self.pixelButtons={} self.pixelFileRows={} self.pixelMenuItems={}
    self.pixelSize={w=w,h=h}
    local function symbol(id,kind,x,y,width,height)
      local r=rect(x,y,width or 22,height or 22)
      ui.symbol(s,r,kind,p,false) self.pixelButtons[#self.pixelButtons+1]={id=id,rect=r} return r
    end
    local function button(id,label,r,active)
      ui.button(s,r,label,p,active) self.pixelButtons[#self.pixelButtons+1]={id=id,rect=r}
    end
    if self.properties then
      ui.label(s,6,8,"Properties",w-40,p.text,p.panel)
      symbol("cancel","close",w-26,2,22,22)
      local text=self.properties.text
      if self.properties.layoutWidth~=w then
        self.properties.layout=fonts.layout(text,w-12,65536,{lineSpacing=3})
        self.properties.layoutWidth=w
      end
      local layout=self.properties.layout
      self.properties.pixelLineCount=#layout.lines
      local visible=math.max(1,math.floor((h-56)/12))
      self.properties.visibleRows=visible
      self.properties.scroll=clamp(self.properties.scroll,0,math.max(0,#layout.lines-visible))
      local first=self.properties.scroll+1
      for i=first,math.min(#layout.lines,first+visible-1) do
        -- Layout has already decoded display text; do not auto-decode it twice.
        fonts.draw(s,6,30+(i-first)*12,layout.lines[i].text,p.text,p.panel)
      end
      symbol("properties_up","up",4,h-22,22,18)
      symbol("properties_down","down",w-26,h-22,22,18)
      ui.label(s,30,h-17,tostring(first).."-"..math.min(#layout.lines,first+visible-1).." / "..#layout.lines,w-60,p.muted,p.panel,"center")
      return
    end
    if self.confirm then
      self.nativeSearchFocused=false
      local title=self.confirm=="trash" and "Move to trash" or self.confirm=="empty_trash" and "Empty trash forever" or "Delete forever"
      ui.label(s,6,8,title,w-12,p.text,p.panel)
      local target=tostring(self.confirmPath or "")
      local name=target:match("([^/]+)$") or target
      ui.label(s,6,27,name,w-12,p.text,p.panel)
      ui.paragraph(s,rect(6,41,w-12,math.max(0,h-74)),target,p.muted,p.panel)
      local bw=math.floor((w-12)/2)
      button("confirm","Confirm",rect(4,h-27,bw,22),true)
      button("cancel","Cancel",rect(w-bw-4,h-27,bw,22))
      return
    end
    if self.mode then
      self.nativeSearchFocused=false
      ui.label(s,4,6,self.mode=="rename" and "Rename" or self.mode=="new_dir" and "New folder" or "New file",w-50,p.text,p.panel)
      symbol("submit","check",w-44,1,20,18) symbol("cancel","close",w-22,1,20,18)
      ui.input(s,rect(4,22,w-8,19),self.input,p,true)
      if h>=114 then keyboard.draw(s,4,44,w-8,math.min(112,h-44),self.keyboard,p) end
      return
    end
    local compact=w<270
    local toolbar=compact and {{"back","previous"},{"up","up"},{"new_file","new_file"},{"menu","more"}}
      or {{"back","previous"},{"up","up"},{"home","home"},{"refresh","refresh"},{"new_file","new_file"},{"new_dir","new_dir"},{"menu","more"}}
    for i,item in ipairs(toolbar) do symbol(item[1],item[2],4+(i-1)*26,3) end
    local pathWidth=w>=380 and math.floor(w*0.6) or w-8
    s:rect(4,31,pathWidth,19,p.desktop)
    ui.label(s,8,36,self.path,pathWidth-8,p.text,p.desktop)
    local sy=w>=380 and 31 or 54
    local sx=w>=380 and pathWidth+8 or 4
    local sw=w-sx-4
    self.pixelSearch=rect(sx,sy,sw,19)
    ui.input(s,self.pixelSearch,self.nativeQuery,p,self.nativeSearchFocused,"Search",24)
    symbol("search_keyboard","keyboard",sx+sw-24,sy+1,22,17)
    local top=sy+24
    local kbHeight=self.showSearchKeyboard and math.min(112,math.max(70,math.floor((h-top-34)/7)*7)) or 0
    if self.showSearchKeyboard and h-top<104 then
      -- Small clients temporarily give the search keyboard the list's space.
      top=31 kbHeight=math.max(0,math.floor((h-top)/7)*7)
      self.pixelButtons={} s:rect(0,0,w,h,p.panel)
      self.pixelSearch=rect(4,3,w-8,24) ui.input(s,self.pixelSearch,self.nativeQuery,p,true,"Search",24)
      symbol("search_keyboard","keyboard",w-28,5,22,20)
      if kbHeight>=70 then keyboard.draw(s,4,top,w-8,kbHeight,searchKeyboard,p) end
      self.pixelVisibleRows=0
      return
    end
    local listBottom=h-18-kbHeight
    local rows=filtered()
    self.pixelVisibleRows=math.max(1,math.floor((listBottom-top)/20))
    self.scroll=clamp(self.scroll,1,math.max(1,#rows-self.pixelVisibleRows+1))
    for i=self.scroll,math.min(#rows,self.scroll+self.pixelVisibleRows-1) do
      local name=rows[i] local y=top+(i-self.scroll)*20
      local r=rect(4,y,w-26,19) self.pixelFileRows[#self.pixelFileRows+1]={name=name,rect=r}
      local selected=name==self.selected local bg=selected and p.button or p.panel
      s:rect(r.x,r.y,r.w,r.h,bg)
      if selected then s:rect(r.x,r.y,2,r.h,p.accent) end
      icon(s,r.x+3,r.y+4,self.directories[name],p)
      ui.label(s,r.x+23,r.y+5,name,r.w-28,p.text,bg)
    end
    if #rows==0 then ui.label(s,8,top+6,"Empty",w-28,p.muted,p.panel) end
    symbol("scroll_up","up",w-20,top,16,17)
    symbol("scroll_down","down",w-20,math.max(top+18,listBottom-18),16,17)
    if listBottom-top>=45 then
      local trackY,trackH=top+20,listBottom-top-40
      s:rect(w-14,trackY,4,trackH,p.desktop)
      local thumb=math.max(4,math.floor(trackH*self.pixelVisibleRows/math.max(self.pixelVisibleRows,#rows)))
      local offset=math.floor((trackH-thumb)*(self.scroll-1)/math.max(1,#rows-self.pixelVisibleRows))
      s:rect(w-14,trackY+offset,4,thumb,p.accent)
    end
    local clipboard=self.clipboard and (self.clipboard.cut and " | Cut ready" or " | Copy ready") or ""
    ui.label(s,6,h-13,tostring(#rows).." items"..clipboard..(self.selected and " | "..self.selected or ""),w-12,p.muted,p.panel)
    if self.showSearchKeyboard then keyboard.draw(s,4,h-18-kbHeight,w-8,kbHeight,searchKeyboard,p) end
    if self.nativeMenu then
      local items={{id="open",label="Open"}}
      for _,item in ipairs(actions) do items[#items+1]=item end
      local capacity=math.max(1,math.floor((h-30)/20))
      self.nativeMenuFirst=clamp(self.nativeMenuFirst or 1,1,math.max(1,#items-capacity+1))
      local menu=rect(2,1,math.min(196,w-4),math.min(h-2,capacity*20+24))
      self.pixelMenu=menu s:rect(menu.x,menu.y,menu.w,menu.h,p.desktop) primitives.rect(s,menu.x,menu.y,menu.w,menu.h,p.border)
      for i=self.nativeMenuFirst,math.min(#items,self.nativeMenuFirst+capacity-1) do
        local r=rect(menu.x+3,menu.y+3+(i-self.nativeMenuFirst)*20,menu.w-6,19)
        self.pixelMenuItems[#self.pixelMenuItems+1]={rect=r,id=items[i].id}
        ui.label(s,r.x+5,r.y+5,items[i].label,r.w-10,p.text,p.desktop)
      end
      symbol("menu_previous","previous",menu.x+4,menu.y+menu.h-20,20,17)
      symbol("menu_next","next",menu.x+menu.w-24,menu.y+menu.h-20,20,17)
    end
  end
  function app:handlePixels(event)
    if event.name=="mouse_scroll" then
      if self.properties then self.properties.scroll=clamp(self.properties.scroll+event.args[1],0,math.max(0,(self.properties.pixelLineCount or 1)-(self.properties.visibleRows or 1)))
      elseif self.nativeMenu then self.nativeMenuFirst=math.max(1,(self.nativeMenuFirst or 1)+event.args[1])
      else self.scroll=math.max(1,self.scroll+event.args[1]) end
      return true
    end
    if event.name~="mouse_click" then return false end
    local button,x,y=table.unpack(event.args)
    if self.nativeMenu then
      for _,hit in ipairs(self.pixelButtons) do
        if hit.id:match("^menu_") and ui.hit(hit.rect,x,y) then
          self.nativeMenuFirst=math.max(1,(self.nativeMenuFirst or 1)+(hit.id=="menu_next" and 1 or -1)) return true
        end
      end
      for _,hit in ipairs(self.pixelMenuItems) do if ui.hit(hit.rect,x,y) then action(hit.id) return true end end
      self.nativeMenu=false return true
    end
    if self.mode and keyboard.handle(event,self.keyboard) then return true end
    if self.showSearchKeyboard and keyboard.handle(event,searchKeyboard) then return true end
    for _,hit in ipairs(self.pixelButtons) do if ui.hit(hit.rect,x,y) then
      if hit.id=="menu" then self.nativeMenu=true self.nativeMenuFirst=1
      elseif hit.id=="search_keyboard" then self.showSearchKeyboard=not self.showSearchKeyboard self.nativeSearchFocused=true
      elseif hit.id=="scroll_up" or hit.id=="scroll_down" then self.scroll=math.max(1,self.scroll+(hit.id=="scroll_up" and -1 or 1))
      elseif hit.id=="submit" then api.submit()
      elseif hit.id=="properties_up" or hit.id=="properties_down" then
        self.properties.scroll=clamp(self.properties.scroll+(hit.id=="properties_up" and -1 or 1),0,
          math.max(0,(self.properties.pixelLineCount or 1)-(self.properties.visibleRows or 1)))
      else action(hit.id) end
      return true
    end end
    if self.mode or self.confirm or self.properties then return true end
    if ui.hit(self.pixelSearch,x,y) then self.nativeSearchFocused=true return true end
    self.nativeSearchFocused=false
    for _,hit in ipairs(self.pixelFileRows) do if ui.hit(hit.rect,x,y) then
      if button==1 and self.selected==hit.name then api.open(hit.name)
      else self.selected=hit.name end
      if button==2 then self.nativeMenu=true self.nativeMenuFirst=1 end
      return true
    end end
    return true
  end
  function app:handlePixelKey(event)
    if not self.graphicsActive then return false end
    if self.properties then
      if event.name=="key" then
        local key=event.args[1]
        if key==keys.escape or key==keys.enter then api.cancel()
        elseif key==keys.up or key==keys.down then self.properties.scroll=clamp(self.properties.scroll+(key==keys.up and -1 or 1),0,math.max(0,(self.properties.pixelLineCount or 1)-(self.properties.visibleRows or 1))) end
      end
      return true
    end
    if event.name=="key" and event.args[1]==keys.escape and self.nativeMenu then self.nativeMenu=false return true end
    if self.nativeSearchFocused and not self.mode and not self.confirm then
      if event.name=="char" or event.name=="paste" then input(tostring(event.args[1])) return true end
      if event.name=="key" then
        if event.args[1]==keys.backspace then searchKeyboard.onBackspace()
        elseif event.args[1]==keys.escape or event.args[1]==keys.enter then searchKeyboard.onEnter() end
        return true
      end
    end
    if event.name=="key" and not self.mode and not self.confirm and (event.args[1]==keys.up or event.args[1]==keys.down) then
      local rows=filtered() local index=event.args[1]==keys.up and #rows+1 or 0
      for i,name in ipairs(rows) do if name==self.selected then index=i break end end
      index=clamp(index+(event.args[1]==keys.up and -1 or 1),1,math.max(1,#rows))
      self.selected=rows[index]
      if index<self.scroll then self.scroll=index elseif index>=self.scroll+(self.pixelVisibleRows or 1) then self.scroll=index-(self.pixelVisibleRows or 1)+1 end
      return true
    end
    return false
  end
end
return M
