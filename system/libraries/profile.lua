-- Integrations are staged after the CC:Tweaked foundation is validated.
local M = { name = "MintCraftOS addons" }

local deferredApps = {}
local deferredServices = {}

function M.appEnabled(id)
  return not deferredApps[id]
end

function M.serviceEnabled(id)
  return not deferredServices[id]
end

return M
