local ui=require('system.graphics.widgets')
local fonts=require('system.graphics.fonts')
local View=require('system.graphics.view')
local primitives=require('system.graphics.primitives')
local Keyboard=require('system.graphics.keyboard')
local M={}
local function rect(x,y,w,h) return {x=x,y=y,w=w,h=h} end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local groups={{'graphics:','Requested renderer','select'},{'display:','Output','select'},{'scale:','Monitor text scale','step'},
  {'theme:','Appearance','radio'},{'profile:','Application profile','radio'},{'volume:','Speaker volume','step'},{'speaker:','Default speaker','select'}}
local hints={label='Computer label',unlock='Unlock password',adminLogin='Admin password',passwordOld='Current admin password',passwordNew='New password',passwordConfirm='Confirm password'}
function M.attach(app,pages)
  function app:drawPixels(s,w,h,p)
    s:rect(0,0,w,h,p.panel) self.pixelHits={} self.scrollbar=nil self.nativeInput=nil self.keyboard.pixelBoxes={} self.nativeReady=w>=200 and h>=120
    if not self.nativeReady then self:cancelInput() self.cleanupPending=false self.rescuePending=false self.dropdown=nil ui.label(s,5,6,'Settings: enlarge window',w-10,p.text,p.panel) return end
    local function button(id,label,r,disabled,kind,active)
      if kind then ui.symbol(s,r,kind,p,active) else ui.button(s,r,label,disabled and {button=p.panel,text=p.muted} or p,active) end
      if self.nativeFocus==id then primitives.rect(s,r.x,r.y,r.w,r.h,p.accent) end
      self.pixelHits[#self.pixelHits+1]={id=id,rect=r,disabled=disabled}
    end
    local title='Settings' for _,page in ipairs(pages) do if page.id==self.page then title=page.label end end
    button('pages',title,rect(5,4,114,24))
    button('reload','',rect(w-29,4,24,24),self.reading,'refresh')
    local sidebar=w>=600 and h>=280 and 120 or 0
    if sidebar>0 then
      local capacity=math.max(1,math.floor((h-52)/24))
      self.navFirst=clamp(self.navFirst or 1,1,math.max(1,#pages-capacity+1))
      self.navArea=rect(4,36,116,h-55)
      for i=self.navFirst,math.min(#pages,self.navFirst+capacity-1) do local page=pages[i]
        button('page:'..page.id,page.label,rect(5,36+(i-self.navFirst)*24,112,23),false,nil,page.id==self.page)
      end
    else self.navArea=nil end
    local area=rect(sidebar+5,36,w-sidebar-19,h-58) self.bodyArea=area
    local model=self.model or {} local items=self:getItems()
    local message=self.appMessage or ''
    local layout=self.nativeLayout
    if not layout or layout.model~=model or layout.width~=area.w or layout.page~=self.page or layout.message~=message or layout.auth~=self.authBusy then
      local blocks={} local y=0
      local function block(kind,data,height) blocks[#blocks+1]={kind=kind,data=data,y=y,h=height} y=y+height+5 end
      if model.page~=self.page then block('text','Reading settings...',20)
      else
        for _,line in ipairs(model.lines or {}) do
          local label,value=line:match('^([^:]+):%s*(.*)$')
          if label and #label<=32 then
            local columns=area.w>=360 local width=columns and area.w-146 or area.w-8
            local text=fonts.layout(value,width,8192,{wrap=true,lineSpacing=2})
            block('property',{label=label,value=text,columns=columns},math.max(17,text.height+(columns and 1 or 13)))
          else
            local text=fonts.layout(line,area.w-8,8192,{wrap=true,lineSpacing=2}) block('paragraph',text,math.max(15,text.height))
          end
        end
        local used={}
        for _,group in ipairs(groups) do
          local options={}
          for _,item in ipairs(items) do if item.id:sub(1,#group[1])==group[1] then options[#options+1]=item used[item.id]=true end end
          if #options>0 then
            if group[1]=='speaker:' and model.audio then for _,item in ipairs(options) do item.active=item.id:sub(9)==model.audio.defaultSide end end
            block(group[3],{label=group[2],options=options},group[3]=='radio' and 17+#options*24 or 47)
          end
        end
        for _,item in ipairs(items) do if not used[item.id] then
          block(item.id=='audio' and 'toggle' or 'action',item,item.id=='audio' and 26 or 25)
        end end
        if self.page=='apps' then for _,item in ipairs(model.apps or {}) do block('app',item,26) end end
      end
      if message~='' then local text=fonts.layout('Last result: '..message,area.w-8,8192,{wrap=true,lineSpacing=2}) block('paragraph',text,math.max(20,text.height)) end
      layout={model=model,width=area.w,page=self.page,blocks=blocks,height=y,message=message,auth=self.authBusy} self.nativeLayout=layout
    end
    self.bodyHeight=layout.height self.bodyScroll=clamp(self.bodyScroll or 0,0,math.max(0,layout.height-area.h))
    local view=View.new(s,area.x,area.y,area.w,area.h)
    local busy=self.authBusy or self.control and self.control.busy
    local function hit(id,x,y,rw,rh,disabled)
      if y>=0 and y+rh<=area.h then
        self.pixelHits[#self.pixelHits+1]={id=id,rect=rect(area.x+x,area.y+y,rw,rh),disabled=disabled}
        if self.nativeFocus==id then primitives.rect(view,x,y,rw,rh,p.accent) end
      end
    end
    for _,block in ipairs(layout.blocks) do local y=block.y-self.bodyScroll local data=block.data
      if y+block.h>=0 and y<area.h then
        if block.kind=='property' then
          ui.label(view,4,y+2,data.label, data.columns and 134 or area.w-8,p.muted,p.panel)
          local x,top=data.columns and 145 or 4,y+(data.columns and 2 or 14)
          for _,line in ipairs(data.value.lines) do if top+line.y+9>0 and top+line.y<area.h then fonts.draw(view,x,top+line.y,line.text,p.text,p.panel) end end
        elseif block.kind=='paragraph' then for _,line in ipairs(data.lines) do if y+line.y+9>0 and y+line.y<area.h then fonts.draw(view,4,y+line.y,line.text,p.text,p.panel) end end
        elseif block.kind=='text' then ui.label(view,4,y+3,data,area.w-8,p.muted,p.panel)
        elseif block.kind=='select' then
          ui.label(view,4,y,data.label,area.w-8,p.muted,p.panel)
          local selected for _,item in ipairs(data.options) do if item.active then selected=item end end
          local r=rect(4,y+16,area.w-8,25) ui.button(view,r,selected and selected.label or 'Select...',p)
          hit('select:'..data.label,r.x,r.y,r.w,r.h,busy)
        elseif block.kind=='step' then
          ui.label(view,4,y,data.label,area.w-8,p.muted,p.panel)
          local index=1 for i,item in ipairs(data.options) do if item.active then index=i end end
          local current=data.options[index]
          ui.symbol(view,rect(4,y+17,24,24),'previous',p)
          ui.label(view,34,y+24,current.label,area.w-72,p.text,p.panel,'center')
          ui.symbol(view,rect(area.w-28,y+17,24,24),'next',p)
          hit('action:'..data.options[math.max(1,index-1)].id,4,y+17,24,24,busy or index==1)
          hit('action:'..data.options[math.min(#data.options,index+1)].id,area.w-28,y+17,24,24,busy or index==#data.options)
        elseif block.kind=='radio' then
          ui.label(view,4,y,data.label,area.w-8,p.muted,p.panel)
          for i,item in ipairs(data.options) do
            local top=y+18+(i-1)*24
            primitives.circle(view,10,top+9,5,p.muted) if item.active then primitives.circle(view,10,top+9,2,p.accent,true) end
            ui.label(view,24,top+5,item.label,area.w-28,busy and p.muted or p.text,p.panel)
            hit('action:'..item.id,3,top,area.w-6,23,busy)
          end
        elseif block.kind=='toggle' or block.kind=='app' then
          local enabled=block.kind=='app' and data.enabled or model.audio and model.audio.enabled
          primitives.rect(view,5,y+6,11,11,p.muted) if enabled then
            primitives.line(view,7,y+11,10,y+14,p.accent) primitives.line(view,10,y+14,14,y+8,p.accent)
          end
          ui.label(view,24,y+7,block.kind=='app' and (data.name..(data.core and ' *' or '')) or 'Audio enabled',area.w-28,p.text,p.panel)
          hit(block.kind=='app' and ('app:'..data.id) or 'action:audio',3,y+1,area.w-6,24,busy or data.core)
        else
          local r=rect(4,y,math.min(area.w-8,math.max(90,#data.label*6+18)),24)
          ui.button(view,r,data.label,p) hit('action:'..data.id,r.x,r.y,r.w,r.h,busy and data.id~='cancelAuth')
        end
      end
    end
    if layout.height>area.h then self.scrollbar=rect(w-11,area.y,7,area.h) self.scrollThumb=ui.scrollbar(s,self.scrollbar,layout.height,area.h,self.bodyScroll+1,p) end
    ui.label(s,5,h-16,self.authBusy and self.appMessage or self.control and self.control.busy and ('Setting '..tostring(self.control.action)..': '..tostring(self.control.phase)) or self.appMessage,w-10,p.muted,p.panel)
    if self.pagesOpen or self.dropdown then
      self.pixelHits={} self.scrollbar=nil self.nativeInput=nil
      local options=self.pagesOpen and pages or self.dropdown.options
      local capacity=math.max(1,math.floor((h-42)/24)) self.optionFirst=clamp(self.optionFirst or 1,1,math.max(1,#options-capacity+1))
      self.optionIndex=clamp(self.optionIndex or 1,1,math.max(1,#options))
      local mw=math.min(260,w-10) s:rect(4,31,mw+2,math.min(capacity,#options)*24+3,p.desktop)
      for i=self.optionFirst,math.min(#options,self.optionFirst+capacity-1) do local item=options[i]
        button(self.pagesOpen and ('page:'..item.id) or ('action:'..item.id),item.label,rect(5,32+(i-self.optionFirst)*24,mw,23),false,nil,item.active)
        if i==self.optionIndex then primitives.rect(s,5,32+(i-self.optionFirst)*24,mw,23,p.accent) end
      end
    end
    if self.cleanupPending or self.rescuePending then
      self.pixelHits={} self.scrollbar=nil self.pagesOpen=false self.dropdown=nil
      local r=rect(5,30,w-10,h-35) s:rect(r.x,r.y,r.w,r.h,p.desktop)
      ui.paragraph(s,rect(r.x+6,r.y+7,r.w-12,r.h-43),self.rescuePending and 'Switch to text rescue now and on next boot?' or 'Prune eligible old update backups? Protected checkpoints remain.',p.text,p.desktop,{wrap=true})
      button('confirm', 'Confirm',rect(r.x+6,r.y+r.h-29,76,23),busy)
      button('cancel','Cancel',rect(r.x+88,r.y+r.h-29,72,23))
    end
    if self.mode then
      self.pixelHits={} self.scrollbar=nil self.pagesOpen=false self.dropdown=nil
      local soft=self.softKeyboard==true
      local compact=soft and h<235
      local r=compact and rect(0,0,w,h) or rect(5,30,w-10,soft and math.min(h-35,215) or math.min(110,h-35))
      s:rect(r.x,r.y,r.w,r.h,p.desktop)
      ui.label(s,r.x+5,r.y+5,hints[self.mode] or 'Password',r.w-64,p.accent,p.desktop)
      button('inputCancel','',rect(r.x+r.w-(compact and 25 or 27),r.y+1,compact and 20 or 23,compact and 17 or 23),false,'close')
      self.nativeInput=rect(r.x+5,r.y+(compact and 22 or 25),r.w-10,compact and 21 or 24)
      ui.input(s,self.nativeInput,self.mode=='label' and self.input or string.rep('*',#self.input),p,true,'')
      if compact then Keyboard.draw(s,5,46,w-10,h-49,self.keyboard,p)
      else
        button('inputSubmit','Confirm',rect(r.x+5,r.y+55,76,24),self.authBusy)
        button('inputKeyboard','',rect(r.x+r.w-31,r.y+55,25,24),false,'keyboard',soft)
        if soft then Keyboard.draw(s,r.x+5,r.y+87,r.w-10,r.h-90,self.keyboard,p) end
      end
    else self.softKeyboard=false end
  end
  function app:handlePixels(event)
    if not self.nativeReady then return false end
    local name,x,y=event.name,event.args[2],event.args[3]
    if self.mode then
      if name=='char' or name=='paste' then self.keyboard.onText(event.args[1]) return true end
      if name=='key' then
        if event.args[1]==keys.escape then self:cancelInput()
        elseif event.args[1]==keys.enter then self.keyboard.onEnter()
        elseif event.args[1]==keys.backspace then self.keyboard.onBackspace() end return true
      end
      if name=='mouse_click' then
        for _,hit in ipairs(self.pixelHits or {}) do if ui.hit(hit.rect,x,y) then
          if hit.id=='inputCancel' then self:cancelInput()
          elseif hit.id=='inputSubmit' and not hit.disabled then self.keyboard.onEnter()
          elseif hit.id=='inputKeyboard' then self.softKeyboard=not self.softKeyboard end return true
        end end
        if self.softKeyboard then Keyboard.handle(event,self.keyboard) end
      end return true
    end
    if name=='mouse_scroll' then
      if self.pagesOpen or self.dropdown then self.optionFirst=math.max(1,(self.optionFirst or 1)+event.args[1]) self.optionIndex=self.optionFirst
      elseif ui.hit(self.navArea,x,y) then self.navFirst=math.max(1,(self.navFirst or 1)+event.args[1])
      else self.bodyScroll=math.max(0,(self.bodyScroll or 0)+event.args[1]*28) end return true
    end
    if name=='mouse_up' then self.scrollDragging=false return true end
    if name=='mouse_drag' and self.scrollDragging and self.scrollbar then self.bodyScroll=ui.scrollbarValue(self.scrollbar,self.bodyHeight,self.bodyArea.h,y)-1 return true end
    local function activate(id,touch)
      if id=='pages' then self.pagesOpen=not self.pagesOpen self.dropdown=nil self.optionFirst=1 self.optionIndex=1
      elseif id:sub(1,5)=='page:' then self:setPage(id:sub(6)) self.pagesOpen=false self.dropdown=nil
      elseif id=='reload' then self:requestRead()
      elseif id=='confirm' then self:action(self.rescuePending and 'rescueConfirm' or 'cleanupConfirm')
      elseif id=='cancel' then self.cleanupPending=false self.rescuePending=false
      elseif id:sub(1,7)=='select:' then
        for _,block in ipairs(self.nativeLayout.blocks) do if type(block.data)=='table' and block.data.label==id:sub(8) then self.dropdown=block.data self.pagesOpen=false self.optionFirst=1 self.optionIndex=1 break end end
      elseif id:sub(1,4)=='app:' then self:toggleApp(id:sub(5))
      elseif id:sub(1,7)=='action:' then self.dropdown=nil self:action(id:sub(8)) if self.mode and touch then self.softKeyboard=true end end
    end
    if name=='key' then
      local key=event.args[1]
      if key==keys.escape then self.pagesOpen=false self.dropdown=nil self.cleanupPending=false self.rescuePending=false return true end
      if key==keys.tab then
        local hits=self.pixelHits or {} local index=0 for i,hit in ipairs(hits) do if hit.id==self.nativeFocus then index=i break end end
        for i=1,#hits do local hit=hits[(index+i-1)%#hits+1] if not hit.disabled then self.nativeFocus=hit.id break end end return true
      end
      if key==keys.enter then for _,hit in ipairs(self.pixelHits or {}) do if hit.id==self.nativeFocus and not hit.disabled then activate(hit.id) return true end end end
      if self.pagesOpen or self.dropdown then
        local options=self.pagesOpen and pages or self.dropdown.options
        if key==keys.down or key==keys.up then
          self.nativeFocus=nil self.optionIndex=clamp((self.optionIndex or 1)+(key==keys.down and 1 or -1),1,#options)
          local capacity=math.max(1,math.floor((self.bodyArea.h+16)/24))
          if self.optionIndex<(self.optionFirst or 1) then self.optionFirst=self.optionIndex
          elseif self.optionIndex>=(self.optionFirst or 1)+capacity then self.optionFirst=self.optionIndex-capacity+1 end
        elseif key==keys.enter then local item=options[self.optionIndex or 1] if item then activate((self.pagesOpen and 'page:' or 'action:')..item.id) end end return true
      end
      if key==keys.down or key==keys.pageDown then self.bodyScroll=(self.bodyScroll or 0)+(key==keys.down and 22 or self.bodyArea.h) return true end
      if key==keys.up or key==keys.pageUp then self.bodyScroll=math.max(0,(self.bodyScroll or 0)-(key==keys.up and 22 or self.bodyArea.h)) return true end
    elseif name=='mouse_click' then
      for i=#(self.pixelHits or {}),1,-1 do local hit=self.pixelHits[i] if ui.hit(hit.rect,x,y) then
        self.nativeFocus=hit.id if not hit.disabled then activate(hit.id,event.monitorTouch) end return true
      end end
      if self.pagesOpen or self.dropdown then self.pagesOpen=false self.dropdown=nil return true end
      if ui.hit(self.scrollbar,x,y) then self.scrollDragging=true self.bodyScroll=ui.scrollbarValue(self.scrollbar,self.bodyHeight,self.bodyArea.h,y)-1 return true end
    end
    return false
  end
end
return M
