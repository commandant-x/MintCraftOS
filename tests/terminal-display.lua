package.path="./?.lua;"..package.path
local cfg={displayTarget="auto"}
package.loaded["system.libraries.log"]={info=function() end,error=function() end}
package.loaded["system.libraries.config"]={load=function() return cfg end,save=function(_,v) cfg=v return true end}
local native={getSize=function() return 51,19 end}
local current=native local width,height,attached,broken=80,30,true,false
local terminal={getSize=function() if broken then error("removed") end return width,height end,isColor=function() return true end,
  setTextScale=function() error("terminal must not receive monitor-only methods") end}
term={native=function() return native end,current=function() return current end,redirect=function(t) current=t end}
peripheral={getNames=function() return attached and {"terminal_0","terminal_1"} or {} end,
  getType=function() return "terminal" end,wrap=function() return terminal end}
local eventBus=require("system.kernel.event_bus").new()
local devices=require("system.services.deviced")
devices.start({eventBus=eventBus})
assert(devices.getTarget()==native,"terminal automatically stole the native workspace")
assert(#devices.listDisplays()==4 and devices.listDisplays()[3].type=="terminal")
assert(devices.setTarget("terminal_0"))
local d=devices.getDisplay()
assert(d.target=="terminal" and d.terminalSide=="terminal_0" and d.mouse and d.keyboard and d.scale==nil)
assert(not devices.setScale(2) and not cfg.displayScales,"monitor scale was saved for a terminal")
local input=require("system.kernel.input")
d.pixelWidth,d.pixelHeight=480,270
local click=input.normalize({"terminal_mouse_click","terminal_0",1,479,269},d)
assert(click.name=="mouse_click" and click.args[2]==80 and click.args[3]==30 and click.pixelX==479 and click.terminalSide=="terminal_0")
assert(not input.normalize({"terminal_mouse_click","terminal_1",1,0,0},d))
assert(not input.normalize({"char","x"},d) and not input.normalize({"key",1},d) and not input.normalize({"mouse_click",1,0,0},d))
assert(input.normalize({"terminal_paste","terminal_0","text"},d).args[1]=="text")
local key=input.normalize({"terminal_key","terminal_0",15,false},d)
assert(key.args[1]==15 and key.args[2]==false)
assert(not input.normalize({"terminal_rednet_message","terminal_0",12},d))
d.mouse=false assert(not input.normalize({"terminal_mouse_click","terminal_0",1,0,0},d))
width,height=100,40
local invalidated,queued=0,0
devices.ctx.invalidateDisplay=function() invalidated=invalidated+1 end
os.queueEvent=function(name) assert(name=="mintcraft_display_resize") queued=queued+1 end
assert(devices.refreshSize() and devices.getDisplay().width==100 and invalidated==1 and queued==1)
assert(not devices.refreshSize() and invalidated==1)
broken=true assert(not devices.refreshSize() and devices.getTarget()==native)
broken=false attached=false eventBus:emit("peripheral_detach","terminal_0")
assert(devices.getPreference()=="terminal_0" and devices.getDisplay().target=="computer")
attached=true eventBus:emit("peripheral","terminal_0") assert(devices.getTarget()==terminal)
devices.stop() assert(current==native)
print("terminal display: explicit selection, no monitor-only scale, source-isolated keys/paste/pixels, resize polling, detach/fallback and reconnect passed")
