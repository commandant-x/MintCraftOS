-- Boot health metadata is separate from user settings and is never rollback data.
local config=require("system.libraries.config")
local M={path="/var/graphics-boot.cfg"}
function M.begin(requested)
  local prior=config.load(M.path,nil)
  local blocked=type(prior)=="table" and (prior.state=="pending" or prior.state=="failed")
  if blocked or requested.safeMode or requested.graphicsMode=="text" then
    return {state=blocked and "safe" or "text",reason=blocked and prior.reason or nil,started=os.clock(),frames=0}
  end
  local state={state="pending",started=os.clock(),frames=0}
  local ok,err=config.save(M.path,{state="pending",reason="Graphical boot did not complete"})
  if not ok then state.state="safe" state.reason="Cannot journal graphics boot: "..tostring(err) end
  return state
end
function M.observe(state,stats)
  if state.state~="pending" then return end
  if stats.backend=="TEXT" then return M.fail(state,stats.lastError or "Graphics unavailable; text fallback active") end
  state.frames=state.frames+1
  if state.frames>=3 and os.clock()-state.started>=1 then
    local ok,err=config.save(M.path,{state="healthy"})
    if ok then state.state="healthy" else return M.fail(state,tostring(err)) end
  end
end
function M.fail(state,reason)
  state.state="safe" state.reason=tostring(reason)
  return config.save(M.path,{state="failed",reason=state.reason})
end
function M.retry()
  return config.save(M.path,{state="retry"})
end
return M
