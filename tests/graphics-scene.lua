package.path="./?.lua;"..package.path
local Surface=require("system.graphics.surface")
local Scene=require("system.graphics.scene")
local s=Surface.new(40,30,15)
local scene=Scene.new()
local calls=0
local background={id="background",x=0,y=0,w=40,h=30,revision=1,draw=function(canvas)
  calls=calls+1 canvas:rect(0,0,40,30,15)
end}
local layer={id="window",x=3,y=5,w=10,h=10,revision=1}
layer.draw=function(canvas) canvas:rect(layer.x,layer.y,layer.w,layer.h,4) end
assert(scene:draw(s,{background,layer})==1 and s.rows[6]:byte(4)==4)
s.dirty={}
assert(scene:draw(s,{background,layer})==0 and next(s.dirty)==nil and calls==1)
layer.revision=2 scene:draw(s,{background,layer})
assert(next(s.dirty)==nil,"identical pixels were retransmitted after layer invalidation")
layer.x,layer.revision=5,3
scene:draw(s,{background,layer})
assert(s.rows[6]:byte(4)==15 and s.rows[6]:byte(6)==4,"old window position not repaired")
local before=calls
background.revision=2 scene:draw(s,{background,layer}) assert(calls>before)
s.dirty={}
scene:draw(s,{background}) assert(s.rows[6]:byte(6)==15,"closed window left pixels")
assert(not s.dirty[1],"closing a small layer repainted the whole screen")
local upper={id="upper",x=6,y=6,w=8,h=8,revision=1,draw=function(canvas) canvas:rect(6,6,8,8,2) end}
scene:draw(s,{background,layer,upper}) assert(s.rows[7]:byte(7)==2)
s.dirty={}
scene:draw(s,{background,upper,layer})
assert(s.rows[7]:byte(7)==4 and not s.dirty[1],"z-order change was not locally recomposed")
scene:draw(s,{background})
local old=s:setClip(10,10,3,3)
s:span(0,10,string.rep(string.char(2),40))
assert(s.rows[11]:byte(10)==15 and s.rows[11]:byte(11)==2 and s.rows[11]:byte(14)==15)
s.clip=old
local broken={id="broken",x=0,y=0,w=1,h=1,revision=1,draw=function() error("render fault") end}
assert(not pcall(scene.draw,scene,s,{background,broken}) and s.clip==old)
assert(scene:draw(s,{background})==1,"failed composition did not invalidate")
print("pixel scene: static frames, dirty rectangles, move/remove repair, clipping and exception restoration passed")
