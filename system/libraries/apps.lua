local log = require("system.libraries.log")
local permissions = require("system.security.permissions")

local M = {
  registry = {},
  ctx = nil,
}

function M.setContext(ctx)
  M.ctx = ctx
end

function M.register(id, name, module, meta)
  meta = meta or {}
  M.registry[id] = {
    id = id,
    name = name,
    module = module,
    icon = meta.icon or "[]",
    iconPath = meta.iconPath,
    category = meta.category or "System",
    version = meta.version or "0.17.1",
    permissions = meta.permissions or {},
    hidden = meta.hidden == true,
  }
end

function M.get(id)
  return M.registry[id]
end

function M.list(includeHidden)
  local rows = {}
  for _, app in pairs(M.registry) do
    if includeHidden or not app.hidden then table.insert(rows, app) end
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

function M.launch(id, args)
  local app = M.registry[id]
  if not app then return false, "Unknown app: " .. tostring(id) end
  if not M.ctx then return false, "App context not ready" end

  local ok, mod = pcall(require, app.module)
  if not ok then
    log.error("apps", tostring(mod))
    return false, tostring(mod)
  end

  local scheduler = M.ctx.scheduler
  local pid
  pid = scheduler:spawn(app.name, function(startEvent)
    local procCtx = scheduler:makeContext(pid)
    procCtx.appId = id
    procCtx.args = args or {}
    procCtx.permissions = app.permissions
    procCtx.security = {
      require = function(permission, target)
        return permissions.require({ pid = pid, appId = id, permissions = app.permissions }, permission, target)
      end,
      audit = function(action, target)
        return permissions.audit({ pid = pid, appId = id, permissions = app.permissions }, action, target)
      end,
    }
    procCtx.windowManager = {
      create = function(_, opts)
        opts.ownerPid = pid
        opts.onError = function(err)
          scheduler:crash(pid, err)
        end
        local win = M.ctx.wm:create(opts)
        scheduler:attachWindow(pid, win)
        return win
      end,
    }
    procCtx.notifications = M.ctx.notifications
    procCtx.apps = M
    procCtx.system = M.ctx
    mod.run(procCtx, startEvent)
  end, { appId = id, permissions = app.permissions })
  scheduler:start(pid)

  return true, pid
end

return M
