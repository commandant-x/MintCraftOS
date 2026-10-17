local log = require("system.libraries.log")
local permissions = require("system.security.permissions")
local profile = require("system.libraries.profile")

local M = {
  registry = {},
  ctx = nil,
}

function M.setContext(ctx)
  M.ctx = ctx
end

function M.register(id, name, module, meta)
  meta = meta or {}
  if M.registry[id] and M.registry[id].builtin and meta.builtin~=true then return false,"Built-in app ID is protected" end
  M.registry[id] = {
    id = id,
    name = name,
    module = module,
    icon = meta.icon or "[]",
    iconPath = meta.iconPath,
    category = meta.category or "System",
    version = meta.version or "0.18.23",
    permissions = meta.permissions or {},
    hidden = meta.hidden == true,
    builtin = meta.builtin == true,
  }
  return true
end

function M.registerBuiltin(id,name,module,meta)
  meta=meta or {} meta.builtin=true
  return M.register(id,name,module,meta)
end

function M.get(id)
  return M.registry[id]
end

function M.list(includeHidden,includeDisabled)
  local rows = {}
  for _, app in pairs(M.registry) do
    if (includeHidden or not app.hidden) and (includeDisabled or profile.appEnabled(app.id)) then table.insert(rows, app) end
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

function M.launch(id, args)
  if not profile.appEnabled(id) then return false, "App disabled; enable it in Settings / Apps: " .. tostring(id) end
  local app = M.registry[id]
  if not app then return false, "Unknown app: " .. tostring(id) end
  if not M.ctx then return false, "App context not ready" end
  if not app.builtin then
    local message="Third-party execution disabled: CC host has no verified CPU/memory isolation"
    pcall(log.warn,"apps",message)
    if M.ctx.notifications then pcall(M.ctx.notifications.push,M.ctx.notifications,"warn","App not trusted",message,5) end
    return false,message
  end
  if M.ctx.services and profile.dependencies then
    for _,service in ipairs(profile.dependencies(id)) do
      local ok,err=M.ctx.services:start(service)
      if not ok then return false,"Service "..service..": "..tostring(err) end
    end
  end

  local ok, mod = pcall(require, app.module)
  if ok and (type(mod) ~= "table" or type(mod.run) ~= "function") then
    ok, mod = false, "Invalid app module: missing run()"
  end
  if not ok then
    log.error("apps", app.name .. ": " .. tostring(mod))
    if M.ctx.notifications then
      M.ctx.notifications:push("error", "App failed to load", app.name, 5)
    end
    return false, tostring(mod)
  end

  local scheduler = M.ctx.scheduler
  local pid
  pid = scheduler:spawn(app.name, function(startEvent)
    local procCtx = scheduler:makeContext(pid)
    procCtx.appId = id
    procCtx.args = args or {}
    procCtx.permissions = {table.unpack(app.permissions)}
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
        opts.appId = id
        opts.onError = function(err)
          scheduler:crash(pid, err)
        end
        local win = M.ctx.wm:create(opts)
        win.appId=id
        scheduler:attachWindow(pid, win)
        return win
      end,
    }
    procCtx.notifications = M.ctx.notifications
    procCtx.apps = M
    procCtx.system = M.ctx
    mod.run(procCtx, startEvent)
  end, { appId = id, permissions = app.permissions })
  local started, err = scheduler:start(pid)
  if not started then return false, err end

  return true, pid
end

return M
