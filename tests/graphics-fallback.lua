package.path="./?.lua;"..package.path
local mode,frozen,blits=0,false,0
local native={getSize=function(m) return m and m>0 and 120 or 20,m and m>0 and 90 or 10 end,
  setGraphicsMode=function(m) mode=m end,getGraphicsMode=function() return mode end,
  setFrozen=function(v) frozen=v end,getFrozen=function() return frozen end,
  drawPixels=function() end,getCursorPos=function() return 3,3 end,getCursorBlink=function() return false end,
  setCursorPos=function() end,setCursorBlink=function() end,blit=function() blits=blits+1 end}
local current=native
term={current=function() return current end,native=function() return native end,redirect=function(t) current=t end}
window={create=function() return {setVisible=function() end,getLine=function() return string.rep(" ",20),string.rep("0",20),string.rep("f",20) end} end}
local compositor=require("system.gui.compositor")
for _,phase in ipairs({"prepare","draw"}) do
  local errors=0 local before=blits
  local screen=compositor.new(function() return native end,nil,{mode="auto",
    beforeRender=function() if phase=="prepare" then error("prepare failed") end end,
    pixelRender=function() if phase=="draw" then error("drawing failed") end end,
    onGraphicsFailure=function() errors=errors+1 end})
  assert(screen:draw(function() end),"pixel shell failure crashed OS")
  assert(screen:stats().backend=="TEXT" and mode==0 and not frozen and errors==1)
  local caps=screen:capabilities() caps.backend="corrupted"
  assert(screen:capabilities().backend=="TEXT","caller mutated capability cache")
  assert(blits==before+10,"text fallback did not repaint all rows")
end
local palettes={[16]={0.1,0.2,0.3}}
native.getPaletteColor=function(i) return table.unpack(palettes[i] or {0,0,0}) end
native.setPaletteColor=function(i,r,g,b) palettes[i]=g and {r,g,b} or {1,1,1} end
local backend=require("system.graphics.backend").new(native,"auto")
backend:palette(16,0xabcdef) backend:palette(16,0x123456) backend:close()
assert(palettes[16][1]==0.1 and palettes[16][3]==0.3,"extended palette leaked after graphics close")
print("pixel shell: preparation/render exceptions repaint text, thaw the display and restore palettes")
