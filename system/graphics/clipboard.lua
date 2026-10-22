-- In-memory text only, scoped to one authenticated session revision.
local M={limit=65536}
local text,revision='',nil
local function session()
 local ok,security=pcall(require,'system.services.securityd')
 if not ok or type(security.sessionRevision)~='function' or type(security.isLocked)~='function' then text,revision='',nil return nil end
 local ready,current=pcall(function()
  if security.isLocked() then return nil end
  if not security.authorize({appId='clipboard'},'filesystem.read') then return nil end
  return security.sessionRevision()
 end)
 if not ready or current==nil then text,revision='',nil return nil end
 if current~=revision then text='' revision=current end
 return current
end
function M.set(value)
 if not session() then return false,'Clipboard unavailable in this session' end
 if type(value)~='string' or #value>M.limit then return false,'Clipboard text exceeds limit' end
 text=value return true
end
function M.get() if not session() then return '' end return text end
function M.clear() text,revision='',nil end
return M
