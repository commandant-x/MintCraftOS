-- Explicit mocked Sputnik APIs. Never observations or flight certificates.
local realLoadfile=loadfile
local tick,values,writes,radioWrites=100,{}, {},{}
getUniverseTime=function() return tick end
getPosition=function() return 1,70,2 end
getVelocity=function() return .1,.2,.3 end
getOrientation=function() return 0,20,0 end
getShipMass=function() return 12 end
getDimension=function() return 'minecraft:overworld' end
getPeripheralIds=function() return {'41','99'} end
getPeripheralType=function() return 'fixture' end
input=function(name) return values[name] or 0 end
local outputs={} output=function(name,value) outputs[name]=value end
local elements={}
ui={label=function(text) return {text=text,setText=function() end} end,
 button=function() return {wasClicked=function() return false end} end,
 itempicker=function()
  local e={item=nil} e.getItem=function() return e.item end elements[#elements+1]=e return e
 end}
addElement=function() end
transmitWirelessRedstone=function(a,b,value) writes[#writes+1]={a,b,value} end
sendPacket=function(channel,code,value) radioWrites[#radioWrites+1]={channel,code,value} end
receivePacket=function() return 0 end
local dashboard=assert(realLoadfile('platforms/sputnik/dist/mintcraft-dashboard.lua'))
local gateway=assert(realLoadfile('platforms/sputnik/dist/mintcraft-link-gateway.lua'))
local radio=assert(realLoadfile('platforms/sputnik/dist/mintcraft-numeric-radio.lua'))
-- Remove host access exactly as far as the port needs: files/HTTP/CC absent.
local savedOs,savedIo,savedRequire=os,io,require
os=nil io=nil require=nil fs=nil http=nil peripheral=nil shell=nil term=nil
assert(pcall(dashboard))
assert(#writes==0 and outputs['Flight qualified']==0 and outputs['Telemetry valid']==1)
local sdk=assert(MintCraftSputnik.require)
local library=assert(realLoadfile('platforms/sputnik/dist/mintcraft-library.lua'))()
assert(library('system.navigation.known_flight'))
assert(sdk('system.navigation.response_model').axes[3]=='vertical')
assert(sdk('system.navigation.altitude_sweep').defaults().maxTravel==0)
assert(sdk('system.navigation.measured_controller')) assert(sdk('system.navigation.state_estimator'))
assert(not pcall(sdk,'system.services.flightd'),'CC service silently substituted into native SDK')
tick=99 dashboard() assert(MintCraftSputnik.clockFault and outputs['Telemetry valid']==0)
tick=0 dashboard() assert(not MintCraftSputnik.clockAvailable and outputs['Telemetry valid']==0)
tick=101 getShipMass=function() return 0 end dashboard() assert(outputs['Telemetry valid']==0,'missing server mass became actual ship telemetry')
-- A high Enable at load never arms; physical zero must be observed first.
values={Enable=1,Signal=5} gateway() assert(#writes==0)
elements[1].item='minecraft:iron_ingot' elements[2].item='minecraft:gold_ingot'
gateway() assert(#writes==0)
values.Enable=0 tick=tick+1 gateway() values.Enable=1 tick=tick+1 gateway() assert(#writes==0,'single initial graph-default zero armed a held-high command')
values.Enable=0 tick=tick+1 gateway() tick=tick+1 gateway() values.Enable=1 tick=tick+1 gateway() assert(#writes==1 and writes[1][3]==5)
values.STOP=1 gateway() assert(writes[#writes][3]==0)
local n=#writes values.STOP=0 gateway() assert(#writes==n,'STOP release rearmed without Enable cycling')
values.Enable=0 tick=tick+1 gateway() tick=tick+1 gateway() values.Enable=1 tick=tick+1 gateway() assert(writes[#writes][3]==5)
elements[2].item='minecraft:diamond' gateway() assert(writes[#writes][2]=='minecraft:gold_ingot' and writes[#writes][3]==0,'old channel not released before remapping')
n=#writes gateway() assert(#writes==n)
values.Enable=0 tick=tick+1 gateway() tick=tick+1 gateway() values.Enable=1 tick=tick+1 gateway() assert(writes[#writes][2]=='minecraft:diamond')
tick=100 gateway() assert(writes[#writes][3]==0,'clock regression kept command active')
tick=102 n=#writes gateway() assert(#writes==n,'clock recovery rearmed held Enable')
values.Enable=0 tick=tick+1 gateway() tick=tick+1 gateway() values.Enable=1 tick=tick+1 gateway()
values.Signal=0/0 gateway() assert(writes[#writes][3]==0,'NaN command left previous signal active')
values.Signal=16 n=#writes gateway() assert(#writes==n,'out-of-range signal emitted')
assert(outputs['Burner feedback verified']==0,'wireless command became physical burner feedback')
-- Numeric radio never broadcasts on boot, on held-high inputs or replay/regression.
values={Channel=10,Code=20,Value=30,Transmit=1} radio() assert(#radioWrites==0)
values.Transmit=0 radio() values.Transmit=1 radio() assert(#radioWrites==1)
radio() assert(#radioWrites==1)
tick=90 radio() values.Transmit=0 radio() values.Transmit=1 radio() assert(#radioWrites==2)
assert(outputs.Authenticated==0 and outputs['Fresh feedback']==0)
os,io,require=savedOs,savedIo,savedRequire
print('Sputnik port: no CC/files/HTTP, actual SDK modules, no boot actuation, explicit physical arm/STOP/remap/clock guards, malformed signal refusal and unauthenticated stale radio semantics passed')
