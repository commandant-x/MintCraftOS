package.path="./?.lua;"..package.path
local Compositor=require("system.gui.compositor")
local Legacy=require("system.graphics.legacy")
local mode,frozen,created=2,true,0
local target={getSize=function(m) return m and m~=0 and 120 or 20,m and m~=0 and 90 or 10 end,
  getGraphicsMode=function() return mode end,setGraphicsMode=function(m) mode=m end,
  getFrozen=function() return frozen end,setFrozen=function(v) frozen=v end,
  getPaletteColour=function(c)
    if mode==2 then assert(c>=0 and c<=255,"invalid color "..c)
    else local valid=false for i=0,15 do if c==2^i then valid=true end end assert(valid,"invalid bitmask") end
    return 0,0,0
  end,
  getCursorPos=function() return 1,1 end,setCursorPos=function() end,
  getCursorBlink=function() return false end,setCursorBlink=function() end,
  blit=function() end,drawPixels=function() end}
local current=target
term={current=function() return current end,native=function() return target end,redirect=function(t) current=t end}
window={create=function(parent)
  created=created+1
  for i=0,15 do parent.getPaletteColour(2^i) end
  return {setVisible=function() end,getLine=function() return string.rep(" ",20),string.rep("0",20),string.rep("f",20) end}
end}
local text=Compositor.new(function() return target end,nil,{mode="text"})
assert(text:draw(function() end))
assert(mode==0 and not frozen and created==1,"text reboot inherited physical graphics state")
local proxy=Legacy.parent(target,2)
mode=2 proxy.getPaletteColour(32768)
mode=0 proxy.getPaletteColour(32768)
mode=false proxy.getPaletteColour(32768)
local failures=0
-- An incompatible ROM window implementation must fall back before boot fails.
local original=window.create
window.create=function(parent,...)
  if mode==2 then error("ROM window rejects indexed palette") end
  return original(parent,...)
end
local screen=Compositor.new(function() return target end,nil,{mode="auto",onGraphicsFailure=function() failures=failures+1 end})
assert(screen:draw(function() end))
assert(mode==0 and failures==1 and screen:stats().backend=="TEXT","window initialization escaped graphics fallback")
print("graphics routing: stale external mode reset, dynamic palette namespace and ROM-window fallback passed")
