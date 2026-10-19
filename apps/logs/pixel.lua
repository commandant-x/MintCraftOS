local ui=require("system.graphics.widgets")
local fonts=require("system.graphics.fonts")
local View=require("system.graphics.view")
local primitives=require("system.graphics.primitives")
local M={}
local levels={"all","error","warn","info","debug"}
local function rect(x,y,w,h) return {x=x,y=y,w=w,h=h} end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function clean(text) return tostring(text or ""):gsub("[%c]"," ") end
local function selected(app)
  if app.selected then for i,row in ipairs(app.rows) do if row.id==app.selected then return row,i end end end
end
function M.attach(app)
  function app:select(index)
    local row=self.rows[clamp(index,1,math.max(1,#self.rows))]
    self.selected=row and row.id or nil self.detailScroll=0 self.follow=false self.focus="list"
    if index<self.first then self.first=math.max(1,index)
    elseif index>=self.first+(self.visible or 1) then self.first=index-(self.visible or 1)+1 end
  end
  function app:drawPixels(s,w,h,p)
    s:rect(0,0,w,h,p.panel) self.pixelHits={} self.rowHits={}
    self.scrollbar=nil self.scrollThumb=nil self.detailArea=nil self.listArea=nil
    if w<170 or h<130 then ui.label(s,5,6,"Logs: enlarge window",w-10,p.text,p.panel) return end
    local function button(id,label,r,kind,active)
      if kind then ui.symbol(s,r,kind,p,active) else ui.button(s,r,label,p,active) end
      if self.focus==id then primitives.rect(s,r.x,r.y,r.w,r.h,p.accent) end
      self.pixelHits[#self.pixelHits+1]={id=id,rect=r}
    end
    button("filter",self.filter:upper(),rect(5,4,80,23),nil,self.filterOpen)
    button("refresh","",rect(90,4,23,23),"refresh")
    button("follow","Live",rect(118,4,46,23),nil,self.follow)
    if w>=250 then button("details",self.inspect and "Back" or "Details",rect(170,4,70,23),nil,self.inspect) end
    ui.label(s,6,34,self.readError and ("Read failed: "..self.readError) or (#self.rows.." / "..#self.records.." cached records"),w-12,self.readError and 14 or p.muted,p.panel)
    local wide=w>=620
    local listWidth=wide and w-246 or w-10
    local listBottom=wide and h-20 or h>=240 and h-108 or h-20
    self.listArea=rect(5,63,listWidth,math.max(18,listBottom-63))
    local area=self.listArea
    self.visible=math.max(1,math.floor(area.h/18))
    local maximum=math.max(1,#self.rows-self.visible+1)
    self.first=self.follow and maximum or clamp(self.first,1,maximum)
    s:rect(area.x,48,area.w,13,p.desktop)
    ui.label(s,area.x+4,50,"LEVEL",45,p.muted,p.desktop)
    local messageX=area.x+51
    if area.w>=400 then
      ui.label(s,area.x+51,50,"TIME",110,p.muted,p.desktop)
      ui.label(s,area.x+166,50,"SOURCE",90,p.muted,p.desktop)
      messageX=area.x+260
    end
    ui.label(s,messageX,50,"MESSAGE",math.max(0,area.x+area.w-messageX-12),p.muted,p.desktop)
    local severity={error=14,warn=1,info=p.accent,debug=p.muted}
    for i=self.first,math.min(#self.rows,self.first+self.visible-1) do
      local row=self.rows[i] local y=area.y+(i-self.first)*18
      local active=row.id==self.selected local bg=active and p.accent or p.panel local fg=active and p.ink or p.text
      s:rect(area.x,y,area.w-10,18,bg)
      ui.label(s,area.x+4,y+5,row.level:upper(),45,active and p.ink or severity[row.level] or p.muted,bg)
      if area.w>=400 then
        ui.label(s,area.x+51,y+5,clean(row.time),110,fg,bg)
        ui.label(s,area.x+166,y+5,clean(row.source),90,fg,bg)
      end
      ui.label(s,messageX,y+5,clean(row.message),math.max(0,area.x+area.w-messageX-14),fg,bg)
      self.rowHits[#self.rowHits+1]={index=i,rect=rect(area.x,y,area.w-10,18)}
    end
    if #self.rows==0 then ui.label(s,area.x+4,area.y+8,"No matching records",area.w-18,p.muted,p.panel) end
    self.scrollbar=rect(area.x+area.w-8,area.y,8,area.h)
    self.scrollThumb=ui.scrollbar(s,self.scrollbar,#self.rows,self.visible,self.first,p)
    if self.focus=="list" then primitives.rect(s,area.x,area.y,area.w,area.h,p.accent) end
    self.detailArea=self.inspect and rect(5,48,w-10,h-68) or wide and rect(w-234,48,229,h-70) or h>=240 and rect(5,h-102,w-10,82) or nil
    local row=selected(self)
    if self.detailArea then
      local r=self.detailArea
      if self.inspect then
        s:rect(r.x,r.y,r.w,r.h,p.panel) self.scrollbar=nil self.rowHits={}
        if w<250 then button("details","Back",rect(5,4,80,23)) end
      end
      ui.label(s,r.x+4,r.y+2,"DETAILS",r.w-8,p.muted,p.panel)
      if self.focus=="details" then primitives.rect(s,r.x,r.y,r.w,r.h,p.accent) end
      local key=row and row.id or self.readError or "none"
      if not self.detailLayout or self.detailKey~=key or self.detailWidth~=r.w then
        local text=row and (row.time.."\n"..row.level:upper().." | "..row.source.."\n\n"..row.message) or self.readError or "No record selected"
        self.detailLayout=fonts.layout(text,math.max(1,r.w-14),65536,{wrap=true,lineSpacing=2})
        self.detailKey,self.detailWidth=key,r.w
      end
      local layout=self.detailLayout
      self.detailVisible=math.max(1,math.floor((r.h-19)/11))
      self.detailMaximum=math.max(0,#layout.lines-self.detailVisible)
      self.detailScroll=clamp(self.detailScroll or 0,0,self.detailMaximum)
      local detail=View.new(s,r.x+5,r.y+17,r.w-12,math.max(1,r.h-18))
      for i=self.detailScroll+1,math.min(#layout.lines,self.detailScroll+self.detailVisible) do
        fonts.draw(detail,0,(i-self.detailScroll-1)*11,layout.lines[i].text,p.text,p.panel)
      end
    end
    ui.label(s,6,h-14,self.follow and "Live tail" or "History",w-12,p.muted,p.panel)
    if self.filterOpen then
      self.filterCapacity=math.max(1,math.floor((h-32)/23))
      self.filterFirst=clamp(self.filterFirst or 1,1,math.max(1,#levels-self.filterCapacity+1))
      for i=self.filterFirst,math.min(#levels,self.filterFirst+self.filterCapacity-1) do
        local r=rect(5,29+(i-self.filterFirst)*23,100,22)
        button("level:"..levels[i],levels[i]:upper(),r,nil,levels[i]==self.filter)
        if i==(self.filterCursor or 1) then primitives.rect(s,r.x,r.y,r.w,r.h,p.accent) end
      end
    end
  end
  function app:handlePixels(event)
    local name=event.name local x,y=event.args[2],event.args[3]
    local function action(id)
      if id=="filter" then self.filterOpen=not self.filterOpen self.filterFirst=1 self.filterCursor=1
      elseif id=="refresh" then self:requestRefresh()
      elseif id=="follow" then self.follow=not self.follow
      elseif id=="details" then self.inspect=not self.inspect self.focus=self.inspect and "details" or "list" self.filterOpen=false
      elseif id:sub(1,6)=="level:" then self:setFilter(id:sub(7)) self.filterOpen=false self.focus="list" end
    end
    if name=="key" then
      local key=event.args[1]
      if key==keys.escape then self.filterOpen=false self.inspect=false self.focus="list" return true end
      if self.filterOpen then
        if key==keys.up or key==keys.down then
          self.filterCursor=clamp((self.filterCursor or 1)+(key==keys.up and -1 or 1),1,#levels)
          if self.filterCursor<(self.filterFirst or 1) then self.filterFirst=self.filterCursor
          elseif self.filterCursor>=(self.filterFirst or 1)+(self.filterCapacity or 1) then self.filterFirst=self.filterCursor-(self.filterCapacity or 1)+1 end
        elseif key==keys.enter then action("level:"..levels[self.filterCursor or 1]) end
        return true
      end
      if key==keys.tab then
        local order={"filter","refresh","follow","list","details"} local index=0
        for i,id in ipairs(order) do if id==self.focus then index=i end end
        self.focus=order[index%#order+1] return true
      end
      if key==keys.enter then
        if self.focus=="filter" or self.focus=="refresh" or self.focus=="follow" then action(self.focus)
        else if not self.detailArea then self.inspect=true end self.focus="details" end
        return true
      end
      if key==keys.up or key==keys.down or key==keys.pageUp or key==keys.pageDown or key==keys.home or key==keys["end"] then
        if self.focus=="details" then
          self.detailScroll=key==keys.home and 0 or key==keys["end"] and (self.detailMaximum or 0) or clamp((self.detailScroll or 0)+(key==keys.up and -1 or key==keys.pageUp and -(self.detailVisible or 1) or key==keys.pageDown and (self.detailVisible or 1) or 1),0,self.detailMaximum or 0)
        else
          local _,index=selected(self)
          index=index or (key==keys.up and self.first+(self.visible or 1) or self.first-1)
          local step=key==keys.pageUp and -(self.visible or 1) or key==keys.pageDown and (self.visible or 1) or key==keys.up and -1 or 1
          self:select(key==keys.home and 1 or key==keys["end"] and #self.rows or clamp(index+step,1,math.max(1,#self.rows)))
          if key==keys["end"] then self.follow=true end
        end
        return true
      end
      return false
    end
    if name=="mouse_scroll" then
      if self.filterOpen then self.filterFirst=math.max(1,(self.filterFirst or 1)+event.args[1])
      elseif ui.hit(self.detailArea,x,y) then self.detailScroll=clamp((self.detailScroll or 0)+event.args[1]*3,0,self.detailMaximum or 0)
      else self.follow=false self.first=math.max(1,self.first+event.args[1]*3) end
      return true
    end
    if name=="mouse_up" then self.scrollDragging=false self.scrollGrab=nil return true end
    if name=="mouse_drag" and self.scrollDragging and self.scrollbar then
      local centre=y+(self.scrollThumb and self.scrollThumb.h/2 or 0)-(self.scrollGrab or (self.scrollThumb and self.scrollThumb.h/2 or 0))
      self.first=ui.scrollbarValue(self.scrollbar,#self.rows,self.visible,centre) self.follow=false return true
    end
    if name~="mouse_click" then return false end
    for i=#(self.pixelHits or {}),1,-1 do local hit=self.pixelHits[i] if ui.hit(hit.rect,x,y) then
      if self.filterOpen and hit.id~="filter" and hit.id:sub(1,6)~="level:" then self.filterOpen=false
      else action(hit.id) end return true
    end end
    if self.filterOpen then self.filterOpen=false return true end
    if ui.hit(self.scrollbar,x,y) then
      self.scrollGrab=ui.hit(self.scrollThumb,x,y) and y-self.scrollThumb.y or nil
      if not self.scrollGrab then self.first=ui.scrollbarValue(self.scrollbar,#self.rows,self.visible,y) end
      self.scrollDragging=true self.follow=false return true
    end
    if ui.hit(self.detailArea,x,y) then self.focus="details" return true end
    for _,hit in ipairs(self.rowHits or {}) do if ui.hit(hit.rect,x,y) then
      self:select(hit.index)
      if not self.detailArea then self.inspect=true self.focus="details" end
      return true
    end end
    return true
  end
end
return M
