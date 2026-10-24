-- Optional Redstone Link gateway. Explicit physical gate, no automatic probing.
-- Configure two native item pickers, and wire Enable/STOP/Signal from graph nodes.
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function item(v) return type(v)=='string' and #v<=192 and v:match('^[a-z0-9_.%-]+:[a-z0-9_./%-]+$') and v~='minecraft:air' end
local state=_G.MintCraftLink
if not state then
 state={seenDisabled=false,lowSamples=0,active=false,reason='Desarme; Enable doit passer par 0 apres chargement'}
 _G.MintCraftLink=state
 state.first=ui.itempicker() state.second=ui.itempicker()
 state.label=ui.label(state.reason)
end
addElement(state.first) addElement(state.second) addElement(state.label)
local enable=input('Enable') local stop=input('STOP') local signal=input('Signal')
local f1,f2=state.first.getItem(),state.second.getItem()
local clock=type(getUniverseTime)=='function' and getUniverseTime() or nil
local live=finite(clock) and clock>0
local enabled=finite(enable) and enable>0 and enable<=15
local stopped=not finite(stop) or stop~=0

local function send(first,second,value)
 if type(transmitWirelessRedstone)~='function' then return false end
 local ok=pcall(transmitWirelessRedstone,first,second,value) return ok
end
-- A changed frequency must first release the previous commanded channel.
local changed=state.f1~=f1 or state.f2~=f2
local regression=live and state.tick~=nil and clock<state.tick
if changed or regression then
 if state.active then send(state.f1,state.f2,0) end
 state.active=false state.seenDisabled=false state.lowSamples=0 state.lowTick=nil
end
state.f1,state.f2=f1,f2
if finite(enable) and enable==0 and live and not regression then
 if state.lowTick==nil or clock>state.lowTick then
  state.lowSamples=(state.lowSamples or 0)+1 state.lowTick=clock
 end
 if state.lowSamples>=2 then state.seenDisabled=true end
elseif enabled and not state.seenDisabled then state.lowSamples=0 state.lowTick=nil end
if live then state.tick=clock end
local valid=live and not regression and item(f1) and item(f2) and finite(signal) and signal>=0 and signal<=15 and finite(enable) and enable>=0 and enable<=15
if stopped or not valid then state.seenDisabled=false state.lowSamples=0 state.lowTick=nil end
local armed=valid and enabled and not stopped and state.seenDisabled
if armed then
 local level=math.floor(signal+.5)
 local ok=send(f1,f2,level)
 state.active=ok state.f1,state.f2=f1,f2
 state.reason=ok and ('Demande Link '..level..'/15; retour bruleur non expose') or 'Emission refusee'
elseif state.active then
 send(state.f1,state.f2,0) state.active=false state.reason='STOP: zero demande au canal precedent'
else state.reason=not live and 'Vue client/horloge absente: etat serveur non expose' or 'Desarme; Enable 0 puis 1, STOP prioritaire' end
state.label.setText(state.reason)
output('Command requested',state.active and 1 or 0)
-- Wireless signal reception is not physical burner/balloon feedback.
output('Burner feedback verified',0)
