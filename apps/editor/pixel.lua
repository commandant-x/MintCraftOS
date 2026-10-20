local ui=require('system.graphics.widgets')
local fonts=require('system.graphics.fonts')
local primitives=require('system.graphics.primitives')
local View=require('system.graphics.view')
local Keyboard=require('system.graphics.keyboard')
local edit=require('apps.editor.editing')
local M={}
local function rect(x,y,w,h) return {x=x,y=y,w=w,h=h} end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
function M.attach(app)
  function app:drawPixels(s,w,h,p)
    s:rect(0,0,w,h,p.panel) self.pixelHits={} self.keyboard.pixelBoxes={} self.codeArea=nil self.scrollbar=nil
    self.nativeReady=w>=200 and h>=120
    if not self.nativeReady then ui.label(s,5,5,'Editor: enlarge window',w-10,p.text,p.panel) return end
    local function button(id,label,r,kind)
      if kind then ui.symbol(s,r,kind,p) else ui.button(s,r,label,p) end
      if self.closePrompt and self.closeFocus==id then primitives.rect(s,r.x,r.y,r.w,r.h,p.accent) end
      self.pixelHits[#self.pixelHits+1]={id=id,rect=r}
    end
    button('save','Save',rect(5,4,47,23)) button('compile','Check',rect(56,4,49,23))
    button('find','',rect(109,4,24,23),'search') button('keyboard','',rect(137,4,24,23),'keyboard')
    button('menu','',rect(165,4,24,23),'more')
    local compact=self.pixelKeyboard and h<230
    if compact then
      ui.label(s,5,30,self.searchOpen and ('Find: '..(self.searchQuery or '')) or ('Line '..self.cy..' / '..self.cx),w-10,p.muted,p.panel)
      Keyboard.draw(s,5,45,w-10,h-48,self.keyboard,p)
    else
      local kbH=self.pixelKeyboard and math.min(130,math.floor(h/3)) or 0
      local top=self.searchOpen and 63 or 34
      if self.searchOpen then
        ui.input(s,rect(5,32,w-91,24),self.searchQuery or '',p,true,'Find literal text')
        button('findNext','Next',rect(w-82,32,49,24)) button('find','',rect(w-28,32,23,24),'close')
      end
      local gutter=math.max(30,#tostring(#self.lines)*6+9)
      local area=rect(5,top,w-18,math.max(13,h-top-kbH-33)) self.codeArea=area self.gutter=gutter
      self.visibleRows=math.max(1,math.floor(area.h/13)) self.visibleCols=math.max(1,math.floor((area.w-gutter-2)/6))
      self.leftCol=math.max(1,self.leftCol or 1)
      if self.revealCursor~=false then
        if self.cy<self.scroll then self.scroll=self.cy elseif self.cy>=self.scroll+self.visibleRows then self.scroll=self.cy-self.visibleRows+1 end
        if self.cx<self.leftCol then self.leftCol=self.cx elseif self.cx>=self.leftCol+self.visibleCols then self.leftCol=self.cx-self.visibleCols+1 end
      end
      self.revealCursor=false self.scroll=clamp(self.scroll,1,math.max(1,#self.lines-self.visibleRows+1))
      local view=View.new(s,area.x,area.y,area.w,area.h) local first,last=edit.range(self)
      local cache={}
      for row=1,self.visibleRows do
        local lineNo=self.scroll+row-1 local line=self.lines[lineNo] if not line then break end
        local y=(row-1)*13
        ui.label(view,0,y+2,tostring(lineNo),gutter-6,p.muted,p.panel,'right')
        local a,b
        if first and lineNo>=first.row and lineNo<=last.row then
          a=lineNo==first.row and first.col or 1 b=lineNo==last.row and last.col or #line+2
          local left=clamp(a-self.leftCol,0,self.visibleCols) local right=clamp(b-self.leftCol,0,self.visibleCols)
          view:rect(gutter+left*6,y,math.max(0,(right-left)*6),12,p.accent)
        end
        local fragment=line:sub(self.leftCol,self.leftCol+self.visibleCols-1)
        local old=self.lineTokens and self.lineTokens[lineNo]
        local tokens=old and old.fragment==fragment and old.tokens or edit.tokens(fragment)
        cache[lineNo]={fragment=fragment,tokens=tokens}
        for _,token in ipairs(tokens) do
          local col=self.leftCol+token.first-1
          local color=token.kind=='comment' and p.muted or token.kind=='keyword' and p.accent or token.kind=='string' and 4 or token.kind=='number' and 11 or p.text
          local start=1
          while start<=#token.text do
            local selected=a and col+start-1>=a and col+start-1<b
            local finish=start
            while finish<#token.text and (a and col+finish>=a and col+finish<b or false)==(selected or false) do finish=finish+1 end
            fonts.draw(view,gutter+(col+start-1-self.leftCol)*6,y+2,token.text:sub(start,finish),selected and p.ink or color,selected and p.accent or p.panel)
            start=finish+1
          end
        end
        if lineNo==self.cy and self.cx>=self.leftCol and self.cx<self.leftCol+self.visibleCols then view:rect(gutter+(self.cx-self.leftCol)*6,y+1,1,11,p.text) end
      end self.lineTokens=cache
      self.scrollbar=rect(w-9,area.y,6,area.h) ui.scrollbar(s,self.scrollbar,#self.lines,self.visibleRows,self.scroll,p)
      local footer=h-kbH
      ui.label(s,5,footer-27,self.completion and ('Tab: '..self.completion.label) or ('Line '..self.cy..', column '..self.cx),w-10,p.muted,p.panel)
      ui.label(s,5,footer-14,(self.isDirty and '* ' or '')..self.status..' | '..self.path,w-10,p.text,p.panel)
      if kbH>0 then Keyboard.draw(s,5,h-kbH,w-10,kbH-2,self.keyboard,p) end
    end
    if self.editMenu then
      self.pixelHits={} self.keyboard.pixelBoxes={} self.codeArea=nil self.scrollbar=nil
      for i,item in ipairs({{'copy','Copy selection'},{'cut','Cut selection'},{'paste','Paste copied text'},{'selectAll','Select all'}}) do
        button(item[1],item[2],rect(5,29+(i-1)*21,math.min(180,w-10),20))
      end
    end
    if self.closePrompt then
      self.pixelHits={} self.keyboard.pixelBoxes={} self.codeArea=nil self.scrollbar=nil
      local mw,mh=math.min(370,w-10),math.min(130,h-10)
      local mx,my=math.floor((w-mw)/2),math.floor((h-mh)/2)
      s:rect(mx,my,mw,mh,p.desktop) primitives.rect(s,mx,my,mw,mh,p.border)
      ui.paragraph(s,rect(mx+8,my+9,mw-16,mh-46),'Unsaved changes. Save, discard the draft, or cancel closing.',p.text,p.desktop,{wrap=true})
      local bw=math.floor((mw-24)/3)
      for i,item in ipairs({{'save','Save'},{'discard','Discard'},{'cancel','Cancel'}}) do button(item[1],item[2],rect(mx+6+(i-1)*(bw+6),my+mh-30,bw,24)) end
    end
  end
  function app:handlePixels(event)
    if not self.nativeReady then return false end
    local name,key=event.name,event.args[1] local x,y=event.args[2],event.args[3]
    if name=='key_up' then
      if key==keys.leftCtrl or key==keys.rightCtrl then self.controlHeld=false end
      if key==keys.leftShift or key==keys.rightShift then self.shiftHeld=false end return true
    end
    if self.closePrompt then
      if name=='key' and key==keys.escape then self:action('cancel')
      elseif name=='key' and (key==keys.tab or key==keys.left or key==keys.right) then
        local choices={'save','discard','cancel'} local index=0
        for i,id in ipairs(choices) do if self.closeFocus==id then index=i break end end
        self.closeFocus=choices[(index+(key==keys.left and -2 or 0))%3+1]
      elseif name=='key' and key==keys.enter and self.closeFocus then self:action(self.closeFocus)
      elseif name=='mouse_click' then for _,hit in ipairs(self.pixelHits) do if ui.hit(hit.rect,x,y) then self:action(hit.id) break end end end return true
    end
    if name=='char' or name=='paste' then
      if name=='char' and self.controlHeld then return true end
      self.keyboard.onText(event.args[1]) return true
    elseif name=='key' then
      if key==keys.leftCtrl or key==keys.rightCtrl then self.controlHeld=true return true end
      if key==keys.leftShift or key==keys.rightShift then self.shiftHeld=true return true end
      if self.controlHeld then
        local shortcuts={[keys.s]='save',[keys.f]='find',[keys.a]='selectAll',[keys.c]='copy',[keys.x]='cut'}
        if shortcuts[key] then self:action(shortcuts[key]) end return true
      end
      if key==keys.escape then self.searchOpen=false self.editMenu=false self.pixelKeyboard=false return true end
      if key==keys.enter then self.keyboard.onEnter() return true end
      if key==keys.backspace then self.keyboard.onBackspace() return true end
      if key==keys.tab then self.keyboard.onTab() return true end
      if self.searchOpen then return true end
      local row,col=self.cy,self.cx
      if key==keys.delete then
        if edit.range(self) then self:insert('')
        elseif col<=#self.lines[row] then edit.move(self,row,col+1,false) self.keyboard.onBackspace()
        elseif row<#self.lines then edit.move(self,row+1,1,false) self.keyboard.onBackspace() end return true
      end
      if key==keys.up then row=row-1 elseif key==keys.down then row=row+1
      elseif key==keys.left then if col==1 and row>1 then row=row-1 col=#self.lines[row]+1 else col=col-1 end
      elseif key==keys.right then if col>#self.lines[row] and row<#self.lines then row=row+1 col=1 else col=col+1 end
      elseif key==keys.home then col=1 elseif key==keys['end'] then col=#self.lines[row]+1
      elseif key==keys.pageUp then row=row-(self.visibleRows or 5) elseif key==keys.pageDown then row=row+(self.visibleRows or 5)
      else return false end
      edit.move(self,row,col,self.shiftHeld) return true
    elseif name=='mouse_up' then self.selecting=false self.scrollDragging=false return true
    elseif name=='mouse_scroll' and self.codeArea then self.revealCursor=false self.scroll=math.max(1,self.scroll+event.args[1]*3) return true
    elseif name=='mouse_click' then
      self.controlHeld=false
      for _,hit in ipairs(self.pixelHits) do if ui.hit(hit.rect,x,y) then
        if hit.id=='menu' then self.editMenu=not self.editMenu else self.editMenu=false self:action(hit.id) end return true
      end end
      if self.editMenu then self.editMenu=false return true end
      if self.pixelKeyboard and Keyboard.handle(event,self.keyboard) then return true end
      if ui.hit(self.scrollbar,x,y) then self.scrollDragging=true self.revealCursor=false self.scroll=ui.scrollbarValue(self.scrollbar,#self.lines,self.visibleRows,y) return true end
      if ui.hit(self.codeArea,x,y) then
        self.searchOpen=false self.selecting=true
        edit.move(self,self.scroll+math.floor((y-self.codeArea.y)/13),self.leftCol+math.floor((x-self.codeArea.x-self.gutter)/6),self.shiftHeld)
        self.anchor=self.anchor or {row=self.cy,col=self.cx} return true
      end
    elseif name=='mouse_drag' then
      if self.scrollDragging and self.scrollbar then self.revealCursor=false self.scroll=ui.scrollbarValue(self.scrollbar,#self.lines,self.visibleRows,y) return true end
      if self.selecting and self.codeArea then
        edit.move(self,self.scroll+math.floor((y-self.codeArea.y)/13),self.leftCol+math.floor((x-self.codeArea.x-self.gutter)/6),true) return true
      end
    end return false
  end
end
return M
