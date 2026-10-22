-- Native controls shared by network clients. Models contain data, never terminal
-- cells. Actions stay in the application so permission checks are shared.
local ui=require("system.graphics.widgets")
local keyboard=require("system.graphics.keyboard")
local fonts=require("system.graphics.fonts")
local clipboard=require('system.graphics.clipboard')
local M={}
function M.attach(app,api)
  local state={first=1,field=nil,showKeyboard=false}
  app.nativeClientState=state
  local kb={}
  local function field()
    for _,f in ipairs((state.model or {}).fields or {}) do if f.id==state.field then return f end end
  end
  kb.onText=function(text) local f=field() if f then api.input(f.id,((state.selectAll and "" or tostring(f.value or ""))..text):sub(1,f.limit or 1024)) state.selectAll=false end end
  kb.onBackspace=function() local f=field() if f then api.input(f.id,state.selectAll and "" or tostring(f.value or ""):sub(1,-2)) state.selectAll=false end end
  kb.onEnter=function() if api.submit then api.submit(state.field) end end
  kb.onTab=function() state.showKeyboard=false end
  function app:drawPixels(s,w,h,p)
    s:rect(0,0,w,h,p.panel)
    local model=api.model(w,h) state.model=model state.hits={}
    state.rendered=false
    if state.page~=model.page then state.first=1 state.field=nil state.selectAll=false state.page=model.page state.lastVisible=0 end
    if w<140 or h<80 then ui.label(s,3,3,"Enlarge window",math.max(0,w-6),p.muted,p.panel) return end

    state.rendered=true
    local function hit(id,r,kind) state.hits[#state.hits+1]={id=id,rect=r,kind=kind} end
    local y=3 local x=4
    local actions=model.actions or {}
    local capacity=math.max(1,math.floor((w-56)/86))
    state.actionFirst=math.max(1,math.min(state.actionFirst or 1,math.max(1,#actions-capacity+1)))
    for i=state.actionFirst,math.min(#actions,state.actionFirst+capacity-1) do
      local a=actions[i]
      local bw=math.max(24,math.floor((w-56)/capacity)-4)
      local r={x=x,y=y,w=bw,h=21}
      ui.button(s,r,a.label,p,a.active) hit(a.id,r,"action") x=x+bw+4
    end
    if #actions>0 then
      for i,id in ipairs({"previous","next"}) do
        local r={x=w-52+(i-1)*25,y=y,w=23,h=21}
        ui.symbol(s,r,id,p) hit(id,r,"actionsPage")
      end
      y=y+25
    end
    local fields=model.fields or {}
    local fieldCapacity=math.max(1,math.floor((h-y-30)/40))
    state.fieldFirst=math.max(1,math.min(state.fieldFirst or 1,math.max(1,#fields-fieldCapacity+1)))
    if #fields>fieldCapacity then
      for i,id in ipairs({"previous","next"}) do
        local r={x=w-52+(i-1)*25,y=y,w=23,h=11}
        ui.symbol(s,r,id,p) hit(id,r,"fieldsPage")
      end
    end
    for i=state.fieldFirst,math.min(#fields,state.fieldFirst+fieldCapacity-1) do
      local f=fields[i]
      ui.label(s,4,y,f.label,w-36,p.muted,p.panel) y=y+12
      local r={x=4,y=y,w=w-34,h=23}
      local value=tostring(f.value or "")
      ui.input(s,r,f.secret and string.rep("*",#value) or value,p,state.field==f.id,f.placeholder)
      hit(f.id,r,"field")
      local toggle={x=w-27,y=y,w=23,h=23}
      ui.symbol(s,toggle,"keyboard",p,state.showKeyboard and state.field==f.id) hit(f.id,toggle,"keyboard") y=y+28
    end
    local kbH=state.showKeyboard and math.min(112,math.max(0,h-y-35)) or 0
    local bottom=h-19-kbH state.top=y state.bottom=bottom
    local rows=model.rows or {}
    state.first=math.max(1,math.min(state.first,math.max(1,#rows)))
    local cy=y
    state.lastVisible=state.first-1
    for i=state.first,#rows do
      if cy+22>bottom then break end
      local row=rows[i]
      local title=tostring(row.title or "")
      local description=tostring(row.description or "")
      local layout=fonts.layout(description,math.max(1,w-34),32768,{wrap=true,lineSpacing=2})
      local fullHeight=math.max(22,14+layout.height)
      if cy>y and cy+fullHeight>bottom then break end
      local rh=math.min(fullHeight,bottom-cy)
      local bg=row.selected and p.button or p.panel
      s:rect(3,cy,w-25,rh,bg)
      ui.label(s,7,cy+3,title,w-34,row.accent and p.accent or p.text,bg)
      local old=s:setClip(4,cy+14,w-30,math.max(0,rh-14))
      for _,line in ipairs(layout.lines) do if line.y<rh-14 then fonts.draw(s,7,cy+14+line.y,line.text,p.muted,bg) end end
      s:setClip(old.x,old.y,old.w,old.h)
      hit(row.id or i,{x=3,y=cy,w=w-25,h=rh},"row") cy=cy+rh+3
      if rh>=fullHeight then state.lastVisible=i end
    end
    if bottom-y>=40 then
      local up={x=w-21,y=y,w=18,h=19} local down={x=w-21,y=bottom-20,w=18,h=19}
      ui.symbol(s,up,"up",p) ui.symbol(s,down,"down",p) hit("up",up,"scroll") hit("down",down,"scroll")
    end
    ui.label(s,4,h-13,model.footer or "",w-8,p.muted,p.panel)
    if kbH>=56 then keyboard.draw(s,3,h-19-kbH,w-6,kbH,kb,p) end
  end
  function app:handlePixels(event)
    if event.name=="mouse_scroll" then state.first=math.max(1,state.first+event.args[1]) return true end
    if event.name~="mouse_click" then return false end
    if state.showKeyboard and keyboard.handle(event,kb) then return true end
    local _,x,y=table.unpack(event.args)
    for _,v in ipairs(state.hits or {}) do if ui.hit(v.rect,x,y) then
      if v.kind=="action" then state.first=1 api.action(v.id)
      elseif v.kind=="actionsPage" then state.actionFirst=math.max(1,(state.actionFirst or 1)+(v.id=="next" and 1 or -1))
      elseif v.kind=="fieldsPage" then state.fieldFirst=math.max(1,(state.fieldFirst or 1)+(v.id=="next" and 1 or -1)) state.field=nil
      elseif v.kind=="row" then if api.select then api.select(v.id,event.args[1]) end
      elseif v.kind=="field" then state.field=v.id state.selectAll=false
      elseif v.kind=="keyboard" then state.field=v.id state.showKeyboard=not state.showKeyboard
      else state.first=math.max(1,state.first+(v.id=="up" and -1 or 1)) end
      return true
    end end
    return true
  end
  function app:handlePixelKey(event)
    if not self.graphicsActive then return false end
    state.model=api.model()
    local function transfer(key)
      local f=field()
      if not f then return true end
      if key=='a' then state.selectAll=true
      elseif key=='c' and not f.secret then clipboard.set(tostring(f.value or ''))
      elseif key=='v' then kb.onText(clipboard.get()) end
      return true
    end
    if event.name=='key_up' and (event.args[1]==keys.leftCtrl or event.args[1]==keys.rightCtrl) then state.control=false return true end
    if event.name=="char" or event.name=="paste" then
      if event.name=='char' and state.control then return transfer(tostring(event.args[1]):lower()) end
      if field() then kb.onText(tostring(event.args[1])) return true end
    elseif event.name=="key" then
      local key=event.args[1]
      if key==keys.leftCtrl or key==keys.rightCtrl then state.control=true return true end
      if state.control and (key==keys.c or key==keys.v or key==keys.a) then return transfer(key==keys.c and 'c' or key==keys.a and 'a' or 'v') end
      if key==keys.escape then state.field=nil state.showKeyboard=false return true end
      if field() then
        if key==keys.enter then kb.onEnter() elseif key==keys.backspace then kb.onBackspace() end
        return true
      end
      if key==keys.up or key==keys.down then state.first=math.max(1,state.first+(key==keys.up and -1 or 1)) return true end
    end
    return false
  end
  return state
end
return M
