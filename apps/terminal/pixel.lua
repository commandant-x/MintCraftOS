local ui=require('system.graphics.widgets')
local fonts=require('system.graphics.fonts')
local View=require('system.graphics.view')
local primitives=require('system.graphics.primitives')
local Keyboard=require('system.graphics.keyboard')
local M={}
local function rect(x,y,w,h) return {x=x,y=y,w=w,h=h} end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local commands={{'ls','List files'},{'home','Home directory'},{'files','Open Files'},{'ps','Processes'},
  {'logs','Recent logs'},{'clear','Clear output'},{'copy','Copy selected output'},{'paste','Paste copied text'}}
function M.attach(app)
  function app:drawPixels(s,w,h,p)
    s:rect(0,0,w,h,p.panel) self.pixelHits={} self.keyboard.pixelBoxes={} self.rowHits={} self.scrollbar=nil self.bodyArea=nil self.inputArea=nil
    self.nativeReady=w>=200 and h>=120
    if not self.nativeReady then self.commandMenu=false self.pixelKeyboard=false ui.label(s,5,6,'Terminal: enlarge window',w-10,p.text,p.panel) return end
    local function button(id,label,r,kind)
      if kind then ui.symbol(s,r,kind,p) else ui.button(s,r,label,p,id=='live' and self.follow) end
      self.pixelHits[#self.pixelHits+1]={id=id,rect=r}
    end
    local function input(r)
      self.inputArea=r local value,private=self:visibleInput() self.privateInput=private
      local count=math.max(1,math.floor((r.w-10)/6)-1)
      local cursor=private and #value+1 or clamp(self.cursor or #value+1,1,#value+1)
      local left=math.max(1,cursor-count+1) self.inputLeft=left
      s:rect(r.x,r.y,r.w,r.h,p.desktop) primitives.rect(s,r.x,r.y,r.w,r.h,p.accent)
      local top=r.y+math.floor((r.h-9)/2)
      fonts.draw(s,r.x+5,top,value:sub(left,left+count-1),p.text,p.desktop)
      s:rect(r.x+5+(cursor-left)*6,top,1,9,p.accent)
    end
    if self.pixelKeyboard and h<230 then
      ui.label(s,5,3,self.authBusy and 'Authenticating...' or 'Terminal',w-37,p.muted,p.panel)
      button('keyboard','',rect(w-26,1,22,18),'close') input(rect(5,23,w-40,23))
      button('submit','',rect(w-30,23,25,23),'next')
      Keyboard.draw(s,5,46,w-10,h-49,self.keyboard,p)
    else
      ui.label(s,5,10,self.cwd,w-122,p.muted,p.panel)
      button('live','Live',rect(w-115,4,48,24)) button('keyboard','',rect(w-62,4,25,24),'keyboard')
      button('menu','',rect(w-32,4,25,24),'more')
      local kbH=self.pixelKeyboard and math.min(130,math.floor(h/3)) or 0
      local inputY=h-kbH-49
      input(rect(5,inputY,w-43,25)) button('submit','',rect(w-33,inputY,28,25),'next')
      local status=self.authBusy and 'Authentication running' or self.pending and 'Confirmation pending: type yes, or another command to cancel'
        or self.completionError or self.suggestion and ('Tab: '..self.suggestion.label) or (#self.lines..' cached output records')
      ui.label(s,5,h-kbH-17,status,w-10,p.muted,p.panel)
      if kbH>0 then Keyboard.draw(s,5,h-kbH,w-10,kbH-2,self.keyboard,p) end
      local area=rect(5,34,w-20,math.max(1,inputY-41)) self.bodyArea=area
      local layout=self.outputLayout
      if not layout or layout.revision~=self.outputRevision or layout.width~=area.w then
        local cache={} local groups={} local budget=8192 local truncated=false
        for i=#self.lines,1,-1 do
          if budget==0 then truncated=true break end
          local id=self.lineIds[i] local source=self.lines[i]
          local old=self.outputTextCache and self.outputTextCache[id]
          local text=old and old.source==source and old.width==area.w and old.text or fonts.layout(source,area.w-8,8192,{wrap=true,lineSpacing=2})
          cache[id]={source=source,width=area.w,text=text}
          local first=math.max(1,#text.lines-budget+1) local group={id=id,color=self.lineColors[i],lines={}}
          if first>1 then truncated=true end
          for index=first,#text.lines do group.lines[#group.lines+1]=text.lines[index].text end
          groups[#groups+1]=group budget=budget-#group.lines
        end
        layout={revision=self.outputRevision,width=area.w,rows={},truncated=truncated}
        for i=#groups,1,-1 do local group=groups[i] for _,line in ipairs(group.lines) do layout.rows[#layout.rows+1]={id=group.id,text=line,color=group.color} end end
        self.outputTextCache=cache self.outputLayout=layout
      end
      self.visibleRows=math.max(1,math.floor(area.h/11)) self.outputFirst=clamp(self.outputFirst or 1,1,math.max(1,#layout.rows-self.visibleRows+1))
      if self.follow then self.outputFirst=math.max(1,#layout.rows-self.visibleRows+1) end
      local view=View.new(s,area.x,area.y,area.w,area.h)
      for i=1,self.visibleRows do local row=layout.rows[self.outputFirst+i-1] if not row then break end
        local selection=self.selection local selected=selection and row.id>=math.min(selection.first,selection.last) and row.id<=math.max(selection.first,selection.last)
        local bg=selected and p.accent or p.panel local fg=selected and p.ink or row.color=='accent' and p.accent or row.color=='muted' and p.muted or row.color=='error' and 14 or p.text
        view:rect(0,(i-1)*11,area.w,11,bg) fonts.draw(view,3,(i-1)*11+1,row.text,fg,bg)
        self.rowHits[#self.rowHits+1]={id=row.id,rect=rect(area.x,area.y+(i-1)*11,area.w,11)}
      end
      self.scrollbar=rect(w-10,area.y,6,area.h) ui.scrollbar(s,self.scrollbar,#layout.rows,self.visibleRows,self.outputFirst,p)
      if layout.truncated then ui.label(s,5,area.y, 'Older visual rows clipped',area.w,p.muted,p.panel) end
    end
    if self.commandMenu then
      self.pixelHits={} self.rowHits={} self.keyboard.pixelBoxes={} self.scrollbar=nil self.inputArea=nil
      local capacity=math.max(1,math.floor((h-36)/23)) local index=clamp(self.menuIndex or 1,1,#commands)
      self.menuIndex=index local first=clamp(self.menuFirst or 1,1,math.max(1,#commands-capacity+1)) self.menuFirst=first
      local mw=math.min(210,w-10) s:rect(4,30,mw+2,math.min(capacity,#commands)*23+2,p.desktop)
      for i=first,math.min(#commands,first+capacity-1) do local item=commands[i]
        button(item[1],item[2],rect(5,31+(i-first)*23,mw,22))
        if i==index then primitives.rect(s,5,31+(i-first)*23,mw,22,p.accent) end
      end
    end
  end
  function app:handlePixels(event)
    if not self.nativeReady then return false end
    local name,key=event.name,event.args[1] local x,y=event.args[2],event.args[3]
    if name=='key_up' and (key==keys.leftCtrl or key==keys.rightCtrl) then self.controlHeld=false return true end
    if self.commandMenu then
      if name=='key' then
        if key==keys.escape then self.commandMenu=false
        elseif key==keys.enter then local item=commands[self.menuIndex or 1] self.commandMenu=false self:action(item[1])
        elseif key==keys.up or key==keys.down then
          self.menuIndex=clamp((self.menuIndex or 1)+(key==keys.up and -1 or 1),1,#commands)
          local capacity=math.max(1,math.floor((self.lastPixelH-36)/23))
          if self.menuIndex<(self.menuFirst or 1) then self.menuFirst=self.menuIndex elseif self.menuIndex>=(self.menuFirst or 1)+capacity then self.menuFirst=self.menuIndex-capacity+1 end
        end
      elseif name=='mouse_click' then
        for _,hit in ipairs(self.pixelHits) do if ui.hit(hit.rect,x,y) then self.commandMenu=false self:action(hit.id) return true end end self.commandMenu=false
      elseif name=='mouse_scroll' then self.menuFirst=clamp((self.menuFirst or 1)+key,1,#commands) self.menuIndex=self.menuFirst end return true
    end
    if name=='char' and self.controlHeld then return true end
    if name=='char' or name=='paste' then return self:handleText(event)
    elseif name=='key' then
      if key==keys.leftCtrl or key==keys.rightCtrl then self.controlHeld=true return true end
      if self.controlHeld then
        if key==keys.l then self.keyboard.onControl('l') elseif key==keys.u then self.keyboard.onControl('u') elseif key==keys.c then self.keyboard.onControl('c') end return true
      end
      if key==keys.escape then self.pixelKeyboard=false self.selection=nil return true end
      if key==keys.pageUp or key==keys.pageDown then self.follow=false self.outputFirst=math.max(1,(self.outputFirst or 1)+(key==keys.pageUp and -1 or 1)*(self.visibleRows or 5)) return true end
      local col=clamp(self.cursor or #self.input+1,1,#self.input+1)
      if key==keys.left then self.cursor=math.max(1,col-1)
      elseif key==keys.right then self.cursor=math.min(#self.input+1,col+1)
      elseif key==keys.home then self.cursor=1 elseif key==keys['end'] then self.cursor=#self.input+1
      elseif key==keys.delete then self.input=self.input:sub(1,col-1)..self.input:sub(col+1)
      else return self:handleText(event) end self:refreshSuggestion() return true
    elseif name=='mouse_up' then self.selecting=false self.scrollDragging=false return true
    elseif name=='mouse_scroll' and self.bodyArea then self.follow=false self.outputFirst=math.max(1,(self.outputFirst or 1)+key*3) return true
    elseif name=='mouse_click' then
      self.controlHeld=false
      for _,hit in ipairs(self.pixelHits) do if ui.hit(hit.rect,x,y) then
        if hit.id=='menu' then self.commandMenu=true self.menuFirst=1 self.menuIndex=1 else self:action(hit.id) end return true
      end end
      if self.pixelKeyboard and Keyboard.handle(event,self.keyboard) then return true end
      if ui.hit(self.inputArea,x,y) then
        self.cursor=self.privateInput and #self.input+1 or clamp((self.inputLeft or 1)+math.floor((x-self.inputArea.x-5)/6),1,#self.input+1)
        self:refreshSuggestion()
        if event.monitorTouch then self.pixelKeyboard=true end return true
      end
      if ui.hit(self.scrollbar,x,y) then self.scrollDragging=true self.follow=false self.outputFirst=ui.scrollbarValue(self.scrollbar,#self.outputLayout.rows,self.visibleRows,y) return true end
      for _,row in ipairs(self.rowHits) do if ui.hit(row.rect,x,y) then self.selection={first=row.id,last=row.id} self.selecting=true return true end end
    elseif name=='mouse_drag' then
      if self.scrollDragging and self.scrollbar then self.follow=false self.outputFirst=ui.scrollbarValue(self.scrollbar,#self.outputLayout.rows,self.visibleRows,y) return true end
      if self.selecting and self.selection then for _,row in ipairs(self.rowHits) do if ui.hit(row.rect,x,y) then self.selection.last=row.id return true end end end
    end return false
  end
  local draw=app.drawPixels app.drawPixels=function(self,s,w,h,p) self.lastPixelH=h return draw(self,s,w,h,p) end
end
return M
