-- Native field/action panel. Reuses application setters and command handlers,
-- never terminal cells. Parsing is atomic before applying any pending edit.
local Client=require('system.graphics.client')
local View=require('system.graphics.view')
local ui=require('system.graphics.widgets')
local M={}
function M.new(api)
 local panel={graphicsActive=true,buffers={}}
 local raw,page
 local function report(message) if api.error then api.error(message) end end
 local function model()
  raw=api.model()
  local layout={tostring(raw.page)}
  for _,f in ipairs(raw.fields or {}) do layout[#layout+1]=tostring(f.label).."/"..tostring(f.kind).."/"..tostring(f.readOnly) end
  local identity=table.concat(layout,"|")
  if identity~=page then panel.buffers={} page=identity end
  local out={page=identity,actions={},fields={},rows={},footer=raw.footer}
  for _,row in ipairs(raw.rows or {}) do out.rows[#out.rows+1]=row end
  for _,a in ipairs(raw.actions or {}) do out.actions[#out.actions+1]=a end
  for i,f in ipairs(raw.fields or {}) do
   local value=f.get()
   if f.readOnly then out.rows[#out.rows+1]={title=f.label,description=tostring(value==nil and "unavailable" or value)}
   else out.fields[#out.fields+1]={id=i,label=f.label,value=panel.buffers[i]~=nil and panel.buffers[i] or tostring(value==nil and '' or value),secret=f.kind=='secret' or f.kind=='password',action=(f.kind=='boolean' or f.options and #f.options>0) and ('fieldCycle:'..i) or nil,checkbox=f.kind=='boolean',placeholder=f.placeholder} end
  end
  return out
 end
 local function commit()
  model()
  local changes={}
  for i,value in pairs(panel.buffers) do
   local f=raw.fields and raw.fields[i]
   if f and not f.readOnly then
    local parsed=value
    if f.kind=='number' then
     parsed=tonumber(value)
     if not parsed or parsed~=parsed or math.abs(parsed)==math.huge then report('Invalid number: '..f.label) return false end
    elseif f.kind=='boolean' then
     if value~='true' and value~='false' then report('Use true/false: '..f.label) return false end
     parsed=value=='true'
    end
    if f.options and #f.options>0 then
     local found=false for _,option in ipairs(f.options) do if tostring(option)==tostring(parsed) then parsed=option found=true break end end
     if not found then report('Choose an available value: '..f.label) return false end
    end
    changes[#changes+1]={field=f,value=parsed}
   end
  end
  for _,c in ipairs(changes) do c.field.set(c.value) end
  panel.buffers={} if api.committed then api.committed() end return true
 end
 local state=Client.attach(panel,{model=model,input=function(id,value) panel.buffers[id]=value end,
  submit=function() commit() end,
  action=function(id)
   if id=='panelConfirm' or id=='panelCancel' then panel.buffers={} api.action(id) return end
   if not commit() then return end
   local index=type(id)=='string' and tonumber(id:match('^fieldCycle:(%d+)$'))
   if index then
    local f=raw.fields[index]
    if f.kind=='boolean' then f.set(not f.get())
    else local at=0 for i,v in ipairs(f.options) do if v==f.get() then at=i break end end f.set(f.options[at%#f.options+1]) end
   else api.action(id) end
   panel.buffers={}
  end})
 local keyHandler=panel.handlePixelKey
 function panel:handlePixelKey(event)
  if event.name=='key' and keys.escape and event.args[1]==keys.escape then self.buffers={} end
  return keyHandler(self,event)
 end
 panel.state=state panel.commit=commit
 local draw,handle=panel.drawPixels,panel.handlePixels
 function panel:drawPixels(s,w,h,p)
  local header=api.urgent and 26 or 0 self.header=header
  if header>0 then
   s:rect(0,0,w,header,p.panel)
   self.urgent={x=3,y=2,w=math.min(108,w-6),h=21}
   ui.button(s,self.urgent,api.urgent.label,p,true)
  end
  local view=View.new(s,0,header,w,math.max(1,h-header))
  draw(self,view,w,math.max(1,h-header),p)
  if api.draw then api.draw(view,w,math.max(1,h-header),p) end
  if api.afterDraw then api.afterDraw(state,raw) end
 end
 function panel:handlePixels(event)
  if api.urgent and event.name=='mouse_click' and self.urgent and ui.hit(self.urgent,event.args[2],event.args[3]) then api.action(api.urgent.id) return true end
  local copy={} for k,v in pairs(event) do copy[k]=v end
  copy.args={} for k,v in pairs(event.args or {}) do copy.args[k]=v end
  if type(copy.args[3])=='number' then copy.args[3]=copy.args[3]-(self.header or 0) end
  if api.pointer and api.pointer(copy) then return true end
  return handle(self,copy)
 end
 return panel
end
return M
