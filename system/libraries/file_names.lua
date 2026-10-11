local M = {}

function M.absolute(path)
  return "/" .. fs.combine("", path):gsub("^/+", "")
end

function M.protected(path)
  path = M.absolute(path)
  return path == "/" or path == "/system" or path == "/apps"
    or path == "/boot.lua" or path == "/startup.lua" or path == "/VERSION"
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
