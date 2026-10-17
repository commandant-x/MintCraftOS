package.path="./?.lua;"..package.path
colors={white=1,orange=2,lightBlue=8,yellow=16,lime=32,pink=64,gray=128,lightGray=256,cyan=512,purple=1024,blue=2048,brown=4096,green=8192,red=16384,black=32768}
local instruments=require("system.navigation.instruments")
local function render(rows,network)
  local canvas,_,labels=instruments.radar(80,32,{radars=rows,targets={}},rows[1].id,nil,{three=true,network=network,yaw=30,pitch=25})
  local signature,green,yellow={},0,0
  for y=1,32 do local a,b,c=canvas:getLine(y) signature[#signature+1]=a..b..c
    for digit in (b..c):gmatch('.') do if digit=='d' or digit=='5' then green=green+1 elseif digit=='4' then yellow=yellow+1 end end
  end
  return table.concat(signature),green,yellow,labels
end
local row={id="a",name="A",position={x=0,y=0,z=0},range=1000}
local _,green,yellow=render({row},false)
assert(green>40 and yellow==0,"3D range circle missing or unknown heading invented")
row.heading=0 row.fov=90 row.halfHeight=100 row.running=true
local a,_,sweep=render({row},false) assert(sweep>0,"real sweep ray missing")
row.heading=90 local b=render({row},false) assert(a~=b,"scanner orientation did not rotate beam")
row.running=false local _,_,off=render({row},false) assert(off==0,"stopped radar still sweeping")
row.running=true
local other={id="b",name="B",position={x=1200,y=100,z=400},range=600,heading=180,fov=60,halfHeight=80,running=true,remote=true}
local _,_,multiple,labels=render({row,other},true)
assert(multiple>0 and #labels==2,"multi radar circles/beam labels absent")
local snap={radars={row},targets={}}
local view={three=true,yaw=41,pitch=32}
local first=instruments.radar(70,30,snap,"a",nil,view)
local before=instruments.stats()
snap.targets={{id="contact",label="Contact",position={x=30,y=0,z=20},history={}}}
instruments.radar(70,30,snap,"a","contact",view)
local after=instruments.stats()
assert(after.backgroundBuilds==before.backgroundBuilds and after.backgroundHits==before.backgroundHits+1,"contact redraw rebuilt static geometry")
snap.targets={}
local third=instruments.radar(70,30,snap,"a",nil,view)
for y=1,30 do
  local a,b,c=first:getLine(y) local x,z,q=third:getLine(y)
  assert(a..b..c==x..z..q,"contact overlay contaminated cached background")
end
print("radar 3D rings, measured beams, rotation, stopped state and multi-sensor volume passed")
