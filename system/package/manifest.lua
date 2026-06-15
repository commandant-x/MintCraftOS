local M = {}

function M.validate(pkg)
  if type(pkg) ~= "table" then return false, "manifest must be a table" end
  if type(pkg.id) ~= "string" or pkg.id == "" then return false, "missing id" end
  if type(pkg.name) ~= "string" or pkg.name == "" then return false, "missing name" end
  if type(pkg.version) ~= "string" or pkg.version == "" then return false, "missing version" end
  if type(pkg.files) ~= "table" then return false, "missing files" end
  for path, content in pairs(pkg.files) do
    if type(path) ~= "string" or path == "" then return false, "invalid file path" end
    if path:match("^/") then return false, "absolute file path not allowed: " .. path end
    if path:match("%.%.") then return false, "parent path not allowed: " .. path end
    if type(content) ~= "string" then return false, "invalid file content: " .. path end
  end
  return true
end

return M
