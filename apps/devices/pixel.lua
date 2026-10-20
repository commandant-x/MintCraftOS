local ui=require('system.graphics.widgets')
local fonts=require('system.graphics.fonts')
local View=require('system.graphics.view')
local primitives=require('system.graphics.primitives')
local M={}
local categories={'all','display','network','radar','cbc','control','avionics','redstone','storage','other'}
local function rect(x,y,w,h) return {x=x,y=y,w=w,h=h} end
local function clamp(value,a,b) return math.max(a,math.min(b,value)) end
function M.attach(app)
  function app:drawPixels(s,w,h,p)
    s:rect(0,0,w,h,p.panel) self.pixelHits={} self.rowHits={} self.scrollbar=nil self.detailArea=nil self.searchArea=nil
    if w<200 or h<170 then self.inspect=false self.categoryMenu=false self.dragging=false ui.label(s,5,6,'Devices: enlarge window',w-10,p.text,p.panel) return end
    local function button(id,label,r,disabled,kind)
      if kind then ui.symbol(s,r,kind,p) else ui.button(s,r,label,disabled and {button=p.panel,text=p.muted} or p) end
      if self.focus==id then primitives.rect(s,r.x,r.y,r.w,r.h,p.accent) end
      self.pixelHits[#self.pixelHits+1]={id=id,rect=r,disabled=disabled}
    end
    button('rescan','',rect(5,4,24,23),self.busy,'refresh')
    button('display','Display',rect(34,4,62,23))
    button('probe','Probe',rect(101,4,54,23),not self:selectedRow() or self.probePending~=nil)
    button('details',w>=280 and (self.inspect and 'Back' or 'Details') or '',rect(w>=280 and 160 or w-29,4,w>=280 and 66 or 24,23),false,w<280 and 'more' or nil)
    self.searchArea=rect(5,34,w-10,23)
    ui.input(s,self.searchArea,self.query,p,self.focus=='search','Search name / type / role')
    button('category',self.category,rect(5,62,90,22))
    local rows=self:filteredRows()
    ui.label(s,101,69,#rows..' / '..#self.rows..(self.busy and ' reading' or '')..(w>=450 and (' | '..tostring(self.header.summary or 'pending')) or ''),w-107,p.muted,p.panel)
    local wide=w>=640
    local listWidth=wide and math.floor(w*0.48) or w-10
    local area=rect(5,105,listWidth,math.max(20,h-129))
    self.visible=math.max(1,math.floor(area.h/22)) self.scroll=clamp(self.scroll,1,math.max(1,#rows-self.visible+1))
    s:rect(area.x,89,area.w,14,p.desktop)
    ui.label(s,area.x+4,92,'DEVICE',area.w-82,p.muted,p.desktop)
    ui.label(s,area.x+area.w-78,92,'ROLE',65,p.muted,p.desktop)
    for i=self.scroll,math.min(#rows,self.scroll+self.visible-1) do
      local row=rows[i] local y=area.y+(i-self.scroll)*22 local active=row.name==self.selected
      local bg=active and p.accent or p.panel local fg=active and p.ink or p.text
      s:rect(area.x,y,area.w-10,22,bg)
      ui.label(s,area.x+4,y+6,row.name,area.w-88,fg,bg)
      ui.label(s,area.x+area.w-78,y+6,row.role,65,fg,bg)
      self.rowHits[#self.rowHits+1]={index=i,rect=rect(area.x,y,area.w-10,22)}
    end
    if #rows==0 then ui.label(s,area.x+4,area.y+6,'No matching devices',area.w-14,p.muted,p.panel) end
    self.scrollbar=rect(area.x+area.w-8,area.y,8,area.h)
    self.thumb=ui.scrollbar(s,self.scrollbar,#rows,self.visible,self.scroll,p)
    self.detailArea=self.inspect and rect(5,89,w-10,h-113) or wide and rect(area.x+area.w+8,89,w-area.w-18,h-113) or nil
    if self.detailArea then
      local r=self.detailArea
      if self.inspect then self.rowHits={} self.scrollbar=nil s:rect(r.x,r.y,r.w,r.h,p.panel) end
      local text=self:detailText()
      if not self.detailLayout or self.detailLayout.text~=text or self.detailLayout.width~=r.w then
        self.detailLayout={text=text,width=r.w,lines=fonts.layout(text,r.w-12,65536,{wrap=true,lineSpacing=2}).lines}
      end
      ui.label(s,r.x+5,r.y+3,'DEVICE INSPECTOR',r.w-10,p.accent,p.panel)
      local canvas=View.new(s,r.x+5,r.y+19,r.w-10,r.h-22)
      self.detailVisible=math.max(1,math.floor((r.h-22)/11))
      self.detailMaximum=math.max(0,#self.detailLayout.lines-self.detailVisible)
      self.detailScroll=clamp(self.detailScroll or 0,0,self.detailMaximum)
      for i=self.detailScroll+1,math.min(#self.detailLayout.lines,self.detailScroll+self.detailVisible) do
        fonts.draw(canvas,0,(i-self.detailScroll-1)*11,self.detailLayout.lines[i].text,p.text,p.panel)
      end
    end
    ui.label(s,6,h-16,self.message or '',w-12,p.muted,p.panel)
    if self.categoryMenu then
      self.pixelHits={} self.rowHits={} self.scrollbar=nil self.detailArea=nil self.searchArea=nil
      local capacity=math.max(1,math.floor((h-92)/22))
      self.categoryFirst=clamp(self.categoryFirst or 1,1,math.max(1,#categories-capacity+1))
      s:rect(4,86,math.min(180,w-8),math.min(capacity,#categories)*22+2,p.desktop)
      for i=self.categoryFirst,math.min(#categories,self.categoryFirst+capacity-1) do
        button('role:'..categories[i],categories[i],rect(6,88+(i-self.categoryFirst)*22,math.min(176,w-12),21))
      end
    end
  end
  function app:handlePixels(event)
    local name,x,y=event.name,event.args[2],event.args[3]
    if name=='key' then
      local key=event.args[1]
      if key==keys.escape then
        if self.categoryMenu then self.categoryMenu=false elseif self.inspect then self.inspect=false else self.focus='list' end return true
      end
      if self.categoryMenu then
        if key==keys.down then self.categoryFirst=(self.categoryFirst or 1)+1
        elseif key==keys.up then self.categoryFirst=math.max(1,(self.categoryFirst or 1)-1)
        elseif key==keys.enter then self.category=categories[self.categoryFirst or 1] self.categoryMenu=false self:filterChanged() end return true
      end
      if key==keys.tab then
        local focus={'rescan','display','probe','details','search','category','list'} local index=0
        for i,id in ipairs(focus) do if id==self.focus then index=i break end end self.focus=focus[index%#focus+1] return true
      end
      if self.focus=='search' and key==keys.backspace then
        local last=#self.query
        while last>1 and self.query:byte(last)>=128 and self.query:byte(last)<=191 do last=last-1 end
        self.query=self.query:sub(1,last-1) self:filterChanged() return true
      end
      if self.focus=='search' and key==keys.enter then self.focus='list' if #self:filteredRows()>0 then self:select(1) end return true end
      if self.focus=='details' or self.inspect then
        if key==keys.down then self.detailScroll=(self.detailScroll or 0)+1 return true end
        if key==keys.up then self.detailScroll=math.max(0,(self.detailScroll or 0)-1) return true end
      end
      if self.focus=='list' then
        local rows=self:filteredRows() local index=0 for i,row in ipairs(rows) do if row.name==self.selected then index=i break end end
        if key==keys.down then self:select(index+1) return true elseif key==keys.up then self:select(index-1) return true
        elseif key==keys.home then self:select(1) return true elseif key==keys['end'] then self:select(#rows) return true
        elseif key==keys.enter and self.selected then self.inspect=true self.focus='details' return true end
      end
      if key==keys.enter then
        if self.focus=='category' then self.categoryMenu=true self.categoryFirst=1 return true end
        for _,hit in ipairs(self.pixelHits or {}) do if hit.id==self.focus and not hit.disabled then self:activate(hit.id) return true end end
      end
    elseif (name=='char' or name=='paste') and self.focus=='search' and not self.categoryMenu then
      self.query=(self.query..tostring(event.args[1]):sub(1,96):gsub('[%c]',' ')):sub(1,96) self:filterChanged() return true
    elseif name=='mouse_scroll' then
      if self.categoryMenu then self.categoryFirst=math.max(1,(self.categoryFirst or 1)+event.args[1])
      elseif ui.hit(self.detailArea,x,y) then self.detailScroll=clamp((self.detailScroll or 0)+event.args[1]*3,0,self.detailMaximum or 0)
      else self.scroll=math.max(1,self.scroll+event.args[1]*3) end return true
    elseif name=='mouse_up' then self.dragging=false self.grab=nil return true
    elseif name=='mouse_drag' and self.dragging and self.scrollbar then
      self.scroll=ui.scrollbarValue(self.scrollbar,#self:filteredRows(),self.visible,y+(self.thumb and self.thumb.h/2 or 0)-(self.grab or 0)) return true
    elseif name=='mouse_click' then
      for i=#(self.pixelHits or {}),1,-1 do local hit=self.pixelHits[i] if ui.hit(hit.rect,x,y) then
        if hit.id:sub(1,5)=='role:' then self.category=hit.id:sub(6) self.categoryMenu=false self:filterChanged()
        elseif hit.id=='category' then self.categoryMenu=not self.categoryMenu self.categoryFirst=1
        elseif not hit.disabled then self.focus=hit.id self:activate(hit.id) end return true
      end end
      if self.categoryMenu then self.categoryMenu=false return true end
      if ui.hit(self.searchArea,x,y) then self.focus='search' return true end
      if ui.hit(self.detailArea,x,y) then self.focus='details' return true end
      if ui.hit(self.scrollbar,x,y) then
        self.grab=ui.hit(self.thumb,x,y) and y-self.thumb.y or self.thumb.h/2
        if not ui.hit(self.thumb,x,y) then self.scroll=ui.scrollbarValue(self.scrollbar,#self:filteredRows(),self.visible,y) end
        self.dragging=true return true
      end
      for _,hit in ipairs(self.rowHits or {}) do if ui.hit(hit.rect,x,y) then
        self:select(hit.index) if not self.detailArea then self.inspect=true self.focus='details' end return true
      end end
      return true
    end
    return false
  end
end
return M
