local ui=require("system.graphics.widgets")
local fonts=require("system.graphics.fonts")
local View=require("system.graphics.view")
local primitives=require("system.graphics.primitives")
local M={}
local function rect(x,y,w,h) return {x=x,y=y,w=w,h=h} end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function selected(app)
  if app.selected then for i,row in ipairs(app.rows) do if row.name==app.selected then return row,i end end end
end
function M.attach(app)
  function app:select(index)
    index=clamp(index,1,math.max(1,#self.rows))
    self.selected=self.rows[index] and self.rows[index].name or nil
    self.detailScroll=0 self.focus="list"
    if index<self.scroll then self.scroll=index elseif index>=self.scroll+(self.visible or 1) then self.scroll=index-(self.visible or 1)+1 end
  end
  function app:drawPixels(s,w,h,p)
    s:rect(0,0,w,h,p.panel) self.pixelHits={} self.rowHits={} self.scrollbar=nil self.detailArea=nil self.thumb=nil
    if w<200 or h<150 then
      self.confirm=nil self.scrollDragging=false self.grab=nil
      ui.label(s,5,6,"Services: enlarge window",w-10,p.text,p.panel) return
    end
    local row=selected(self)
    local busy=self.control.busy
    local function button(id,label,r,disabled,kind)
      local palette=disabled and {button=p.panel,text=p.muted} or p
      if kind then ui.symbol(s,r,kind,p,false) else ui.button(s,r,label,palette,false) end
      if self.focus==id then primitives.rect(s,r.x,r.y,r.w,r.h,p.accent) end
      self.pixelHits[#self.pixelHits+1]={id=id,rect=r,disabled=disabled}
    end
    button("start","Start",rect(5,4,46,23),busy or not row or row.transitioning or row.uncertain)
    button("stop","Stop",rect(55,4,44,23),busy or not row or row.protected or row.transitioning)
    button("restart","Restart",rect(103,4,62,23),busy or not row or row.protected or row.transitioning)
    button("refresh","",rect(w-28,4,23,23),false,"refresh")
    if w>=290 then button("details",self.inspect and "Back" or "Details",rect(170,4,64,23)) end
    local degraded=0 for _,service in ipairs(self.rows) do if service.error or service.state=="crashed" or service.state=="degraded" then degraded=degraded+1 end end
    ui.label(s,6,34,#self.rows.." services | "..degraded.." degraded"..(busy and " | transition "..tostring(self.control.phase) or ""),w-12,busy and 1 or p.muted,p.panel)
    local wide=w>=620
    local width=wide and w-250 or w-10
    local bottom=not wide and h>=300 and h-128 or h-24
    local area=rect(5,64,width,math.max(18,bottom-64))
    self.visible=math.max(1,math.floor(area.h/20))
    self.scroll=clamp(self.scroll,1,math.max(1,#self.rows-self.visible+1))
    s:rect(area.x,48,area.w,14,p.desktop)
    ui.label(s,area.x+4,51,"SERVICE",math.max(48,area.w-124),p.muted,p.desktop)
    ui.label(s,area.x+area.w-114,51,"STATE",65,p.muted,p.desktop)
    ui.label(s,area.x+area.w-42,51,"AUTO",32,p.muted,p.desktop)
    local stateColor={running=p.accent,stopped=p.muted,degraded=1,crashed=14}
    for i=self.scroll,math.min(#self.rows,self.scroll+self.visible-1) do
      local service=self.rows[i] local y=area.y+(i-self.scroll)*20
      local active=service.name==self.selected local bg=active and p.accent or p.panel local fg=active and p.ink or p.text
      s:rect(area.x,y,area.w-10,20,bg)
      ui.label(s,area.x+4,y+6,service.name..(service.protected and " [protected]" or ""),math.max(48,area.w-124),fg,bg)
      ui.label(s,area.x+area.w-114,y+6,service.transitioning and "pending" or service.state,65,active and p.ink or service.transitioning and 1 or stateColor[service.state] or p.muted,bg)
      ui.label(s,area.x+area.w-42,y+6,service.autostart and "yes" or "no",28,fg,bg)
      self.rowHits[#self.rowHits+1]={index=i,rect=rect(area.x,y,area.w-10,20)}
    end
    if #self.rows==0 then ui.label(s,area.x+4,area.y+8,"No registered services",area.w-14,p.muted,p.panel) end
    self.scrollbar=rect(area.x+area.w-8,area.y,8,area.h)
    self.thumb=ui.scrollbar(s,self.scrollbar,#self.rows,self.visible,self.scroll,p)
    if self.focus=="list" then primitives.rect(s,area.x,area.y,area.w,area.h,p.accent) end
    self.detailArea=self.inspect and rect(5,48,w-10,h-70) or wide and rect(w-238,48,233,h-70) or h>=300 and rect(5,h-122,w-10,98) or nil
    if self.detailArea then
      local r=self.detailArea
      if self.inspect then
        s:rect(r.x,r.y,r.w,r.h,p.panel) self.scrollbar=nil self.rowHits={}
        if w<290 then button("details","Back",rect(5,4,46,23)) end
      end
      local text=row and (row.name.."\nState: "..tostring(row.state).."\nAutostart: "..tostring(row.autostart).."\nPID: "..tostring(row.pid or "unavailable")..
        "\nProtected: "..tostring(row.protected==true).."\nUncertain: "..tostring(row.uncertain==true).."\nLast success: "..tostring(row.lastSuccess or "unavailable").."\n\nLast error:\n"..tostring(row.error or "none")) or "No service selected"
      if not self.detailLayout or self.detailText~=text or self.detailWidth~=r.w then
        self.detailLayout=fonts.layout(text,math.max(1,r.w-12),65536,{wrap=true,lineSpacing=2}) self.detailText=text self.detailWidth=r.w
      end
      ui.label(s,r.x+4,r.y+2,"DETAILS",r.w-8,p.muted,p.panel)
      local view=View.new(s,r.x+5,r.y+18,r.w-10,math.max(1,r.h-20))
      self.detailVisible=math.max(1,math.floor((r.h-20)/11)) self.detailMaximum=math.max(0,#self.detailLayout.lines-self.detailVisible)
      self.detailScroll=clamp(self.detailScroll or 0,0,self.detailMaximum)
      for i=self.detailScroll+1,math.min(#self.detailLayout.lines,self.detailScroll+self.detailVisible) do fonts.draw(view,0,(i-self.detailScroll-1)*11,self.detailLayout.lines[i].text,p.text,p.panel) end
      if self.focus=="details" then primitives.rect(s,r.x,r.y,r.w,r.h,p.accent) end
    end
    ui.label(s,6,h-15,busy and (tostring(self.control.action).." "..tostring(self.control.name)..": "..tostring(self.control.message or self.control.phase)) or self.message,w-12,busy and 1 or p.muted,p.panel)
    if self.confirm then
      self.pixelHits={} self.rowHits={} self.scrollbar=nil self.detailArea=nil
      local r=rect(8,math.max(32,math.floor(h/2)-43),w-16,86)
      s:rect(r.x,r.y,r.w,r.h,p.desktop)
      ui.paragraph(s,rect(r.x+7,r.y+7,r.w-14,34),self.confirm.action.." "..self.confirm.name.."?",p.text,p.desktop,{wrap=true})
      button("confirm","Confirm",rect(r.x+8,r.y+54,78,24)) button("cancel","Cancel",rect(r.x+94,r.y+54,70,24))
    end
  end
  function app:handlePixels(event)
    local x,y=event.args[2],event.args[3]
    local function action(id)
      if id=="cancel" then self.confirm=nil
      elseif id=="confirm" and self.confirm then
        local request=self.confirm self.confirm=nil
        if self.selected~=request.name then self.message="Selection changed; action cancelled" else self:request(request.action) end
      elseif id=="refresh" then self:refresh()
      elseif id=="details" then self.inspect=not self.inspect self.focus=self.inspect and "details" or "list"
      elseif id=="start" then self:request("start")
      elseif id=="stop" or id=="restart" then self.confirm={action=id,name=self.selected} end
    end
    if event.name=="key" then
      local key=event.args[1]
      if key==keys.escape then self.confirm=nil self.inspect=false self.focus="list" return true end
      if self.confirm then if key==keys.enter then action("confirm") end return true end
      if key==keys.tab then
        local order={"start","stop","restart","refresh","list","details"} local index=0
        for i,id in ipairs(order) do if id==self.focus then index=i end end
        self.focus=order[index%#order+1] return true
      elseif key==keys.enter then
        for _,hit in ipairs(self.pixelHits or {}) do if hit.id==self.focus then if not hit.disabled then action(hit.id) end return true end end
        self.inspect=not self.detailArea self.focus="details" return true
      elseif key==keys.up or key==keys.down or key==keys.home or key==keys["end"] or key==keys.pageUp or key==keys.pageDown then
        if self.focus=="details" then self.detailScroll=key==keys.home and 0 or key==keys["end"] and (self.detailMaximum or 0) or clamp((self.detailScroll or 0)+(key==keys.up and -1 or key==keys.pageUp and -(self.detailVisible or 1) or key==keys.pageDown and (self.detailVisible or 1) or 1),0,self.detailMaximum or 0)
        else
          local _,index=selected(self) index=index or (key==keys.up and self.scroll+(self.visible or 1) or self.scroll-1)
          local step=key==keys.up and -1 or key==keys.pageUp and -(self.visible or 1) or key==keys.pageDown and (self.visible or 1) or 1
          self:select(key==keys.home and 1 or key==keys["end"] and #self.rows or index+step)
        end return true
      end
      return false
    end
    if self.confirm and event.name~="mouse_click" then return true end
    if event.name=="mouse_scroll" then
      if ui.hit(self.detailArea,x,y) then self.detailScroll=clamp((self.detailScroll or 0)+event.args[1]*3,0,self.detailMaximum or 0)
      else self.scroll=math.max(1,self.scroll+event.args[1]*3) end return true
    end
    if event.name=="mouse_up" then self.scrollDragging=false self.grab=nil return true end
    if event.name=="mouse_drag" and self.scrollDragging and self.scrollbar then
      self.scroll=ui.scrollbarValue(self.scrollbar,#self.rows,self.visible,y+(self.thumb and self.thumb.h/2 or 0)-(self.grab or (self.thumb and self.thumb.h/2 or 0))) return true
    end
    if event.name~="mouse_click" then return false end
    if event.args[1]~=1 then return true end
    for i=#(self.pixelHits or {}),1,-1 do local hit=self.pixelHits[i] if ui.hit(hit.rect,x,y) then if not hit.disabled then action(hit.id) end return true end end
    if self.confirm then return true end
    if ui.hit(self.scrollbar,x,y) then
      self.grab=ui.hit(self.thumb,x,y) and y-self.thumb.y or nil
      if not self.grab then self.scroll=ui.scrollbarValue(self.scrollbar,#self.rows,self.visible,y) end
      self.scrollDragging=true return true
    end
    if ui.hit(self.detailArea,x,y) then self.focus="details" return true end
    for _,hit in ipairs(self.rowHits or {}) do if ui.hit(hit.rect,x,y) then
      self:select(hit.index) if not self.detailArea then self.inspect=true self.focus="details" end return true
    end end
    return true
  end
end
return M
