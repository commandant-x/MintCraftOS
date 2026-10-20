package.path = "./?.lua;" .. package.path
local writes, keyboardTop = {}, nil
package.loaded["system.gui.renderer"] = {writeAt = function(x,y,text) writes[y] = text end, crop = function(t) return t end, button=function() end}
package.loaded["system.gui.theme"] = {get=function() return 1 end}
package.loaded["system.gui.keyboard"] = {height = function() return 7 end, draw = function(x,y) keyboardTop = y end}
package.loaded["system.dev.autocomplete"] = {prefix = function() return "" end, suggest = function() return nil end}
colors = {white=1,gray=2,black=3,lightGray=4,orange=5}
term = {getSize = function() return 51,19 end}
local allowWrite, compiled, removed = false, 0, nil
fs = {
  exists = function() return false end,
  open = function() if allowWrite then return {write=function() end,close=function() end} end end,
  delete = function(path) removed = path end,
}
loadfile = function(path) compiled = compiled + 1 return function() error("must not execute compiled code") end end
local app,release,cleanup,unhooked
local ctx = {pid=42,args={},security={require=function() return true end},windowManager={create=function(_,opts) app=opts.app return {closed=false} end},pullEvent=function() coroutine.yield() end,
  system={eventBus={on=function(_,name,fn) assert(name=='key_up') release=fn return 1 end,off=function(_,id) assert(id==1) unhooked=true end}},onCleanup=function(fn) cleanup=fn end}
local co = coroutine.create(function() require("apps.editor.main").run(ctx) end)
assert(coroutine.resume(co))
app:draw(47,14)
app:handle({name="mouse_click",args={1,9,1}})
assert(compiled == 0 and app.status:find("cannot write",1,true))
allowWrite = true
app:handle({name="mouse_click",args={1,9,1}})
assert(compiled == 1 and app.status == "Compile OK")
assert(removed == "/var/tmp/editor_compile_42.lua")
app:draw(47,14)
assert(writes[6]:find("Compile OK",1,true) and keyboardTop == 8, "status hidden behind keyboard")
keys = {up=1,down=2,left=3,right=4,backspace=5,enter=6,tab=7}
app.lines, app.cy, app.cx = {"long line", "x"}, 1, 10
app:handle({name="key",args={keys.down}})
assert(app.cy == 2 and app.cx == 2)
app:handle({name="key",args={keys.right}})
assert(app.cx == 2)
app.cx = 1
app:handle({name="key",args={keys.backspace}})
assert(#app.lines == 1 and app.lines[1] == "long linex" and app.cx == 10)
app.lines, app.cy, app.cx = {"ab"}, 1, 2
app:handle({name="paste",args={"x\ny"}})
assert(app.lines[1] == "ax" and app.lines[2] == "yb" and app.cy == 2 and app.cx == 2)
app.cx = 1
app.keyboard.onBackspace()
assert(#app.lines == 1 and app.lines[1] == "axyb")
local completion = package.loaded["system.dev.autocomplete"]
completion.suggest = function() return {label="function",insert="function()\nend",kind="snippet"} end
completion.apply = function() return "function()\nend suffix", 15 end
app.lines, app.cy, app.cx = {"fun suffix", "following line"}, 1, 4
app.keyboard.onTab()
assert(#app.lines == 3 and app.lines[1] == "function()" and app.lines[2] == "end suffix")
assert(app.lines[3] == "following line" and app.cy == 2 and app.cx == 4)
for _, line in ipairs(app.lines) do assert(not line:find("\n",1,true)) end
app.lines={'one','two','three'} app.anchor={row=1,col=2} app.cy=3 app.cx=3
app:insert('X') assert(#app.lines==1 and app.lines[1]=='oXree' and app.cy==1 and app.cx==3)
app:action('find') local before=table.concat(app.lines,'\n') app.keyboard.onText('X')
assert(app.searchQuery=='X' and table.concat(app.lines,'\n')==before,'find input edited source')
app:action('findNext') assert(require('apps.editor.editing').selected(app)=='X')
app.searchOpen=false app:insert('Y') assert(app.lines[1]=='oYree','search selection replacement failed')
local oldSuggest=completion.suggest local calls=0
completion.suggest=function(...) calls=calls+1 return oldSuggest(...) end
app:refreshCompletion() local before=calls app:draw(47,14)
assert(calls==before,'drawing queried autocomplete sources')
keys.leftCtrl=99 keys.leftShift=100 app.controlHeld=true app.shiftHeld=true
release(keys.leftCtrl) release(keys.leftShift) assert(not app.controlHeld and not app.shiftHeld,'unfocused modifier release was lost')
cleanup() assert(unhooked,'modifier listener leaked after close')
print("editor compile tests passed")
