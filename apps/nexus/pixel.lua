local client=require("system.graphics.client")
local fonts=require("system.graphics.fonts")
local M={}
function M.attach(app,pages,actions,api)
  local editing,editText,width=nil,"",480
  local nativeState
  local function applyField()
    if not editing then return true end
    local n=tonumber(editText)
    if not n or n~=n or math.abs(n)==math.huge then app.message="Invalid number" return false end
    app.rules[editing]=n editing=nil return true
  end
  local fields={{id="enabled",label="Alerts enabled",boolean=true},{id="offlineSeconds",label="Offline alert (s)"},
    {id="staleSeconds",label="Stale sample (s)"},{id="energyLowPercent",label="Energy low (%)"},
    {id="diskLowPercent",label="Disk free low (%)"},{id="inventoryHighPercent",label="Slot use high (%)"}}
  nativeState=client.attach(app,{
    model=function(w)
      width=w or width
      local rows,buttons,inputs={},{},{}
      if app.confirm then
        local layout=fonts.layout(app.confirm.title,math.max(24,width-38),65536,{wrap=true})
        for _,line in ipairs(layout.lines) do rows[#rows+1]={title=line.text} end
        -- Confirmation becomes available only after scrolling through the whole
        -- warning. Preserve the application's two distinct confirmations.
        local read=nativeState and nativeState.page==app.confirm and nativeState.lastVisible>=#rows
        buttons={{id="cancel",label="Cancel"},{id="confirm",label=read and "Confirm" or "Read next"}}
        return {page=app.confirm,actions=buttons,rows=rows,footer="Review all affected IDs before confirming"}
      end
      for _,page in ipairs(pages) do buttons[#buttons+1]={id="page:"..page.id,label=page.label,active=app.page==page.id} end
      for _,a in ipairs(actions()) do buttons[#buttons+1]=a end
      local s=app.snapshot
      if app.page=="setup" then
        inputs={{id="group",label="Deployment group",value=app.settings.group},{id="key",label="Key (empty = automatic HTTPS)",value=app.settings.key,secret=true}}
      elseif app.page=="monitoring" then
        for _,f in ipairs(fields) do rows[#rows+1]={id="field:"..f.id,title=f.label,description=tostring(app.rules[f.id])} end
        if editing then inputs={{id=editing,label=editing,value=editText}} end
      elseif app.page=="computers" or app.page=="map" then
        if app.page=="computers" then buttons[#buttons+1]={id="authorize",label="Authorize"} buttons[#buttons+1]={id="drive",label="Next disk"} end
        for _,r in ipairs(s.computers) do
          rows[#rows+1]={id=r.id,title=(r.authorized and "[x] " or "[ ] ")..r.id.." "..r.label,
            description=r.state.." | "..tostring(r.group or "unmanaged").." | agent "..tostring(r.version or "unknown"),selected=r.id==app.selected}
          if app.page=="map" and r.id==app.selected then
            rows[#rows+1]={title="Last seen",description=r.lastSeenSeconds and tostring(r.lastSeenSeconds).."s" or "never"}
            rows[#rows+1]={title="Tasks / link",description=tostring(r.activeMissions or 0).." | "..(r.name and "wired peripheral" or "Rednet")}
            for _,d in ipairs(r.peripherals or {}) do rows[#rows+1]={title=tostring(d.name),description=tostring(d.type)} end
            for _,cap in ipairs(r.capabilities or {}) do rows[#rows+1]={title=tostring(cap)} end
            if r.error then rows[#rows+1]={title=r.error} end
          end
        end
      else
        for _,line in ipairs(app:contentLines(math.max(4,math.floor((width-38)/6)))) do rows[#rows+1]={title=tostring(line)} end
      end
      return {page=app.page,actions=buttons,fields=inputs,rows=rows,footer=app.message~="" and app.message or tostring(s.message or "")}
    end,
    input=function(id,value)
      if app.page=="setup" then app.settings[id]=value
      elseif id~="enabled" then editText=value end
    end,
    submit=applyField,
    action=function(id)
      if app.confirm then
        if id=="cancel" then app.confirm=nil
        elseif id=="confirm" then
          local rows=nativeState.model.rows
          if nativeState.page~=app.confirm or nativeState.lastVisible<#rows then
            nativeState.first=math.max(nativeState.first+1,nativeState.lastVisible+1)
          else local fn=app.confirm.fn app.confirm=nil fn() end
        end
        return
      end
      local page=id:match("^page:(.+)$")
      if page then app.page=page app.scroll=1 editing=nil
      elseif id=="authorize" then for _,r in ipairs(app.snapshot.computers) do if r.id==app.selected then api.select(r,true) break end end
      else if id=="monitorConfig" and not applyField() then return end app:command(id) end
    end,
    select=function(id)
      local key=tostring(id):match("^field:(.+)$")
      if key then if key=="enabled" then app.rules.enabled=not app.rules.enabled else editing=key editText=tostring(app.rules[key] or "") end
      else for _,r in ipairs(app.snapshot.computers) do if r.id==id then api.select(r,false) break end end end
    end,
  })
end
return M
