return function()
  local state = {nodes={["/"]=true}, hook=nil}
  local function normalized(path)
    path = path:gsub("/+", "/"):gsub("/$", "")
    return path == "" and "/" or path
  end
  local function event(action, path)
    if state.hook then state.hook(action, path) end
  end
  local function children(path)
    local result, seen = {}, {}
    local prefix = path == "/" and "/" or path .. "/"
    for key in pairs(state.nodes) do
      if key:sub(1,#prefix) == prefix then
        local name = key:sub(#prefix+1):match("^[^/]+")
        if name and not seen[name] then result[#result+1],seen[name]=name,true end
      end
    end
    table.sort(result)
    return result
  end
  local function mkdir(path)
    path = normalized(path)
    local parent = path:match("^(.*)/[^/]+$")
    if parent and parent ~= "" and parent ~= path then mkdir(parent) end
    assert(state.nodes[path] == nil or state.nodes[path] == true, "Directory conflicts with file")
    state.nodes[path] = true
  end
  local function copy(from, to, moving)
    from, to = normalized(from), normalized(to)
    assert(state.nodes[from] ~= nil and state.nodes[to] == nil, "Invalid copy/move")
    mkdir(to:match("^(.*)/[^/]+$") or "/")
    local changes = {}
    for key,value in pairs(state.nodes) do
      if key == from or key:sub(1,#from+1) == from .. "/" then changes[key]=value end
    end
    for key,value in pairs(changes) do
      state.nodes[to .. key:sub(#from+1)] = value
      if moving then state.nodes[key] = nil end
    end
    event(moving and "move" or "copy", to)
  end
  fs = {
    exists=function(path) return state.nodes[normalized(path)] ~= nil end,
    isDir=function(path) return state.nodes[normalized(path)] == true end,
    getDir=function(path) return normalized(path):match("^(.*)/[^/]+$") or "" end,
    combine=function(a,b) return normalized(a .. "/" .. b) end,
    list=function(path) return children(normalized(path)) end,
    getSize=function(path) return #(state.nodes[normalized(path)] or "") end,
    getFreeSpace=function() return 100000000 end,
    makeDir=function(path) mkdir(path) event("mkdir",normalized(path)) end,
    copy=function(a,b) copy(a,b,false) end,
    move=function(a,b) copy(a,b,true) end,
    delete=function(path)
      path=normalized(path)
      for key in pairs(state.nodes) do
        if key == path or key:sub(1,#path+1) == path .. "/" then state.nodes[key]=nil end
      end
      event("delete",path)
    end,
    open=function(path,mode)
      path=normalized(path)
      if mode == "r" then
        if type(state.nodes[path]) ~= "string" then return nil end
        return {readAll=function() return state.nodes[path] end, close=function() end}
      end
      assert(not fs.isDir(path), "Cannot open directory")
      mkdir(fs.getDir(path))
      state.nodes[path]=""
      event("open",path)
      return {write=function(value) state.nodes[path]=value event("write",path) end,
        writeLine=function(value) state.nodes[path]=state.nodes[path]..value.."\n" event("write",path) end,
        close=function() event("close",path) end}
    end,
  }
  local function serialize(value)
    if type(value) == "table" then
      local parts={"{"}
      for key,item in pairs(value) do parts[#parts+1]="["..serialize(key).."]="..serialize(item).."," end
      parts[#parts+1]="}"
      return table.concat(parts)
    end
    if type(value)=="string" then return string.format("%q",value) end
    return tostring(value)
  end
  textutils = {serialize=serialize,unserialize=function(data)
    local fn=load("return "..tostring(data),"metadata","t",{})
    if not fn then return nil end
    local ok,result=pcall(fn)
    return ok and result or nil
  end}
  state.put=function(path,value)
    mkdir(fs.getDir(path)) state.nodes[normalized(path)]=value
  end
  state.config=function(path,value) state.put(path,serialize(value)) end
  return state
end
