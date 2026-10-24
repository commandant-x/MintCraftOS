-- Isolated lamp-only radio diagnostic. Never connect its frequency to propulsion.
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function item(v) return type(v)=='string' and #v<=192 and v~='minecraft:air' and v:match('^[a-z0-9_.%-]+:[a-z0-9_./%-]+$') end
local s=_G.MintCraftLinkTest
if not s then
 s={label=ui.label('TEST LAMPE UNIQUEMENT: frequence reservee, jamais les moteurs'),a=ui.itempicker(),b=ui.itempicker(),on=ui.checkbox('Emettre 15 sur la frequence de TEST LAMPE'),ready=false}
 _G.MintCraftLinkTest=s
end
addElement(s.label) addElement(s.a) addElement(s.b) addElement(s.on)
local emit=output
if false then output('Status','string') output('Requested signal',0) output('Universe clock available',0) end
local a,b=s.a.getItem(),s.b.getItem()
local tick=type(getUniverseTime)=='function' and getUniverseTime() or nil
local server=finite(tick) and tick>0
-- Native transmitWirelessRedstone itself ignores client calls. No flight clock
-- or vehicle prerequisite is used by this isolated diagnostic.
local function clear()
 if s.owner and type(transmitWirelessRedstone)=='function' then pcall(transmitWirelessRedstone,s.owner[1],s.owner[2],0) end
 s.owner=nil
end
local valid=item(a) and item(b) and type(transmitWirelessRedstone)=='function'
local sig=tostring(a)..','..tostring(b)
local changed=s.signature and s.signature~=sig
local checked=s.on.isChecked()
if changed or not valid then clear() s.ready=false end
local requested=0
local reason='Configurer une paire reservee puis decocher avant activation'
if not checked then clear() s.ready=valid reason='Test desactive; pret apres sauvegarde'
elseif valid and s.ready and not changed then
 local ok=pcall(transmitWirelessRedstone,a,b,15)
 if ok then s.owner={a,b} requested=15 reason='Appel emission 15 effectue; verifier la lampe, aucun ACK physique'
 else clear() s.ready=false reason='Erreur API emission; decocher puis sauvegarder' end
end
s.signature=sig s.tick=tick
s.label.setText(reason)
emit('Status',reason) emit('Requested signal',requested) emit('Universe clock available',server and 1 or 0)
if type(display)=='function' then display('MC_LINK_TEST',reason) end
