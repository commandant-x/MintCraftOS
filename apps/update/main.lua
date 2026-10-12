local renderer = require("system.gui.renderer")
local updated = require("system.services.updated")
local ui=require("system.gui.components")
local appWorker=require("system.libraries.app_worker")

local M = {}

function M.run(ctx)
  local app = {
    status = updated.status,
    message = "Ready",
  }
  local worker
  local function submit(action)
    if app.busy then app.message="Operation already running" return end
    if action~="check" then
      local allowed,denied=ctx.security.require("system.update",action)
      if not allowed then app.message=tostring(denied) return end
      ctx.security.audit("update "..action,"GitHub/backup")
    end
    app.busy=true app.message=action.."..."
    local ok,err=worker:submit({action=action})
    if not ok then app.busy=false app.message=tostring(err) end
  end

  function app:refresh()
    submit("check")
  end

  function app:apply()
    submit("apply")
  end

  function app:rollback()
    submit("rollback")
  end

  function app:draw(w, h)
    self.lastH = h
    self.status=updated.status
    local rollback = updated.rollbackInfo()
    renderer.writeAt(1, 1, renderer.crop("MintCraft Update", w), colors.black, colors.lightGray)
    renderer.writeAt(2, 3, renderer.crop("Local : " .. tostring(self.status.localVersion), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(2, 4, renderer.crop("GitHub: " .. tostring(self.status.remoteVersion), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(2, 5, renderer.crop("State : " .. tostring(self.message=="Ready" and self.status.message or self.message), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(2, 7, renderer.crop("Rollback: " .. tostring(rollback and rollback.fromVersion or "none"), w - 2), colors.black, colors.lightGray)
    self.barState=self.barState or {}
    self.buttons=ui.toolbar(1,h-1,w,{{id="check",label="Check"},{id="apply",label="Apply"},{id="rollback",label="Rollback"}},self.barState)
  end

  function app:handle(event)
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    for _,box in ipairs(self.buttons or {}) do if box.delta and ui.hit(box,x,y) then self.barState.first=math.max(1,(self.barState.first or 1)+box.delta) return true end end
    local action=ui.toolbarHit(self.buttons,x,y)
    if action=="check" then
      self:refresh()
      return true
    elseif action=="apply" then
      self:apply()
      return true
    elseif action=="rollback" then
      self:rollback()
      return true
    end
    return false
  end

  local sw, sh = term.getSize()
  app.lastH = math.min(12, sh - 3)
  local win = ctx.windowManager:create({ title = "Update", w = math.min(44, sw - 4), h = app.lastH, x = 7, y = 4, app = app })
  worker=appWorker.new(ctx,"Update operations",function(request)
    if request.action=="check" then return updated.check() end
    if request.action=="apply" then return updated.apply() end
    return updated.rollback()
  end,function(request,ok,result,message)
    app.busy=false
    if not ok then app.message="Update failed: "..tostring(result)
    elseif request.action=="check" then app.status=result app.message=result.message
    else app.message=tostring(message or result) end
    if ctx.notifications and (not ok or request.action~="check") then
      ctx.notifications:push(ok and result~=false and "success" or "error","Update",app.message,6)
    end
  end)
  while not win.closed do ctx.pullEvent() end
end

return M
