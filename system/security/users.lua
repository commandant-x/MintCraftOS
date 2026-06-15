local config = require("system.libraries.config")

local M = {
  path = "/system/security/users.db",
}

local function computerId()
  if os.getComputerID then return os.getComputerID() end
  if os.computerID then return os.computerID() end
  return 0
end

local function hashPassword(password)
  password = tostring(password or "")
  local h = 5381 + computerId()
  for i = 1, #password do
    h = ((h * 33) + string.byte(password, i)) % 2147483647
  end
  return tostring(h)
end

local function defaults()
  return {
    currentUser = "admin",
    locked = false,
    users = {
      admin = {
        name = "admin",
        role = "admin",
        passwordHash = hashPassword(""),
        permissions = { "*" },
      },
      guest = {
        name = "guest",
        role = "guest",
        passwordHash = hashPassword(""),
        permissions = {
          "filesystem.read",
          "network.http",
          "rednet.send",
          "rednet.receive",
          "logs.read",
          "devices.list",
        },
      },
    },
    roles = {
      admin = { "*" },
      guest = {
        "filesystem.read",
        "network.http",
        "rednet.send",
        "rednet.receive",
        "logs.read",
        "devices.list",
      },
    },
  }
end

local function mergeDefaults(db)
  local def = defaults()
  db = db or {}
  db.currentUser = db.currentUser or def.currentUser
  db.locked = db.locked == true
  db.users = db.users or {}
  db.roles = db.roles or def.roles
  for name, user in pairs(def.users) do
    db.users[name] = db.users[name] or user
    db.users[name].permissions = db.users[name].permissions or user.permissions
    db.users[name].role = db.users[name].role or user.role
    db.users[name].passwordHash = db.users[name].passwordHash or user.passwordHash
  end
  return db
end

function M.load()
  local db = mergeDefaults(config.load(M.path, nil))
  config.save(M.path, db)
  return db
end

function M.save(db)
  return config.save(M.path, mergeDefaults(db))
end

function M.current()
  local db = M.load()
  return db.users[db.currentUser], db
end

local function listToSet(list, set)
  set = set or {}
  for _, item in ipairs(list or {}) do set[item] = true end
  return set
end

function M.permissionSet(user, db)
  db = db or M.load()
  user = user or db.users[db.currentUser]
  local set = {}
  if user then
    listToSet(db.roles[user.role] or {}, set)
    listToSet(user.permissions or {}, set)
  end
  return set
end

function M.hasPermission(permission)
  if permission == nil or permission == "" then return true end
  local user, db = M.current()
  if not user then return false end
  local set = M.permissionSet(user, db)
  return set["*"] == true or set[permission] == true
end

function M.verify(name, password)
  local db = M.load()
  local user = db.users[name]
  if not user then return false, "unknown user" end
  if user.passwordHash ~= hashPassword(password or "") then return false, "bad password" end
  return true
end

function M.login(name, password)
  local ok, err = M.verify(name, password)
  if not ok then return false, err end
  local db = M.load()
  db.currentUser = name
  db.locked = false
  M.save(db)
  return true, "logged in as " .. tostring(name)
end

function M.lock()
  local db = M.load()
  db.locked = true
  M.save(db)
  return true
end

function M.unlock(password)
  local db = M.load()
  return M.login(db.currentUser or "admin", password)
end

function M.logout()
  local db = M.load()
  db.currentUser = "guest"
  db.locked = false
  M.save(db)
  return true
end

function M.setPassword(name, password)
  local db = M.load()
  if not db.users[name] then return false, "unknown user" end
  db.users[name].passwordHash = hashPassword(password or "")
  M.save(db)
  return true
end

function M.list()
  local db = M.load()
  local rows = {}
  for _, user in pairs(db.users) do
    table.insert(rows, {
      name = user.name,
      role = user.role,
      permissions = user.permissions or {},
      active = user.name == db.currentUser,
    })
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

function M.isLocked()
  return M.load().locked == true
end

return M
