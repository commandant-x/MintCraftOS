package.path="./?.lua;"..package.path
local Backend=require("system.graphics.backend")
local Surface=require("system.graphics.surface")
local fonts=require("system.graphics.fonts")
local Legacy=require("system.graphics.legacy")
local input=require("system.kernel.input")
local function target(reject2)
  local mode,frozen,calls=0,false,{}
  local t={getSize=function(m) if m and m~=0 then return 306,171 end return 51,19 end,
    getGraphicsMode=function() return mode end,
    setGraphicsMode=function(m) if reject2 and m==2 then error("unsupported mode") end mode=m end,
    getFrozen=function() return frozen end,setFrozen=function(v) frozen=v end,
    drawPixels=function(x,y,rows)
      assert(x>=0 and y>=0 and x+#rows[1]<=306 and y+#rows<=171)
      calls[#calls+1]={x=x,y=y,rows=rows}
    end}
  return t,calls
end
local t,calls=target()
local b=Backend.new(t,"auto")
assert(b.mode==2 and b.caps.backend=="PIXEL256" and b.surface.width==306)
assert(b:present() and not t.getFrozen())
local count=#calls
assert(b:present() and #calls==count,"static framebuffer rewritten")
b.surface:rect(-4,-4,6,6,4)
assert(b.surface.rows[1]:sub(1,3)==string.char(4,4,15))
assert(b:present() and #calls==count+2,"dirty spans not isolated")
fonts.draw(b.surface,2,2,"MintCraft",0,15)
assert(fonts.measure("a\nb")==6)
assert(b:present())
local before=b.surface.rows[1]
b.surface:pixel(306,0,1) assert(b.surface.rows[1]==before)
local pixel16=Backend.new(target(true),"auto") assert(pixel16.mode==1)
assert(pixel16.generation~=b.generation and Backend.new(target(),"auto").generation~=b.generation,"backend replacement reused counter generation")
assert(Backend.new({getSize=function() return 51,19 end},"auto").mode==0)
assert(Backend.new(t,"text").mode==0)
local failed=Backend.new(t,"auto")
t.drawPixels=function() error("GPU failure") end
assert(not failed:present() and failed.mode==0 and t.getGraphicsMode()==0 and not t.getFrozen())
local bounded=Surface.new(960,540,15)
assert(#bounded.rows==540 and #bounded.rows[540]==960)
assert(not pcall(Surface.new,4096,4096))
Legacy.row(bounded,1,"A"..string.char(129),"04","ff",160,60)
assert(bounded.rows[1]:byte(7)==4,"mosaic pixel lost")
local e=input.normalize({"mouse_click",1,305,170},{target="computer",width=51,height=19,pixelWidth=306,pixelHeight=171})
assert(e.args[2]==51 and e.args[3]==19 and e.pixelX==305)
assert(input.normalize({"mouse_click",1,0,0},{target="computer",width=51,height=19,pixelWidth=306,pixelHeight=171}).args[2]==1)
assert(not input.normalize({"terminal_char","left","x"},{target="computer"}))
assert(input.normalize({"terminal_paste","left","abc"},{target="terminal",terminalSide="left"}).args[1]=="abc")
local monitor=input.normalize({"monitor_touch","monitor_0",305,170},{target="monitor",monitorSide="monitor_0",width=51,height=19,pixelWidth=306,pixelHeight=171})
assert(monitor.args[2]==51 and monitor.args[3]==19 and monitor.monitorTouch)
local primitives=require("system.graphics.primitives")
local small=Surface.new(12,12,15)
primitives.line(small,-1e9,5,1e9,5,4)
assert(small.rows[6]==string.rep(string.char(4),12))
primitives.circle(small,6,6,3,0,true)
assert(small.rows[7]:byte(7)==0 and small.rows[1]:byte(1)==15)
local virtual=Legacy.buffer({}) assert(virtual.getGraphicsMode()==false)
assert(not pcall(virtual.setGraphicsMode,2))
local paletteIndex
Legacy.parent({getPaletteColor=function(c) paletteIndex=c end},2).getPaletteColor(32768)
assert(paletteIndex==15,"legacy bitmask was not translated")
print("graphics: indexed surfaces, dirty spans, font, mosaic compatibility, real dimensions, 256/16/text fallback, thaw-on-error and source input passed")
