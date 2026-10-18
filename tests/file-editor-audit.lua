package.path = "./?.lua;" .. package.path

local nodes, denied, failWrite, failMove, failDelete = {}, nil, nil, nil, nil
local function norm(path)
  local parts = {}
  for p in path:gsub("\\", "/"):gmatch("[^/]+") do
    if p == ".." then table.remove(parts) elseif p ~= "." then parts[#parts+1] = p end
  end
  return "/" .. table.concat(parts, "/")
end
fs = {
  combine = function(a,b) return norm(a .. "/" .. b):sub(2) end,
  getName = function(p) return norm(p):match("([^/]+)$") or "" end,
  getDir = function(p) return norm(p):match("^(.*)/[^/]+$") or "" end,
  exists = function(p) return nodes[norm(p)] ~= nil end,
  isDir = function(p) return nodes[norm(p)] == true end,
  makeDir = function(p)
    p = norm(p)
    assert(nodes[p] == nil or nodes[p] == true)
    nodes[p] = true
    local parent = fs.getDir(p)
    if parent ~= "" and parent ~= "/" then fs.makeDir(parent) end
  end,
  list = function(p)
    local out = {}
    p = norm(p)
    for key in pairs(nodes) do
      if key:sub(1,#p+1) == p .. "/" and not key:sub(#p+2):find("/",1,true) then out[#out+1] = key:sub(#p+2) end
    end
    return out
  end,
  open = function(p, mode)
    p = norm(p)
    if mode == "r" then
      if type(nodes[p]) ~= "string" then return nil end
      return {readAll=function() return nodes[p] end, close=function() end}
    end
    assert(nodes[fs.getDir(p)] == true, "missing directory " .. fs.getDir(p))
    nodes[p] = ""
    return {write=function(s) if failWrite and p:find(failWrite,1,true) then error("disk full") end nodes[p]=s end, close=function() end}
  end,
  move = function(a,b)
    a,b = norm(a),norm(b)
    if failMove and a == failMove then error("move failed") end
    assert(nodes[a] ~= nil and nodes[b] == nil, "unsafe move " .. a .. " -> " .. b)
    local moved = {}
    for key,value in pairs(nodes) do
      if key == a or key:sub(1,#a+1) == a .. "/" then moved[b .. key:sub(#a+1)] = value nodes[key] = nil end
    end
    for key,value in pairs(moved) do nodes[key] = value end
  end,
  delete = function(p)
    p = norm(p)
    if failDelete and p == failDelete then error("delete failed") end
    for key in pairs(nodes) do if key == p or key:sub(1,#p+1) == p .. "/" then nodes[key]=nil end end
  end,
}
local records, serial = {}, 0
textutils = {
  serialize=function(record) serial=serial+1 local key="record:" .. serial records[key]=record return key end,
  unserialize=function(key) return records[key] end,
}
colors = {white=1, black=2, gray=4, lightGray=8, orange=16, red=32, cyan=64}
keys = {escape=1,enter=2,backspace=3,tab=4,up=5,down=6,left=7,right=8}
term = {getSize=function() return 51,19 end}
local drawW,drawH,keyboardDraws = 100,100,0
package.loaded["system.gui.renderer"] = {
  writeAt=function(x,y,s,fg,bg) assert(x>=1 and y>=1 and y<=drawH and x+#s-1<=drawW, "draw outside viewport") assert(fg and bg) end,
  crop=function(s,w) return s:sub(1,w) end,
  button=function(x,y,w,label) assert(x>=1 and y>=1 and x+w-1<=drawW and y<=drawH) end,
}
package.loaded["system.gui.theme"] = {get=function() return 1 end}
package.loaded["system.gui.keyboard"] = {
  height=function() return 7 end,
  draw=function(x,y,w,state) assert(y>=1 and y+6<=drawH) state.boxes={} keyboardDraws=keyboardDraws+1 end,
  handle=function() return false end,
}
package.loaded["system.dev.autocomplete"] = {prefix=function() return "" end, suggest=function() return nil end}
local ui = require("system.gui.components")
local realToolbar, boxes = ui.toolbar, nil
ui.toolbar = function(...) boxes=realToolbar(...) return boxes end
local notices, checks = {}, {}
local function start(module,path)
  local app,win
  local ctx = {pid=12,args={path=path},security={require=function(permission,target)
    checks[#checks+1]={permission,target}
    return not (denied and denied(permission,norm(target))), "permission denied"
  end},notifications={push=function(_,kind,title,message) notices[#notices+1]=message end},apps={launch=function() end},
    windowManager={create=function(_,opts) app=opts.app win={closed=false} return win end},pullEvent=function() coroutine.yield() end}
  local co=coroutine.create(function() require(module).run(ctx) end)
  local ok,err=coroutine.resume(co)
  assert(ok,err)
  return app,win
end
local function draw(app,w,h)
  drawW,drawH=w or 80,h or 18
  app:draw(drawW,drawH)
end
local function action(app,id,w,h)
  for _=1,20 do
    draw(app,w,h)
    local nextBox
    for _,box in ipairs(boxes) do
      if box.id==id then assert(app:handle({name="mouse_click",args={1,box.x,box.y}})) return end
      if box.delta==1 then nextBox=box end
    end
    assert(nextBox,"missing action " .. id)
    app:handle({name="mouse_click",args={1,nextBox.x,nextBox.y}})
  end
  error("unreachable action " .. id)
end
local function reset()
  nodes,denied,failWrite,failMove,failDelete={},{},nil,nil,nil
  denied=nil
  fs.makeDir("/home/user/docs")
  fs.makeDir("/var/tmp")
end
local trash="/home/user/.trash"
local metadata=trash .. "/.mintcraft-metadata"

reset()
nodes["/home/user/docs/report.123"]="first"
local files=start("apps.files.main","/home/user/docs")
files.selected="report.123"
action(files,"delete")
assert(files.confirm=="trash" and nodes["/home/user/docs/report.123"]=="first")
action(files,"cancel")
assert(nodes["/home/user/docs/report.123"]=="first")
action(files,"delete") action(files,"confirm")
assert(nodes[trash .. "/report.123"]=="first" and not nodes["/home/user/docs/report.123"])
local info=records[nodes[metadata .. "/report.123"]]
assert(info.original=="/home/user/docs/report.123" and info.name=="report.123")
nodes["/home/user/docs/report.123"]="second"
files.selected="report.123"
action(files,"delete") action(files,"confirm")
assert(nodes[trash .. "/report.123.1"]=="second")
files.path,files.selected=trash,"report.123"
action(files,"restore")
assert(nodes["/home/user/docs/report.123"]=="first")
files.selected="report.123.1"
action(files,"restore")
assert(nodes[trash .. "/report.123.1"]=="second" and nodes["/home/user/docs/report.123"]=="first")
fs.delete("/home/user/docs/report.123")
action(files,"restore")
assert(nodes["/home/user/docs/report.123"]=="second" and not nodes[metadata .. "/report.123.1"])
nodes[trash .. "/legacy.42"]="legacy"
files.selected="legacy.42" action(files,"restore")
assert(nodes["/home/user/legacy.42"]=="legacy" and not nodes["/home/user/legacy"])

reset()
nodes["/home/user/docs/a.txt"]="original"
files=start("apps.files.main","/home/user/docs") files.selected="a.txt"
failWrite=".mintcraft-metadata"
action(files,"delete") action(files,"confirm")
assert(nodes["/home/user/docs/a.txt"]=="original" and not nodes[trash .. "/a.txt"])
failWrite=nil failMove="/home/user/docs/a.txt"
action(files,"confirm")
assert(nodes["/home/user/docs/a.txt"]=="original" and nodes[metadata .. "/a.txt"])
failMove=nil action(files,"confirm")
assert(nodes[trash .. "/a.txt.1"]=="original", "orphan metadata reused")
files.path,files.selected=trash,"a.txt.1"
nodes[metadata .. "/a.txt.1"]="corrupt"
action(files,"restore") assert(nodes[trash .. "/a.txt.1"]=="original")
action(files,"delete_forever") action(files,"cancel") assert(nodes[trash .. "/a.txt.1"])
action(files,"delete_forever") action(files,"confirm") assert(not nodes[trash .. "/a.txt.1"])
nodes[trash .. "/one"],nodes[trash .. "/two"]="one","two"
action(files,"empty_trash")
denied=function(permission,target) return permission=="filesystem.write" and target==trash .. "/two" end
action(files,"confirm") assert(nodes[trash .. "/one"] and nodes[trash .. "/two"],"partial permission-denied deletion")
denied=nil action(files,"confirm") assert(not nodes[trash .. "/one"] and not nodes[trash .. "/two"])
assert(nodes[metadata .. "/a.txt"],"interrupted-operation recovery metadata deleted")

reset()
nodes["/system"],nodes["/system/test.lua"]=true,"OS"
files=start("apps.files.main","/system") files.selected="test.lua"
action(files,"delete_forever") assert(not files.confirm and nodes["/system/test.lua"]=="OS")
action(files,"new_file") files.input="new.lua" files.keyboard.onEnter()
assert(not nodes["/system/new.lua"])
files.path="/home/user/docs" files.mode=nil
nodes["/home/user/docs/keep.txt"]="keep"
action(files,"new_file") files.input="keep.txt" files.keyboard.onEnter()
assert(nodes["/home/user/docs/keep.txt"]=="keep")
action(files,"cancel")
denied=function(permission) return permission=="filesystem.write" end
action(files,"new_file") files.input="denied.txt" files.keyboard.onEnter()
assert(not nodes["/home/user/docs/denied.txt"])
denied=function(permission) return permission=="filesystem.read" end
files.mode=nil action(files,"refresh") assert(#files.files==0)

reset()
local path="/home/user/docs/edit.lua"
nodes[path]="original"
local editor,win=start("apps.editor.main",path)
assert(editor:canClose(win)==true)
editor:handle({name="char",args={"X"}})
local draft
for p,v in pairs(nodes) do if p:match("%.draft$") then draft=p assert(records[v].text=="Xoriginal") end end
assert(draft and nodes[path]=="original")
assert(editor:canClose(win)==false and not win.closed)
editor:handle({name="char",args={"ignored"}})
assert(editor.lines[1]=="Xoriginal")
action(editor,"cancel") assert(not win.closed and not editor.closePrompt)
local recovered,recoveredWin=start("apps.editor.main",path)
assert(recovered.lines[1]=="Xoriginal" and recovered.status=="Recovered unsaved draft")
assert(recovered:canClose(recoveredWin)==false)
denied=function(permission) return permission=="filesystem.write" end
action(recovered,"save") assert(not recoveredWin.closed and nodes[path]=="original")
denied=nil failWrite=path .. ".mintcraft-save/next"
action(recovered,"save") assert(not recoveredWin.closed and nodes[path]=="original")
failWrite=nil action(recovered,"save")
assert(recoveredWin.closed and nodes[path]=="Xoriginal" and not nodes[draft])

editor,win=start("apps.editor.main",path)
editor:handle({name="paste",args={"draft\n"}})
assert(editor:canClose(win)==false)
action(editor,"discard") assert(win.closed and nodes[path]=="Xoriginal" and not nodes[draft])
editor,win=start("apps.editor.main",path)
editor:handle({name="char",args={"Y"}})
nodes[path]="external"
editor:canClose(win) action(editor,"save")
assert(not win.closed and nodes[path]=="external" and editor.status:find("changed on disk",1,true))
action(editor,"cancel")
local later,laterWin=start("apps.editor.main",path)
assert(later.lines[1]=="YXoriginal")
later:canClose(laterWin) action(later,"save") assert(not laterWin.closed and nodes[path]=="external")
action(later,"discard")

editor,win=start("apps.editor.main",path)
editor:handle({name="char",args={"Z"}})
editor:handle({name="key",args={keys.backspace}})
assert(not nodes[draft],"reverted edits left a stale recovery draft")
local kbBefore=keyboardDraws
draw(editor,47,14) assert(keyboardDraws==kbBefore+1)
action(editor,"keyboard")
local hiddenCount=keyboardDraws
draw(editor,47,14) assert(keyboardDraws==hiddenCount and not editor.keyboardVisible)
action(editor,"keyboard")
draw(editor,47,14) assert(keyboardDraws==hiddenCount+1 and editor.keyboardVisible)
for _,size in ipairs({{12,5},{26,10},{47,14},{1,1}}) do draw(editor,size[1],size[2]) end
editor:handle({name="char",args={"Q"}}) editor:canClose(win)
for _,size in ipairs({{12,5},{26,10},{47,14},{1,1}}) do draw(editor,size[1],size[2]) end
action(editor,"cancel",12,5) assert(not win.closed)

reset()
nodes[path]="base"
local first=start("apps.editor.main",path)
local second=start("apps.editor.main",path)
first:handle({name="char",args={"A"}})
second:handle({name="char",args={"B"}})
for p,v in pairs(nodes) do if p:match("%.draft$") then assert(records[v].text=="Abase","another editor's draft overwritten") end end
assert(second.status:find("another editor",1,true))

reset()
nodes["/home/user/docs/original.txt"]="original"
local explorer=start("apps.files.main","/home/user/docs")
explorer.graphicsActive=true
local Surface=require("system.graphics.surface")
local palette={desktop=15,panel=7,button=8,border=8,text=0,muted=8,accent=9,ink=15}
local function pixelDraw(width,height)
  local saved={list=fs.list,open=fs.open,exists=fs.exists,isDir=fs.isDir}
  for key in pairs(saved) do fs[key]=function() error("filesystem acquisition in native draw") end end
  local ok,err=pcall(explorer.drawPixels,explorer,Surface.new(width or 420,height or 210,15),width or 420,height or 210,palette)
  for key,value in pairs(saved) do fs[key]=value end
  assert(ok,err)
end
local function pixelClick(rect) assert(explorer:handlePixels({name="mouse_click",args={1,rect.x+1,rect.y+1}})) end
local function pixelAction(id)
  for _=1,20 do
    pixelDraw()
    for _,hit in ipairs(explorer.pixelButtons) do if hit.id==id then pixelClick(hit.rect) return end end
    if not explorer.nativeMenu then
      for _,hit in ipairs(explorer.pixelButtons) do if hit.id=="menu" then pixelClick(hit.rect) break end end
    else
      local found
      for _,hit in ipairs(explorer.pixelMenuItems) do if hit.id==id then found=hit break end end
      if found then pixelClick(found.rect) return end
      for _,hit in ipairs(explorer.pixelButtons) do if hit.id=="menu_next" then pixelClick(hit.rect) break end end
    end
  end
  error("native action unreachable: "..id)
end
pixelDraw(154,122)
explorer:handlePixels({name="mouse_click",args={1,explorer.pixelSearch.x+2,explorer.pixelSearch.y+2}})
explorer:handle({name="paste",args={"original"}})
pixelDraw(154,122) assert(#explorer.pixelFileRows==1 and explorer.pixelFileRows[1].name=="original.txt")
explorer.nativeQuery="" explorer.nativeSearchFocused=false
pixelAction("new_file")
explorer.input="" explorer:handle({name="paste",args={"native.txt"}})
pixelAction("submit") assert(nodes["/home/user/docs/native.txt"]=="")
explorer.selected="native.txt" pixelAction("rename")
explorer.input="renamed.txt" pixelAction("submit")
assert(nodes["/home/user/docs/native.txt"]==nil and nodes["/home/user/docs/renamed.txt"]=="")
pixelAction("delete") assert(explorer.confirm=="trash" and nodes["/home/user/docs/renamed.txt"]=="")
pixelAction("cancel") assert(nodes["/home/user/docs/renamed.txt"]=="")
pixelAction("delete") pixelAction("confirm")
assert(not nodes["/home/user/docs/renamed.txt"] and nodes[trash.."/renamed.txt"]=="")
pixelAction("up") pixelDraw()
for _,hit in ipairs(explorer.pixelFileRows) do if hit.name==".trash" then pixelClick(hit.rect) pixelClick(hit.rect) break end end
assert(explorer.path==trash)
explorer.selected="renamed.txt" pixelAction("restore")
assert(nodes["/home/user/docs/renamed.txt"]=="")
fs.makeDir("/system") nodes["/system/kernel.lua"]="protected"
explorer.path="/system" explorer.selected="kernel.lua" explorer.files={"kernel.lua"} explorer.directories={} explorer.fileRevision=100
pixelAction("delete") assert(not explorer.confirm and nodes["/system/kernel.lua"]=="protected")
print("file/editor audit and native Files: no draw acquisition, search, create, rename, confirmed trash, restore and protected paths passed")
