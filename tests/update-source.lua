package.path = "./?.lua;" .. package.path
local source = require("system.libraries.update_source")
local sha = string.rep("a", 40)
local requests = {}
textutils = {unserializeJSON = function(body)
  if body == "valid" then return {sha = sha} end
  if body == "invalid" then return {sha = "main"} end
  error("bad JSON")
end}
local function get(url) requests[#requests + 1] = url return "valid" end
local pinned = assert(source.resolve({repo = "owner/repo", branch = "release/core"}, get))
assert(requests[1] == "https://api.github.com/repos/owner/repo/commits/release%2Fcore")
assert(source.url(pinned, "VERSION") == "https://raw.githubusercontent.com/owner/repo/" .. sha .. "/VERSION")
sha = string.rep("b", 40)
assert(source.url(pinned, "install.lua"):find(string.rep("a", 40), 1, true), "release changed after resolution")
assert(source.resolve({repo = "owner/repo", branch = sha}, function() error("unnecessary request") end))
for _, body in ipairs({"invalid", "broken"}) do
  assert(not source.resolve({repo = "owner/repo", branch = "main"}, function() return body end))
end
assert(not source.resolve({repo = "owner/repo", branch = "main"}, function() return nil, "offline" end))
assert(not source.resolve({repo = "../bad", branch = "main"}, get))
assert(not pcall(source.url, {repo = "owner/repo", sha = "main"}, "install.lua"))
print("pinned update source tests passed")
