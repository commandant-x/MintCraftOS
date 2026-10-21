local client=require("system.graphics.client")
local fonts=require("system.graphics.fonts")
local M={}
function M.attach(app,api)
  local width=480
  client.attach(app,{
    model=function(w)
      width=w or width
      local t=api.tab() local page=t.page or api.home()
      local actions={{id="back",label="Back"},{id="forward",label="Next"},{id="reload",label="Reload"},
        {id="home",label="Home"},{id="bookmark",label="Bookmark"},{id="download",label="Download"},
        {id="crafttube",label="CraftTube"},{id="new",label="+ Tab"}}
      for i,item in ipairs(app.tabs) do actions[#actions+1]={id="tab:"..i,label=tostring(i).." "..tostring(item.title or "Tab"):sub(1,12),active=i==app.active} end
      if api.settings.showBookmarks then for i,b in ipairs(app.bookmarks) do actions[#actions+1]={id="bookmark:"..i,label=b.title:sub(1,16)} end end
      local rows={}
      for i,line in ipairs(page.lines or {}) do
        local layout=fonts.layout(tostring(line),math.max(24,width-38),65536,{wrap=true})
        for _,part in ipairs(layout.lines) do rows[#rows+1]={id=i,title=part.text,accent=line:match("^#")~=nil or line:match("%[%d+%]")~=nil} end
      end
      return {page=t,actions=actions,fields={{id="address",label="Address / search",value=app.focusAddress and app.address or t.url,limit=2048}},rows=rows,footer=app.status}
    end,
    input=function(_,value) app.focusAddress=true app.address=value end,
    submit=api.submit,
    action=function(id)
      local t=api.tab() local n=id:match("^tab:(%d+)$") local b=id:match("^bookmark:(%d+)$")
      if n then app.active=tonumber(n) app.focusAddress=false
      elseif b then api.enqueue("load",{url=app.bookmarks[tonumber(b)].url,history=true})
      elseif id=="new" then api.newTab()
      elseif id=="bookmark" then api.bookmark()
      elseif id=="crafttube" then api.crafttube()
      elseif id=="download" then api.enqueue("download",t.url)
      elseif id=="back" or id=="forward" then api.enqueue("history",id=="back" and -1 or 1)
      else api.enqueue("load",{url=id=="home" and api.settings.home or t.url,history=id=="home",bypass=id=="reload"}) end
    end,
    select=function(index)
      local page=api.tab().page or api.home() local line=page.lines[index] or ""
      for _,link in ipairs(page.links or {}) do if line:find("["..tostring(link.index).."]",1,true) then api.link(link) break end end
    end,
  })
end
return M
