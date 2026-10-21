package.path='./?.lua;'..package.path
local Backend=require('system.graphics.backend')
local Surface=require('system.graphics.surface')
local function target(mode16,single)
  local mode,frozen=0,false
  local calls={freeze=0,draw=0,palette=0,bytes=0}
  local pixels={}
  local t={getSize=function(m) if m and m~=0 then return 960,540 end return 51,19 end,
    getGraphicsMode=function() return mode end,setGraphicsMode=function(m) if mode16 and m==2 then error('no 256') end mode=m end,
    getFrozen=function() return frozen end,setFrozen=function(v) frozen=v calls.freeze=calls.freeze+1 end,
    getPaletteColor=function() return 1,1,1 end,setPaletteColor=function() calls.palette=calls.palette+1 end,
    drawPixels=function(x,y,rows)
      if single and #rows>1 then error('single row only') end
      assert(x>=0 and y>=0 and y+#rows<=540)
      calls.draw=calls.draw+1
      for i,row in ipairs(rows) do
        assert(x+#row<=960)
        local old=pixels[y+i] or string.rep(string.char(15),960)
        pixels[y+i]=old:sub(1,x)..row..old:sub(x+#row+1)
        calls.bytes=calls.bytes+#row
      end
    end}
  return t,calls,pixels
end
for _,batch in ipairs({4,8,16,32}) do
  local t,c,pixels=target()
  local b=Backend.new(t,'auto',{batchRows=batch})
  assert(b:present())
  local draws,freeze=c.draw,c.freeze
  for i=1,1000 do assert(b:present()) end
  assert(c.draw==draws and c.freeze==freeze and b.frames==1 and b.skippedPresents==1000)
  b:palette(16,0x123456) assert(b:present()) assert(c.freeze==freeze+2 and c.palette==1)
  local bytes=c.bytes
  b.surface:pixel(0,0,1) b.surface:pixel(959,0,2)
  assert(b:present() and c.bytes==bytes+2,'distant pixels submitted unchanged center')
  b.surface:rect(10,10,20,34,5) assert(b:present())
  for y=1,540 do assert(pixels[y]==b.surface.rows[y],'batched framebuffer mismatch') end
  b.surface:pixel(0,0,4)
  t.drawPixels=function() error('GPU failure') end
  assert(not b:present() and b.mode==0 and not t.getFrozen() and not next(b.surface.dirty))
end
local t,c=target(true,true) local b=Backend.new(t,'auto')
assert(b.mode==1 and b:present() and b.batchRows==1 and b.drawCalls==542)
assert(Backend.new(t,'text').mode==0)
local s=Surface.new(100,2,15) s.dirty={}
for x=0,98,2 do s:pixel(x,0,1) end
assert(#(s.dirty[1].spans or {s.dirty[1]})<=8)
local Scene=require('system.graphics.scene')
local scene=Scene.new() local surf=Surface.new(100,20,15)
local function layer(id,x,w,rev,c) return {id=id,x=x,y=0,w=w,h=20,revision=rev,draw=function(out) out:rect(x,0,w,20,c) end} end
scene:draw(surf,{layer('a',0,10,1,1),layer('b',30,10,1,2),layer('c',8,24,1,3)})
surf.dirty={}
local count=scene:draw(surf,{layer('a',0,10,2,1),layer('b',30,10,2,2),layer('c',8,24,2,3)})
assert(count==1 and not next(surf.dirty),'transitive damage or identical frame handling failed')
print('graphics performance: 1000 idle presents, palette, batches 4/8/16/32, exact framebuffer, sparse spans, bounded fragmentation, single-row fallback, errors and transitive damage passed')
