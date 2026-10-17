package.path = "./?.lua;" .. package.path
local nodes = { ["/VERSION"] = "1.0.0", ["/system"] = true }
local saved, failCopy, failPublish = {}, false, false
local function remove(path)
  for key in pairs(nodes) do
    if key == path or key:sub(1, #path + 1) == path .. "/" then nodes[key] = nil saved[key] = nil end
  end
end
fs = {
  isDir = function(path) return nodes[path] == true end,
  list = function(path)
    local seen, result = {}, {}
    for key in pairs(nodes) do
      if key:sub(1, #path + 1) == path .. "/" then
        local name = key:sub(#path + 2):match("^[^/]+")
        if not seen[name] then result[#result+1], seen[name] = name, true end
      end
    end
    return result
  end,
  getSize = function(path) return type(nodes[path]) == "string" and #nodes[path] or 0 end,
  exists = function(path) return nodes[path] ~= nil end,
  makeDir = function(path) nodes[path] = true end,
  getDir = function(path) return path:match("^(.*)/[^/]*$") or "" end,
  delete = remove,
  copy = function(from, to)
    if failCopy then error("disk full") end
    assert(nodes[from] and not nodes[to])
    nodes[to] = nodes[from]
  end,
  move = function(from, to)
    if failPublish and to:match("/update/latest.cfg$") then error("publish failed") end
    assert(nodes[from] and not nodes[to])
    nodes[to], saved[to] = nodes[from], saved[from]
    nodes[from], saved[from] = nil, nil
  end,
  open = function(path) return {readAll = function() return nodes[path] end, close = function() end} end,
}
package.loaded["system.libraries.config"] = {
  load = function(path, fallback) return saved[path] or fallback end,
  save = function(path, value) nodes[path] = "config" saved[path] = value return true end,
}
os.epoch = function() return 123 end
local updated = require("system.services.updated")
local ok, first = updated.createRollback()
assert(ok and first.id == "123")
failCopy = true
assert(not updated.createRollback())
assert(updated.rollbackInfo().id == first.id)
assert(nodes[updated.rollbackRoot .. "/123/VERSION"] == "1.0.0")
failCopy = false
local success, second = updated.createRollback()
assert(success and second.id ~= first.id)
assert(nodes[updated.rollbackRoot .. "/123/VERSION"])
assert(updated.rollbackInfo().id == second.id)
failPublish = true
assert(not updated.createRollback())
assert(updated.rollbackInfo().id == second.id, "lost previous pointer after interrupted publication")
failPublish = false
local root = updated.rollbackRoot .. "/" .. second.id
local manifest = saved[root .. "/manifest.cfg"]
local originalPaths = manifest.paths
nodes["/VERSION"] = "2.0.0"
nodes[root .. "/system"] = nil
assert(not updated.rollback())
assert(nodes["/VERSION"] == "2.0.0", "missing later backup must not partially restore VERSION")
nodes[root .. "/system"] = true
for _, paths in ipairs({{"/VERSION", "/home/user"}, {"/VERSION", "/VERSION"}, {}, {[2] = "/VERSION"}}) do
  manifest.paths = paths
  assert(not updated.rollback())
  assert(nodes["/VERSION"] == "2.0.0", "invalid manifest changed live installation")
end
manifest.paths = originalPaths
assert(updated.rollback())
assert(nodes["/VERSION"] == "1.0.0")
failCopy = true
nodes["/VERSION"] = "2.0.0"
local restored, reason = updated.rollback()
assert(not restored and reason:find("backup retained", 1, true))
assert(nodes["/VERSION"] == "2.0.0", "copy failure deleted live file")
assert(nodes[root .. "/VERSION"] == "1.0.0")
print("backup retention tests passed")
