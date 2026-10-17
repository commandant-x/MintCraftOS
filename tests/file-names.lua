package.path = "./?.lua;" .. package.path
fs = {
  combine = function(dir, name) return (dir .. "/" .. name):gsub("^/+", "") end,
  exists = function(path) return path == "home/user/notes.txt" end,
}
local names = require("system.libraries.file_names")
assert(names.target("/home/user", "new notes.txt") == "home/user/new notes.txt")
assert(names.absolute("home/user/.trash") == "/home/user/.trash")
for _, path in ipairs({"system", "/system", "system/kernel/a.lua", "/apps/files", "boot.lua", "VERSION", "/install.lua", "/rom/startup", "/packages", "/home", "/home/user", "/home/user/../../system/x", "\\system\\kernel"}) do
  assert(names.protected(path), "unprotected spelling: " .. path)
end
assert(not names.protected("home/user/file.txt"))
for _, name in ipairs({"notes.txt", "../notes.txt", "/boot.lua", "a/b", "a\\b", ".", "..", "", "  ", "a\nb"}) do
  local path, reason = names.target("/home/user", name)
  assert(not path and reason, "unsafe or existing target accepted: " .. name)
end
print("file name validation tests passed")
