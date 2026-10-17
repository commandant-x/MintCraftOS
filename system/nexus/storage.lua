local M={}
function M.read(path)
  local h=fs.open(path,"r") if not h then return nil end
  local value=h.readAll() h.close() return value
end
function M.load(path,default)
  local data=M.read(path)
  if not data or #data>262144 then return default end
  local ok,value=pcall(textutils.unserialize,data)
  return ok and type(value)=="table" and value or default
end
function M.write(path,data)
  assert(type(data)=="string" and #data<=262144,"NEXUS file too large")
  fs.makeDir(fs.getDir(path))
  local pending,backup=path..".pending",path..".backup"
  if fs.exists(pending) then fs.delete(pending) end
  local h=assert(fs.open(pending,"w"),"Cannot write "..path)
  h.write(data) h.close()
  assert(M.read(pending)==data,"NEXUS write verification failed")
  if fs.exists(backup) then fs.delete(backup) end
  if fs.exists(path) then fs.move(path,backup) end
  fs.move(pending,path)
  return true
end
function M.save(path,value) return M.write(path,textutils.serialize(value)) end
function M.recover(path)
  if not fs.exists(path) and fs.exists(path..".backup") then fs.move(path..".backup",path) end
end
return M
