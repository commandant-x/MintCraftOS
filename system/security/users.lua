local config = require("system.libraries.config")
local safeWrite = require("system.libraries.safe_write")

local M = {
  path = "/system/security/users.db",
}

local function computerId()
  if os.getComputerID then return os.getComputerID() end
  if os.computerID then return os.computerID() end
  return 0
end

-- Only used to authenticate existing installations during migration.
local function legacyHash(password)
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
        passwordHash = legacyHash(""),
        permissions = { "*" },
      },
      guest = {
        name = "guest",
        role = "guest",
        passwordHash = legacyHash(""),
        permissions = {
          "filesystem.read",
          "network.http",
          "rednet.send",
          "rednet.receive",
          "logs.read",
          "devices.list",
          "sable.read",
          "avionics.read",
          "combat.read",
          "peripheral.probe",
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
        "sable.read",
        "avionics.read",
        "combat.read",
        "peripheral.probe",
      },
    },
  }
end

local function mergeDefaults(db)
  local def = defaults()
  if db == nil then return def end
  assert(type(db) == "table" and type(db.users) == "table", "Invalid user database")
  db.currentUser = db.currentUser or def.currentUser
  db.locked = db.locked == true
  db.roles = db.roles or def.roles
  assert(type(db.roles) == "table", "Invalid user roles")
  for name, user in pairs(db.users) do
    assert(type(user) == "table", "Invalid user record")
    user.name = user.name or name
    local fallback = def.users[name]
    if fallback then
      user.permissions = user.permissions or fallback.permissions
      user.role = user.role or fallback.role
    end
  end
  return db
end

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = copy(item) end
  return result
end

local function same(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for key, value in pairs(a) do if not same(value, b[key]) then return false end end
  for key in pairs(b) do if a[key] == nil then return false end end
  return true
end

local function crypto()
  -- Provider owns the vetted KDF and salt generation. Never downgrade.
  local ok, provider = pcall(require, "system.libraries.password_crypto")
  if ok and type(provider) == "table" and type(provider.create) == "function"
      and type(provider.verify) == "function" then return provider end
  return nil, "Password changes unavailable: vetted password KDF provider is not installed"
end

local failures, retryAt = 0, 0
local function now()
  return os.epoch and os.epoch("utc") / 1000 or os.clock()
end

local function failedAttempt()
  failures = math.min(failures + 1, 12)
  if failures >= 5 then retryAt = now() + math.min(300, 2 ^ (failures - 5)) end
  return false, "invalid credentials"
end

local function authenticate(db, name, password, options)
  if now() < retryAt then return false, "Too many attempts; retry later" end
  if type(password) ~= "string" or #password > 1024 then return failedAttempt() end
  local user = db.users[name]
  if not user then return failedAttempt() end
  if type(user.passwordHash) == "table" then
    local provider, err = crypto()
    if not provider then return false, err end
    local ok, valid = pcall(provider.verify, password, copy(user.passwordHash), options)
    if not ok then return false, "Password verification unavailable" end
    if valid ~= true then return failedAttempt() end
  elseif type(user.passwordHash) ~= "string" or user.passwordHash ~= legacyHash(password) then
    return failedAttempt()
  end
  return true
end

local function credential(password, options)
  local provider, err = crypto()
  if not provider then return nil, err end
  local ok, value = pcall(provider.create, password, options)
  if not ok or type(value) ~= "table" then return nil, "Password KDF failed; password unchanged" end
  return value
end

function M.load()
  local stored = config.load(M.path, nil)
  if stored == nil and fs and fs.exists and fs.exists(M.path) then error("User database unreadable", 0) end
  local db = mergeDefaults(copy(stored))
  return db
end

function M.save(db, expected)
  if expected and not same(M.load(), expected) then return false, "Session changed; retry operation" end
  return safeWrite.write(M.path, textutils.serialize(mergeDefaults(copy(db))))
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

local function verify(name, password, options)
  local db = M.load()
  return authenticate(db, name, password, options)
end

local function login(name, password, options)
  local db = M.load()
  local expected = copy(db)
  local ok, err = authenticate(db, name, password, options)
  if not ok then return false, err end
  if type(db.users[name].passwordHash) == "string" then
    local provider = crypto()
    if provider then
      local migrated, migrationErr = credential(password, options)
      if not migrated then return false, migrationErr end
      db.users[name].passwordHash = migrated
    end
  end
  db.currentUser = name
  db.locked = false
  if options and options.cancelled and options.cancelled() then return false, "Authentication cancelled" end
  local saved, saveErr = M.save(db, expected)
  if not saved then return false, saveErr end
  failures, retryAt = 0, 0
  return true, "logged in as " .. tostring(name)
end

function M.lock()
  local db = M.load()
  db.locked = true
  return M.save(db)
end

function M.unlock(password, options)
  local db = M.load()
  return M.login(db.currentUser or "admin", password, options)
end

function M.logout()
  local db = M.load()
  db.currentUser = "guest"
  db.locked = false
  return M.save(db)
end

local function setPassword(name, password, oldPassword, options)
  local db = M.load()
  local expected = copy(db)
  local actor = db.users[db.currentUser]
  if db.locked then return false, "session locked" end
  if not actor or actor.role ~= "admin" then return false, "administrator required" end
  local permissions = M.permissionSet(actor, db)
  if not permissions["*"] and not permissions["system.security.admin"] then return false, "administrator permission required" end
  if not db.users[name] then return false, "unknown user" end
  if type(password) ~= "string" or #password < 8 or #password > 1024 then
    return false, "New password must contain 8 to 1024 characters"
  end
  local ok, err = authenticate(db, db.currentUser, oldPassword, options)
  if not ok then return false, err end
  local value, hashErr = credential(password, options)
  if not value then return false, hashErr end
  db.users[name].passwordHash = value
  if options and options.cancelled and options.cancelled() then return false, "Authentication cancelled" end
  local saved, saveErr = M.save(db, expected)
  if saved then failures, retryAt = 0, 0 end
  return saved, saveErr
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

-- Only the factory's empty legacy credential is eligible for enrollment.
function M.needsEnrollment()
  local db=M.load()
  local admin=db.users.admin
  return admin~=nil and admin.passwordHash==legacyHash("")
end

local authBusy = false
local authOwner
local function exclusive(fn, ...)
  if authBusy and authOwner and coroutine.status(authOwner) == "dead" then authBusy = false end
  if authBusy then return false, "Authentication already in progress" end
  authBusy = true
  authOwner = coroutine.running()
  local result = table.pack(pcall(fn, ...))
  authBusy, authOwner = false, nil
  if not result[1] then return false, "Authentication unavailable" end
  return table.unpack(result, 2, result.n)
end
function M.verify(...) return exclusive(verify, ...) end
function M.login(...) return exclusive(login, ...) end
function M.setPassword(...) return exclusive(setPassword, ...) end
function M.enroll(password, options)
  return exclusive(function()
    local db=M.load()
    local expected=copy(db)
    if not db.users.admin or db.users.admin.passwordHash~=legacyHash("") then return false,"Enrollment unavailable" end
    if type(password)~="string" or #password<8 or #password>1024 then return false,"Password must contain 8 to 1024 characters" end
    local value,err=credential(password,options)
    if not value then return false,err end
    if options and options.cancelled and options.cancelled() then return false,"Authentication cancelled" end
    db.users.admin.passwordHash=value db.currentUser="admin" db.locked=false
    return M.save(db,expected)
  end)
end
function M.authBusy() return authBusy end

return M
