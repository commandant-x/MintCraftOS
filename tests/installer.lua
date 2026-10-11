package.path = "./?.lua;" .. package.path
local files, dirs, failAt = {}, {}, nil
local function parent(p) return p:match("^(.*)/[^/]+$") or "" end
fs = {
  getDir = parent,
  exists = function(p) return files[p] ~= nil or dirs[p] == true end,
  isDir = function(p) return dirs[p] == true end,
  makeDir = function(p) dirs[p] = true end,
  delete = function(p)
    for k in pairs(files) do if k == p or k:sub(1,#p+1) == p.."/" then files[k] = nil end end
    for k in pairs(dirs) do if k == p or k:sub(1,#p+1) == p.."/" then dirs[k] = nil end end
  end,
  copy = function(a,b) assert(files[a], "missing source") files[b] = files[a] end,
  open = function(p, mode)
    if mode == "r" then
      if not files[p] then return nil end
      return {readAll=function() return files[p] end, close=function() end}
    end
    files[p] = ""
    return { write = function(s)
      if p == failAt then failAt = nil error("disk full") end
      files[p] = s
    end, close = function() end }
  end,
}
local journal
textutils = {
  serialize = function(t) journal = t return "journal" end,
  unserialize = function() return journal end,
}
local nativeLoadfile = loadfile
loadfile = function(p) return load(files[p], p) end
local installer = assert(nativeLoadfile("system/libraries/installer.lua"))()
files["/system/config/audio.cfg"] = "custom"
files["/home/user/note.txt"] = "personal"
files["/boot.lua"] = "return 'old'"
local bundle = {
  ["boot.lua"] = "return 'new'",
  ["system/config/audio.cfg"] = "default",
  ["home/user/note.txt"] = "sample",
  ["system/new.lua"] = "return true",
}
assert(installer.install(bundle))
assert(files["/boot.lua"] == bundle["boot.lua"])
assert(files["/system/config/audio.cfg"] == "custom" and files["/home/user/note.txt"] == "personal")
bundle["boot.lua"] = "invalid ! lua"
assert(not pcall(installer.install, bundle))
assert(files["/boot.lua"] == "return 'new'", "validation changed live files")
bundle["boot.lua"] = "return 'next'"
failAt = "/system/new.lua"
assert(not pcall(installer.install, bundle))
assert(files["/boot.lua"] == "return 'new'", "failed installation did not restore boot")
assert(files["/system/new.lua"] == "return true")
assert(not fs.exists("/var/tmp/mintcraft-install"))
assert(not pcall(installer.install, {["system/../../outside"]="bad"}))
dirs["/var/tmp/mintcraft-install"] = true
assert(not pcall(installer.install,bundle), "overwrote interrupted transaction")
print("installer tests passed")
