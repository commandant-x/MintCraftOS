package.path='./?.lua;'..package.path
local Policy=require('system.graphics.policy')
local now=0
local p=Policy.new(Policy.options({}),function() return now end)
p:request(true) assert(p:delay()==0) p:presented()
for i=1,1000 do p:request(false) assert(not p:delay()) end
p:request(true) assert(p:delay()==0.05)
for i=1,100 do p:request(true) end
now=0.05 assert(p:delay()==0) p:presented() assert(p.frames==2 and p.skipped==1000)
assert(not Policy.options({graphicsProfile='stable'}).optimized)
assert(not Policy.options({graphicsOptimizations=false}).optimized)
assert(Policy.options({graphicsProfile='performance',graphicsMaxHz=10}).maxHz==10)
assert(Policy.options({graphicsMaxHz=0/0}).maxHz==20)
local ctx={wm={windows={{id=1,title='test',x=1,y=1,w=20,h=10,minimized=true,dirty=false}}},notifications={queue={}}}
package.loaded['system.gui.theme']={currentId='mint'}
local key=Policy.visibleKey(ctx,{revision=0})
ctx.wm.windows[1].dirty=true assert(key==Policy.visibleKey(ctx,{revision=0}),'minimized client requests frames')
ctx.wm.windows[1].minimized=false assert(key~=Policy.visibleKey(ctx,{revision=0}))
print('render policy: static requests, bounded coalescing, 10/20 Hz, disabled optimization and minimized invalidations passed')
