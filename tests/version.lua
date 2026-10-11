package.path = "./?.lua;" .. package.path
fs = { open = function() return { readAll = function() return " 1.2.3\n" end, close = function() end } end }
local version = require("system.libraries.version")
assert(version.current() == "1.2.3")
assert(version.compare("1.10.0", "1.9.9") == 1)
assert(version.compare("0.17.3", "1.0.0") == -1)
assert(version.compare("1.0.0", "1.0.0") == 0)
assert(version.compare("error page", "1.0.0") == nil)
assert(version.compare("1.0.0", "unknown") == nil)
print("version tests passed")
