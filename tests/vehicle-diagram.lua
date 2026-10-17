package.path="./?.lua;"..package.path
colors={black=32768,gray=128,lightGray=256,cyan=512,orange=2,white=1,lime=32,red=16384,yellow=16,magenta=4,lightBlue=8}
local width,height,calls
local function check(x,y,text)
  assert(x>=1 and y>=1 and x+#text-1<=width and y<=height,"diagram outside viewport")
  calls=calls+1
end
package.loaded["system.gui.renderer"]={color=function(c)
  for i=0,15 do if c==2^i then return string.format("%x",i) end end
  error("invalid color")
end,crop=function(s,w) return s:sub(1,math.max(0,w)) end,writeAt=check,
blitAt=function(x,y,text,fg,bg) assert(#text==#fg and #text==#bg) check(x,y,text) end}
local vehicle=require("system.navigation.vehicle")
local diagram=require("system.navigation.vehicle_diagram")
local profile={type="hexacopter",com={x=0,y=0,z=0},comVerified=true}
local channels={}
for i=1,6 do channels[i]={id="rotor"..i,actuator={role="lift",geometryVerified=true,
 position={x=math.cos(i*math.pi/3)*4,y=0,z=math.sin(i*math.pi/3)*4},direction={x=0,y=1,z=0}}} end
for _,size in ipairs({{12,9},{20,10},{26,17},{80,28}}) do
 width,height=table.unpack(size) calls=0
 for _,side in ipairs({false,true}) do diagram.draw(width,height,vehicle.analyze(profile,channels),profile,side) end
 assert(calls>0)
 diagram.draw(width,height,vehicle.analyze({},{}),vehicle.profile({}),false)
end
print("vehicle top/side diagram: six rotors, unknown geometry, subpixel rows and small viewports passed")
