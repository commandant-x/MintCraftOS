package.path="./?.lua;"..package.path
local Surface=require("system.graphics.surface")
local keyboard=require("system.graphics.keyboard")
local p={desktop=15,panel=7,button=8,border=8,text=0,muted=8,accent=9,ink=15}
local text,control="",nil
local state={onText=function(c) text=text..c end,onControl=function(c) control=c end}
local surface=Surface.new(154,77,15)
local function draw() keyboard.draw(surface,0,0,154,77,state,p) end
local function press(id,value)
  draw()
  for _,key in ipairs(state.pixelBoxes) do if key.id==id and (not value or key.text==value) then
    assert(key.rect.x>=0 and key.rect.y>=0 and key.rect.x+key.rect.w<=154 and key.rect.y+key.rect.h<=77)
    assert(keyboard.handle({name="mouse_click",args={1,key.rect.x+1,key.rect.y+1}},state)) return
  end end
  error("key missing: "..id..":"..tostring(value))
end
press("shift") press("text","A") assert(text=="A" and not state.shift)
press("caps") press("text","Z") assert(text=="AZ")
press("shift") press("text","e") assert(text=="AZe")
press("ctrl") press("text","R") assert(control=="r" and text=="AZe")
press("ctrl") press("caps") press("symbols") press("text","{") assert(text=="AZe{")
draw()
assert(#keyboard.boxes(0,0,50,30,state)==0,"keyboard overflowed an undersized viewport")
local line=Surface.new(80,30,15)
require("system.graphics.widgets").label(line,0,0,"A\nB",80,0,15)
assert(line.rows[11]==string.rep(string.char(15),80),"single-line label escaped into the next row")
print("pixel keyboard: shared AZERTY, shift/caps XOR, Ctrl, punctuation pages, bounded geometry and small-client glyphs passed")
