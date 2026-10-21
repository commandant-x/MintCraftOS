local client=require("system.graphics.client")
local M={}
function M.attach(app,rows,actions)
  client.attach(app,{
    model=function()
      local result={}
      for _,pkg in ipairs(rows()) do result[#result+1]={id=pkg.id,title=pkg.name.." "..pkg.version,
        description=(pkg.installed and "Installed | " or "Available | ")..tostring(pkg.description or ""),selected=app.selected==pkg.id} end
      return {page="store",actions=actions,rows=result,footer=app.message}
    end,
    action=function(id) app:action(id) end,
    select=function(id) app.selected=id end,
  })
end
return M
