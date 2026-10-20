local ui=require('system.graphics.widgets')
local fonts=require('system.graphics.fonts')
local View=require('system.graphics.view')
local primitives=require('system.graphics.primitives')
local Keyboard=require('system.graphics.keyboard')
local M={}
local function rect(x,y,w,h) return {x=x,y=y,w=w,h=h} end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
function M.attach(app)
  function app:drawPixels(s,w,h,p)
    s:rect(0,0,w,h,p.panel) self.pixelHits={} self.keyboard.pixelBoxes={} self.scrollbar=nil self.bodyArea=nil
    self.nativeReady=w>=200 and h>=120
    if not self.nativeReady then self.softKeyboard=false ui.label(s,5,6,'Messenger: enlarge window',w-10,p.text,p.panel) return end
    local function button(id,label,r,kind,disabled)
      local palette=disabled and {button=p.panel,text=p.muted,border=p.muted,accent=p.muted,ink=p.panel} or p
      if kind then ui.symbol(s,r,kind,palette) else ui.button(s,r,label,palette,id=='live' and self.follow) end
      if self.focus==id then primitives.rect(s,r.x,r.y,r.w,r.h,p.accent) end
      self.pixelHits[#self.pixelHits+1]={id=id,rect=r,disabled=disabled}
    end
    local compact=self.softKeyboard and h<260
    if compact then
      ui.label(s,5,3,'Public / insecure',w-37,p.muted,p.panel)
      button('keyboard','',rect(w-26,1,22,18),'close')
      self.inputArea=rect(5,23,w-40,23) ui.input(s,self.inputArea,self.input,p,true,'Message')
      button('send','',rect(w-30,23,25,23),'next',self.busy or self.input=='')
      Keyboard.draw(s,5,46,w-10,h-49,self.keyboard,p) return
    end
    ui.label(s,5,9,'Public chat',math.max(70,w-118),p.text,p.panel)
    button('live','Live',rect(w-111,4,46,24))
    button('rescan','',rect(w-61,4,25,24),'refresh',self.busy)
    button('clear','',rect(w-32,4,25,24),'close')
    ui.label(s,5,34,'Not authenticated / not encrypted',w-10,p.accent,p.panel)
    ui.label(s,5,46,self.status,w-10,p.muted,p.panel)
    local kbH=self.softKeyboard and math.min(130,math.floor(h/3)) or 0
    local composeY=h-32-kbH
    self.inputArea=rect(5,composeY,w-100,25)
    ui.input(s,self.inputArea,self.input,p,self.focus==nil or self.focus=='input','Message')
    self.pixelHits[#self.pixelHits+1]={id='input',rect=self.inputArea}
    button('send','Send',rect(w-90,composeY,55,25),nil,self.busy or self.input=='')
    button('keyboard','',rect(w-30,composeY,25,25),'keyboard')
    if self.softKeyboard then Keyboard.draw(s,5,h-kbH,w-10,kbH-3,self.keyboard,p) end
    local area=rect(5,61,w-20,math.max(1,composeY-67)) self.bodyArea=area
    local layout=self.messageLayout
    if not layout or layout.revision~=self.revision or layout.width~=area.w then
      layout={revision=self.revision,width=area.w,rows={},height=0}
      for _,message in ipairs(self.messages) do
        local text=fonts.layout(message.text,area.w-12,8192,{wrap=true,lineSpacing=2})
        layout.rows[#layout.rows+1]={y=layout.height,from=message.from,own=message.own,text=text}
        layout.height=layout.height+text.height+25
      end self.messageLayout=layout
    end
    self.bodyHeight=layout.height
    self.pixelScroll=self.follow and math.max(0,layout.height-area.h) or clamp(self.pixelScroll or 0,0,math.max(0,layout.height-area.h))
    local view=View.new(s,area.x,area.y,area.w,area.h)
    if #layout.rows==0 then ui.label(view,4,5,'No messages',area.w-8,p.muted,p.panel) end
    for _,row in ipairs(layout.rows) do
      local y=row.y-self.pixelScroll
      if y+row.text.height+20>0 and y<area.h then
        ui.label(view,4,y,row.from,area.w-8,row.own and p.accent or p.muted,p.panel)
        for _,line in ipairs(row.text.lines) do local top=y+14+line.y
          if top+9>0 and top<area.h then fonts.draw(view,6,top,line.text,p.text,p.panel) end
        end
      end
    end
    if layout.height>area.h then
      self.scrollbar=rect(w-10,area.y,6,area.h)
      ui.scrollbar(s,self.scrollbar,layout.height,area.h,self.pixelScroll+1,p)
    end
  end
  function app:handlePixels(event)
    if not self.nativeReady then return false end
    local name,x,y=event.name,event.args[2],event.args[3]
    if name=='char' or name=='paste' then self.keyboard.onText(event.args[1]) self.focus='input' return true end
    if name=='key' then
      local key=event.args[1]
      if key==keys.escape then self.softKeyboard=false return true end
      if key==keys.tab then
        local hits=self.pixelHits local index=0 for i,hit in ipairs(hits) do if hit.id==self.focus then index=i break end end
        for i=1,#hits do local hit=hits[(index+i-1)%#hits+1] if not hit.disabled then self.focus=hit.id break end end return true
      end
      if key==keys.enter then
        if not self.focus or self.focus=='input' then self:action('send')
        else for _,hit in ipairs(self.pixelHits) do if hit.id==self.focus and not hit.disabled then self:action(hit.id) break end end end return true
      end
      if key==keys.backspace then self.keyboard.onBackspace() return true end
      if key==keys.pageUp or key==keys.pageDown then
        self.follow=false self.pixelScroll=math.max(0,(self.pixelScroll or 0)+(key==keys.pageUp and -1 or 1)*(self.bodyArea and self.bodyArea.h or 50)) return true
      end
    elseif name=='mouse_scroll' then
      if self.bodyArea and ui.hit(self.bodyArea,x,y) then self.follow=false self.pixelScroll=math.max(0,(self.pixelScroll or 0)+event.args[1]*25) end return true
    elseif name=='mouse_up' then self.scrollDragging=false return true
    elseif name=='mouse_drag' and self.scrollDragging and self.scrollbar then
      self.follow=false self.pixelScroll=ui.scrollbarValue(self.scrollbar,self.bodyHeight,self.bodyArea.h,y)-1 return true
    elseif name=='mouse_click' then
      for _,hit in ipairs(self.pixelHits) do if ui.hit(hit.rect,x,y) then
        self.focus=hit.id
        if not hit.disabled then
          if hit.id=='input' then if event.monitorTouch then self.softKeyboard=true end else self:action(hit.id) end
        end return true
      end end
      if self.softKeyboard and Keyboard.handle(event,self.keyboard) then return true end
      if ui.hit(self.scrollbar,x,y) then
        self.scrollDragging=true self.follow=false self.pixelScroll=ui.scrollbarValue(self.scrollbar,self.bodyHeight,self.bodyArea.h,y)-1 return true
      end
    end return false
  end
end
return M
