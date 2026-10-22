package.path='./?.lua;'..package.path
local Surface=require('system.graphics.surface')
local Scale=require('system.graphics.scale')
for _,factor in ipairs({1,1.5,2}) do
 local backend={mode=2,surface=Surface.new(640,400,15),palette=function() end}
 local scaler=Scale.new(factor) local proxy=scaler:prepare(backend)
 assert(proxy.surface.width==math.floor(640/factor))
 proxy.surface:rect(0,0,2,2,255) scaler:flush()
 for y=1,math.floor(2*factor) do for x=1,math.floor(2*factor) do assert(backend.surface.rows[y]:byte(x)==255,'palette byte changed by scale') end end
 local event={name='mouse_click',pixelX=30,pixelY=18,args={1,4,2}}
 local transformed=scaler:event(event)
 assert(transformed.pixelX==math.floor(30/factor) and transformed.pixelY==math.floor(18/factor))
 assert(event.pixelX==30 and transformed.args==event.args,'physical/text input mutated')
 if factor>1 then
  proxy.surface:span(3,5,string.char(200)) scaler:flush()
  assert(backend.surface.rows[math.floor(5*factor)+1]:byte(math.floor(3*factor)+1)==200)
  assert(not next(proxy.surface.dirty),'logical damage never cleared')
 end
 assert(not scaler:set(3))
 assert(scaler:set(1)) assert(scaler:prepare(backend)==backend)
end
local small={mode=2,surface=Surface.new(154,131,15)}
local scaler=Scale.new(2) assert(scaler:prepare(small)==small and scaler.effective==1)
print('UI scale: 1/1.5/2, physical framebuffer/palette preservation, scaled pointer mapping, dirty updates and small-display fallback passed')

scaler:deactivate() assert(scaler.effective==1 and scaler.requested==2)
assert(scaler:event({pixelX=20,pixelY=10}).pixelX==20,'text rescue kept scaled pointer mapping')
