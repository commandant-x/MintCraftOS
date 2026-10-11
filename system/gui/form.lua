local ui=require("system.gui.components")
local renderer=require("system.gui.renderer")
local keyboard=require("system.gui.keyboard")
local M={}
function M.new()
  local form={scroll=1,fields={},keyboard={},text=""}
  local function apply()
    if not form.edit then return end
    local value=form.text
    if form.edit.kind=="number" then
      value=tonumber(value)
      if not value or value~=value or math.abs(value)==math.huge then form.error="Invalid number" return end
    end
    form.edit.set(value) form.edit=nil form.error=nil
  end
  form.keyboard.onText=function(text) form.text=form.text..text end
  form.keyboard.onBackspace=function() form.text=form.text:sub(1,-2) end
  form.keyboard.onEnter=apply
  function form:draw(w,h,fields)
    self.fields=fields self.boxes={}
    self.scroll=math.max(1,math.min(self.scroll,math.max(1,#fields-math.max(1,h-6)+1)))
    if self.edit then
      ui.input(1,4,w,self.error or self.edit.label,self.text,true)
      self.actions=ui.toolbar(1,3,w,{{id="apply",label="Apply"},{id="cancel",label="Cancel"}})
      if h>=12 then keyboard.draw(1,h-7,w,self.keyboard) end
      if h<12 then renderer.writeAt(1,5,renderer.crop("Enlarge for touch keyboard",w),colors.orange) end
      return
    end
    self.actions=ui.toolbar(1,h-2,w,{{id="prev",label="Up"},{id="next",label="Down"}})
    for i=self.scroll,math.min(#fields,self.scroll+math.max(1,h-6)-1) do
      local field=fields[i]
      local y=4+i-self.scroll
      local value=field.get()
      if field.kind=="boolean" then value=value and "[x]" or "[ ]" end
      ui.input(1,y,w,field.label,value,false)
      self.boxes[#self.boxes+1]={x=1,y=y,w=w,h=1,field=field}
    end
  end
  function form:handle(event)
    if self.edit then
      if keyboard.handle(event,self.keyboard) then return true end
      if event.name=="char" then self.keyboard.onText(event.args[1]) return true end
      if event.name=="paste" then self.keyboard.onText(event.args[1]) return true end
      if event.name=="key" then
        if event.args[1]==keys.enter then apply() return true end
        if event.args[1]==keys.backspace then self.keyboard.onBackspace() return true end
        if event.args[1]==keys.escape then self.edit=nil return true end
      end
    end
    if event.name=="mouse_scroll" then self.scroll=self.scroll+event.args[1] return true end
    if event.name~="mouse_click" then return false end
    local _,x,y=table.unpack(event.args)
    local action=ui.toolbarHit(self.actions,x,y)
    if action=="apply" then apply() return true elseif action=="cancel" then self.edit=nil return true
    elseif action=="prev" then self.scroll=self.scroll-1 return true elseif action=="next" then self.scroll=self.scroll+1 return true end
    if self.edit then return true end
    for _,box in ipairs(self.boxes) do
      if ui.hit(box,x,y) then
        local field=box.field
        if field.readOnly then return true
        elseif field.options and #field.options>0 then
          local at=0
          for i,value in ipairs(field.options) do if value==field.get() then at=i break end end
          field.set(field.options[at%#field.options+1])
        elseif field.kind=="boolean" then field.set(not field.get())
        else self.edit=field self.text=tostring(field.get() or "") end
        return true
      end
    end
    return false
  end
  return form
end
function M.field(object,key,label,kind,options)
  return {label=label,kind=kind,options=options,get=function() return object[key] end,set=function(value) object[key]=value end}
end
return M
