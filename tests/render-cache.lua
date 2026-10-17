package.path="./?.lua;"..package.path
package.loaded["system.gui.theme"]={currentId="mint",get=function() return 1 end}
package.loaded["system.gui.renderer"]={fill=function() end,writeAt=function() end,crop=function(t,w) return t:sub(1,w) end}
local parent={}
term={getSize=function() return 80,30 end,current=function() return parent end,
  redirect=function(target) local old=parent parent=target return old end,
  setBackgroundColor=function() end,setTextColor=function() end,clear=function() end}
window={create=function() return {setVisible=function() end,reposition=function() end} end}
local Window=require("system.wm.window")
local draws=0
local app={draw=function() draws=draws+1 end}
local win=Window.new({id=1,w=30,h=20,app=app})
win:draw() win:draw() assert(draws==1,"clean window drew twice")
win.dirty=true win:draw() assert(draws==2)
win.w=40 win:draw() assert(draws==3,"resize reused wrong-size content")
package.loaded["system.gui.theme"].currentId="dark" win:draw() assert(draws==4)
app.canClose=function() return false end
assert(not win:requestClose() and not win.closed and win.dirty)
app.canClose=function() return true end
assert(win:requestClose() and win.closed)
print("per-window render cache, resize/theme invalidation and close veto passed")
