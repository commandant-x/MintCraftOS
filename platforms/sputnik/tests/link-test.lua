-- The host radio call has no ACK; this fixture verifies only requests and guards.
_G.MintCraftLinkTest=nil
ui={label=function() return {setText=function() end} end,
 itempicker=function() local c={v='minecraft:air'};c.getItem=function() return c.v end;return c end,
 checkbox=function() local c={v=false};c.isChecked=function() return c.v end;return c end}
local tick=100 local nativeServer=true local writes,out={},{}
getUniverseTime=function() return tick end getShipMass=function() return 0 end -- no vehicle required
addElement=function() end output=function(k,v) out[k]=v end display=function() end
transmitWirelessRedstone=function(a,b,v) if nativeServer then writes[#writes+1]={a,b,v} end end
local node=assert(loadfile('platforms/sputnik/dist/mintcraft-link-test.lua'))
local function step() tick=tick+1;node() end
step();assert(#writes==0)
local s=_G.MintCraftLinkTest
s.a.v='minecraft:diamond';s.b.v='minecraft:emerald';s.on.v=true;step()
assert(#writes==0,'boot/remap-high emitted without low baseline')
s.on.v=false;step();s.on.v=true;step()
assert(writes[#writes][3]==15 and out['Requested signal']==15,'lamp test blocked by missing mass/calibration')
local count=#writes;step();assert(#writes==count+1,'TTL emission not refreshed')
s.b.v='minecraft:gold_ingot';step()
assert(writes[#writes][2]=='minecraft:emerald' and writes[#writes][3]==0,'remap did not clear original channel')
step();assert(out['Requested signal']==0,'held checkbox retargeted new channel')
s.on.v=false;step();s.on.v=true;step();assert(writes[#writes][2]=='minecraft:gold_ingot' and writes[#writes][3]==15)
s.on.v=false;step();assert(writes[#writes][3]==0)
s.on.v=true;step();tick=0;node();assert(out['Requested signal']==15 and writes[#writes][3]==15,'radio test depends on flight clock')
count=#writes;nativeServer=false;node();assert(#writes==count,'native client no-op was misrepresented as physical transmission')
print('Isolated lamp radio: no vehicle/calibration needed, explicit low-high gate, TTL refresh, old-frequency cleanup, remap latch and clock-independent operation/native client no-op passed; no physical reception proof')
