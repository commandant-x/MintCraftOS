package.path = "./?.lua;" .. package.path
fs = {
  combine = function(a,b) return a:gsub("/$", "") .. "/" .. b end,
  exists = function() return true end,
  isDir = function(path) return not path:match("%.lua$") and not path:match("%.txt$") end,
  list = function(path)
    if path == "/system" then return {"zebra.lua"} end
    if path == "/apps" then return {} end
    return {"file.txt", "folder", "mkdir.txt"}
  end,
}
local a = require("system.dev.autocomplete")
local function complete(text, prefix)
  local s = a.suggest({mode="terminal",text=text,cursor=#text+1,prefix=prefix,cwd="/home"})
  return a.apply(text,#text+1,s,prefix),s
end
assert(complete("cat docs/fi", "docs/fi") == "cat docs/file.txt")
assert(complete("cat /docs/fi", "/docs/fi") == "cat /docs/file.txt")
assert(complete("cd docs/fo", "docs/fo") == "cd docs/folder/")
local text,s = complete("cat mk", "mk")
assert(text == "cat mkdir.txt" and s.kind == "path")
assert(complete("mk", "mk") == "mkdir")
local module = a.suggest({mode="editor",prefix="system.z",lines={}})
assert(module and module.insert == "system.zebra")
local originalList, scans = fs.list, 0
fs.list = function(...) scans = scans + 1 return originalList(...) end
for i = 1, 100 do
  assert(a.suggest({mode="terminal",prefix="mk",text="mk",cursor=3}).insert == "mkdir")
  assert(a.suggest({mode="editor",prefix="system.z",lines={}}).insert == "system.zebra")
end
assert(scans == 0, "static completions/module cache repeated filesystem scans")
a.invalidate()
assert(a.suggest({mode="editor",prefix="system.z",lines={}}) and scans == 2)
local lines = {"local customVariable = 1"}
assert(a.suggest({mode="editor",prefix="custom",lines=lines,revision=1}).insert == "customVariable")
lines[1] = "local customReplacement = 1"
assert(a.suggest({mode="editor",prefix="custom",lines=lines,revision=2}).insert == "customReplacement")
print("autocomplete path and module tests passed")
