-- Presentation policy only. Never gates event dispatch or acquisition timers.
local M={}
function M.options(cfg)
  cfg=cfg or {}
  local profile=cfg.graphicsProfile or "balanced"
  if profile~="stable" and profile~="balanced" and profile~="performance" then profile="balanced" end
  local hz=tonumber(cfg.graphicsMaxHz)
  if not hz or hz~=hz or hz<10 or hz>20 then hz=profile=="performance" and 10 or 20 end
  local optimized=cfg.graphicsOptimizations~=false and profile~="stable"
  return {profile=profile,optimized=optimized,maxHz=hz,batchRows=optimized and 8 or 1}
end
function M.new(options,clock)
  clock=clock or os.clock
  local self={options=options,pending=false,last=-math.huge,requests=0,skipped=0,frames=0}
  function self:request(changed)
    self.requests=self.requests+1
    if changed then self.pending=true else self.skipped=self.skipped+1 end
  end
  function self:delay()
    if not self.pending then return end
    return math.max(0,1/self.options.maxHz-(clock()-self.last))
  end
  function self:presented() self.pending=false self.last=clock() self.frames=self.frames+1 end
  return self
end
function M.visibleKey(ctx,workspace)
  local parts={tostring(workspace.revision),tostring(require("system.gui.theme").currentId)}
  for _,win in ipairs(ctx.wm.windows) do
    local b=win.pixelBounds or {}
    parts[#parts+1]=table.concat({win.id,tostring(win.closed),tostring(win.minimized),win.x,win.y,win.w,win.h,
      b.x or 0,b.y or 0,b.w or 0,b.h or 0,tostring(win.maximized),tostring(win.movePending),win.title},":")
    if not win.closed and not win.minimized then
      parts[#parts+1]=tostring(win.dirty)..":"..tostring(win.surfaceRevision)
    end
  end
  for _,item in ipairs(ctx.notifications.queue or {}) do parts[#parts+1]="notification:"..item.id end
  return table.concat(parts,"|")
end
return M
