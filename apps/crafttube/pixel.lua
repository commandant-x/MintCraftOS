local client=require("system.graphics.client")
local fonts=require("system.graphics.fonts")
local M={}
function M.attach(app,actions,enqueue)
  local width=480
  client.attach(app,{
    model=function(w)
      width=w or width
      local rows={}
      for _,item in ipairs(app.rows) do
        rows[#rows+1]={id=item.id,title=item.title,description=item.channel.." | "..item.duration.." | "..item.views,selected=item.id==app.selected}
        if item.id==app.selected then
          rows[#rows+1]={id=item.id,title=item.url}
          local layout=fonts.layout(tostring(item.description or ""),math.max(24,width-38),65536,{wrap=true})
          for _,line in ipairs(layout.lines) do rows[#rows+1]={id=item.id,title=line.text} end
        end
      end
      return {page="crafttube",actions=actions,fields={{id="input",label=app.mode=="proxy" and "Proxy URL" or app.mode=="audio" and "Audio proxy URL" or "Search",value=app.input,limit=2048}},rows=rows,footer=app.status}
    end,
    input=function(_,value) app.input=value end,
    submit=function() app.keyboard.onEnter() end,
    action=function(id) app:action(id) end,
    select=function(id) if app.selected~=id then app.selected=id enqueue("details") end end,
  })
end
return M
