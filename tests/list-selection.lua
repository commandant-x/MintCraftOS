package.path="./?.lua;"..package.path
colors={black=32768,cyan=512}
local calls={}
package.loaded["system.gui.theme"]={get=function(key) return key=="windowBg" and 128 or 1 end}
package.loaded["system.gui.renderer"]={crop=function(s) return s end,writeAt=function(x,y,text,fg,bg) calls[#calls+1]={fg=fg,bg=bg} end}
local ui=require("system.gui.components")
ui.list(1,1,20,4,{"file"},nil,1,function(s) return s end)
for _,call in ipairs(calls) do assert(call.bg==128 and call.fg==1,"empty row selected or dark-theme text unreadable") end
calls={}
ui.list(1,1,20,3,{"file"},"file",1,function(s) return s end)
assert(calls[1].bg==512 and calls[1].fg==32768 and calls[2].bg==128)
print("lists: nil rows are not selected and unselected text follows the theme")
