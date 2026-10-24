local tick,mass,enable=100,100,0
local bus,controls,out={},{},{}
_G.MintCraftTypewriter=nil
ui={label=function() return {setText=function() end} end,
 checkbox=function() local c={v=false};c.isChecked=function() return c.v end;return c end,
 itempicker=function() local c={v='minecraft:air'};c.getItem=function() return c.v end;return c end}
addElement=function() end
getUniverseTime=function() return tick end getShipMass=function() return mass end
input=function() return enable end output=function(k,v) out[k]=v end
receiveWirelessRedstone=function(a,b) return bus[a..','..b] or 0 end
transmitWirelessRedstone=function() error('keyboard must never transmit') end
local node=assert(loadfile('platforms/sputnik/dist/mintcraft-typewriter.lua'))
local function step() tick=tick+1;node() end
node() local s=_G.MintCraftTypewriter
local names={'W','S','Q','D','Space','Shift'}
for i,name in ipairs(names) do
 s.keys[name].a.v='minecraft:stone' s.keys[name].b.v='minecraft:item_'..i
 controls[name]='minecraft:stone,minecraft:item_'..i
end
s.verified.v=true
local function arm() enable=0;bus={};step();step();step();enable=15;step();assert(out['Commands valid']==1) end
arm()
bus[controls.W]=15;step();assert(out['Forward demand']==1)
bus[controls.Q]=15;step();assert(math.abs(out['Forward demand']-1/math.sqrt(2))<1e-9 and out['Left demand']==out['Forward demand'])
bus[controls.S]=15;bus[controls.D]=15;step();assert(out['Forward demand']==0 and out['Left demand']==0)
bus[controls.Space]=1;step();assert(out['Vertical demand']==1)
bus[controls.Shift]=15;step();assert(out['Vertical demand']==0)
bus={};step();assert(out['Hold requested']==1)
enable=0;step();assert(out['Commands valid']==0)
-- A held key cannot arm, including boot-high.
s.armed=false;s.low=0;enable=15;bus[controls.W]=15;step();assert(out['Commands valid']==0)
arm();s.keys.S.b.v=s.keys.W.b.v;step();assert(out['Commands valid']==0)
s.keys.S.b.v='minecraft:item_2';arm()
bus[controls.W]=0/0;step();assert(out['Commands valid']==0)
arm();tick=tick+20;step();assert(out['Commands valid']==0)
arm();mass=0;step();assert(out['Commands valid']==0 and out['Forward demand']==0)
mass=100;arm();tick=tick-5;node();assert(out['Commands valid']==0)
assert(out['Flight qualified']==0)
print('Typewriter: six unique receivers, diagonal normalization, opposites, vertical intent, release, low-before-enable, remap/malformed/clock/mass refusal; no actuator writes passed')
