local M = {}

function M.absolute(path)
  local parts = {}
  for part in tostring(path or ""):gsub("\\", "/"):gmatch("[^/]+") do
    if part == ".." then table.remove(parts)
    elseif part ~= "." then parts[#parts + 1] = part end
  end
  return "/" .. table.concat(parts, "/")
end

function M.protected(path)
  path = M.absolute(path)
  return path == "/" or path == "/system" or path == "/apps"
    or path == "/boot.lua" or path == "/startup.lua" or path == "/VERSION" or path == "/install.lua"
    or path == "/home" or path == "/home/user" or path=="/var" or path=="/var/tmp"
    or path=="/var/backups" or path:match("^/var/backups/")~=nil
    or path=="/var/tmp/mintcraft-install" or path:match("^/var/tmp/mintcraft%-install/")~=nil
    or path=="/var/tmp/mintcraft-package" or path:match("^/var/tmp/mintcraft%-package/")~=nil
    or path=="/var/tmp/mintcraft-restore" or path:match("^/var/tmp/mintcraft%-restore/")~=nil
    or path=="/var/tmp/mintcraft-rollback.cfg"
    or path == "/rom" or path:match("^/rom/") ~= nil
    or path == "/packages" or path:match("^/packages/") ~= nil
    or path:match("^/system/") ~= nil or path:match("^/apps/") ~= nil
end

function M.target(directory, name)
  if type(name) ~= "string" or name == "" or name == "." or name == ".."
    or name:find("[/\\%c]") or name:match("^%s*$") then
    return nil, "Enter a file name, not a path"
  end
  local path = fs.combine(directory, name)
  if fs.exists(path) then return nil, "Name already exists" end
  return path
end

return M
