local config = require("system.libraries.config")
local safeWrite = require("system.libraries.safe_write")
local throttle = require("system.security.auth_throttle")

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

local memoryCredential
local function stage(options,label)
  if options and options.stage then options.stage(label) end
end
local function remember(db,name,password)
  memoryCredential=nil
  local user=db.users[name]
  if not user or type(user.passwordHash)~="table" then return end
  local provider=crypto()
  if not provider or type(provider.memoryVerifier)~="function" then return end
  local ok,verifier=pcall(provider.memoryVerifier,password)
  if ok and type(verifier)=="function" then
    memoryCredential={name=name,passwordHash=copy(user.passwordHash),quickHash=copy(user.quickPasswordHash),
      quickSource=copy(user.quickPasswordSource),verify=verifier}
  end
end
local function authenticate(db, name, password, options)
  if options and options.cancelled and options.cancelled() then return false,"Authentication cancelled" end
  local reservation,err=throttle.reserve(db.authThrottle)
  if not reservation then return false,err end
  local expected=copy(db)
  db.authThrottle=reservation
  -- Reserve durably before an expensive/yielding comparison: reboot/cancellation
  -- cannot discard an attempted guess. A storage failure refuses authentication.
  local saved,saveErr=M.save(db,expected)
  if not saved then return false,saveErr end
  local reserved=copy(db)
  local function failed()
    db.authThrottle=throttle.defer(reservation)
    local ok,problem=M.save(db,reserved)
    if not ok then return false,problem end
    return false,"invalid credentials"
  end
  if type(password)~="string" or #password>1024 then return failed() end
  local user=db.users[name]
  if not user then return failed() end
  if type(user.passwordHash)=="table" then
    local provider,problem=crypto()
    if not provider then return false,problem end
    local cached=memoryCredential
    local ok,valid
    if cached and cached.name==name and same(cached.passwordHash,user.passwordHash)
      and same(cached.quickHash,user.quickPasswordHash) and same(cached.quickSource,user.quickPasswordSource) then
      stage(options,"Quick unlock")
      ok,valid=pcall(cached.verify,password)
    else
      memoryCredential=nil
      local value=user.passwordHash
      if type(user.quickPasswordHash)=="table" and same(user.quickPasswordSource,value) then value=user.quickPasswordHash end
      stage(options,type(value.iterations)=="number" and value.iterations>15000 and "First verification (slow)" or "Password check")
      ok,valid=pcall(provider.verify,password,copy(value),options)
    end
    if not ok then return false,"Password verification unavailable" end
    if valid~=true then return failed() end
  elseif type(user.passwordHash)~="string" or user.passwordHash~=legacyHash(password) then
    return failed()
  end
  if options and options.cancelled and options.cancelled() then return false,"Authentication cancelled" end
  db.authThrottle=nil
  return M.save(db,reserved)
end

local function credential(password, options)
  local provider, err = crypto()
  if not provider then return nil, err end
  stage(options,"Password setup (slow)")
  local ok, value = pcall(provider.create, password, options)
  if not ok or type(value) ~= "table" then return nil, "Password KDF failed; password unchanged" end
  return value
end

local function prepareQuick(user,password,options)
  local provider=crypto()
  if not provider or type(provider.createQuick)~="function" then return true end
  if type(user.quickPasswordHash)=="table" and same(user.quickPasswordSource,user.passwordHash) then return true end
  stage(options,"Preparing quick unlock")
  local ok,value=pcall(provider.createQuick,password,options)
  if not ok or type(value)~="table" then return false,"Password verification setup unavailable" end
  user.quickPasswordHash=value user.quickPasswordSource=copy(user.passwordHash)
  return true
end

function M.authenticationStatus()
  return throttle.status(M.load().authThrottle)
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
  local ok, err = authenticate(db, name, password, options)
  if not ok then return false, err end
  local expected=copy(db)
  if type(db.users[name].passwordHash) == "string" then
    local provider = crypto()
    if provider then
      local migrated, migrationErr = credential(password, options)
      if not migrated then return false, migrationErr end
      db.users[name].passwordHash = migrated
    end
  end
  local ready,problem=prepareQuick(db.users[name],password,options)
  if not ready then return false,problem end
  db.currentUser = name
  db.locked = false
  if options and options.cancelled and options.cancelled() then return false, "Authentication cancelled" end
  local saved, saveErr = M.save(db, expected)
  if not saved then return false, saveErr end
  remember(db,name,password)
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
  memoryCredential=nil
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
  expected=copy(db)
  local value, hashErr = credential(password, options)
  if not value then return false, hashErr end
  db.users[name].passwordHash = value
  db.users[name].quickPasswordHash=nil db.users[name].quickPasswordSource=nil
  local ready,problem=prepareQuick(db.users[name],password,options)
  if not ready then return false,problem end
  if options and options.cancelled and options.cancelled() then return false, "Authentication cancelled" end
  local saved, saveErr = M.save(db, expected)
  if saved then
    memoryCredential=nil
    if name==db.currentUser then remember(db,name,password) end
  end
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
    db.users.admin.passwordHash=value
    local ready,problem=prepareQuick(db.users.admin,password,options)
    if not ready then return false,problem end
    if options and options.cancelled and options.cancelled() then return false,"Authentication cancelled" end
    db.authThrottle=nil db.currentUser="admin" db.locked=false
    local saved,err=M.save(db,expected)
    if saved then remember(db,"admin",password) end
    return saved,err
  end)
end
function M.authBusy() return authBusy end

return M
