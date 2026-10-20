local ui=require("system.graphics.widgets")
local fonts=require("system.graphics.fonts")
local primitives=require("system.graphics.primitives")
local M={}
local function rect(x,y,w,h) return {x=x,y=y,w=w,h=h} end
function M.attach(app)
  function app:drawPixels(s,w,h,p)
    s:rect(0,0,w,h,p.panel) self.pixelHits={} self.detailArea=nil
    if w<200 or h<170 then self.confirm=nil ui.label(s,5,6,"Enlarge Update",w-10,p.text,p.panel) return end
    local function button(id,label,r,disabled)
      ui.button(s,r,label,p,false)
      if disabled then ui.label(s,r.x+4,r.y+7,label,r.w-8,p.muted,p.button,"center") end
      if self.focus==id then primitives.rect(s,r.x,r.y,r.w,r.h,p.accent) end
      self.pixelHits[#self.pixelHits+1]={id=id,rect=r,disabled=disabled}
    end
    local control,status,meta=self.control or {},self.status or {},self.metadata or {}
    local cfg=meta.cfg or {} local backup=meta.backup
    button("check","Check",rect(6,5,60,24),control.busy)
    button("apply","Apply",rect(72,5,60,24),control.busy or not status.ok or not status.updateAvailable or not status.source)
    button("rollback","Rollback",rect(138,5,math.min(82,w-144),24),control.busy or not backup)
    local scale=w>=450 and 2 or 1
    fonts.draw(s,8,40,tostring(meta.localVersion or status.localVersion or "unknown"),p.text,p.panel,scale)
    ui.label(s,8,40+9*scale+6,"Installed | release "..tostring(status.remoteVersion or "unchecked"),w-16,p.muted,p.panel)
    local y=40+9*scale+24
    ui.label(s,8,y,tostring(cfg.repo or "Source unavailable").." @ "..tostring(cfg.branch or "?"),w-16,p.text,p.panel)
    local source=status.source
    ui.label(s,8,y+14,source and ("Commit "..source.sha) or "No verified release commit",w-16,p.muted,p.panel)
    ui.label(s,8,y+28,"Rollback: "..tostring(backup and (tostring(backup.fromVersion).." #"..backup.id) or "none"),w-16,p.muted,p.panel)
    local state=tostring(control.phase or "idle")
    if control.busy then state=state..(control.committed and " | transaction engaged" or " | preparing") end
    if type(control.done)=="number" and type(control.total)=="number" then state=state.." | "..control.done.."/"..control.total end
    local top=y+47
    ui.label(s,8,top,state,w-16,p.accent,p.panel)
    local area=rect(8,top+17,w-28,math.max(9,h-top-23)) self.detailArea=area
    local detail=tostring(control.message or "").."\n"..tostring(self.message or "").."\n"..tostring(status.message or "")
    detail=detail:sub(1,8192)
    if not self.detailLayout or self.detailLayout.text~=detail or self.detailLayout.width~=area.w then
      self.detailLayout={text=detail,width=area.w,lines=fonts.layout(detail,area.w,65536,{wrap=true,lineSpacing=2}).lines}
    end
    local lines=self.detailLayout.lines
    local visible=math.max(1,math.floor(area.h/11))
    self.detailScroll=math.max(1,math.min(self.detailScroll or 1,math.max(1,#lines-visible+1)))
    for i=self.detailScroll,math.min(#lines,self.detailScroll+visible-1) do
      ui.label(s,area.x,area.y+(i-self.detailScroll)*11,lines[i].text,area.w,p.text,p.panel)
    end
    if #lines>visible then ui.scrollbar(s,rect(w-15,area.y,7,area.h),#lines,visible,self.detailScroll,p) end
    if self.confirm then
      self.pixelHits={} self.detailArea=nil
      local c=self.confirm local r=rect(5,32,w-10,h-37)
      s:rect(r.x,r.y,r.w,r.h,p.desktop)
      ui.label(s,r.x+7,r.y+8,"Confirm "..c.action,r.w-14,p.accent,p.desktop)
      local text=tostring(c.localVersion).." -> "..tostring(c.version).."\n"..(c.source and (c.source.repo.."\n"..c.source.sha) or ("Checkpoint "..tostring(c.backupId)))
      ui.paragraph(s,rect(r.x+7,r.y+26,r.w-14,r.h-68),text,p.text,p.desktop,{wrap=true})
      button("confirm","Confirm",rect(r.x+7,r.y+r.h-32,78,24))
      button("cancel","Cancel",rect(r.x+91,r.y+r.h-32,72,24))
    end
  end
  function app:handlePixels(event)
    if event.name=="key" then
      local key=event.args[1]
      if key==keys.escape then self.confirm=nil return true end
      if key==keys.tab then
        local hits=self.pixelHits or {} local index=0
        for i,hit in ipairs(hits) do if hit.id==self.focus then index=i break end end
        for i=1,#hits do local hit=hits[(index+i-1)%#hits+1] if not hit.disabled then self.focus=hit.id break end end
        return true
      end
      if key==keys.enter then for _,hit in ipairs(self.pixelHits or {}) do if hit.id==self.focus and not hit.disabled then self:activate(hit.id) return true end end end
      if key==keys.down then self.detailScroll=(self.detailScroll or 1)+1 return true end
      if key==keys.up then self.detailScroll=math.max(1,(self.detailScroll or 1)-1) return true end
    elseif event.name=="mouse_scroll" then
      if not self.confirm then self.detailScroll=math.max(1,(self.detailScroll or 1)+event.args[1]*3) end return true
    elseif event.name=="mouse_click" then
      for _,hit in ipairs(self.pixelHits or {}) do if ui.hit(hit.rect,event.args[2],event.args[3]) then
        if not hit.disabled then self:activate(hit.id) end return true
      end end
    end
    return false
  end
end
return M
