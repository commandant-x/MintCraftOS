package.path='./?.lua;'..package.path
os.time=function() return 12 end
package.loaded['system.gui.theme']={currentId='mint'}
local Surface=require('system.graphics.surface')
local Workspace=require('system.graphics.workspace')
local wm={windows={},active=function(self) return self.windows[#self.windows] end}
local ctx={wm=wm,apps={list=function() return {} end},notifications={queue={}}}
local backend={mode=1,surface=Surface.new(600,360,15),caps={textWidth=100,textHeight=40}}
local workspace=Workspace.new(ctx) workspace.cacheLimit=40000
local count=0
for i=1,3 do wm.windows[i]={id=i,title='Native '..i,x=i*4,y=i*3,w=38,h=14,surfaceRevision=1,
 app={drawPixels=function() end,handlePixels=function() end},
 drawPixels=function(_,canvas,w,h) count=count+1 canvas:rect(0,0,w,h,7) return true end} end
local function frame() workspace:prepare(backend) workspace:draw(backend) assert(workspace.cacheBytes<=workspace.cacheLimit) end
frame()
assert(workspace.content[3].surface,'active window did not get cache priority')
for i=1,20 do frame() end
local cached=workspace.content[3].surface
wm.windows[3].pixelBounds.x=wm.windows[3].pixelBounds.x+1 frame()
assert(workspace.content[3].surface==cached,'move rebuilt native client')
wm.windows[3].minimized=true frame()
assert(not workspace.content[3],'minimized surface retained')
wm.windows[3].minimized=false frame()
assert(workspace.content[3].surface and workspace.stats.cacheHits>0)
assert(workspace.stats.cacheMisses>0 and workspace.stats.cacheEvictions>0)
print('graphics cache: bounded bytes, active-window priority, unchanged/moved reuse, minimize eviction and restore passed')
