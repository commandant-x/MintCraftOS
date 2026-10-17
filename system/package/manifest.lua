local M = {}

local reserved = {
  browser=true, combat=true, crafttube=true, devices=true, editor=true, files=true,
  logs=true, messenger=true, navigation=true, services=true, settings=true,
  store=true, taskmanager=true, terminal=true, update=true,
}

function M.validId(id)
  return type(id) == "string" and id:match("^[a-z][a-z0-9_%-]*$") ~= nil and not reserved[id]
end

function M.ownedPath(path, id)
  if type(path) ~= "string" or path:find("[%c:\\]") or path:find("//", 1, true)
    or path:sub(-1) == "/" then return false end
  for part in path:gmatch("[^/]+") do
    if part == "." or part == ".." or part:find(".mintcraft-save", 1, true) then return false end
  end
  local owner = path:match("^apps/([^/]+)/.+$") or path:match("^system/themes/icons/([^/]+)%.nfp$")
  return M.validId(owner) and (id == nil or owner == id) or false
end

function M.validate(pkg)
  if type(pkg) ~= "table" then return false, "manifest must be a table" end
  if not M.validId(pkg.id) then return false, "invalid or reserved package id" end
  if type(pkg.name) ~= "string" or pkg.name == "" then return false, "missing name" end
  if type(pkg.version) ~= "string" or pkg.version == "" then return false, "missing version" end
  if type(pkg.files) ~= "table" then return false, "missing files" end
  for path, content in pairs(pkg.files) do
    if not M.ownedPath(path, pkg.id) then return false, "path outside package namespace: " .. tostring(path) end
    if type(content) ~= "string" then return false, "invalid file content: " .. path end
    if path:match("%.lua$") then
      local fn, err = load(content, "@" .. path, "t", {})
      if not fn then return false, tostring(err) end
    end
  end
  if pkg.app ~= nil then
    if type(pkg.app) ~= "table" or (pkg.app.id ~= nil and pkg.app.id ~= pkg.id)
      or type(pkg.app.module) ~= "string" then return false, "invalid application identity" end
    local modulePath = pkg.app.module:gsub("%.", "/") .. ".lua"
    if not M.ownedPath(modulePath, pkg.id) or not pkg.files[modulePath] then return false, "application module not owned" end
    if pkg.app.iconPath and (type(pkg.app.iconPath) ~= "string" or pkg.app.iconPath:sub(1, 1) ~= "/"
      or not M.ownedPath(pkg.app.iconPath:sub(2), pkg.id)) then return false, "application icon not owned" end
  end
  return true
end

return M
