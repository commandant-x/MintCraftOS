package.path = "./?.lua;" .. package.path
local nodes, failWrite, failMove = {}, false, false
fs = {
  exists = function(p) return nodes[p] ~= nil end,
  isDir = function(p) return nodes[p] == true end,
  makeDir = function(p) nodes[p] = true end,
  open = function(p)
    nodes[p] = ""
    return {write=function(value) if failWrite then error("disk full") end nodes[p]=value end, close=function() end}
  end,
  move = function(a,b)
    if failMove and a:match("/next$") then error("move failed") end
    assert(nodes[a] ~= nil and nodes[b] == nil)
    nodes[b],nodes[a] = nodes[a],nil
  end,
  delete = function(p)
    for key in pairs(nodes) do if key == p or key:sub(1,#p+1) == p .. "/" then nodes[key]=nil end end
  end,
}
local writer = require("system.libraries.safe_write")
nodes["/notes.txt"] = "original"
failWrite = true
assert(not writer.write("/notes.txt", "new"))
assert(nodes["/notes.txt"] == "original")
failWrite, failMove = false, true
assert(not writer.write("/notes.txt", "new"))
assert(nodes["/notes.txt"] == "original")
failMove = false
assert(writer.write("/notes.txt", "new"))
assert(nodes["/notes.txt"] == "new" and not nodes["/notes.txt.mintcraft-save"])
nodes["/notes.txt.mintcraft-save"] = true
assert(not writer.write("/notes.txt", "replacement"))
assert(nodes["/notes.txt"] == "new" and nodes["/notes.txt.mintcraft-save"])
print("safe write tests passed")
