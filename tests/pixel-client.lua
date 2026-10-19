package.path="./?.lua;"..package.path
package.loaded["system.gui.theme"]={get=function() return 1 end}
package.loaded["system.gui.renderer"]={}
term={getSize=function() return 80,30 end}
local Window=require("system.wm.window")
local Surface=require("system.graphics.surface")
local View=require("system.graphics.view")
local surface=Surface.new(40,30,15)
local errors=0
local app={drawPixels=function(_,s,w,h)
  assert(w==10 and h==12)
  s:rect(-100,-100,1000,1000,4)
end,handlePixels=function(_,e) assert(e.args[2]==0) return true end}
local win=Window.new({app=app,onError=function() errors=errors+1 end})
assert(not pcall(Window.new,{minPixelWidth="invalid"}) and not pcall(Window.new,{minPixelHeight=0/0}))
win.pixelManaged=true win.w,win.h=102,55 win:clamp()
assert(win.w==102 and win.h==55,"physical text grid constrained a pixel-sized virtual client")
assert(win:drawPixels(View.new(surface,5,7,10,12),10,12,{}))
assert(surface.rows[8]:byte(6)==4 and surface.rows[8]:byte(5)==15 and surface.rows[20]:byte(6)==15,"client escaped clipping")
local old=surface:setClip(7,8,2,3)
View.new(surface,5,7,10,12):rect(0,0,10,12,2)
assert(surface.rows[9]:byte(8)==2 and surface.rows[9]:byte(7)==4)
surface.clip=old
win.dirty=false assert(win:handlePixels({name="mouse_click",args={1,0,0}}) and win.dirty)
win.pixelNative=true win.dirty=true
win:draw() assert(win.surfaceRevision==1 and not win.dirty,"native client did not publish invalidation")
win:draw() assert(win.surfaceRevision==1,"static native window revision changed")
app.drawPixels=function() error("application draw failure") end
assert(not win:drawPixels(View.new(surface,0,0,10,12),10,12,{}) and win.closed and errors==1)
win.closed=false app.handlePixels=function() error("application input failure") end
assert(win:handlePixels({name="mouse_click",args={1,0,0}}) and win.closed and errors==2)
print("native app contract: local clipping, damage clip preservation and per-app draw/input crash isolation passed")
