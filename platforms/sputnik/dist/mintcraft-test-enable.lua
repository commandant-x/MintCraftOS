-- Dedicated physical consent/stop frequency, never an actuator transmitter.
local s=_G.MintCraftConsent
if not s then
 s={label=ui.label('Levier Enable dedie: 0=arret, 15=essais'),a=ui.itempicker(),b=ui.itempicker()}
 _G.MintCraftConsent=s
end
addElement(s.label) addElement(s.a) addElement(s.b)
local emit=output
if false then output('Binding','string') end
local a,b=s.a.getItem(),s.b.getItem() local value=0
if type(a)=='string' and type(b)=='string' and type(receiveWirelessRedstone)=='function' then
 local ok,v=pcall(receiveWirelessRedstone,a,b)
 if ok and type(v)=='number' and v==v and v>=0 and v<=15 then value=v end
end
output('Enable',value)

emit('Binding',type(a)=='string' and type(b)=='string' and (a..','..b) or '')
